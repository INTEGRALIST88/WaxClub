import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plugin_catalog.dart';

/// Manifesto de um plugin publicado no site (waxclub.com.br/plugins/<id>.json).
///
/// **Só dados, nenhum código** (regra da Apple, App Store 2.5.2, e boa prática no Android): o manifesto
/// descreve o plugin e diz qual integração **que já vem no app** ele liga (ex.: a fonte de letras
/// NetEase). Instalar é baixar e validar este arquivo; nada é executado.
class PluginManifest {
  static const String format = 'waxclub-plugin';
  static const int formatVersion = 1;
  static const String baseUrl = 'https://waxclub.com.br/plugins';

  final String id;

  /// Letra da categoria (L, D, S, A, C).
  final String category;
  final int number;
  final String name;
  final String version;
  final String? engine;

  const PluginManifest({
    required this.id,
    required this.category,
    required this.number,
    required this.name,
    required this.version,
    this.engine,
  });

  static Uri urlFor(String id) => Uri.parse('$baseUrl/$id.json');

  /// Lê e valida o manifesto; lança [FormatException] se não for um manifesto de plugin WaxClub
  /// ou se pedir uma versão mais nova do formato.
  factory PluginManifest.fromJson(Map<String, dynamic> j) {
    if (j['format'] != format) throw const FormatException('not a WaxClub plugin'); // l10n-ignore
    final fv = j['formatVersion'];
    if (fv is! int || fv > formatVersion) throw const FormatException('newer plugin format'); // l10n-ignore
    final id = j['id'];
    final category = j['category'];
    final number = j['number'];
    final name = j['name'];
    final version = j['version'];
    if (id is! String || !RegExp(r'^[a-z0-9]+(\.[a-z0-9]+)+$').hasMatch(id)) {
      throw const FormatException('bad id'); // l10n-ignore
    }
    if (category is! String || number is! int || name is! String || version is! String) {
      throw const FormatException('missing fields'); // l10n-ignore
    }
    final provides = j['provides'];
    final engine = provides is Map<String, dynamic> ? provides['engine'] as String? : null;
    return PluginManifest(id: id, category: category, number: number, name: name, version: version, engine: engine);
  }
}

/// Resultado de uma instalação pelo site.
enum PluginInstallResult {
  installed,
  alreadyInstalled,
  builtIn,

  /// O app não conhece este plugin (precisa de uma versão mais nova do WaxClub).
  needsUpdate,

  /// Não existe no site (ou foi retirado).
  notFound,

  /// Arquivo inválido.
  invalid,

  /// Sem internet / site fora do ar.
  network,
}

/// Instala plugins a partir do site: baixa o manifesto, confere e liga o plugin.
class PluginInstaller {
  final PluginStore store;
  final http.Client _client;

  PluginInstaller({required this.store, http.Client? client}) : _client = client ?? http.Client();

  Future<PluginInstallResult> install(String id) async {
    await store.load();
    final known = store.byId(id);
    if (known != null && known.isBuiltIn) return PluginInstallResult.builtIn;
    if (known != null && store.isInstalled(known)) return PluginInstallResult.alreadyInstalled;
    final http.Response res;
    try {
      res = await _client.get(PluginManifest.urlFor(id)).timeout(const Duration(seconds: 15));
    } catch (_) {
      return PluginInstallResult.network;
    }
    if (res.statusCode == 404) return PluginInstallResult.notFound;
    if (res.statusCode != 200) return PluginInstallResult.network;
    final PluginManifest m;
    try {
      m = PluginManifest.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
    } on FormatException catch (e) {
      return e.message == 'newer plugin format' ? PluginInstallResult.needsUpdate : PluginInstallResult.invalid; // l10n-ignore
    } catch (_) {
      return PluginInstallResult.invalid;
    }
    if (m.id != id) return PluginInstallResult.invalid;
    if (known == null || known.isComingSoon) return PluginInstallResult.needsUpdate;
    return await store.installFromManifest(m) ? PluginInstallResult.installed : PluginInstallResult.invalid;
  }
}
