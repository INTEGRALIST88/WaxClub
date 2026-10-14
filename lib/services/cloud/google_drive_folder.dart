import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../app_info.dart';
import 'cloud_folder.dart';

/// Acesso do Google Drive: o login do Google do Android (o Google não aceita login dentro de WebView).
/// [interactive] = pode mostrar a escolha de conta e o pedido de permissão; sem ele, só devolve um
/// acesso já concedido (ou nulo).
typedef GoogleDriveTokenProvider = Future<String?> Function({required bool interactive});

/// Pasta "WaxClub Lyrics" no Google Drive do usuário (em qualquer lugar do Drive).
///
/// O Google não tem "pasta só do app" que o usuário veja no computador, então é preciso a permissão de
/// **ler o Drive** (`drive.readonly`, escopo restrito): funciona em teste (até 100 usuários de teste no
/// projeto Google Cloud); para o app publicado, o Google exige uma auditoria de segurança anual.
/// O WaxClub só abre a pasta "WaxClub Lyrics".
class GoogleDriveFolder extends CloudLyricsFolder {
  static const String scope = 'https://www.googleapis.com/auth/drive.readonly';
  static const String folderName = 'WaxClub Lyrics';
  static const String _api = 'https://www.googleapis.com/drive/v3';
  static const String _key = 'waxclub_gdrive';

  final CloudTokenStore _store;
  final http.Client _client;
  final GoogleDriveTokenProvider _tokens;

  bool _connected = false;
  String? _accountName;
  DateTime? _lastSync;
  bool _loaded = false;

  GoogleDriveFolder({CloudTokenStore? store, http.Client? client, GoogleDriveTokenProvider? tokens})
      : _store = store ?? SecureCloudTokenStore(),
        _client = client ?? http.Client(),
        _tokens = tokens ?? _pluginToken;

  static bool _initialized = false;

  /// Acesso pelo google_sign_in (mesmo projeto do login com Google do WaxClub).
  static Future<String?> _pluginToken({required bool interactive}) async {
    final google = GoogleSignIn.instance;
    if (!_initialized) {
      try {
        await google.initialize(serverClientId: kGoogleServerClientId);
      } catch (_) {} // já inicializado pelo login com Google
      _initialized = true;
    }
    final client = google.authorizationClient;
    final authz = interactive
        ? await client.authorizeScopes(const [scope])
        : await client.authorizationForScopes(const [scope]);
    return authz?.accessToken;
  }

  @override
  String get cloudId => 'gdrive';
  @override
  String get serviceName => 'Google Drive'; // l10n-ignore
  @override
  String get folderLabel => folderName;
  @override
  bool get configured => true;
  @override
  bool get isConnected => _connected;
  @override
  String? get accountName => _accountName;
  @override
  DateTime? get lastSync => _lastSync;

  @override
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _store.read(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _connected = j['connected'] == true;
        _accountName = j['name'] as String?;
        _lastSync = DateTime.tryParse(j['lastSync'] as String? ?? '');
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() => _store.write(
      _key,
      _connected
          ? jsonEncode({'connected': true, 'name': _accountName, 'lastSync': _lastSync?.toIso8601String()})
          : null);

  @override
  Future<void> markSynced(DateTime at) async {
    _lastSync = at;
    notifyListeners();
    await _save();
  }

  /// Escolha da conta e permissão de leitura do Drive. `true` = conectado.
  Future<bool> connect() async {
    final String? token;
    try {
      token = await _tokens(interactive: true);
    } catch (_) {
      return false;
    }
    if (token == null) return false;
    _connected = true;
    _accountName = await _fetchAccountName(token);
    notifyListeners();
    await _save();
    return true;
  }

  Future<String?> _fetchAccountName(String token) async {
    try {
      final res = await _client.get(Uri.parse('$_api/about?fields=user(displayName,emailAddress)'),
          headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) return null;
      final user = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      return user?['displayName'] as String? ?? user?['emailAddress'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String> _token() async {
    final t = await _tokens(interactive: false);
    if (t == null) throw StateError('Google Drive needs to be connected again'); // l10n-ignore
    return t;
  }

  Future<Map<String, dynamic>> _getJson(String token, String path, Map<String, String> query) async {
    final res = await _client.get(Uri.parse('$_api/$path').replace(queryParameters: query),
        headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw StateError('Google Drive ${res.statusCode}'); // l10n-ignore
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Arquivos das pastas "WaxClub Lyrics" (com subpastas).
  @override
  Future<List<CloudFile>> listAppFolder() async {
    final token = await _token();
    const folderType = 'application/vnd.google-apps.folder';
    final roots = await _getJson(token, 'files', {
      'q': "name = '$folderName' and mimeType = '$folderType' and trashed = false", // l10n-ignore
      'fields': 'files(id,name)',
      'pageSize': '20',
    });
    final pending = <(String, String)>[
      for (final f in (roots['files'] as List<dynamic>).whereType<Map<String, dynamic>>()) (f['id'] as String, ''),
    ];
    final files = <CloudFile>[];
    while (pending.isNotEmpty) {
      final (folderId, prefix) = pending.removeLast();
      String? page;
      do {
        final j = await _getJson(token, 'files', {
          'q': "'$folderId' in parents and trashed = false", // l10n-ignore
          'fields': 'nextPageToken,files(id,name,mimeType,size,md5Checksum,modifiedTime)',
          'pageSize': '200',
          if (page != null) 'pageToken': page,
        });
        for (final e in (j['files'] as List<dynamic>).whereType<Map<String, dynamic>>()) {
          final name = e['name'] as String;
          if (e['mimeType'] == folderType) {
            pending.add((e['id'] as String, '$prefix/$name'));
          } else {
            files.add(CloudFile(
              id: e['id'] as String,
              path: '$prefix/$name',
              name: name,
              rev: e['md5Checksum'] as String? ?? e['modifiedTime'] as String? ?? '',
              size: int.tryParse('${e['size'] ?? 0}') ?? 0,
            ));
          }
        }
        page = j['nextPageToken'] as String?;
      } while (page != null);
    }
    return files;
  }

  @override
  Future<String> download(CloudFile file) async {
    final token = await _token();
    final res = await _client.get(Uri.parse('$_api/files/${file.id}?alt=media'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) throw StateError('Google Drive download ${res.statusCode}'); // l10n-ignore
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  @override
  Future<void> disconnect() async {
    try {
      final t = await _tokens(interactive: false);
      if (t != null) {
        await _client.post(Uri.parse('https://oauth2.googleapis.com/revoke'), body: {'token': t});
        await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: t);
      }
    } catch (_) {}
    _connected = false;
    _accountName = null;
    _lastSync = null;
    notifyListeners();
    await _save();
  }
}
