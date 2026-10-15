import '../../l10n/l10n.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/track_entry.dart';
import '../tracklist_provider.dart';
import 'discogs_auth_service.dart';
import 'discogs_config.dart';

/// Catálogo de discos do Discogs (a maior base de vinil: prensagens, coletâneas, lados A/B e capas).
/// Exige a conta do usuário conectada ([DiscogsAuthService]); limite de 60 consultas por minuto.
class DiscogsTracklistProvider implements TracklistProvider {
  final DiscogsAuthService _auth;
  final http.Client _client;

  DiscogsTracklistProvider({required DiscogsAuthService auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>?> _get(String path, Map<String, String> query) async {
    // A busca exige a conta; a página de uma prensagem (/releases/{id}) é pública
    final headers = _auth.authHeaders ??
        (path.startsWith('/releases/') ? const {'User-Agent': DiscogsConfig.userAgent} : null);
    if (headers == null) throw StateError('Conta Discogs não conectada');
    final res = await _client
        .get(Uri.https('api.discogs.com', path, query), headers: headers)
        .timeout(const Duration(seconds: 12));
    if (res.statusCode == 429) {
      debugPrint('[Discogs] Limite de consultas atingido (429).');
      throw Exception(l10n.discogsTooManyRequests);
    }
    if (res.statusCode != 200) {
      throw Exception(l10n.discogsUnavailableHttp(res.statusCode));
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
    // Sem o que vem entre parênteses ("(studio Chat + New remix)", "(Remastered)"): o Discogs não acha
    // a faixa nem o disco com essas anotações de edição digital
    final track = catalogSearchName(title);
    final albumName = album == null ? '' : catalogSearchName(album);
    // 1º: banda + disco (o disco que está tocando, em todas as prensagens de vinil)
    final byAlbum = albumName.isEmpty
        ? null
        : await _get('/database/search', {
            'type': 'release',
            'release_title': albumName,
            'artist': artist,
            'format': 'Vinyl',
            'per_page': '100',
          });
    final byArtist = await _get('/database/search', {
      'type': 'release',
      'track': track,
      'artist': artist,
      'format': 'Vinyl',
      'per_page': '100',
    });
    // Coletâneas são creditadas a "Various": busca pela faixa com o artista no texto livre
    final compilations = await _get('/database/search', {
      'type': 'release',
      'track': track,
      'q': artist,
      'format': 'Vinyl',
      'per_page': '100',
    });
    return groupReleaseEditions([
      ...parseSearchResults(byAlbum),
      ...parseSearchResults(byArtist),
      ...parseSearchResults(compilations),
    ]);
  }

  /// Busca livre de discos (escolha manual do usuário).
  Future<List<ReleaseCandidate>> searchReleasesByText(String query) async {
    if (query.trim().isEmpty) return [];
    final data = await _get('/database/search', {'type': 'release', 'q': query.trim(), 'format': 'Vinyl', 'per_page': '100'});
    return groupReleaseEditions(parseSearchResults(data));
  }

  /// Prensagens com este código de barras (EAN/UPC lido pela câmera). Sem agrupar edições.
  /// O Discogs guarda o código como o colecionador digitou ("5400863170370", "5 400863 170370",
  /// UPC sem o 0 da frente...): tenta cada forma e, por fim, o texto livre (que também procura nos
  /// identificadores da prensagem).
  Future<List<ReleaseCandidate>> searchByBarcode(String barcode) async {
    final code = barcode.replaceAll(RegExp(r'\D'), '');
    if (code.isEmpty) return [];
    for (final v in barcodeVariants(code)) {
      final found = parseSearchResults(await _get('/database/search', {'type': 'release', 'barcode': v, 'per_page': '50'}));
      if (found.isNotEmpty) return found;
    }
    return parseSearchResults(await _get('/database/search', {'type': 'release', 'q': code, 'per_page': '50'}));
  }

  /// Prensagens com este número de catálogo (ex.: "6349 123", "SHVL 804", "PIASC0999DLP"). Sem agrupar
  /// edições. Tenta o número como foi lido, sem separadores e com espaço entre letras e números; depois
  /// sem o filtro de vinil (prensagem cadastrada com formato incompleto) e, por fim, no texto livre.
  Future<List<ReleaseCandidate>> searchByCatalogNumber(String catno) async {
    final q = catno.trim();
    if (q.isEmpty) return [];
    final variants = catalogNumberVariants(q);
    for (final v in variants) {
      final found = parseSearchResults(
          await _get('/database/search', {'type': 'release', 'catno': v, 'format': 'Vinyl', 'per_page': '50'}));
      if (found.isNotEmpty) return found;
    }
    final anyFormat = parseSearchResults(await _get('/database/search', {'type': 'release', 'catno': variants.first, 'per_page': '50'}));
    if (anyFormat.isNotEmpty) return anyFormat;
    return parseSearchResults(await _get('/database/search', {'type': 'release', 'q': q, 'per_page': '50'}));
  }

  /// Formas em que um código de barras costuma estar cadastrado no Discogs.
  static List<String> barcodeVariants(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    final out = <String>{d};
    if (d.length == 13) {
      out.add('${d[0]} ${d.substring(1, 7)} ${d.substring(7)}'); // como vem impresso: 5 400863 170370
      if (d.startsWith('0')) out.add(d.substring(1)); // EAN de um UPC-A americano
    } else if (d.length == 12) {
      out.add('0$d');
      out.add('${d[0]} ${d.substring(1, 6)} ${d.substring(6, 11)} ${d[11]}'); // 0 12345 67890 5
    }
    return out.toList();
  }

  /// Formas de um número de catálogo: como lido, sem separadores e com espaço entre letras e números
  /// ("PIAS C 0999" ↔ "PIASC0999DLP" ↔ "PIASC 0999 DLP"; "SHVL-804" ↔ "SHVL 804").
  static List<String> catalogNumberVariants(String raw) {
    final t = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final compact = t.replaceAll(RegExp(r'[\s.\-/]'), '');
    final spaced = compact.replaceAllMapped(RegExp(r'(?<=[A-Z])(?=\d)|(?<=\d)(?=[A-Z])'), (_) => ' ');
    final dashed = compact.replaceAllMapped(RegExp(r'(?<=[A-Z])(?=\d)'), (_) => '-');
    return {t, compact, spaced, dashed}.where((s) => s.isNotEmpty).toList();
  }

  /// Número da prensagem num link ou código do Discogs ("discogs.com/release/35436508-Bloc-Party...",
  /// "[r35436508]", "r35436508"); nulo se o texto não for isso.
  static String? releaseIdFrom(String text) {
    final t = text.trim();
    final link = RegExp(r'discogs\.com/(?:[a-z]{2}(?:[_-][a-z]{2})?/)?release/(\d+)', caseSensitive: false).firstMatch(t);
    if (link != null) return link.group(1);
    final code = RegExp(r'^\[?r(\d{3,})\]?$', caseSensitive: false).firstMatch(t);
    return code?.group(1);
  }

  /// A prensagem pelo número (link colado pelo usuário). Funciona mesmo sem a conta conectada.
  Future<ReleaseCandidate?> fetchRelease(String releaseId) async {
    final data = await _get('/releases/$releaseId', const {});
    return data == null ? null : parseRelease(data);
  }

  /// Converte a página completa da prensagem (/releases/{id}) no mesmo formato dos resultados da busca.
  static ReleaseCandidate? parseRelease(Map<String, dynamic> d) {
    final id = d['id'];
    final title = (d['title'] as String?)?.trim();
    if (id == null || title == null || title.isEmpty) return null;
    final artist = DiscogsTracklistProvider.trackArtist(d['artists']);
    final formats = <String>[];
    for (final f in (d['formats'] as List<dynamic>? ?? const [])) {
      if (f is! Map) continue;
      if (f['name'] is String) formats.add(f['name'] as String);
      for (final x in (f['descriptions'] as List<dynamic>? ?? const [])) {
        if (x is String) formats.add(x);
      }
    }
    final lower = formats.map((f) => f.toLowerCase()).toList();
    final labels = d['labels'] as List<dynamic>? ?? const [];
    final firstLabel = labels.isNotEmpty && labels.first is Map ? labels.first as Map : null;
    String? barcode;
    for (final i in (d['identifiers'] as List<dynamic>? ?? const [])) {
      if (i is Map && i['type'] == 'Barcode' && i['value'] is String) {
        barcode = i['value'] as String;
        break;
      }
    }
    final images = d['images'] as List<dynamic>? ?? const [];
    final cover = images.isNotEmpty && images.first is Map ? (images.first as Map)['uri'] as String? : null;
    final master = d['master_id'];
    final year = d['year'];
    return ReleaseCandidate(
      providerId: 'discogs', // l10n-ignore
      releaseId: id.toString(),
      albumTitle: title,
      format: formats.isEmpty ? null : formats.join(', '),
      primaryType: lower.contains('album') || lower.contains('lp') ? 'Album' : (lower.contains('single') ? 'Single' : null),
      secondaryTypes: [
        if (lower.contains('compilation') || (artist ?? '').toLowerCase().startsWith('various')) 'Compilation',
        if (lower.contains('live')) 'Live',
      ],
      artistName: artist,
      year: (year is num && year > 0) ? year.toString() : null,
      country: d['country'] as String?,
      coverUrl: (cover != null && cover.isNotEmpty) ? cover : d['thumb'] as String?,
      label: firstLabel?['name']?.toString(),
      catalogNumber: (firstLabel?['catno'] as String?)?.trim(),
      barcode: barcode,
      trackCount: (d['tracklist'] as List<dynamic>?)?.length,
      groupId: (master is num && master > 0) ? 'm$master' : null,
    );
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
        format: formats.isEmpty ? null : formats.join(', '),
        primaryType: lower.contains('album') || lower.contains('lp') ? 'Album' : (lower.contains('single') ? 'Single' : null),
        secondaryTypes: [
          if (lower.contains('compilation') || (artistName ?? '').toLowerCase().startsWith('various')) 'Compilation',
          if (lower.contains('live')) 'Live',
        ],
        artistName: artistName,
        year: (r['year']?.toString().isNotEmpty ?? false) ? r['year'].toString() : null,
        country: r['country'] as String?,
        coverUrl: (r['thumb'] as String?)?.isNotEmpty == true ? r['thumb'] as String : r['cover_image'] as String?,
        label: (r['label'] is List && (r['label'] as List).isNotEmpty) ? (r['label'] as List).first.toString() : null,
        catalogNumber: (r['catno'] as String?)?.trim().isNotEmpty == true ? (r['catno'] as String).trim() : null,
        barcode: (r['barcode'] is List && (r['barcode'] as List).isNotEmpty) ? (r['barcode'] as List).first.toString() : null,
        groupId: (master is num && master > 0) ? 'm$master' : null,
      ));
    }
    return out;
  }

  /// Notas da prensagem (texto livre dos colecionadores: gravação, créditos, histórias), se houver.
  Future<String?> fetchReleaseNotes(String releaseId) async {
    final data = await _get('/releases/$releaseId', const {});
    final notes = data?['notes'];
    return (notes is String && notes.trim().isNotEmpty) ? notes : null;
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
