import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/track_entry.dart';
import '../tracklist_provider.dart';
import 'discogs_auth_service.dart';

/// Catálogo de discos do Discogs (a maior base de vinil: prensagens, coletâneas, lados A/B e capas).
/// Exige a conta do usuário conectada ([DiscogsAuthService]); limite de 60 consultas por minuto.
class DiscogsTracklistProvider implements TracklistProvider {
  final DiscogsAuthService _auth;
  final http.Client _client;

  DiscogsTracklistProvider({required DiscogsAuthService auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>?> _get(String path, Map<String, String> query) async {
    final headers = _auth.authHeaders;
    if (headers == null) throw StateError('Conta Discogs não conectada');
    final res = await _client
        .get(Uri.https('api.discogs.com', path, query), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 429) {
      debugPrint('[Discogs] Limite de consultas atingido (429).');
      throw Exception('Discogs: too many requests, try again in a few seconds.');
    }
    if (res.statusCode != 200) {
      throw Exception('Discogs unavailable (HTTP ${res.statusCode}).');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Todos os discos que contêm a música: os do próprio artista e as coletâneas (artista "Various").
  /// Lança exceção se o Discogs falhar, para que o app recorra à base reserva.
  @override
  Future<List<ReleaseCandidate>> searchReleases({
    required String title,
    required String artist,
    String? album,
  }) async {
    final byArtist = await _get('/database/search', {
      'type': 'release',
      'track': title,
      'artist': artist,
      'per_page': '100',
    });
    // Coletâneas são creditadas a "Various": busca pela faixa com o artista no texto livre
    final compilations = await _get('/database/search', {
      'type': 'release',
      'track': title,
      'q': artist,
      'per_page': '100',
    });
    return groupReleaseEditions([
      ...parseSearchResults(byArtist),
      ...parseSearchResults(compilations),
    ]);
  }

  /// Busca livre de discos (escolha manual do usuário).
  Future<List<ReleaseCandidate>> searchReleasesByText(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/database/search', {'type': 'release', 'q': query.trim(), 'per_page': '100'});
    return groupReleaseEditions(parseSearchResults(data));
  }

  /// Converte os resultados da busca do Discogs ("Artista - Disco", formatos, ano, capa...).
  static List<ReleaseCandidate> parseSearchResults(Map<String, dynamic>? data) {
    final results = data?['results'] as List<dynamic>? ?? const [];
    final out = <ReleaseCandidate>[];
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      final id = r['id'];
      final fullTitle = r['title'] as String?;
      if (id == null || fullTitle == null) continue;
      // O Discogs devolve "Artista - Disco"; o disco pode conter " - " também
      final sep = fullTitle.indexOf(' - ');
      final artistName = sep > 0 ? fullTitle.substring(0, sep).trim() : null;
      final albumTitle = sep > 0 ? fullTitle.substring(sep + 3).trim() : fullTitle.trim();
      final formats = [for (final f in (r['format'] as List<dynamic>? ?? const [])) if (f is String) f];
      final lower = formats.map((f) => f.toLowerCase()).toList();
      final master = r['master_id'];
      out.add(ReleaseCandidate(
        providerId: 'discogs',
        releaseId: id.toString(),
        albumTitle: albumTitle,
        format: formats.isEmpty ? null : formats.take(3).join(', '),
        primaryType: lower.contains('album') || lower.contains('lp') ? 'Album' : (lower.contains('single') ? 'Single' : null),
        secondaryTypes: [
          if (lower.contains('compilation') || (artistName ?? '').toLowerCase().startsWith('various')) 'Compilation',
          if (lower.contains('live')) 'Live',
        ],
        artistName: artistName,
        year: (r['year']?.toString().isNotEmpty ?? false) ? r['year'].toString() : null,
        country: r['country'] as String?,
        coverUrl: (r['thumb'] as String?)?.isNotEmpty == true ? r['thumb'] as String : r['cover_image'] as String?,
        groupId: (master is num && master > 0) ? 'm$master' : null,
      ));
    }
    return out;
  }

  @override
  Future<List<TrackEntry>> loadTracklist(ReleaseCandidate candidate) async {
    final data = await _get('/releases/${candidate.releaseId}', const {});
    return parseTracklist(data);
  }

  /// Faixas do disco com lado ("A1" → lado A) e duração; ignora títulos de seção.
  static List<TrackEntry> parseTracklist(Map<String, dynamic>? data) {
    final list = data?['tracklist'] as List<dynamic>? ?? const [];
    final entries = <TrackEntry>[];
    var position = 1;

    void addTrack(Map<String, dynamic> t, {String? parentPosition}) {
      final title = (t['title'] as String?)?.trim();
      if (title == null || title.isEmpty) return;
      final number = ((t['position'] as String?)?.trim().isNotEmpty ?? false)
          ? (t['position'] as String).trim()
          : parentPosition;
      String? side;
      if (number != null) {
        final m = RegExp(r'^([A-Za-z]+)\d*').firstMatch(number);
        if (m != null) side = m.group(1)!.toUpperCase();
      }
      entries.add(TrackEntry(
        position: position++,
        title: title,
        number: number,
        side: side,
        lengthMs: parseDuration(t['duration'] as String?),
        artist: trackArtist(t['artists']),
      ));
    }

    for (final t in list) {
      if (t is! Map<String, dynamic>) continue;
      final type = t['type_'] as String? ?? 'track';
      if (type == 'heading') continue;
      if (type == 'index') {
        for (final sub in (t['sub_tracks'] as List<dynamic>? ?? const [])) {
          if (sub is Map<String, dynamic>) addTrack(sub, parentPosition: t['position'] as String?);
        }
        continue;
      }
      addTrack(t);
    }
    return entries;
  }

  /// Artista da faixa nas coletâneas ("Tim Maia (2)" → "Tim Maia"); `null` quando é o do disco.
  static String? trackArtist(dynamic artists) {
    if (artists is! List || artists.isEmpty) return null;
    final names = [
      for (final a in artists)
        if (a is Map && a['name'] is String) (a['anv'] as String?)?.isNotEmpty == true ? a['anv'] as String : a['name'] as String,
    ].map((n) => n.replaceAll(RegExp(r'\s*\(\d+\)$'), '').trim()).where((n) => n.isNotEmpty).toList();
    return names.isEmpty ? null : names.join(', ');
  }

  /// "4:35" → 275000 ms; "1:02:03" também é aceito.
  static int? parseDuration(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.trim().split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null)) return null;
    var seconds = 0;
    for (final p in parts) {
      seconds = seconds * 60 + p!;
    }
    return seconds > 0 ? seconds * 1000 : null;
  }

  @override
  void dispose() {}
}
