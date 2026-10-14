import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import '../../l10n/l10n.dart';
import 'plugin_manifest.dart';

/// Categoria de plugin. Para criar outra categoria, basta acrescentar aqui (letra, cor e regra) e
/// os textos no app_en.arb: a jukebox monta teclado, filtros, prato e legenda a partir desta lista.
enum PluginCategory {
  language('L', Color(0xFF5FE08F), exclusive: true),
  display('D', Color(0xFF2FD6F0)),
  sources('S', Color(0xFFFFD34D)),
  ai('A', Color(0xFFB590FF)),
  connections('C', Color(0xFFFF9A3C));

  /// Letra do código de seleção na cartela (L1, D2, A1...).
  final String letter;

  /// Cor do vinil do compacto.
  final Color color;

  /// Só um plugin ativo por vez (ex.: idioma).
  final bool exclusive;

  const PluginCategory(this.letter, this.color, {this.exclusive = false});

  String get label => switch (this) {
        PluginCategory.language => l10n.pluginCatLanguage,
        PluginCategory.display => l10n.pluginCatDisplay,
        PluginCategory.sources => l10n.pluginCatSources,
        PluginCategory.ai => l10n.pluginCatAi,
        PluginCategory.connections => l10n.pluginCatConnections,
      };

  String get rule => switch (this) {
        PluginCategory.language => l10n.pluginRuleLanguage,
        PluginCategory.display => l10n.pluginRuleDisplay,
        PluginCategory.sources => l10n.pluginRuleSources,
        PluginCategory.ai => l10n.pluginRuleAi,
        PluginCategory.connections => l10n.pluginRuleConnections,
      };

  static PluginCategory? fromLetter(String letter) {
    for (final c in values) {
      if (c.letter == letter.toUpperCase()) return c;
    }
    return null;
  }
}

/// Situação de um plugin no catálogo.
enum PluginAvailability {
  /// Vem com o app; não pode ser desinstalado.
  builtIn,

  /// Pode ser instalado e ligado/desligado.
  installable,

  /// Anunciado, ainda não disponível.
  comingSoon,
}

/// Um plugin (compacto na jukebox). [number] forma o código com a letra da categoria.
class PluginInfo {
  final String id;
  final PluginCategory category;
  final int number;
  final String name;
  final String author;
  final String license;
  final String description;
  final PluginAvailability availability;

  /// Plugin embutido que não pode ser desligado (ex.: a única exibição de letra que existe hoje).
  final bool locked;

  /// Fonte de letras (categoria Lyrics sources): qual integração do app o plugin liga ('lrclib',
  /// 'netease'...). O plugin não traz código: o manifesto só liga uma integração que já vem no app.
  final String? engine;

  const PluginInfo({
    required this.id,
    required this.category,
    required this.number,
    required this.name,
    required this.author,
    required this.license,
    required this.description,
    this.availability = PluginAvailability.installable,
    this.locked = false,
    this.engine,
  });

  String get code => '${category.letter}$number';
  bool get isBuiltIn => availability == PluginAvailability.builtIn;
  bool get isComingSoon => availability == PluginAvailability.comingSoon;
  bool get isInstallable => availability == PluginAvailability.installable;
}

/// Catálogo de plugins conhecidos pelo app. Por enquanto: os embutidos e os anunciados; os plugins
/// baixados (página na Hostinger) entram aqui a partir do manifesto de cada um.
class PluginCatalog {
  PluginCatalog._();

