import '../../l10n/l10n.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'discogs_config.dart';

/// Credenciais da conta Discogs do usuário: OAuth (token + segredo) ou token pessoal.
class DiscogsCredentials {
  final String? oauthToken;
  final String? oauthTokenSecret;
  final String? personalToken;
  final String? username;

  const DiscogsCredentials({this.oauthToken, this.oauthTokenSecret, this.personalToken, this.username});

  bool get isOAuth => oauthToken != null && oauthTokenSecret != null;
  bool get isValid => isOAuth || (personalToken != null && personalToken!.isNotEmpty);

  Map<String, dynamic> toJson() => {
        if (oauthToken != null) 'oauthToken': oauthToken,
        if (oauthTokenSecret != null) 'oauthTokenSecret': oauthTokenSecret,
        if (personalToken != null) 'personalToken': personalToken,
        if (username != null) 'username': username,
      };

  factory DiscogsCredentials.fromJson(Map<String, dynamic> json) => DiscogsCredentials(
        oauthToken: json['oauthToken'] as String?,
        oauthTokenSecret: json['oauthTokenSecret'] as String?,
        personalToken: json['personalToken'] as String?,
        username: json['username'] as String?,
      );

  DiscogsCredentials withUsername(String? name) => DiscogsCredentials(
        oauthToken: oauthToken,
        oauthTokenSecret: oauthTokenSecret,
        personalToken: personalToken,
        username: name,
      );
}

/// Armazenamento das credenciais e preferências do Discogs (abstrato para os testes).
abstract class DiscogsCredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// Armazenamento cifrado no aparelho (Keystore do Android): as credenciais ficam só neste celular.
class SecureDiscogsCredentialStore implements DiscogsCredentialStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[Discogs] Falha ao ler credenciais: $e');
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
      debugPrint('[Discogs] Falha ao gravar credenciais: $e');
    }
  }
}

class MemoryDiscogsCredentialStore implements DiscogsCredentialStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}

/// Token temporário da 1ª etapa do login OAuth.
class DiscogsRequestToken {
  final String token;
  final String secret;
  const DiscogsRequestToken(this.token, this.secret);

  String get authorizeUrl => 'https://www.discogs.com/oauth/authorize?oauth_token=${Uri.encodeQueryComponent(token)}';
}

/// Conta Discogs do usuário: login (OAuth 1.0a com assinatura PLAINTEXT sobre HTTPS, ou token pessoal),
/// credenciais guardadas para as próximas vezes e o cabeçalho de autorização das consultas.
class DiscogsAuthService extends ChangeNotifier {
  static const String _credentialsKey = 'discogs_credentials';
  static const String _enabledKey = 'discogs_enabled';

  final DiscogsCredentialStore _store;
  final http.Client _client;
  final String _consumerKey;
  final String _consumerSecret;

  DiscogsAuthService({
    DiscogsCredentialStore? store,
    http.Client? client,
    String? consumerKey,
    String? consumerSecret,
  })  : _store = store ?? SecureDiscogsCredentialStore(),
        _client = client ?? http.Client(),
        _consumerKey = consumerKey ?? DiscogsConfig.consumerKey,
        _consumerSecret = consumerSecret ?? DiscogsConfig.consumerSecret;

  DiscogsCredentials? _credentials;
  bool _enabled = false;
  bool _loaded = false;

  DiscogsCredentials? get credentials => _credentials;
  bool get isLoggedIn => _credentials?.isValid ?? false;
  String? get username => _credentials?.username;

  /// Caixa "Consultar Discogs" marcada (lembrada entre sessões).
  bool get isEnabled => _enabled && isLoggedIn;

  /// Plugin C1 (Discogs) ligado na jukebox, com ou sem conta conectada.
  bool get wantsEnabled => _enabled;

