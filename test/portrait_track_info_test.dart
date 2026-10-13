import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';
import 'package:waxclub/ui/screens/home_screen.dart';

void main() {
  testWidgets('em pé, com música tocando: música, banda · disco abaixo do disco, sem estourar', (tester) async {
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
    expect(find.text('Coming Around Again'), findsOneWidget, reason: 'nome da música na faixa abaixo do disco');
    expect(find.textContaining('Carly Simon'), findsOneWidget, reason: 'banda (· disco) na segunda linha');
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);

    engine.stop();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 8));
  });
}
