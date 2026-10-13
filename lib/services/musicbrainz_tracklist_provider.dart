import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track_entry.dart';
import 'tracklist_matcher.dart';
import 'tracklist_provider.dart';

/// Implementação do provedor de tracklists utilizando a API oficial do MusicBrainz.
/// Possui gate de taxa serializado (>= 1100ms entre requisições), retry único para 429/503
/// e pré-pontuação para priorizar mídias de vinil e edições oficiais.
class MusicBrainzTracklistProvider implements TracklistProvider {
  static const String _userAgent = 'WaxClub/1.0 (contact@waxclub.app)';
  static const int _minIntervalMs = 1100;

  // Heurísticas de pontuação para seleção de candidatos
  static const int kScoreAlbumTitleMatch = 40;
  static const int kScoreVinylFormat = 25;
  static const int kScoreOfficialStatus = 15;
  static const int kScoreAlbumPrimaryType = 10;
  static const int kScoreSecondaryPenalty = -30;

  final http.Client _client;
  final bool _isCustomClient;

  DateTime? _lastRequestStart;
  Future<void>? _rateGateQueue;

  MusicBrainzTracklistProvider({http.Client? client})
      : _client = client ?? http.Client(),
        _isCustomClient = client != null;

  /// Gate de taxa serializado obrigatório do MusicBrainz (máximo ~1 req/s).
  Future<http.Response> _executeWithRateGate(Uri uri) {
    final completer = (_rateGateQueue ?? Future.value()).then((_) async {
      if (_lastRequestStart != null) {
        final elapsed = DateTime.now().difference(_lastRequestStart!).inMilliseconds;
        if (elapsed < _minIntervalMs) {
          await Future.delayed(Duration(milliseconds: _minIntervalMs - elapsed));
        }
      }
      _lastRequestStart = DateTime.now();

      http.Response res;
      try {
        res = await _client.get(uri, headers: {
          'User-Agent': _userAgent,
        }).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[MusicBrainz] Erro de rede em $uri: $e');
        rethrow;
      }

      // Tratamento de rate limit com retry único
      if (res.statusCode == 429 || res.statusCode == 503) {
        int retrySeconds = 3;
        final retryHeader = res.headers['retry-after'];
        if (retryHeader != null) {
          retrySeconds = int.tryParse(retryHeader) ?? 3;
        }
        debugPrint('[MusicBrainz] Rate limit (${res.statusCode}). Aguardando ${retrySeconds}s para retry...');
        await Future.delayed(Duration(seconds: retrySeconds));
        _lastRequestStart = DateTime.now();

        res = await _client.get(uri, headers: {
          'User-Agent': _userAgent,
        }).timeout(const Duration(seconds: 10));
      }

      return res;
    });

    _rateGateQueue = completer.then((_) => null).catchError((_) => null);
    return completer;
  }

