import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cloud_folder.dart';

/// App WaxClub cadastrado na Microsoft (portal.azure.com → App registrations): contas pessoais e
/// corporativas, plataforma "Mobile and desktop applications" com o endereço de retorno abaixo, e
/// permissões delegadas `Files.ReadWrite.AppFolder`, `User.Read` e `offline_access`. Cliente público
/// (PKCE): não há segredo no app. O WaxClub só enxerga a pasta do app (`OneDrive/Apps/<nome do app>`).
class OneDriveConfig {
  /// ID público do app "WaxClub" na Microsoft (não é segredo: o login usa PKCE).
  static const String clientId =
      String.fromEnvironment('ONEDRIVE_CLIENT_ID', defaultValue: 'f993ec1a-2e5a-4e72-87f0-16e4c068a491');
  static const String redirectUri = 'https://waxclub.com.br/auth/onedrive/';
  static const String appFolder = 'OneDrive/Apps/WaxClub';
  static const String scopes = 'offline_access User.Read Files.ReadWrite.AppFolder';
  static const String authority = 'https://login.microsoftonline.com/common/oauth2/v2.0';
}

/// Pasta do app no OneDrive: login PKCE com acesso renovável; lista e baixa só dessa pasta.
class OneDriveFolder extends CloudLyricsFolder with OAuthTokens implements WebLoginCloudFolder {
  static const String _graph = 'https://graph.microsoft.com/v1.0';

  @override
  final CloudTokenStore tokenStore;
  final http.Client _client;
  final String clientId;

  String? _verifier;
  String? _state;

  OneDriveFolder({CloudTokenStore? store, http.Client? client, String? clientId})
      : tokenStore = store ?? SecureCloudTokenStore(),
        _client = client ?? http.Client(),
        clientId = clientId ?? OneDriveConfig.clientId;

  @override
  String get storeKey => 'waxclub_onedrive';
  @override
  String get cloudId => 'onedrive';
  @override
  String get serviceName => 'OneDrive'; // l10n-ignore
  @override
  String get folderLabel => OneDriveConfig.appFolder;
  @override
  bool get configured => clientId.isNotEmpty;

  @override
  Uri authorizeUrl() {
    _verifier = Pkce.random(64);
    _state = Pkce.random(24);
    return Uri.parse('${OneDriveConfig.authority}/authorize').replace(queryParameters: {
      'client_id': clientId,
      'response_type': 'code',
      'response_mode': 'query',
      'redirect_uri': OneDriveConfig.redirectUri,
      'scope': OneDriveConfig.scopes,
      'code_challenge': Pkce.challenge(_verifier!),
      'code_challenge_method': 'S256',
      'state': _state!,
    });
  }

  @override
  bool isCallback(String url) => url.startsWith(OneDriveConfig.redirectUri);

  void _takeTokens(Map<String, dynamic> j) {
    accessToken = j['access_token'] as String?;
    // A Microsoft troca o refresh token a cada renovação
    refreshToken = j['refresh_token'] as String? ?? refreshToken;
    expiresAt = DateTime.now().add(Duration(seconds: (j['expires_in'] as num? ?? 3600).toInt() - 60));
  }

  @override
  Future<bool> finishLogin(Uri callback) async {
    final code = callback.queryParameters['code'];
    if (code == null || callback.queryParameters['state'] != _state || _verifier == null) return false;
    final res = await _client.post(Uri.parse('${OneDriveConfig.authority}/token'), body: {
      'client_id': clientId,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': OneDriveConfig.redirectUri,
      'code_verifier': _verifier!,
      'scope': OneDriveConfig.scopes,
    });
    _verifier = null;
    _state = null;
    if (res.statusCode != 200) return false;
    _takeTokens(jsonDecode(res.body) as Map<String, dynamic>);
    if (accessToken == null || refreshToken == null) return false;
    savedAccountName = await _fetchAccountName();
    notifyListeners();
    await saveTokens();
    return true;
  }

  Future<String?> _fetchAccountName() async {
    try {
      final res = await _client.get(Uri.parse('$_graph/me?\$select=displayName,userPrincipalName'),
          headers: {'Authorization': 'Bearer $accessToken'});
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return j['displayName'] as String? ?? j['userPrincipalName'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String> _token() async {
    final t = accessToken;
    final exp = expiresAt;
    if (t != null && exp != null && DateTime.now().isBefore(exp)) return t;
    final refresh = refreshToken;
    if (refresh == null) throw StateError('OneDrive not connected'); // l10n-ignore
    final res = await _client.post(Uri.parse('${OneDriveConfig.authority}/token'), body: {
      'client_id': clientId,
      'grant_type': 'refresh_token',
      'refresh_token': refresh,
      'scope': OneDriveConfig.scopes,
    });
    if (res.statusCode == 400 || res.statusCode == 401) {
      await disconnect();
      throw StateError('OneDrive access revoked'); // l10n-ignore
    }
    if (res.statusCode != 200) throw StateError('OneDrive token ${res.statusCode}'); // l10n-ignore
    _takeTokens(jsonDecode(res.body) as Map<String, dynamic>);
    await saveTokens();
    return accessToken!;
  }

  /// Todos os arquivos da pasta do app (com subpastas).
  @override
  Future<List<CloudFile>> listAppFolder() async {
    final token = await _token();
    final files = <CloudFile>[];
    // Pastas a visitar: (endereço da listagem, caminho para mostrar)
    final pending = <(String, String)>[('$_graph/me/drive/special/approot/children', '')];
    while (pending.isNotEmpty) {
      final (first, prefix) = pending.removeLast();
      String? next = '$first?\$top=200';
      while (next != null) {
        final res = await _client.get(Uri.parse(next), headers: {'Authorization': 'Bearer $token'});
        if (res.statusCode != 200) throw StateError('OneDrive list ${res.statusCode}'); // l10n-ignore
        final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        for (final e in (j['value'] as List<dynamic>).whereType<Map<String, dynamic>>()) {
          final name = e['name'] as String;
          final id = e['id'] as String;
          if (e['folder'] != null) {
            pending.add(('$_graph/me/drive/items/$id/children', '$prefix/$name'));
          } else if (e['file'] != null) {
            files.add(CloudFile(
              id: id,
              path: '$prefix/$name',
              name: name,
              rev: e['eTag'] as String? ?? e['cTag'] as String? ?? '',
              size: (e['size'] as num? ?? 0).toInt(),
              downloadUrl: e['@microsoft.graph.downloadUrl'] as String?,
            ));
          }
        }
        next = j['@odata.nextLink'] as String?;
      }
    }
    return files;
  }

  @override
  Future<String> download(CloudFile file) async {
    final http.Response res;
    if (file.downloadUrl != null) {
      // Endereço já autorizado, de curta duração (sem o token)
      res = await _client.get(Uri.parse(file.downloadUrl!));
    } else {
      final token = await _token();
      res = await _client.get(Uri.parse('$_graph/me/drive/items/${file.id}/content'),
          headers: {'Authorization': 'Bearer $token'});
    }
    if (res.statusCode != 200) throw StateError('OneDrive download ${res.statusCode}'); // l10n-ignore
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  @override
  Future<void> disconnect() async {
    // A Microsoft não tem revogação por token para apps públicos: o app esquece o acesso; o usuário pode
    // removê-lo em account.microsoft.com → Privacy → Apps and services
    clearTokens();
    notifyListeners();
    await saveTokens();
  }
}
