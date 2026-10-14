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
  final String? username;
  final String? displayName;
  final String? countryCode;
  final String? stateCode;
  final String? stateName;
  final int? cityId;
  final String? city;
  final bool hasPassword;
  final bool google;

  /// Nome de usuário e local preenchidos (quem entrou pelo Google ainda precisa completar).
  final bool profileComplete;

  const WaxClubAccount({
    required this.id,
    required this.email,
    this.username,
    this.displayName,
    this.countryCode,
    this.stateCode,
    this.stateName,
    this.cityId,
    this.city,
    this.hasPassword = false,
    this.google = false,
    this.profileComplete = false,
  });

  /// "Campinas, São Paulo, BR"
  String get locationLabel => [city, stateName, countryCode].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (username != null) 'username': username,
        if (displayName != null) 'displayName': displayName,
        if (countryCode != null) 'countryCode': countryCode,
        if (stateCode != null) 'stateCode': stateCode,
        if (stateName != null) 'stateName': stateName,
        if (cityId != null) 'cityId': cityId,
        if (city != null) 'city': city,
        'hasPassword': hasPassword,
        'google': google,
        'profileComplete': profileComplete,
      };

  factory WaxClubAccount.fromJson(Map<String, dynamic> j) => WaxClubAccount(
        id: (j['id'] as num).toInt(),
        email: j['email'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        countryCode: j['countryCode'] as String?,
        stateCode: j['stateCode'] as String?,
        stateName: j['stateName'] as String?,
        cityId: (j['cityId'] as num?)?.toInt(),
        city: j['city'] as String?,
        hasPassword: j['hasPassword'] == true,
        google: j['google'] == true,
        profileComplete: j['profileComplete'] == true,
      );
}

/// País da lista do cadastro (base GeoNames).
class GeoCountry {
  final String code;
  final String name;
  final bool hasStates;
  const GeoCountry(this.code, this.name, {this.hasStates = false});
}

/// Estado/província de um país.
class GeoState {
  final String code;
  final String name;
  const GeoState(this.code, this.name);
}

/// Cidade (busca no servidor).
class GeoCity {
  final int id;
  final String name;
  final String stateCode;
  const GeoCity(this.id, this.name, this.stateCode);
}

/// Local escolhido no cadastro.
class LocationChoice {
  final GeoCountry country;
  final GeoState? state;
  final GeoCity city;
  const LocationChoice({required this.country, this.state, required this.city});
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

