import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/ui/screens/plugin_jukebox_screen.dart';
import 'package:waxclub/ui/widgets/seven_inch_record.dart';

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

void main() {
  test('categorias: letra, cor e regra; idioma é um por vez', () {
    expect(PluginCategory.values.map((c) => c.letter), ['L', 'D', 'A']);
    expect(PluginCategory.language.exclusive, isTrue);
    expect(PluginCategory.display.exclusive, isFalse);
    expect(PluginCategory.fromLetter('a'), PluginCategory.ai);
    expect(PluginCategory.fromLetter('X'), isNull);
  });

  test('embutidos começam no prato: English (idioma) e Synced lyrics (exibição)', () {
    final store = PluginStore();
    final en = store.byCode('L1')!;
    final lyrics = store.byCode('d1')!;
    expect(en.name, 'English');
    expect(store.isActive(en), isTrue);
    expect(store.isActive(lyrics), isTrue);
    expect(store.canToggle(lyrics), isFalse, reason: 'a letra é a única exibição que existe hoje');
    expect(store.canToggle(en), isFalse, reason: 'o idioma ativo só troca escolhendo outro');
    expect(store.byCode('A1')!.isComingSoon, isTrue);
    expect(store.notInstalled().every((p) => p.isComingSoon), isTrue);
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
    expect(store.activeIn(PluginCategory.display).map((p) => p.code), ['D1', 'D2', 'D9']);
    await store.toggle(_theme);
    expect(store.activeIn(PluginCategory.display).map((p) => p.code), ['D1', 'D2']);
  });

  testWidgets('jukebox: discos por categoria e seleção pelo teclado abre o plugin', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: PluginJukeboxScreen(store: PluginStore())));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plugin Jukebox'), findsOneWidget);
    expect(find.byType(SevenInchRecord), findsWidgets);
    expect(tester.takeException(), isNull);

    // Teclado: L + 1 + Select → abre English
    await tester.tap(find.text('L').first);
    await tester.pump();
    await tester.tap(find.text('1').first);
    await tester.pump();
    await tester.tap(find.text('Select'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('menus and texts of the app in English'), findsOneWidget);
    expect(find.textContaining('Only one Language plugin plays at a time'), findsOneWidget);
  });
}
