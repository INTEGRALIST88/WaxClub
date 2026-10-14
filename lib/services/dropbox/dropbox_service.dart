import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../local_lyrics_library.dart';

/// App WaxClub cadastrado no Dropbox (dropbox.com/developers/apps): acesso **só à pasta do app**
/// (`Dropbox/Apps/<nome do app>`), permissões `files.metadata.read` e `files.content.read`, e clientes
/// públicos (PKCE) liberados. A chave do app é pública (não há segredo no app).
class DropboxConfig {
  static const String appKey = String.fromEnvironment('DROPBOX_APP_KEY');

  /// Retorno do login. O app intercepta a navegação para ele dentro do WebView; a página existe no site
  /// só como reserva ("volte ao WaxClub"). Precisa estar cadastrado em "Redirect URIs" no Dropbox.
  static const String redirectUri = 'https://waxclub.com.br/auth/dropbox/';

  /// Pasta do app dentro do Dropbox do usuário (o nome do app cadastrado no Dropbox).
  static const String appFolder = 'Apps/WaxClub';

  static bool get configured => appKey.isNotEmpty;
}

/// Armazenamento das credenciais (abstrato para os testes).
abstract class DropboxTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// Cifrado no aparelho (Keystore do Android).
class SecureDropboxTokenStore implements DropboxTokenStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
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
    } catch (_) {}
  }
}

class MemoryDropboxTokenStore implements DropboxTokenStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Um arquivo da pasta do app no Dropbox.
class DropboxFile {
  /// Caminho dentro da pasta do app (ex.: `/The Beatles/Abbey Road/The Beatles - Something.lrc`).
  final String path;
  final String name;

  /// Revisão do arquivo: muda quando o arquivo muda.
  final String rev;
  final int size;
  const DropboxFile({required this.path, required this.name, required this.rev, required this.size});
}

/// Login PKCE (OAuth 2, sem segredo) com acesso renovável, e leitura da pasta do app no Dropbox.
class DropboxService extends ChangeNotifier implements LyricsFolderSource {
  static const String _key = 'waxclub_dropbox';
  final DropboxTokenStore _store;
  final http.Client _client;
  final String appKey;

  String? _accessToken;
  DateTime? _expiresAt;
  String? _refreshToken;
  String? _accountName;
  DateTime? _lastSync;
  bool _loaded = false;

  /// PKCE do login em andamento.
  String? _verifier;
  String? _state;

  DropboxService({DropboxTokenStore? store, http.Client? client, String? appKey})
      : _store = store ?? SecureDropboxTokenStore(),
        _client = client ?? http.Client(),
        appKey = appKey ?? DropboxConfig.appKey;

  bool get configured => appKey.isNotEmpty;
  bool get isConnected => _refreshToken != null;
  String? get accountName => _accountName;
  DateTime? get lastSync => _lastSync;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _refreshToken = j['refresh'] as String?;
        _accessToken = j['access'] as String?;
        _expiresAt = DateTime.tryParse(j['expires'] as String? ?? '');
        _accountName = j['name'] as String?;
        _lastSync = DateTime.tryParse(j['lastSync'] as String? ?? '');
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() => _store.write(
      _key,
      _refreshToken == null
          ? null
          : jsonEncode({
              'refresh': _refreshToken,
              'access': _accessToken,
              'expires': _expiresAt?.toIso8601String(),
              'name': _accountName,
              'lastSync': _lastSync?.toIso8601String(),
            }));

  Future<void> markSynced(DateTime at) async {
    _lastSync = at;
    notifyListeners();
    await _save();
  }

