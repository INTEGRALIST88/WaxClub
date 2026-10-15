import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/ui/widgets/plugin_panel_strip.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_panel_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('painel: só plugins que mudam a tela (exibição e letras), sem os travados e os em breve', () {
    final store = PluginStore(directory: dir, bundleLyricsSources: true);
    final codes = store.panelPlugins().map((p) => p.code).toList();
    expect(codes, ['D1', 'S1', 'S2', 'S3'], reason: 'S5 não está instalado; L, A e C ficam de fora');
  });

  test('arrastar muda a ordem, fica salvo e vira a ordem da busca de letras', () async {
    final store = PluginStore(directory: dir, bundleLyricsSources: true);
    await store.load();
    expect(store.lyricsEngineOrder(), ['lrclib', 'netease', 'megalobiz']);

    // NetEase (S2, posição 2) para o começo
    await store.movePanelPlugin(2, 0);
    expect(store.panelPlugins().map((p) => p.code).toList(), ['S2', 'D1', 'S1', 'S3']);
    expect(store.lyricsEngineOrder(), ['netease', 'lrclib', 'megalobiz']);

    // Desligada não entra na busca
    await store.toggle(store.byCode('S1')!);
    expect(store.lyricsEngineOrder(), ['netease', 'megalobiz']);

    final again = PluginStore(directory: dir, bundleLyricsSources: true);
    await again.load();
    expect(again.panelPlugins().first.code, 'S2', reason: 'a ordem fica salva no aparelho');
  });

  test('a busca de letras consulta as fontes na ordem do painel', () async {
    final hosts = <String>[];
    final client = MockClient((req) async {
      hosts.add(req.url.host);
      return http.Response('{}', 404);
    });
    LyricsProviderService.sourceOrder = () => const ['netease', 'lrclib'];
    LyricsProviderService.sourceEnabled = (s) => s == 'netease' || s == 'lrclib';
    addTearDown(() {
      LyricsProviderService.sourceOrder = () => const ['local', 'lrclib', 'netease', 'megalobiz'];
      LyricsProviderService.sourceEnabled = (_) => true;
    });
    await LyricsProviderService(client: client).fetchLyricsDetails(trackName: 'Song', artistName: 'Band');
    final firstNetease = hosts.indexWhere((h) => h.contains('163'));
    final firstLrclib = hosts.indexWhere((h) => h.contains('lrclib'));
    expect(firstNetease, isNonNegative);
    expect(firstLrclib, isNonNegative);
    expect(firstNetease, lessThan(firstLrclib), reason: 'NetEase está antes da LRCLIB no painel');
  });

  testWidgets('caixinha: luz e código; tocar liga e desliga; as caixinhas dividem a largura', (tester) async {
    final store = PluginStore(directory: dir, bundleLyricsSources: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SizedBox(width: 360, child: PluginPanelStrip(store: store))),
    ));
    expect(find.text('D1'), findsOneWidget);
    expect(find.text('S3'), findsOneWidget);
    expect(find.text('S4'), findsNothing);
    final w = tester.getSize(find.ancestor(of: find.text('S1'), matching: find.byType(InkWell))).width;
    expect(w, closeTo((360 - 16) / 4 - 4, 1), reason: '4 caixinhas na largura da tela');

    final s1 = store.byCode('S1')!;
    expect(store.isActive(s1), isTrue);
    await tester.tap(find.text('S1'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(store.isActive(s1), isFalse);
    await tester.tap(find.text('S1'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(store.isActive(s1), isTrue);
  });

  testWidgets('arrastar para outra caixinha troca de lugar; para fora da linha pergunta se quer ejetar', (tester) async {
    final store = PluginStore(directory: dir, bundleLyricsSources: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const SizedBox(height: 200),
          SizedBox(width: 360, child: PluginPanelStrip(store: store)),
          const SizedBox(height: 300),
        ]),
      ),
    ));
    Future<void> drag(String code, Offset to) async {
      final from = tester.getCenter(find.text(code));
      final g = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 600)); // segurar
      for (var k = 1; k <= 5; k++) {
        await g.moveTo(Offset.lerp(from, to, k / 5)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    // S2 solto em cima do D1: vai para o começo (o arraste começa direto, sem precisar segurar)
    await drag('S2', tester.getCenter(find.text('D1')));
    expect(store.panelPlugins().first.code, 'S2');

    // S3 arrastado bem para baixo: pergunta; Cancel mantém
    await drag('S3', tester.getCenter(find.text('S3')) + const Offset(0, 200));
    expect(find.text('Eject this plugin?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.isInstalled(store.byCode('S3')!), isTrue);

    // De novo, agora ejeta
    await drag('S3', tester.getCenter(find.text('S3')) + const Offset(0, 200));
    await tester.tap(find.widgetWithText(FilledButton, 'Eject'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(store.isInstalled(store.byCode('S3')!), isFalse);
    expect(find.text('S3'), findsNothing);

    // Embutido (D1): não ejeta, só explica
    await drag('D1', tester.getCenter(find.text('D1')) - const Offset(0, 150));
    expect(find.text('Built-in plugin'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('D1'), findsOneWidget);
  });
}