  @override
  Future<List<ReleaseCandidate>> searchReleases({
    required String title,
    required String artist,
    String? album,
  }) async {
    try {
      final cleanTitle = TracklistMatcher.normalize(title);
      final cleanArtist = TracklistMatcher.normalize(artist);

      final queryTitle = cleanTitle.replaceAll('"', '\\"');
      final queryArtist = cleanArtist.replaceAll('"', '\\"');

      final searchUrl = Uri.parse(
        'https://musicbrainz.org/ws/2/recording?query=recording:"$queryTitle" AND artist:"$queryArtist"&limit=25&fmt=json',
      );

      final response = await _executeWithRateGate(searchUrl);
      if (response.statusCode != 200) {
        debugPrint('[MusicBrainz] Busca de gravações falhou: HTTP ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final recordings = data['recordings'] as List<dynamic>?;
      if (recordings == null || recordings.isEmpty) return [];

      final candidatesMap = <String, ReleaseCandidate>{};

      for (final rec in recordings) {
        if (rec is! Map<String, dynamic>) continue;
        final releases = rec['releases'] as List<dynamic>?;
        if (releases == null) continue;

        for (final rel in releases) {
          if (rel is! Map<String, dynamic>) continue;
          final relId = rel['id'] as String?;
          final relTitle = rel['title'] as String?;
          if (relId == null || relTitle == null || candidatesMap.containsKey(relId)) continue;

          String? format;
          final media = rel['media'] as List<dynamic>?;
          if (media != null && media.isNotEmpty) {
            format = media[0]['format'] as String?;
          }

          final status = rel['status'] as String?;
          final releaseGroup = rel['release-group'] as Map<String, dynamic>?;
          final primaryType = releaseGroup?['primary-type'] as String?;

          final secondaryList = <String>[];
          final secTypes = releaseGroup?['secondary-types'] as List<dynamic>?;
          if (secTypes != null) {
            for (final st in secTypes) {
              if (st is String) secondaryList.add(st);
            }
          }

          candidatesMap[relId] = ReleaseCandidate(
            providerId: 'musicbrainz',
            releaseId: relId,
            albumTitle: relTitle,
            format: format,
            status: status,
            primaryType: primaryType,
            secondaryTypes: secondaryList,
            artistName: _artistCredit(rel['artist-credit']) ?? _artistCredit(rec['artist-credit']),
            year: _year(rel['date'] as String?),
            country: rel['country'] as String?,
            coverUrl: 'https://coverartarchive.org/release/$relId/front-250',
            trackCount: (rel['track-count'] as num?)?.toInt(),
            groupId: releaseGroup?['id'] as String?,
          );
        }
      }

      // Pré-pontuação dos candidatos
      final scoredCandidates = candidatesMap.values.toList();
      scoredCandidates.sort((a, b) {
        final scoreA = _calculatePreScore(a, album);
        final scoreB = _calculatePreScore(b, album);
        return scoreB.compareTo(scoreA);
      });

      return scoredCandidates;
    } catch (e) {
      debugPrint('[MusicBrainz] Erro em searchReleases: $e');
      return [];
    }
  }

  /// Prensagens com este código de barras (EAN/UPC).
  Future<List<ReleaseCandidate>> searchByBarcode(String barcode) {
    final code = barcode.replaceAll(RegExp(r'\D'), '');
    return code.isEmpty ? Future.value(const []) : searchReleasesByText('barcode:$code', raw: true);
  }

  /// Prensagens com este número de catálogo.
  Future<List<ReleaseCandidate>> searchByCatalogNumber(String catno) {
    final q = catno.trim().replaceAll('"', '');
    return q.isEmpty ? Future.value(const []) : searchReleasesByText('catno:"$q"', raw: true);
  }

  /// Busca livre de discos (escolha manual do usuário): "disco", "artista disco"...
  /// [raw]: [query] já está na sintaxe de busca do MusicBrainz (ex.: `barcode:...`).
  Future<List<ReleaseCandidate>> searchReleasesByText(String query, {bool raw = false}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final url = Uri.https('musicbrainz.org', '/ws/2/release', {'query': q, 'limit': raw ? '50' : '40', 'fmt': 'json'});
      final response = await _executeWithRateGate(url);
      if (response.statusCode != 200) {
        debugPrint('[MusicBrainz] Busca livre falhou: HTTP ${response.statusCode}');
        return [];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final releases = data['releases'] as List<dynamic>? ?? const [];
      final result = <ReleaseCandidate>[];
      for (final rel in releases) {
        if (rel is! Map<String, dynamic>) continue;
        final relId = rel['id'] as String?;
        final relTitle = rel['title'] as String?;
        if (relId == null || relTitle == null) continue;
        final media = rel['media'] as List<dynamic>?;
        final releaseGroup = rel['release-group'] as Map<String, dynamic>?;
        result.add(ReleaseCandidate(
          providerId: 'musicbrainz',
          releaseId: relId,
          albumTitle: relTitle,
          format: (media != null && media.isNotEmpty) ? media[0]['format'] as String? : null,
          status: rel['status'] as String?,
          primaryType: releaseGroup?['primary-type'] as String?,
          secondaryTypes: [
            for (final st in (releaseGroup?['secondary-types'] as List<dynamic>? ?? const []))
              if (st is String) st,
          ],
          artistName: _artistCredit(rel['artist-credit']),
          year: _year(rel['date'] as String?),
          country: rel['country'] as String?,
          coverUrl: 'https://coverartarchive.org/release/$relId/front-250',
          trackCount: (rel['track-count'] as num?)?.toInt(),
          label: _labelInfo(rel, 'label'),
          catalogNumber: _labelInfo(rel, 'catalog-number'),
          barcode: (rel['barcode'] as String?)?.isNotEmpty == true ? rel['barcode'] as String : null,
          groupId: releaseGroup?['id'] as String?,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('[MusicBrainz] Erro na busca livre: $e');
      return [];
    }
  }

  /// Primeira gravadora (`label`) ou nº de catálogo (`catalog-number`) de `label-info`.
  static String? _labelInfo(Map<String, dynamic> rel, String field) {
    final info = rel['label-info'];
    if (info is! List) return null;
    for (final i in info) {
      if (i is! Map) continue;
      final v = field == 'label' ? (i['label'] is Map ? i['label']['name'] : null) : i['catalog-number'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static String? _artistCredit(dynamic credit) {
    if (credit is! List || credit.isEmpty) return null;
    final buffer = StringBuffer();
    for (final c in credit) {
      if (c is! Map) continue;
      buffer.write(c['name'] ?? (c['artist'] is Map ? c['artist']['name'] : '') ?? '');
      buffer.write(c['joinphrase'] ?? '');
    }
    final s = buffer.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _year(String? date) => (date != null && date.length >= 4) ? date.substring(0, 4) : null;

  int _calculatePreScore(ReleaseCandidate c, String? targetAlbum) {
    int score = 0;

    final normAlbumTarget = targetAlbum != null ? TracklistMatcher.normalize(targetAlbum) : '';
    final albumSimilarity = normAlbumTarget.isNotEmpty
        ? TracklistMatcher.similarity(c.albumTitle, normAlbumTarget)
        : 0.0;

    if (albumSimilarity >= 0.85) {
      score += kScoreAlbumTitleMatch;
    }

    final formatLower = (c.format ?? '').toLowerCase();
    if (formatLower.contains('vinyl') ||
        formatLower.contains('lp') ||
        formatLower.contains('12"') ||
        formatLower.contains('10"') ||
        formatLower.contains('7"')) {
      score += kScoreVinylFormat;
    }

    if (c.status == 'Official') {
      score += kScoreOfficialStatus;
    }

    if (c.primaryType == 'Album') {
      score += kScoreAlbumPrimaryType;
    }

    final hasSecondaryPenalty = c.secondaryTypes.any((t) =>
        t == 'Compilation' ||
        t == 'Live' ||
        t == 'Soundtrack' ||
        t == 'Remix' ||
        t == 'Demo' ||
        t == 'Bootleg');

    if (hasSecondaryPenalty && albumSimilarity < 0.85) {
      score += kScoreSecondaryPenalty;
    }

    return score;
  }

  @override
  Future<List<TrackEntry>> loadTracklist(ReleaseCandidate candidate) async {
    try {
      final detailUrl = Uri.parse(
        'https://musicbrainz.org/ws/2/release/${candidate.releaseId}?inc=recordings&fmt=json',
      );

      final response = await _executeWithRateGate(detailUrl);
      if (response.statusCode != 200) {
        debugPrint('[MusicBrainz] Falha ao carregar release ${candidate.releaseId}: HTTP ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final mediaList = data['media'] as List<dynamic>?;
      if (mediaList == null || mediaList.isEmpty) return [];

      final entries = <TrackEntry>[];
      int globalPosition = 1;

      for (final media in mediaList) {
        if (media is! Map<String, dynamic>) continue;
        final tracks = media['tracks'] as List<dynamic>?;
        if (tracks == null) continue;

        for (final track in tracks) {
          if (track is! Map<String, dynamic>) continue;
          final title = track['title'] as String?;
          if (title == null || title.trim().isEmpty) continue;

          final numberStr = track['number']?.toString();
          final length = (track['length'] as num?)?.toInt();

          String? side;
          if (numberStr != null) {
            final match = RegExp(r'^([A-Za-z]+)\d+$').firstMatch(numberStr.trim());
            if (match != null) {
              side = match.group(1)!.toUpperCase();
            }
          }

          entries.add(TrackEntry(
            position: globalPosition++,
            title: title.trim(),
            number: numberStr,
            side: side,
            lengthMs: length,
          ));
        }
      }

      return entries;
    } catch (e) {
      debugPrint('[MusicBrainz] Erro em loadTracklist para ${candidate.releaseId}: $e');
      return [];
    }
  }

  @override
  void dispose() {
    if (!_isCustomClient) {
      _client.close();
    }
  }
}
