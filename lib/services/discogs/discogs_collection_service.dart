import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'discogs_auth_service.dart';

/// Adiciona discos à coleção do usuário no Discogs (pasta "Uncategorized", id 1), com a conta já
/// conectada no aparelho. Primeiro passo da sincronização nos dois sentidos.
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

  void dispose() => _client.close();
}
