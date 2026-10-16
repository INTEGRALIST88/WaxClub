import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../collection_service.dart';
import 'discogs_auth_service.dart';

/// Coleção do usuário no Discogs, com a conta já conectada no aparelho: lê a coleção inteira (para trazer os
/// discos para My Collection) e adiciona discos a ela (pasta "Uncategorized", id 1).
class DiscogsCollectionService {
  final DiscogsAuthService _auth;
  final http.Client _client;

  DiscogsCollectionService({required DiscogsAuthService auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client();

  bool get canWrite => _auth.isLoggedIn && (_auth.username ?? '').isNotEmpty;

  /// Adiciona a prensagem [releaseId] e, se houver, grava a nota (1 a 5). Retorna `true` se deu certo.
  Future<bool> addRelease(String releaseId, {int? rating}) async {
    final headers = _auth.authHeaders;
    final user = _auth.username;
    if (headers == null || user == null || user.isEmpty) return false;
    final base = '/users/${Uri.encodeComponent(user)}/collection/folders/1/releases/${Uri.encodeComponent(releaseId)}';
    try {
      final res = await _client.post(Uri.https('api.discogs.com', base), headers: headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 201 && res.statusCode != 200) {
        debugPrint('[DiscogsCollection] Falha ao adicionar $releaseId: HTTP ${res.statusCode}');
        return false;
      }
      final instanceId = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['instance_id'];
      if (rating != null && rating >= 1 && rating <= 5 && instanceId != null) {
        final r = await _client
            .post(
              Uri.https('api.discogs.com', '$base/instances/$instanceId'),
              headers: {...headers, 'Content-Type': 'application/json'},
              body: jsonEncode({'rating': rating}),
            )
            .timeout(const Duration(seconds: 12));
        if (r.statusCode >= 300) debugPrint('[DiscogsCollection] Nota não gravada: HTTP ${r.statusCode}');
      }
      return true;
    } catch (e) {
      debugPrint('[DiscogsCollection] Erro ao adicionar $releaseId: $e');
      return false;
    }
  }

  /// Lê a coleção inteira (todas as pastas), 100 discos por página, do mais recente ao mais antigo.
  /// [onProgress] recebe (lidos, total). Nulo se não houver conta ou o Discogs não responder.
  Future<List<CollectionItem>?> fetchCollection({void Function(int done, int total)? onProgress}) async {
    final headers = _auth.authHeaders;
    final user = _auth.username;
    if (headers == null || user == null || user.isEmpty) return null;
    final items = <CollectionItem>[];
    var page = 1;
    var pages = 1;
    var tries = 0;
    while (page <= pages) {
      final uri = Uri.https('api.discogs.com', '/users/${Uri.encodeComponent(user)}/collection/folders/0/releases', {
        'per_page': '100',
        'page': '$page',
        'sort': 'added',
        'sort_order': 'desc',
      });
      final http.Response res;
      try {
        res = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint('[DiscogsCollection] Coleção, página $page: $e');
        if (++tries > 3) return items.isEmpty ? null : items;
        await Future<void>.delayed(const Duration(seconds: 3));
        continue;
      }
      if (res.statusCode == 429) {
        // Limite do Discogs (60 pedidos por minuto): espera e tenta a mesma página
        if (++tries > 3) return items.isEmpty ? null : items;
        await Future<void>.delayed(Duration(seconds: int.tryParse(res.headers['retry-after'] ?? '') ?? 30));
        continue;
      }
      if (res.statusCode != 200) {
        debugPrint('[DiscogsCollection] Coleção, página $page: HTTP ${res.statusCode}');
        return items.isEmpty ? null : items;
      }
      tries = 0;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final pagination = j['pagination'] as Map<String, dynamic>? ?? const {};
      pages = (pagination['pages'] as num?)?.toInt() ?? 1;
      final total = (pagination['items'] as num?)?.toInt() ?? 0;
      for (final r in (j['releases'] as List<dynamic>? ?? const [])) {
        if (r is! Map<String, dynamic>) continue;
        final item = itemFromRelease(r);
        if (item != null) items.add(item);
      }
      onProgress?.call(items.length, total);
      page++;
    }
    debugPrint('[DiscogsCollection] Coleção lida: ${items.length} discos');
    return items;
  }

  /// Um disco da coleção do Discogs (`releases[]` de /collection/folders/0/releases) como item de My Collection.
  static CollectionItem? itemFromRelease(Map<String, dynamic> r) {
    final b = r['basic_information'] as Map<String, dynamic>? ?? const {};
    final title = '${b['title'] ?? ''}'.trim();
    final artist = artistName(b['artists'] as List<dynamic>? ?? const []);
    if (title.isEmpty || artist.isEmpty) return null;
    final formats = [
      for (final f in (b['formats'] as List<dynamic>? ?? const []))
        if (f is Map<String, dynamic>) ...['${f['name'] ?? ''}', for (final d in (f['descriptions'] as List<dynamic>? ?? const [])) '$d'],
    ].where((s) => s.trim().isNotEmpty).toSet().join(', ');
    final label = (b['labels'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().firstOrNull;
    String? note(int field) {
      for (final n in (r['notes'] as List<dynamic>? ?? const [])) {
        if (n is Map<String, dynamic> && n['field_id'] == field && '${n['value'] ?? ''}'.trim().isNotEmpty) {
          return '${n['value']}'.trim();
        }
      }
      return null;
    }

    final cover = '${b['cover_image'] ?? ''}';
    final year = (b['year'] as num?)?.toInt() ?? 0;
    final rating = (r['rating'] as num?)?.toInt() ?? 0;
    return CollectionItem(
      album: title,
      artist: artist,
      coverUrl: cover.isEmpty || cover.contains('spacer.gif') ? null : cover,
      year: year > 0 ? '$year' : null,
      format: formats.isEmpty ? null : formats,
      discogsReleaseId: '${r['id'] ?? b['id']}',
      label: label == null ? null : '${label['name'] ?? ''}'.replaceAll(RegExp(r'\s*\(\d+\)$'), '').trim(),
      catalogNumber: label == null || '${label['catno'] ?? ''}'.trim().isEmpty ? null : '${label['catno']}'.trim(),
      addedAt: DateTime.tryParse('${r['date_added'] ?? ''}')?.toLocal() ?? DateTime.now(),
      rating: rating >= 1 && rating <= 5 ? rating : null,
      mediaCondition: note(1), // campos padrão do Discogs: 1 = Media Condition, 2 = Sleeve Condition, 3 = Notes
      sleeveCondition: note(2),
      notes: note(3),
    );
  }

  /// Nome dos artistas como o Discogs mostra ("Simon & Garfunkel"), sem o número de homônimos ("Nirvana (2)").
  static String artistName(List<dynamic> artists) {
    final b = StringBuffer();
    for (final a in artists.whereType<Map<String, dynamic>>()) {
      final anv = '${a['anv'] ?? ''}'.trim();
      final name = (anv.isNotEmpty ? anv : '${a['name'] ?? ''}').replaceAll(RegExp(r'\s*\(\d+\)$'), '').trim();
      if (name.isEmpty) continue;
      b.write(name);
      final join = '${a['join'] ?? ''}'.trim();
      if (join.isNotEmpty) b.write(join == ',' ? ', ' : ' $join ');
    }
    return b.toString().trim().replaceAll(RegExp(r'[,&]$'), '').trim();
  }

  void dispose() => _client.close();
}