  static String _random(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String challengeFor(String verifier) =>
      base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');

  /// Endereço da página de login do Dropbox (começa um novo login PKCE).
  Uri authorizeUrl() {
    _verifier = _random(64);
    _state = _random(24);
    return Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': appKey,
      'response_type': 'code',
      'code_challenge': challengeFor(_verifier!),
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
      'redirect_uri': DropboxConfig.redirectUri,
      'state': _state!,
    });
  }

  /// O WebView chegou no endereço de retorno: troca o código pelo acesso. `true` = conectado.
  Future<bool> finishLogin(Uri callback) async {
    final code = callback.queryParameters['code'];
    if (code == null || callback.queryParameters['state'] != _state || _verifier == null) return false;
    final res = await _client.post(Uri.parse('https://api.dropboxapi.com/oauth2/token'), body: {
      'code': code,
      'grant_type': 'authorization_code',
      'code_verifier': _verifier!,
      'client_id': appKey,
      'redirect_uri': DropboxConfig.redirectUri,
    });
    _verifier = null;
    _state = null;
    if (res.statusCode != 200) return false;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _accessToken = j['access_token'] as String?;
    _refreshToken = j['refresh_token'] as String?;
    _expiresAt = DateTime.now().add(Duration(seconds: (j['expires_in'] as num? ?? 14400).toInt() - 60));
    if (_accessToken == null || _refreshToken == null) return false;
    _accountName = await _fetchAccountName();
    notifyListeners();
    await _save();
    return true;
  }

  static bool isCallback(String url) => url.startsWith(DropboxConfig.redirectUri);

  Future<String?> _fetchAccountName() async {
    try {
      final res = await _client.post(
        Uri.parse('https://api.dropboxapi.com/2/users/get_current_account'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (j['name'] as Map<String, dynamic>?)?['display_name'] as String? ?? j['email'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Acesso válido (renova pelo refresh token quando vence).
  Future<String> _token() async {
    final t = _accessToken;
    final exp = _expiresAt;
    if (t != null && exp != null && DateTime.now().isBefore(exp)) return t;
    final refresh = _refreshToken;
    if (refresh == null) throw StateError('Dropbox not connected'); // l10n-ignore
    final res = await _client.post(Uri.parse('https://api.dropboxapi.com/oauth2/token'), body: {
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
      'client_id': appKey,
    });
    if (res.statusCode == 400 || res.statusCode == 401) {
      // Acesso revogado no Dropbox: desconecta
      await disconnect(revoke: false);
      throw StateError('Dropbox access revoked'); // l10n-ignore
    }
    if (res.statusCode != 200) throw StateError('Dropbox token ${res.statusCode}'); // l10n-ignore
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    _accessToken = j['access_token'] as String;
    _expiresAt = DateTime.now().add(Duration(seconds: (j['expires_in'] as num? ?? 14400).toInt() - 60));
    await _save();
    return _accessToken!;
  }

  /// Todos os arquivos da pasta do app (com subpastas).
  @override
  Future<List<DropboxFile>> listAppFolder() async {
    final token = await _token();
    final files = <DropboxFile>[];
    var res = await _client.post(
      Uri.parse('https://api.dropboxapi.com/2/files/list_folder'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'path': '', 'recursive': true, 'include_deleted': false}),
    );
    while (true) {
      if (res.statusCode != 200) throw StateError('Dropbox list ${res.statusCode}'); // l10n-ignore
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      for (final e in (j['entries'] as List<dynamic>).whereType<Map<String, dynamic>>()) {
        if (e['.tag'] != 'file') continue;
        files.add(DropboxFile(
          path: e['path_display'] as String? ?? e['path_lower'] as String,
          name: e['name'] as String,
          rev: e['rev'] as String? ?? '',
          size: (e['size'] as num? ?? 0).toInt(),
        ));
      }
      if (j['has_more'] != true) break;
      res = await _client.post(
        Uri.parse('https://api.dropboxapi.com/2/files/list_folder/continue'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'cursor': j['cursor']}),
      );
    }
    return files;
  }

  /// JSON para o cabeçalho Dropbox-API-Arg: caracteres fora do ASCII viram \uXXXX (acentos no nome).
  static String headerJson(Object value) => jsonEncode(value).replaceAllMapped(
        RegExp(r'[^\x00-\x7F]'),
        (m) => m[0]!.codeUnits.map((c) => '\\u${c.toRadixString(16).padLeft(4, '0')}').join(),
      );

  /// Texto de um arquivo da pasta do app.
  @override
  Future<String> download(String path) async {
    final token = await _token();
    final res = await _client.post(
      Uri.parse('https://content.dropboxapi.com/2/files/download'),
      headers: {'Authorization': 'Bearer $token', 'Dropbox-API-Arg': headerJson({'path': path})},
    );
    if (res.statusCode != 200) throw StateError('Dropbox download ${res.statusCode}'); // l10n-ignore
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  /// Atualiza a biblioteca de letras com a pasta do app e anota a hora.
  Future<LyricsFolderSync> syncInto(LocalLyricsLibrary lib) async {
    final r = await lib.syncFrom(this);
    await markSynced(DateTime.now());
    return r;
  }

  /// Sai da conta neste aparelho (e revoga o acesso no Dropbox).
  Future<void> disconnect({bool revoke = true}) async {
    final t = _accessToken;
    if (revoke && t != null) {
      try {
        await _client.post(Uri.parse('https://api.dropboxapi.com/2/auth/token/revoke'),
            headers: {'Authorization': 'Bearer $t'});
      } catch (_) {}
    }
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _accountName = null;
    _lastSync = null;
    notifyListeners();
    await _save();
  }
}
