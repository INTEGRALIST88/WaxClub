import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/ui/screens/plugin_jukebox_screen.dart';
import 'package:waxclub/ui/widgets/jukebox_machine.dart';

const _fr = PluginInfo(
  id: 'lang.fr',
  category: PluginCategory.language,
  number: 4,
  name: 'Français',
  author: 'Community',
  license: 'Community translation',
  description: 'French',
);
const _theme = PluginInfo(
  id: 'display.theme',
  category: PluginCategory.display,
  number: 9,
  name: 'Wood TV theme',
  author: 'Community',
  license: 'MIT',
  description: 'Theme',
);

/// Serviço de conta falso (no app é o DiscogsAuthService).
class _FakeDiscogs extends ChangeNotifier {
  bool enabled = false;
  String? user;

  void set({bool? enabled, String? user}) {
    if (enabled != null) this.enabled = enabled;
    if (user != null) this.user = user;
    notifyListeners();
  }

  late final PluginConnection connection = PluginConnection(
    listenable: this,
    isEnabled: () => enabled,
    setEnabled: (v) async => set(enabled: v),
    isConnected: () => user != null,
    accountName: () => user,
    connect: () async {
      set(user: 'vinylfan', enabled: true);
      return true;
    },
    disconnect: () async {
      user = null;
      notifyListeners();
    },
  );
}

void main() {
  test('categorias: letra, cor e regra; idioma é um por vez', () {
    expect(PluginCategory.values.map((c) => c.letter), ['L', 'D', 'S', 'A', 'C']);
    expect(PluginCategory.connections.label, 'Connections');
    expect(PluginCategory.language.exclusive, isTrue);
    expect(PluginCategory.display.exclusive, isFalse);
    expect(PluginCategory.fromLetter('a'), PluginCategory.ai);
    expect(PluginCategory.fromLetter('X'), isNull);
  });

  test('embutidos começam no prato: English (idioma) e Curiosidades (D1); a letra não é mais plugin D', () {
    final store = PluginStore();
    final en = store.byCode('L1')!;
    final curiosities = store.byCode('d1')!;
    expect(en.name, 'English');
    expect(curiosities.id, 'display.curiosities');
    expect(store.isActive(en), isTrue);
    expect(store.isActive(curiosities), isTrue);
    expect(store.canToggle(curiosities), isTrue);
    expect(store.byCode('D2'), isNull, reason: 'o antigo D1 (Synced lyrics) saiu: as letras são os plugins S');
    expect(store.canToggle(en), isFalse, reason: 'o idioma ativo só troca escolhendo outro');
    expect(store.byCode('A1')!.isComingSoon, isTrue);
    expect(store.notInstalled().every((p) => p.isComingSoon || p.isInstallable), isTrue,
        reason: 'fora do app: os anunciados e os que se instalam pelo site (S2–S4)');
  });

  test('ligar outro idioma desliga o anterior; exibição aceita vários', () async {
    final store = PluginStore(catalog: [...PluginCatalog.builtIn, _fr, _theme]);
    expect(await store.toggle(_fr), isFalse, reason: 'precisa instalar antes');
    expect(await store.install(_fr), isTrue);
    expect(await store.toggle(_fr), isTrue);
    expect(store.isActive(_fr), isTrue);
    expect(store.isActive(store.byCode('L1')!), isFalse);
    expect(store.activeIn(PluginCategory.language).map((p) => p.code), ['L4']);

    await store.install(_theme);
    await store.toggle(_theme);
    expect(store.activeIn(PluginCategory.display).map((p) => p.code), ['D1', 'D9']);
    await store.toggle(_theme);
    expect(store.activeIn(PluginCategory.display).map((p) => p.code), ['D1']);
  });

  test('Discogs vem pré-instalado (C1) e o estado fica no serviço do Discogs', () async {
    final service = _FakeDiscogs();
    final store = PluginStore()..bindConnection(PluginCatalog.discogsId, service.connection);
    final discogs = store.byCode('C1')!;
    expect(discogs.name, 'Discogs');
    expect(discogs.isBuiltIn, isTrue);
    expect(store.isInstalled(discogs), isTrue);

    // primeira abertura desta versão: a conexão nova entra ligada
    await store.load();
    expect(service.enabled, isTrue);
    expect(store.isActive(discogs), isTrue);

    // ligar/desligar na jukebox muda o serviço; mudar no serviço aparece na jukebox
    expect(await store.toggle(discogs), isTrue);
    expect(service.enabled, isFalse);
    service.set(enabled: true);
    expect(store.isActive(discogs), isTrue);
  });

  testWidgets('plugin de conexão: sem conta mostra "Connect your Discogs account"; conectado mostra a conta', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final service = _FakeDiscogs();
    final store = PluginStore()..bindConnection(PluginCatalog.discogsId, service.connection);

    await tester.pumpWidget(MaterialApp(home: PluginJukeboxScreen(store: store)));
    await tester.pump(const Duration(milliseconds: 100));
    // tocar na cartela do C1: o braço busca o disco e abrem os detalhes
    await tester.tap(find.byKey(const ValueKey('strip-${PluginCatalog.discogsId}')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('No account connected yet.'), findsOneWidget);

    await tester.tap(find.text('Connect your Discogs account'));
    await tester.pump();
    expect(find.text('Connected as vinylfan'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
  });

  testWidgets('jukebox: pilha de discos, cartelas, ON/OFF, filtro por categoria e detalhes', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final store = PluginStore();

    await tester.pumpWidget(MaterialApp(home: PluginJukeboxScreen(store: store)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plugin Jukebox'), findsOneWidget);
    expect(find.byType(JukeboxMachine), findsOneWidget, reason: 'vitrine com a pilha e o mecanismo');
    expect(find.byKey(const ValueKey('strip-lang.en')), findsOneWidget);
    expect(find.text('Tap a record or a strip'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // ON/OFF da cartela liga e desliga o plugin (Curiosidades, D1)
    final d1 = store.byCode('D1')!;
    expect(store.isActive(d1), isTrue);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('strip-display.curiosities')), matching: find.text('ON')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.isActive(d1), isFalse);
    expect(find.descendant(of: find.byKey(const ValueKey('strip-display.curiosities')), matching: find.text('OFF')), findsOneWidget);
    expect(find.text('D1 · Record curiosities'), findsOneWidget, reason: 'o visor mostra o disco escolhido');

    // Botão-joia "L" filtra as cartelas: só os idiomas
    await tester.tap(find.text('L'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('strip-lang.en')), findsOneWidget);
    expect(find.byKey(const ValueKey('strip-display.curiosities')), findsNothing);

    // Tocar na cartela abre os detalhes do plugin
    await tester.tap(find.byKey(const ValueKey('strip-lang.en')));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('menus and texts of the app in English'), findsOneWidget);
    expect(find.textContaining('Only one Language plugin plays at a time'), findsOneWidget);
  });
}
