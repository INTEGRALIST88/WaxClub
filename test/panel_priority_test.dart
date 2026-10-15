import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/ui/widgets/plugin_panel_strip.dart';

void main() {
  group('letra exibível', () {
    const good = '[00:10.00] um\n[00:20.00] dois\n[00:30.00] três\n[03:00.00] fim';
    test('sincronizada: 3 linhas ou mais e tempo compatível com a música', () {
      expect(LyricsQuality.usable(good, durationSeconds: 200), isTrue);
      expect(LyricsQuality.usable('[00:10.00] um\n[00:20.00] dois', durationSeconds: 200), isFalse, reason: '2 linhas');
      expect(LyricsQuality.usable(good, durationSeconds: 60), isFalse, reason: 'a letra vai muito além do fim');
      expect(LyricsQuality.usable('[00:05.00] a\n[00:10.00] b\n[00:15.00] c', durationSeconds: 240), isFalse,
          reason: 'acaba antes de um quarto da música');
      expect(LyricsQuality.usable(good), isTrue, reason: 'sem a duração, só conta as linhas');
    });

    test('texto simples: pelo menos 4 linhas', () {
      expect(LyricsQuality.usable('linha um\nlinha dois'), isFalse);
      expect(LyricsQuality.usable('a\nb\nc\nd'), isTrue);
      expect(LyricsQuality.usable('[ar:Banda]\n[ti:Música]\na\nb'), isFalse, reason: 'tags não contam');
    });
  });

  test('a cascata pula a letra quebrada (vermelho) e usa a próxima fonte', () async {
    final hosts = <String>[];
    final client = MockClient((req) async {
      hosts.add(req.url.host);
      if (req.url.host.contains('lrclib') && req.url.path.endsWith('/get')) {
        return http.Response(
            r'{"id":1,"trackName":"Song","artistName":"Band","albumName":"A","duration":200,"syncedLyrics":"[00:10.00] so\n[02:50.00] duas"}',
            200,
            headers: {'content-type': 'application/json'});
      }
      if (req.url.host.contains('lrclib')) {
        return http.Response(
            r'[{"id":1,"trackName":"Song","artistName":"Band","albumName":"A","duration":200,"syncedLyrics":"[00:10.00] so\n[02:50.00] duas"}]',
            200,
            headers: {'content-type': 'application/json'});
      }
      return http.Response('{}', 404);
    });
    LyricsProviderService.sourceOrder = () => const ['lrclib', 'netease'];
    LyricsProviderService.sourceEnabled = (s) => s == 'lrclib' || s == 'netease';
    addTearDown(() {
      LyricsProviderService.sourceOrder = () => const ['local', 'lrclib', 'netease', 'megalobiz', 'lyrics.ovh'];
      LyricsProviderService.sourceEnabled = (_) => true;
    });
    final service = LyricsProviderService(client: client, lrcLibService: LrcLibService(client: client));
    final r = await service.fetchLyricsDetails(trackName: 'Song', artistName: 'Band', durationSeconds: 200);
    expect(r, isNull, reason: 'a NetEase de mentira não tem letra');
    expect(service.lastAttempts['lrclib'], LyricsAttempt.broken);
    expect(service.lastAttempts['netease'], LyricsAttempt.notFound);
  });

  testWidgets('painel: luz vermelha em quem não achou nada; brilho embaixo de quem está na tela', (tester) async {
    final dir = Directory.systemTemp.createTempSync('waxclub_prio_');
    final store = PluginStore(directory: dir, bundleLyricsSources: true);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: PluginPanelStrip(store: store, shownId: 'lyrics.netease', failedIds: const {'lyrics.lrclib'}),
        ),
      ),
    ));
    expect(find.bySemanticsLabel(RegExp(r'^S1 · LRCLIB — found nothing')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^S2 · NetEase Cloud Music — on')), findsOneWidget);
    final lights = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    final colors = lights.map((c) => (c.decoration as BoxDecoration?)?.color).toList();
    expect(colors, contains(PluginPanelStrip.failedColor), reason: 'a luz da S1 está vermelha');
    // Brilho: uma barra creme logo abaixo da caixinha da S2
    final glow = find.byWidgetPredicate((w) =>
        w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).boxShadow?.length == 2);
    expect(glow, findsOneWidget);
    final s2 = tester.getRect(find.text('S2'));
    final g = tester.getRect(glow);
    expect(g.center.dx, closeTo(s2.center.dx, 20));
    expect(g.top, greaterThan(s2.bottom));
  });
}
