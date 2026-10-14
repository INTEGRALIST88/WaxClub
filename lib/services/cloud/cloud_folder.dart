import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../local_lyrics_library.dart';

/// Um arquivo na pasta de letras da nuvem (Dropbox, OneDrive, Google Drive).
class CloudFile {
  /// Identificador no serviço (no Dropbox, o próprio caminho).
  final String id;

  /// Caminho dentro da pasta de letras (para mostrar e para achar o mesmo arquivo de novo).
  final String path;
  final String name;

  /// Revisão: muda quando o arquivo muda.
  final String rev;
  final int size;

  /// Endereço de download já autorizado (OneDrive), se o serviço der um.
  final String? downloadUrl;

  const CloudFile({
    required this.id,
    required this.path,
    required this.name,
    required this.rev,
    required this.size,
    this.downloadUrl,
  });
}

/// Armazenamento das credenciais (abstrato para os testes).
abstract class CloudTokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

/// Cifrado no aparelho (Keystore do Android).
class SecureCloudTokenStore implements CloudTokenStore {
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

class MemoryCloudTokenStore implements CloudTokenStore {
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

/// PKCE (OAuth 2 sem segredo no app): verificador aleatório e desafio S256.
class Pkce {
  static String random(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String challenge(String verifier) =>
      base64Url.encode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
}

/// Pasta de letras do usuário num serviço de nuvem (plugin S5). Cada serviço diz como conectar,
/// listar e baixar; a biblioteca de letras faz o resto ([LocalLyricsLibrary.syncFrom]).
abstract class CloudLyricsFolder extends ChangeNotifier implements LyricsFolderSource {
  /// 'dropbox', 'onedrive', 'gdrive'.
  @override
  String get cloudId;

  /// Nome do serviço ("Dropbox").
  String get serviceName;

  /// Onde o usuário guarda os arquivos ("Dropbox/Apps/WaxClub").
  String get folderLabel;

  /// O app tem as chaves do serviço (sem elas, o cartão não aparece).
  bool get configured;
  bool get isConnected;
  String? get accountName;
  DateTime? get lastSync;

  Future<void> load();
  Future<void> markSynced(DateTime at);
  Future<void> disconnect();

  /// Atualiza a biblioteca de letras com a pasta e anota a hora.
  Future<LyricsFolderSync> syncInto(LocalLyricsLibrary lib) async {
    final r = await lib.syncFrom(this);
    await markSynced(DateTime.now());
    return r;
  }
}

/// Serviço com login OAuth 2 + PKCE numa página web dentro do app (Dropbox, OneDrive).
abstract class WebLoginCloudFolder extends CloudLyricsFolder {
  /// Endereço da página de login (começa um novo login).
  Uri authorizeUrl();

  /// Endereço de retorno do login (interceptado no WebView).
  bool isCallback(String url);

  /// Troca o código do retorno pelo acesso. `true` = conectado.
  Future<bool> finishLogin(Uri callback);
}

/// Credenciais salvas de um serviço com login OAuth (acesso + renovação).
mixin OAuthTokens on CloudLyricsFolder {
  CloudTokenStore get tokenStore;
  String get storeKey;

  String? accessToken;
  DateTime? expiresAt;
  String? refreshToken;
  String? savedAccountName;
  DateTime? savedLastSync;
  bool _tokensLoaded = false;

  @override
  bool get isConnected => refreshToken != null;
  @override
  String? get accountName => savedAccountName;
  @override
  DateTime? get lastSync => savedLastSync;

  @override
  Future<void> load() async {
    if (_tokensLoaded) return;
    _tokensLoaded = true;
    final raw = await tokenStore.read(storeKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        refreshToken = j['refresh'] as String?;
        accessToken = j['access'] as String?;
        expiresAt = DateTime.tryParse(j['expires'] as String? ?? '');
        savedAccountName = j['name'] as String?;
        savedLastSync = DateTime.tryParse(j['lastSync'] as String? ?? '');
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> saveTokens() => tokenStore.write(
      storeKey,
      refreshToken == null
          ? null
          : jsonEncode({
              'refresh': refreshToken,
              'access': accessToken,
              'expires': expiresAt?.toIso8601String(),
              'name': savedAccountName,
              'lastSync': savedLastSync?.toIso8601String(),
            }));

  @override
  Future<void> markSynced(DateTime at) async {
    savedLastSync = at;
    notifyListeners();
    await saveTokens();
  }

  void clearTokens() {
    accessToken = null;
    refreshToken = null;
    expiresAt = null;
    savedAccountName = null;
    savedLastSync = null;
  }
}
