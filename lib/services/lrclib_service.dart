import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'tracklist_matcher.dart';

/// Resultado detalhado da busca na LRCLIB, contendo letra sincronizada e metadados.
class LrcResponse {
  /// Conteúdo das letras no formato .lrc sincronizado
  final String? syncedLyrics;

  /// Duração oficial da faixa em segundos (fornecida pelo catálogo de estúdio)
  final double? durationSeconds;

  /// Nome do álbum associado
  final String? albumName;

  /// Origem do LRC ('lrclib' | 'netease' | 'megalobiz' | 'lyrics.ovh')
  final String? source;

  /// Letra em texto simples (sem timestamps), usada como último recurso quando não há versão sincronizada.
  final String? plainLyrics;

  const LrcResponse({
    this.syncedLyrics,
    this.durationSeconds,
    this.albumName,
    this.source,
    this.plainLyrics,
  });
}

/// Cliente para consumo da API pública da LRCLIB (https://lrclib.net).
class LrcLibService {
  final http.Client _client;
  static const String _baseUrl = 'https://lrclib.net/api';

  LrcLibService({http.Client? client}) : _client = client ?? http.Client();

  /// Busca letras sincronizadas e metadados oficiais (incluindo duração exata).
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    try {
      final queryParams = {
        'track_name': _cleanSearchTerm(trackName),
        'artist_name': _cleanSearchTerm(artistName),
      };

      if (albumName != null && albumName.isNotEmpty) {
        queryParams['album_name'] = _cleanSearchTerm(albumName);
      }
      if (durationSeconds != null && durationSeconds > 0) {
        queryParams['duration'] = durationSeconds.toString();
      }

      final uri = Uri.parse('$_baseUrl/get').replace(queryParameters: queryParams);
      final response = await _client.get(uri, headers: {
        'User-Agent': 'WaxClub/1.0 (https://github.com/waxclub)',
      }).timeout(const Duration(seconds: 10));

      LrcResponse? exact;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        exact = LrcResponse(
          syncedLyrics: data['syncedLyrics'] as String?,
          durationSeconds: (data['duration'] as num?)?.toDouble(),
          albumName: data['albumName'] as String?,
          source: 'lrclib',
          plainLyrics: data['plainLyrics'] as String?,
        );
        if (_hasText(exact.syncedLyrics)) return exact;
      }

      // A rota exata falhou OU só trouxe texto simples (ex.: a versão de um álbum sem LRC, enquanto outra
      // edição da mesma música tem LRC sincronizado): tenta a busca ampla antes de desistir do sincronizado.
      final searched = await _fallbackSearchDetails(
        trackName: trackName,
        artistName: artistName,
        durationSeconds: durationSeconds?.toDouble() ?? exact?.durationSeconds,
      );
      if (searched != null && _hasText(searched.syncedLyrics)) return searched;

      // Sem versão sincronizada em lugar nenhum: devolve o texto simples encontrado (sem marcar como LRC)
      final plain = _hasText(exact?.plainLyrics) ? exact : searched;
      if (plain == null) return null;
      return LrcResponse(
        durationSeconds: plain.durationSeconds,
        albumName: plain.albumName,
        source: 'lrclib',
        plainLyrics: plain.plainLyrics,
      );
    } catch (e) {
      debugPrint('[LrcLibService] Erro ao buscar detalhes da letra: $e');
      return null;
    }
  }

  static bool _hasText(String? s) => s != null && s.trim().isNotEmpty;

  /// Instante (s) do último timestamp de um LRC, para validar coerência com a duração da faixa.
  static double? _lastTimestampSeconds(String lrc) {
    final matches = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]').allMatches(lrc);
    if (matches.isEmpty) return null;
    final m = matches.last;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!).toDouble();
  }

  /// Busca letras sincronizadas na LRCLIB pelo título da faixa e artista.
  Future<String?> fetchSyncedLyrics({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    final details = await fetchLyricsDetails(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      durationSeconds: durationSeconds,
    );
    return details?.syncedLyrics;
  }

  /// Busca ampla na API (`/search`) quando a rota exata falha ou não tem LRC sincronizado.
  ///
  /// Só aceita resultados do mesmo artista e título. Entre os sincronizados, prefere os coerentes
  /// (último timestamp dentro da duração declarada) e, quando a duração esperada é conhecida, o mais próximo dela.
  Future<LrcResponse?> _fallbackSearchDetails({
    required String trackName,
    required String artistName,
    double? durationSeconds,
  }) async {
    try {
      final cleanTrack = _cleanSearchTerm(trackName);
      final cleanArtist = _cleanSearchTerm(artistName);

      final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'track_name': cleanTrack,
        'artist_name': cleanArtist,
      });
      final response = await _client.get(uri, headers: {
        'User-Agent': 'WaxClub/1.0 (https://github.com/waxclub)',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final list = jsonDecode(response.body) as List<dynamic>;

      final matching = <Map<String, dynamic>>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final title = item['trackName'] as String? ?? '';
        final artist = item['artistName'] as String? ?? '';
        if (TracklistMatcher.isSameTitle(title, trackName) && TracklistMatcher.isSameArtist(artist, artistName)) {
          matching.add(item);
        }
      }
      if (matching.isEmpty) return null;

      final synced = matching.where((i) => _hasText(i['syncedLyrics'] as String?)).toList();
      if (synced.isNotEmpty) {
        double score(Map<String, dynamic> item) {
          final dur = (item['duration'] as num?)?.toDouble();
          final last = _lastTimestampSeconds(item['syncedLyrics'] as String);
          double s = 0;
          // LRC que termina depois do fim declarado da faixa é inconsistente (edição/duração trocada)
          if (dur != null && last != null && last > dur + 2) s += 1000;
          if (durationSeconds != null && dur != null) s += (dur - durationSeconds).abs();
          return s;
        }
        synced.sort((a, b) => score(a).compareTo(score(b)));
        final best = synced.first;
        return LrcResponse(
          syncedLyrics: best['syncedLyrics'] as String,
          durationSeconds: (best['duration'] as num?)?.toDouble(),
          albumName: best['albumName'] as String?,
          source: 'lrclib',
          plainLyrics: best['plainLyrics'] as String?,
        );
      }

      final plain = matching.firstWhere(
        (i) => _hasText(i['plainLyrics'] as String?),
        orElse: () => matching.first,
      );
      return LrcResponse(
        durationSeconds: (plain['duration'] as num?)?.toDouble(),
        albumName: plain['albumName'] as String?,
        source: 'lrclib',
        plainLyrics: plain['plainLyrics'] as String?,
      );
    } catch (e) {
      debugPrint('[LrcLibService] Erro na busca fallback: $e');
      return null;
    }
  }

  /// Remove caracteres especiais ou sufixos comuns que possam poluir a busca (ex: "(Remastered 2011)").
  static String _cleanSearchTerm(String text) {
    return text
        .replaceAll(RegExp(r'\(.*?(remaster|live|version|edit|mono|stereo).*?\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r' - .*?Remaster.*?', caseSensitive: false), '')
        .trim();
  }

  void dispose() {
    _client.close();
  }
}
