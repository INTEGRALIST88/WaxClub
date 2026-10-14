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
    expect(codes, ['D2', 'S1', 'S2', 'S3', 'S4'], reason: 'D1 é travado; S5 não está instalado; L, A e C ficam de fora');
  });

  test('arrastar muda a ordem, fica salvo e vira a ordem da busca de letras', () async {
    final store = PluginStore(directory: dir, bundleLyricsSources: true);
    await store.load();
    expect(store.lyricsEngineOrder(), ['lrclib', 'netease', 'megalobiz', 'lyrics.ovh']);

    // NetEase (S2, posição 2) para o começo
    await store.movePanelPlugin(2, 0);
    expect(store.panelPlugins().map((p) => p.code).toList(), ['S2', 'D2', 'S1', 'S3', 'S4']);
    expect(store.lyricsEngineOrder(), ['netease', 'lrclib', 'megalobiz', 'lyrics.ovh']);

    // Desligada não entra na busca
    await store.toggle(store.byCode('S1')!);
    expect(store.lyricsEngineOrder(), ['netease', 'megalobiz', 'lyrics.ovh']);

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
      LyricsProviderService.sourceOrder = () => const ['local', 'lrclib', 'netease', 'megalobiz', 'lyrics.ovh'];
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
    expect(find.text('D2'), findsOneWidget);
    expect(find.text('S4'), findsOneWidget);
    final w = tester.getSize(find.ancestor(of: find.text('S1'), matching: find.byType(InkWell))).width;
    expect(w, closeTo((360 - 16) / 5 - 4, 1), reason: '5 caixinhas na largura da tela');

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
}