  static List<PluginInfo> get builtIn => [
        PluginInfo(
          id: 'lang.en',
          category: PluginCategory.language,
          number: 1,
          name: l10n.pluginEnglishName,
          author: l10n.pluginAuthorBuiltIn,
          license: l10n.pluginLicenseOfficial,
          description: l10n.pluginEnglishDesc,
          availability: PluginAvailability.builtIn,
        ),
        PluginInfo(
          id: 'display.lyrics',
          category: PluginCategory.display,
          number: 1,
          name: l10n.pluginLyricsName,
          author: l10n.pluginAuthorBuiltIn,
          license: l10n.pluginLicenseLyrics,
          description: l10n.pluginLyricsDesc,
          availability: PluginAvailability.builtIn,
          locked: true,
        ),
        PluginInfo(
          id: 'display.curiosities',
          category: PluginCategory.display,
          number: 2,
          name: l10n.pluginCuriositiesName,
          author: l10n.pluginAuthorBuiltIn,
          license: l10n.pluginLicenseCuriosities,
          description: l10n.pluginCuriositiesDesc,
          availability: PluginAvailability.builtIn,
        ),
        // Fontes de letras: cada site consultado é um plugin. LRCLIB vem com o app; os outros são
        // instalados pelo site (waxclub.com.br/plugins), que só liga a integração já embutida no app.
        PluginInfo(
          id: 'lyrics.lrclib',
          category: PluginCategory.sources,
          number: 1,
          name: l10n.pluginLrclibName,
          author: l10n.pluginLrclibAuthor,
          license: l10n.pluginLrclibLicense,
          description: l10n.pluginLrclibDesc,
          availability: PluginAvailability.builtIn,
          engine: 'lrclib', // l10n-ignore
        ),
        PluginInfo(
          id: 'lyrics.netease',
          category: PluginCategory.sources,
          number: 2,
          name: l10n.pluginNeteaseName,
          author: l10n.pluginNeteaseAuthor,
          license: l10n.pluginSourceLicense,
          description: l10n.pluginNeteaseDesc,
          engine: 'netease', // l10n-ignore
        ),
        PluginInfo(
          id: 'lyrics.megalobiz',
          category: PluginCategory.sources,
          number: 3,
          name: l10n.pluginMegalobizName,
          author: l10n.pluginMegalobizAuthor,
          license: l10n.pluginSourceLicense,
          description: l10n.pluginMegalobizDesc,
          engine: 'megalobiz', // l10n-ignore
        ),
        PluginInfo(
          id: 'lyrics.lyricsovh',
          category: PluginCategory.sources,
          number: 4,
          name: l10n.pluginLyricsOvhName,
          author: l10n.pluginLyricsOvhAuthor,
          license: l10n.pluginSourceLicense,
          description: l10n.pluginLyricsOvhDesc,
          engine: 'lyrics.ovh', // l10n-ignore
        ),
        PluginInfo(
          id: 'ai.curiosities',
          category: PluginCategory.ai,
          number: 1,
          name: l10n.pluginAiCuriositiesName,
          author: l10n.pluginAuthorWaxClub,
          license: l10n.pluginLicenseAi,
          description: l10n.pluginAiCuriositiesDesc,
          availability: PluginAvailability.comingSoon,
        ),
        PluginInfo(
          id: 'ai.translate',
          category: PluginCategory.ai,
          number: 2,
          name: l10n.pluginAiTranslateName,
          author: l10n.pluginAuthorWaxClub,
          license: l10n.pluginLicenseAi,
          description: l10n.pluginAiTranslateDesc,
          availability: PluginAvailability.comingSoon,
        ),
        PluginInfo(
          id: discogsId,
          category: PluginCategory.connections,
          number: 1,
          name: l10n.pluginDiscogsName,
          author: l10n.pluginAuthorBuiltIn,
          license: l10n.pluginLicenseDiscogs,
          description: l10n.pluginDiscogsDesc,
          availability: PluginAvailability.builtIn,
        ),
      ];

  /// Plugin C1: conta Discogs (busca de prensagens, coleção no Discogs).
  static const String discogsId = 'connect.discogs';

  /// Fontes de letras que o app usava antes de virarem plugins (até a 1.4.8): quem já tinha o app
  /// continua com elas instaladas e ligadas.
  static const List<String> legacyLyricsSources = ['lyrics.netease', 'lyrics.megalobiz', 'lyrics.lyricsovh'];

  /// Página de plugins no site oficial.
  static const String siteUrl = 'https://waxclub.com.br/#plugins';
}

/// Plugin de conexão com um serviço externo (categoria Connections). O estado vem do próprio serviço
/// (ex.: [DiscogsAuthService]): ligado/desligado, conta conectada, entrar e sair da conta.
class PluginConnection {
  final Listenable listenable;
  final bool Function() isEnabled;
  final Future<void> Function(bool enabled) setEnabled;
  final bool Function() isConnected;
  final String? Function() accountName;

  /// Abre o login do serviço; `true` quando a conta foi conectada.
  final Future<bool> Function() connect;
  final Future<void> Function() disconnect;

  const PluginConnection({
    required this.listenable,
    required this.isEnabled,
    required this.setEnabled,
    required this.isConnected,
    required this.accountName,
    required this.connect,
    required this.disconnect,
  });
}

/// Quais plugins estão instalados e ligados ("no prato"), guardado no aparelho
/// (depois, sincronizado pela conta WaxClub).
class PluginStore extends ChangeNotifier {
  static const String _fileName = 'waxclub_plugins.json';
  final Directory? _directory;
  final List<PluginInfo> catalog;

