import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../collection_service.dart';

/// Conta WaxClub do usuário (servidor em https://api.waxclub.com.br).
class WaxClubAccount {
  final int id;
  final String email;
  final String? displayName;
  final String? city;

  const WaxClubAccount({required this.id, required this.email, this.displayName, this.city});

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (displayName != null) 'displayName': displayName,
        if (city != null) 'city': city,
      };

  factory WaxClubAccount.fromJson(Map<String, dynamic> j) => WaxClubAccount(
        id: (j['id'] as num).toInt(),
        email: j['email'] as String,
        displayName: j['displayName'] as String?,
        city: j['city'] as String?,
      );
}

/// Erro devolvido pela API (`error` do JSON) ou de rede (`network`).
class AccountApiException implements Exception {
  final String code;
  final int status;
  final int? attemptsLeft;
  const AccountApiException(this.code, this.status, {this.attemptsLeft});

  @override
  String toString() => 'AccountApiException($status, $code)';
}

/// Armazenamento do token e do estado da sincronização (abstrato para os testes).
abstract class AccountStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// Cifrado no aparelho (Keystore do Android).
class SecureAccountStore implements AccountStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[Account] Falha ao ler: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (e) {
      debugPrint('[Account] Falha ao gravar: $e');
    }
  }
}

class MemoryAccountStore implements AccountStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}

/// Login por código no e-mail e sincronização da coleção e das audições com a conta.
///
/// Coleção: envia o que mudou desde o último envio (o mais recente vence no servidor) e recebe o que
/// mudou nos outros aparelhos. Audições: só envio (cópia de segurança) por enquanto.
class AccountService extends ChangeNotifier {
  static const String defaultBaseUrl = 'https://api.waxclub.com.br/v1';
  static const int batchSize = 500;
  static const Duration syncDelay = Duration(seconds: 8);

  static const _kToken = 'waxclub.account.token';
  static const _kAccount = 'waxclub.account.user';
  static const _kPushAt = 'waxclub.sync.pushAt';
  static const _kPullServerTime = 'waxclub.sync.pullServerTime';
  static const _kPlaysAt = 'waxclub.sync.playsAt';
  static const _kLastSync = 'waxclub.sync.lastSync';

  final String baseUrl;
  final AccountStore _store;
  final http.Client _client;

