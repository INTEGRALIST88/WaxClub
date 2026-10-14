import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cloud_folder.dart';

/// App WaxClub cadastrado no Dropbox (dropbox.com/developers/apps): acesso **só à pasta do app**
/// (`Dropbox/Apps/<nome do app>`), permissões `files.metadata.read` e `files.content.read`, e clientes
/// públicos (PKCE) liberados. A chave do app é pública (não há segredo no app).
class DropboxConfig {
  /// Chave pública do app "WaxClub" no Dropbox (não é segredo: o login usa PKCE).
  static const String appKey = String.fromEnvironment('DROPBOX_APP_KEY', defaultValue: '27dns92hbr92qwn');

  /// Só leitura, mesmo que o cadastro no Dropbox libere mais permissões.
  static const String scopes = 'account_info.read files.metadata.read files.content.read';

  /// Retorno do login. O app intercepta a navegação para ele dentro do WebView; a página existe no site
  /// só como reserva ("volte ao WaxClub"). Precisa estar cadastrado em "Redirect URIs" no Dropbox.
  static const String redirectUri = 'https://waxclub.com.br/auth/dropbox/';

  /// Pasta do app dentro do Dropbox do usuário (o nome do app cadastrado no Dropbox).
  static const String appFolder = 'Dropbox/Apps/WaxClub';
}

/// Pasta do app no Dropbox: login PKCE com acesso renovável; lista e baixa só dessa pasta.
class DropboxFolder extends CloudLyricsFolder with OAuthTokens implements WebLoginCloudFolder {
  @override
  final CloudTokenStore tokenStore;
  final http.Client _client;
  final String appKey;

  String? _verifier;
  String? _state;

  DropboxFolder({CloudTokenStore? store, http.Client? client, String? appKey})
      : tokenStore = store ?? SecureCloudTokenStore(),
        _client = client ?? http.Client(),
        appKey = appKey ?? DropboxConfig.appKey;

  @override
  String get storeKey => 'waxclub_dropbox';
  @override
  String get cloudId => 'dropbox';
  @override
  String get serviceName => 'Dropbox'; // l10n-ignore
  @override
  String get folderLabel => DropboxConfig.appFolder;
  @override
  bool get configured => appKey.isNotEmpty;

  @override
  Uri authorizeUrl() {
    _verifier = Pkce.random(64);
    _state = Pkce.random(24);
    return Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': appKey,
      'response_type': 'code',
      'code_challenge': Pkce.challenge(_verifier!),
      'code_challenge_method': 'S256',
      'token_access_type': 'offline',
      'scope': DropboxConfig.scopes,
      'redirect_uri': DropboxConfig.redirectUri,
      'state': _state!,
    });
  }

  @override
  bool isCallback(String url) => url.startsWith(DropboxConfig.redirectUri);

  @override
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
    accessToken = j['access_token'] as String?;
    refreshToken = j['refresh_token'] as String?;
    expiresAt = DateTime.now().add(Duration(seconds: (j['expires_in'] as num? ?? 14400).toInt() - 60));
    if (accessToken == null || refreshToken == null) return false;
    savedAccountName = await _fetchAccountName();
    notifyListeners();
    await saveTokens();
    return true;
  }

  Future<String?> _fetchAccountName() async {
    try {
      final res = await _client.post(
        Uri.parse('https://api.dropboxapi.com/2/users/get_current_account'),
        headers: {'Authorization': 'Bearer $accessToken'},
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
    final t = accessToken;
    final exp = expiresAt;
    if (t != null && exp != null && DateTime.now().isBefore(exp)) return t;
    final refresh = refreshToken;
    if (refresh == null) throw StateError('Dropbox not connected'); // l10n-ignore
    final res = await _client.post(Uri.parse('https://api.dropboxapi.com/oauth2/token'), body: {
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
      'client_id': appKey,
    });
    if (res.statusCode == 400 || res.statusCode == 401) {
      await disconnect(revoke: false); // acesso revogado no Dropbox
      throw StateError('Dropbox access revoked'); // l10n-ignore
    }
    if (res.statusCode != 200) throw StateError('Dropbox token ${res.statusCode}'); // l10n-ignore
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    accessToken = j['access_token'] as String;
    expiresAt = DateTime.now().add(Duration(seconds: (j['expires_in'] as num? ?? 14400).toInt() - 60));
    await saveTokens();
    return accessToken!;
  }

  @override
  Future<List<CloudFile>> listAppFolder() async {
    final token = await _token();
    final files = <CloudFile>[];
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
        final path = e['path_display'] as String? ?? e['path_lower'] as String;
        files.add(CloudFile(
          id: path,
          path: path,
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

  @override
  Future<String> download(CloudFile file) async {
    final token = await _token();
    final res = await _client.post(
      Uri.parse('https://content.dropboxapi.com/2/files/download'),
      headers: {'Authorization': 'Bearer $token', 'Dropbox-API-Arg': headerJson({'path': file.id})},
    );
    if (res.statusCode != 200) throw StateError('Dropbox download ${res.statusCode}'); // l10n-ignore
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  @override
  Future<void> disconnect({bool revoke = true}) async {
    final t = accessToken;
    if (revoke && t != null) {
      try {
        await _client.post(Uri.parse('https://api.dropboxapi.com/2/auth/token/revoke'),
            headers: {'Authorization': 'Bearer $t'});
      } catch (_) {}
    }
    clearTokens();
    notifyListeners();
    await saveTokens();
  }
}