  final Set<String> _installed = {};
  final Set<String> _active = {};
  bool _loaded = false;

  PluginStore({List<PluginInfo>? catalog, Directory? directory})
      : catalog = catalog ?? PluginCatalog.builtIn,
        _directory = directory {
    _applyDefaults();
  }

  bool get isLoaded => _loaded;

  PluginInfo? byCode(String code) {
    final c = code.toUpperCase().replaceAll(' ', '');
    for (final p in catalog) {
      if (p.code == c) return p;
    }
    return null;
  }

  bool isInstalled(PluginInfo p) => p.isBuiltIn || _installed.contains(p.id);
  bool isActive(PluginInfo p) => _connections[p.id]?.isEnabled() ?? _active.contains(p.id);

  final Map<String, PluginConnection> _connections = {};

  /// Embutidos que apareceram nesta versão do app (entram ligados).
  final Set<String> _newBuiltIns = {};

  PluginConnection? connectionFor(PluginInfo p) => _connections[p.id];

  /// Liga um plugin de conexão ao serviço que guarda o estado dele. Plugin novo nesta versão entra ligado.
  void bindConnection(String id, PluginConnection connection) {
    _connections[id]?.listenable.removeListener(notifyListeners);
    _connections[id] = connection;
    connection.listenable.addListener(notifyListeners);
    if (_loaded && _newBuiltIns.remove(id)) connection.setEnabled(true);
  }

  @override
  void dispose() {
    for (final c in _connections.values) {
      c.listenable.removeListener(notifyListeners);
    }
    super.dispose();
  }

  /// Pode ser ligado/desligado pelo usuário agora.
  bool canToggle(PluginInfo p) {
    if (p.isComingSoon || p.locked || !isInstalled(p)) return false;
    // Idioma: desligar o único ativo deixaria o app sem idioma; troca-se escolhendo outro
    if (p.category.exclusive && isActive(p)) return false;
    return true;
  }

  List<PluginInfo> installed() => catalog.where(isInstalled).toList();
  List<PluginInfo> activeIn(PluginCategory c) => catalog.where((p) => p.category == c && isActive(p)).toList();
  List<PluginInfo> notInstalled() => catalog.where((p) => !isInstalled(p)).toList();

  void _applyLanguageDefault() {
    for (final c in PluginCategory.values.where((c) => c.exclusive)) {
      final hasActive = _active.any((id) => catalog.any((p) => p.id == id && p.category == c));
      if (hasActive) continue;
      final builtIn = catalog.where((p) => p.category == c && p.isBuiltIn).toList();
      if (builtIn.isNotEmpty) _active.add(builtIn.first.id);
    }
  }

  void _applyDefaults() {
    // Embutidos começam ligados; o idioma padrão é o primeiro embutido da categoria
    for (final c in PluginCategory.values) {
      final builtIns = catalog.where((p) => p.category == c && p.isBuiltIn).toList();
      if (c.exclusive) {
        if (builtIns.isNotEmpty && !_active.any((id) => catalog.any((p) => p.id == id && p.category == c))) {
          _active.add(builtIns.first.id);
        }
      } else {
        _active.addAll(builtIns.map((p) => p.id));
      }
    }
  }

  /// Liga ou desliga. Em categoria exclusiva, ligar um desliga o outro.
  /// Retorna `false` se não for permitido (anunciado, travado, não instalado).
  Future<bool> toggle(PluginInfo p) async {
    if (!canToggle(p)) return false;
    final connection = _connections[p.id];
    if (connection != null) {
      await connection.setEnabled(!connection.isEnabled());
      notifyListeners();
      return true;
    }
    if (isActive(p)) {
      _active.remove(p.id);
    } else {
      if (p.category.exclusive) {
        _active.removeWhere((id) => catalog.any((q) => q.id == id && q.category == p.category));
      }
      _active.add(p.id);
    }
    notifyListeners();
    await _save();
    return true;
  }

  /// Instala um plugin disponível (por enquanto, só os do catálogo marcados como instaláveis).
  Future<bool> install(PluginInfo p) async {
    if (p.availability != PluginAvailability.installable || _installed.contains(p.id)) return false;
    _installed.add(p.id);
    notifyListeners();
    await _save();
    return true;
  }

  /// Versão do manifesto instalado de cada plugin (baixado do site).
  final Map<String, String> _versions = {};
  String? installedVersion(PluginInfo p) => _versions[p.id];

