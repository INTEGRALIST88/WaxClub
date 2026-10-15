import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';
import 'package:waxclub/ui/screens/home_screen.dart';

void main() {
  testWidgets('em pé, com música tocando: música, banda e disco no alto, ao lado da capa, sem estourar', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late WaxClubEngine engine;
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('waxclub_portrait_');
      final cache = VinylCacheService(storageDirectory: dir);
      await cache.init();
      engine = WaxClubEngine(cacheService: cache, logService: SessionLogService(storageDirectory: dir));
      await engine.loadManualTrack(
        title: 'Coming Around Again',
        artist: 'Carly Simon',
        startOffsetSeconds: 10,
        lrcText: '[00:01.00] Baby sneezes\n[00:04.00] Mommy pleases',
      );
    });

    await tester.pumpWidget(MaterialApp(home: HomeScreen(engine: engine)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull, reason: 'nada pode estourar na barra superior');
    final title = find.text('Coming Around Again');
    expect(title, findsOneWidget);
    expect(find.text('Carly Simon'), findsOneWidget, reason: 'banda logo abaixo da música');

    // No alto, ao lado da capa (logo à esquerda) e acima dos botões de madeira e do painel de plugins
    final cover = tester.getRect(find.byWidgetPredicate((w) => w is Image && w.width == 66));
    final t = tester.getRect(title);
    expect(cover.width, greaterThanOrEqualTo(60), reason: 'capa um pouco maior em pé');
    expect(t.left, greaterThan(cover.right));
    expect(t.top, lessThan(cover.bottom));
    final buttons = tester.getRect(find.bySemanticsLabel('Plugins').first);
    expect(t.bottom, lessThan(buttons.top), reason: 'a música fica acima dos botões e dos plugins');

    engine.stop();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
  });
}