  AccountService({String? baseUrl, AccountStore? store, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _store = store ?? SecureAccountStore(),
        _client = client ?? http.Client();

  String? _token;
  WaxClubAccount? _account;
  bool _loaded = false;
  bool _syncing = false;
  DateTime? _lastSyncAt;
  String? _lastSyncError;
  CollectionService? _collection;
  Timer? _syncTimer;

  bool get isSignedIn => _token != null && _account != null;
  WaxClubAccount? get account => _account;
  bool get isSyncing => _syncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastSyncError => _lastSyncError;

  /// Liga a coleção: cada alteração local agenda uma sincronização.
  void attachCollection(CollectionService collection) {
    _collection?.removeListener(_onCollectionChanged);
    _collection = collection;
    collection.addListener(_onCollectionChanged);
  }

  void _onCollectionChanged() {
    if (!isSignedIn || _syncing) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(syncDelay, () => sync());
  }

  /// Lê a sessão salva e, se houver, confere a conta e sincroniza em segundo plano.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _token = await _store.read(_kToken);
    final raw = await _store.read(_kAccount);
    if (raw != null) {
      try {
        _account = WaxClubAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    _lastSyncAt = DateTime.tryParse(await _store.read(_kLastSync) ?? '');
    if (_token == null) _account = null;
    notifyListeners();
    if (isSignedIn) unawaited(_refreshAndSync());
  }

  Future<void> _refreshAndSync() async {
    try {
      final j = await _request('GET', '/me');
      await _saveAccount(WaxClubAccount.fromJson(j['user'] as Map<String, dynamic>));
    } on AccountApiException catch (e) {
      if (e.status == 401) {
        await _clearSession(); // sessão expirada ou encerrada em outro lugar
        return;
      }
    }
    await sync();
  }

  /// Pede o código de 6 dígitos para o e-mail.
  Future<void> requestCode(String email) async {
    await _request('POST', '/auth/email/start', body: {'email': email.trim()}, auth: false);
  }

  /// Confere o código, abre a sessão e envia a coleção do aparelho para a conta.
  Future<void> verifyCode(String email, String code) async {
    final j = await _request('POST', '/auth/email/verify',
        body: {'email': email.trim(), 'code': code.trim(), 'device': 'WaxClub Android'}, auth: false);
    _token = j['token'] as String;
    await _store.write(_kToken, _token);
    // conta nova neste aparelho: a próxima sincronização envia tudo e recebe tudo
    for (final k in [_kPushAt, _kPullServerTime, _kPlaysAt, _kLastSync]) {
      await _store.write(k, null);
    }
    _lastSyncAt = null;
    await _saveAccount(WaxClubAccount.fromJson(j['user'] as Map<String, dynamic>));
    unawaited(sync());
  }

  Future<void> signOut() async {
    try {
      await _request('POST', '/auth/logout');
    } catch (_) {
      // sem rede: a sessão some só do aparelho
    }
    await _clearSession();
  }

  /// Apaga a conta e todos os dados dela no servidor (a coleção do aparelho continua).
  Future<void> deleteAccount() async {
    await _request('DELETE', '/me');
    await _clearSession();
  }

  Future<void> _saveAccount(WaxClubAccount a) async {
    _account = a;
    await _store.write(_kAccount, jsonEncode(a.toJson()));
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _syncTimer?.cancel();
    _token = null;
    _account = null;
    _lastSyncAt = null;
    _lastSyncError = null;
    for (final k in [_kToken, _kAccount, _kPushAt, _kPullServerTime, _kPlaysAt, _kLastSync]) {
      await _store.write(k, null);
    }
    notifyListeners();
  }

  /// Sincroniza a coleção e envia as audições novas. Retorna `true` quando deu certo.
  Future<bool> sync() async {
    final collection = _collection;
    if (!isSignedIn || collection == null || _syncing) return false;
    _syncing = true;
    _syncTimer?.cancel();
    notifyListeners();
    try {
      await collection.load();

      // 1. envio: discos alterados e removidos desde o último envio
      final pushStart = DateTime.now();
      final lastPush = DateTime.tryParse(await _store.read(_kPushAt) ?? '');
      final outgoing = <Map<String, dynamic>>[
        for (final i in collection.changedSince(lastPush))
          {...i.toJson(), 'key': i.key, 'updatedAt': i.changedAt.toUtc().toIso8601String()},
        for (final e in collection.removedSince(lastPush).entries)
          {'key': e.key, 'deleted': true, 'updatedAt': e.value.toUtc().toIso8601String()},
      ];
      for (var i = 0; i < outgoing.length; i += batchSize) {
        final chunk = outgoing.sublist(i, (i + batchSize).clamp(0, outgoing.length));
        final j = await _request('POST', '/collection/sync', body: {'items': chunk});
        await _applyServerItems(collection, j['items'] as List<dynamic>? ?? const []);
      }
      await _store.write(_kPushAt, pushStart.toIso8601String());

      // 2. recebimento: o que mudou na conta (outros aparelhos) desde a última vez
      final since = await _store.read(_kPullServerTime);
      final pulled = await _request('GET', '/collection${since == null ? '' : '?since=${Uri.encodeQueryComponent(since)}'}');
      await _applyServerItems(collection, pulled['items'] as List<dynamic>? ?? const []);
      await _store.write(_kPullServerTime, pulled['serverTime'] as String?);

      // 3. audições novas (cópia de segurança na conta)
      final playsAt = DateTime.tryParse(await _store.read(_kPlaysAt) ?? '');
      final plays = collection.playsAfter(playsAt);
      for (var i = 0; i < plays.length; i += batchSize) {
        final chunk = plays.sublist(i, (i + batchSize).clamp(0, plays.length));
        await _request('POST', '/plays', body: {
          'plays': [
            for (final p in chunk) {...p.toJson(), 'at': p.at.toUtc().toIso8601String()},
          ],
        });
        await _store.write(_kPlaysAt, chunk.last.at.toIso8601String());
      }

      _lastSyncAt = DateTime.now();
      _lastSyncError = null;
      await _store.write(_kLastSync, _lastSyncAt!.toIso8601String());
      return true;
    } on AccountApiException catch (e) {
      _lastSyncError = e.code;
      if (e.status == 401) await _clearSession();
      return false;
    } catch (e) {
      debugPrint('[Account] Falha na sincronização: $e');
      _lastSyncError = 'network';
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _applyServerItems(CollectionService collection, List<dynamic> items) async {
    final upserts = <CollectionItem>[];
    final deletions = <String, DateTime>{};
    for (final raw in items) {
      final m = raw as Map<String, dynamic>;
      final key = m['key'] as String?;
      final at = DateTime.tryParse(m['updatedAt'] as String? ?? '');
      if (key == null || at == null) continue;
      if (m['deleted'] == true) {
        deletions[key] = at.toLocal();
      } else if (m['album'] != null && m['artist'] != null) {
        upserts.add(CollectionItem.fromJson({...m, 'updatedAt': at.toLocal().toIso8601String()}));
      }
    }
    await collection.applyRemote(upserts: upserts, deletions: deletions);
  }

  Future<Map<String, dynamic>> _request(String method, String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Accept'] = 'application/json';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json; charset=utf-8';
      req.body = jsonEncode(body);
    }
    if (auth) {
      if (_token == null) throw const AccountApiException('unauthorized', 401);
      req.headers['Authorization'] = 'Bearer $_token';
    }
    final http.Response resp;
    try {
      resp = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 20)));
    } catch (e) {
      throw const AccountApiException('network', 0);
    }
    Map<String, dynamic> j = const {};
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map<String, dynamic>) j = decoded;
    } catch (_) {}
    if (resp.statusCode >= 400) {
      throw AccountApiException(j['error'] as String? ?? 'http_${resp.statusCode}', resp.statusCode,
          attemptsLeft: (j['attemptsLeft'] as num?)?.toInt());
    }
    return j;
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners(); // sincronização em andamento pode terminar depois de fechar
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    _collection?.removeListener(_onCollectionChanged);
    super.dispose();
  }
}