  PluginInfo? byId(String id) {
    for (final p in catalog) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Instala pelo manifesto do site e já põe no prato. O manifesto não traz código: ele precisa
  /// corresponder a um plugin que o app conhece (mesma categoria e mesma integração).
  Future<bool> installFromManifest(PluginManifest m) async {
    final p = byId(m.id);
    if (p == null || !p.isInstallable || p.category.letter != m.category || p.engine != m.engine) return false;
    _installed.add(p.id);
    _versions[p.id] = m.version;
    if (p.category.exclusive) {
      _active.removeWhere((id) => catalog.any((q) => q.id == id && q.category == p.category));
    }
    _active.add(p.id);
    notifyListeners();
    await _save();
    return true;
  }

  /// Tira do aparelho um plugin instalado pelo site (os embutidos ficam).
  Future<bool> uninstall(PluginInfo p) async {
    if (!p.isInstallable || !_installed.remove(p.id)) return false;
    _active.remove(p.id);
    _versions.remove(p.id);
    notifyListeners();
    await _save();
    return true;
  }

  /// A fonte de letras [engine] está instalada e ligada (LRCLIB, NetEase...).
  bool isLyricsEngineOn(String engine) =>
      catalog.any((p) => p.category == PluginCategory.sources && p.engine == engine && isInstalled(p) && isActive(p));

  Future<File?> _file() async {
    try {
      final dir = _directory ?? await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (f != null && await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final known = catalog.map((p) => p.id).toSet();
        _installed
          ..clear()
          ..addAll((j['installed'] as List<dynamic>? ?? const []).whereType<String>().where(known.contains));
        _versions
          ..clear()
          ..addAll((j['versions'] as Map<String, dynamic>? ?? const {}).map((k, v) => MapEntry(k, '$v')));
        final active = (j['active'] as List<dynamic>? ?? const []).whereType<String>().where(known.contains).toSet();
        // Embutidos que o usuário já conhecia respeitam o que ele escolheu; embutidos novos (de uma
        // versão nova do app) entram ligados. Travados continuam sempre ligados.
        // Arquivo da 1.3.12 (sem a lista): os embutidos daquela versão eram English e Synced lyrics
        final seen = j.containsKey('seenBuiltIns')
            ? (j['seenBuiltIns'] as List<dynamic>).whereType<String>().toSet()
            : const {'lang.en', 'display.lyrics'};
        _newBuiltIns.addAll(catalog.where((p) => p.isBuiltIn && !seen.contains(p.id)).map((p) => p.id));
        // Até a 1.4.8 as fontes de letras não eram plugins e o app usava todas: quem já tinha o app
        // continua com elas instaladas e ligadas
        final legacy = !seen.contains('lyrics.lrclib') // l10n-ignore
            ? PluginCatalog.legacyLyricsSources.where(known.contains)
            : const <String>[];
        _installed.addAll(legacy);
        _active
          ..clear()
          ..addAll(active)
          ..addAll(legacy)
          ..addAll(catalog.where((p) => p.locked).map((p) => p.id))
          ..addAll(catalog.where((p) =>
              p.isBuiltIn && !p.category.exclusive && !seen.contains(p.id)).map((p) => p.id));
        // Idioma: se nenhum ativo, o padrão
        _applyLanguageDefault();
      } else {
        _newBuiltIns.addAll(catalog.where((p) => p.isBuiltIn).map((p) => p.id)); // primeira abertura
      }
    } catch (e) {
      debugPrint('[PluginStore] Arquivo de plugins ilegível: $e');
    }
    _loaded = true;
    // Conexões novas nesta versão (ex.: Discogs na 1.3.22) entram ligadas
    final hadNew = _newBuiltIns.isNotEmpty;
    for (final id in _connections.keys.where(_newBuiltIns.contains).toList()) {
      _newBuiltIns.remove(id);
      await _connections[id]!.setEnabled(true);
    }
    if (hadNew) await _save(); // grava os embutidos vistos (não volta a ligar o que o usuário desligar)
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(jsonEncode({
        'version': 2,
        'installed': _installed.toList(),
        'active': _active.toList(),
        'versions': _versions,
        'seenBuiltIns': catalog.where((p) => p.isBuiltIn).map((p) => p.id).toList(),
      }));
    } catch (e) {
      debugPrint('[PluginStore] Falha ao salvar os plugins: $e');
    }
  }
}
