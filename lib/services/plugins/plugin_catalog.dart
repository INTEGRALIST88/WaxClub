import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import '../../l10n/l10n.dart';

/// Categoria de plugin. Para criar outra categoria, basta acrescentar aqui (letra, cor e regra) e
/// os textos no app_en.arb: a jukebox monta teclado, filtros, prato e legenda a partir desta lista.
enum PluginCategory {
  language('L', Color(0xFF5FE08F), exclusive: true),
  display('D', Color(0xFF2FD6F0)),
  ai('A', Color(0xFFB590FF));

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
        PluginCategory.ai => l10n.pluginCatAi,
      };

  String get rule => switch (this) {
        PluginCategory.language => l10n.pluginRuleLanguage,
        PluginCategory.display => l10n.pluginRuleDisplay,
        PluginCategory.ai => l10n.pluginRuleAi,
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
  });

  String get code => '${category.letter}$number';
  bool get isBuiltIn => availability == PluginAvailability.builtIn;
  bool get isComingSoon => availability == PluginAvailability.comingSoon;
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
          id: 'lang.pt-BR',
          category: PluginCategory.language,
          number: 2,
          name: l10n.pluginPortugueseName,
          author: l10n.pluginAuthorWaxClub,
          license: l10n.pluginLicenseOfficial,
          description: l10n.pluginLanguagePackDesc,
          availability: PluginAvailability.comingSoon,
        ),
        PluginInfo(
          id: 'lang.es',
          category: PluginCategory.language,
          number: 3,
          name: l10n.pluginSpanishName,
          author: l10n.pluginAuthorWaxClub,
          license: l10n.pluginLicenseOfficial,
          description: l10n.pluginLanguagePackDesc,
          availability: PluginAvailability.comingSoon,
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
          author: l10n.pluginAuthorWaxClub,
          license: l10n.pluginLicenseCuriosities,
          description: l10n.pluginCuriositiesDesc,
          availability: PluginAvailability.comingSoon,
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
      ];
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
  bool isActive(PluginInfo p) => _active.contains(p.id);

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
        final active = (j['active'] as List<dynamic>? ?? const []).whereType<String>().where(known.contains).toSet();
        // Travados continuam sempre ligados
        _active
          ..clear()
          ..addAll(active)
          ..addAll(catalog.where((p) => p.locked).map((p) => p.id));
        _applyDefaults();
      }
    } catch (e) {
      debugPrint('[PluginStore] Arquivo de plugins ilegível: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(jsonEncode({'version': 1, 'installed': _installed.toList(), 'active': _active.toList()}));
    } catch (e) {
      debugPrint('[PluginStore] Falha ao salvar os plugins: $e');
    }
  }
}