  void detachCollection(CollectionService collection) {
    if (_collection != collection) return;
    collection.removeListener(_onCollectionChanged);
    _collection = null;
    _syncTimer?.cancel();
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
    _loading = true;
    _token = await _store.read(_kToken);
    final raw = await _store.read(_kAccount);
    if (raw != null) {
      try {
        _account = WaxClubAccount.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    _lastSyncAt = DateTime.tryParse(await _store.read(_kLastSync) ?? '');
    if (_token == null) _account = null;
    _loading = false;
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

  bool get isLoaded => _loaded && !_loading;
  bool _loading = false;

  static const String _device = 'WaxClub Android';

  /// Cadastro com senha: o servidor manda um código para confirmar o e-mail ([verifyEmail]).
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required LocationChoice location,
  }) async {
    await _request('POST', '/auth/register',
        body: {
          'email': email.trim(),
          'password': password,
          'username': username.trim(),
          ..._locationBody(location),
        },
        auth: false);
  }

  /// Confirma o e-mail com o código e entra na conta.
  Future<void> verifyEmail(String email, String code) async {
    final j = await _request('POST', '/auth/verify-email',
        body: {'email': email.trim(), 'code': code.trim(), 'device': _device}, auth: false);
    await _openSession(j);
  }

  Future<void> resendVerification(String email) async {
    await _request('POST', '/auth/verify-email/resend', body: {'email': email.trim()}, auth: false);
  }

  /// Login com e-mail e senha. E-mail ainda não confirmado: erro `email_not_verified` (o servidor reenvia o código).
  Future<void> login(String email, String password) async {
    final j = await _request('POST', '/auth/login',
        body: {'email': email.trim(), 'password': password, 'device': _device}, auth: false);
    await _openSession(j);
  }

  /// Login com o token do Google (idToken obtido no aparelho).
  Future<void> loginWithGoogle(String idToken) async {
    final j = await _request('POST', '/auth/google', body: {'idToken': idToken, 'device': _device}, auth: false);
    await _openSession(j);
  }

  /// "Esqueci a senha": manda o código para o e-mail.
  Future<void> forgotPassword(String email) async {
    await _request('POST', '/auth/password/forgot', body: {'email': email.trim()}, auth: false);
  }

  /// Nova senha com o código do e-mail; entra na conta (as outras sessões são encerradas).
  Future<void> resetPassword(String email, String code, String password) async {
    final j = await _request('POST', '/auth/password/reset',
        body: {'email': email.trim(), 'code': code.trim(), 'password': password, 'device': _device}, auth: false);
    await _openSession(j);
  }

  /// Nome de usuário e local (completar o cadastro ou editar o perfil).
  Future<void> updateProfile({required String username, required LocationChoice location}) async {
    final j = await _request('PATCH', '/me', body: {'username': username.trim(), ..._locationBody(location)});
    await _saveAccount(WaxClubAccount.fromJson(j['user'] as Map<String, dynamic>));
  }

  /// `null` quando o nome é inválido; senão, se está livre.
  Future<bool?> usernameAvailable(String username) async {
    final j = await _request('GET', '/auth/username-available?u=${Uri.encodeQueryComponent(username.trim())}', auth: false);
    return j['valid'] == true ? j['available'] == true : null;
  }

  Map<String, dynamic> _locationBody(LocationChoice l) => {
        'countryCode': l.country.code,
        if (l.state != null) 'stateCode': l.state!.code,
        'cityId': l.city.id,
      };

  // ---------- listas do cadastro ----------

  List<GeoCountry>? _countries;

  Future<List<GeoCountry>> countries() async {
    if (_countries != null) return _countries!;
    final j = await _request('GET', '/geo/countries', auth: false);
    return _countries = [
      for (final c in (j['countries'] as List).cast<Map<String, dynamic>>())
        GeoCountry(c['code'] as String, c['name'] as String, hasStates: c['hasStates'] == true),
    ];
  }

  Future<List<GeoState>> states(String countryCode) async {
    final j = await _request('GET', '/geo/states?country=${Uri.encodeQueryComponent(countryCode)}', auth: false);
    return [
      for (final s in (j['states'] as List).cast<Map<String, dynamic>>()) GeoState(s['code'] as String, s['name'] as String),
    ];
  }

  Future<List<GeoCity>> cities(String countryCode, {String? stateCode, String query = ''}) async {
    final qs = [
      'country=${Uri.encodeQueryComponent(countryCode)}',
      if (stateCode != null) 'state=${Uri.encodeQueryComponent(stateCode)}',
      if (query.trim().isNotEmpty) 'q=${Uri.encodeQueryComponent(query.trim())}',
    ].join('&');
    final j = await _request('GET', '/geo/cities?$qs', auth: false);
    return [
      for (final c in (j['cities'] as List).cast<Map<String, dynamic>>())
        GeoCity((c['id'] as num).toInt(), c['name'] as String, c['stateCode'] as String? ?? ''),
    ];
  }

  /// Guarda a sessão nova e envia a coleção do aparelho para a conta.
  Future<void> _openSession(Map<String, dynamic> j) async {
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

  /// Chamado ao sair da conta (ex.: desconectar o Google para a próxima entrada mostrar a escolha de conta).
  Future<void> Function()? onSignedOut;

  Future<void> _clearSession() async {
    unawaited(onSignedOut?.call());
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