  /// O app tem chaves próprias cadastradas no Discogs (login pela tela do Discogs).
  bool get supportsOAuthLogin => _consumerKey.isNotEmpty && _consumerSecret.isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read(_credentialsKey);
    if (raw != null) {
      try {
        _credentials = DiscogsCredentials.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _credentials = null;
      }
    }
    _enabled = (await _store.read(_enabledKey)) == 'true';
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _store.write(_enabledKey, value ? 'true' : 'false');
    notifyListeners();
  }

  Future<void> logout() async {
    _credentials = null;
    _enabled = false;
    await _store.write(_credentialsKey, null);
    await _store.write(_enabledKey, 'false');
    notifyListeners();
  }

  // ─── LOGIN OAUTH ───

  static String _nonce() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  String _oauthHeader(Map<String, String> extra, {String tokenSecret = ''}) {
    final params = <String, String>{
      'oauth_consumer_key': _consumerKey,
      'oauth_nonce': _nonce(),
      'oauth_signature': '${Uri.encodeComponent(_consumerSecret)}&${Uri.encodeComponent(tokenSecret)}',
      'oauth_signature_method': 'PLAINTEXT',
      'oauth_timestamp': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      ...extra,
    };
    return 'OAuth ${params.entries.map((e) => '${e.key}="${Uri.encodeComponent(e.value)}"').join(', ')}';
  }

  /// 1ª etapa: pede um token temporário e devolve o endereço da tela de login/autorização do Discogs.
  Future<DiscogsRequestToken> requestToken() async {
    final res = await _client.post(
      Uri.parse('https://api.discogs.com/oauth/request_token'),
      headers: {
        'Authorization': _oauthHeader({'oauth_callback': DiscogsConfig.callbackUrl}),
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': DiscogsConfig.userAgent,
      },
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception(l10n.discogsSignInRejected(res.statusCode));
    }
    final q = Uri.splitQueryString(res.body);
    final token = q['oauth_token'];
    final secret = q['oauth_token_secret'];
    if (token == null || secret == null) throw Exception(l10n.discogsUnexpectedResponse);
    return DiscogsRequestToken(token, secret);
  }

  /// Extrai o verificador do endereço de retorno; `null` se a URL não é o retorno do login.
  static String? verifierFromCallback(String url) {
    if (!url.startsWith(DiscogsConfig.callbackUrl)) return null;
    return Uri.tryParse(url)?.queryParameters['oauth_verifier'];
  }

  /// 2ª etapa: troca o token temporário autorizado pelo token definitivo e o guarda.
  Future<void> completeOAuth(DiscogsRequestToken requestToken, String verifier) async {
    final res = await _client.post(
      Uri.parse('https://api.discogs.com/oauth/access_token'),
      headers: {
        'Authorization': _oauthHeader(
          {'oauth_token': requestToken.token, 'oauth_verifier': verifier},
          tokenSecret: requestToken.secret,
        ),
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': DiscogsConfig.userAgent,
      },
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception(l10n.discogsSignInNotConfirmed(res.statusCode));
    }
    final q = Uri.splitQueryString(res.body);
    final token = q['oauth_token'];
    final secret = q['oauth_token_secret'];
    if (token == null || secret == null) throw Exception(l10n.discogsUnexpectedResponse);
    await _saveVerified(DiscogsCredentials(oauthToken: token, oauthTokenSecret: secret));
  }

  /// Alternativa sem chaves do app: token pessoal gerado pelo usuário em discogs.com/settings/developers.
  Future<void> loginWithPersonalToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) throw Exception(l10n.discogsPasteToken);
    await _saveVerified(DiscogsCredentials(personalToken: t));
  }

  Future<void> _saveVerified(DiscogsCredentials creds) async {
    final name = await _identity(creds);
    final verified = creds.withUsername(name);
    _credentials = verified;
    _enabled = true;
    await _store.write(_credentialsKey, jsonEncode(verified.toJson()));
    await _store.write(_enabledKey, 'true');
    notifyListeners();
    debugPrint('[Discogs] ✅ Conta conectada: $name');
  }

  /// Confere as credenciais e obtém o nome de usuário.
  Future<String> _identity(DiscogsCredentials creds) async {
    final res = await _client.get(
      Uri.parse('https://api.discogs.com/oauth/identity'),
      headers: {...authHeadersFor(creds)},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 401) throw Exception(l10n.discogsInvalidCredentials);
    if (res.statusCode != 200) throw Exception(l10n.discogsUnavailableHttp(res.statusCode));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['username'] as String?) ?? 'Discogs';
  }

  /// Cabeçalhos das consultas autenticadas, ou `null` sem conta conectada.
  Map<String, String>? get authHeaders => isLoggedIn ? authHeadersFor(_credentials!) : null;

  Map<String, String> authHeadersFor(DiscogsCredentials creds) => {
        'User-Agent': DiscogsConfig.userAgent,
        'Authorization': creds.isOAuth
            ? _oauthHeader({'oauth_token': creds.oauthToken!}, tokenSecret: creds.oauthTokenSecret!)
            : 'Discogs token=${creds.personalToken}',
      };
}
