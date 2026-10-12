import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';
import 'package:waxclub/ui/widgets/vinyl_control_cockpit.dart';

class _FakeRecord extends AudioRecordService {
  @override
  Future<Uint8List?> recordSample({
    Duration duration = const Duration(milliseconds: 5000),
    int sampleRate = 16000,
    RecordPriority priority = RecordPriority.user,
  }) async =>
      Uint8List.fromList(List.filled(100, 1));

  @override
  Future<void> cancelRecording() async {}
}

class _FakeShazam extends ShazamService {
  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async => const TrackInfo(
        title: 'Um Título de Música Bem Comprido Para Testar Quebras de Linha',
        artist: 'Artista Com Nome Longo',
        album: 'Disco Com Nome Igualmente Longo e Detalhado',
        offsetSeconds: 30,
      );
}

class _FakeLyrics extends LyricsProviderService {
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async =>
      const LrcResponse(syncedLyrics: '[00:01.00] linha', durationSeconds: 240, source: 'lrclib');
}

void main() {
  late Directory tempDir;
  setUp(() async => tempDir = await Directory.systemTemp.createTemp('waxclub_cockpit_test_'));
  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  // Altura útil abaixo da barra do app: celular comum (~393×852) e compacto (~360×740)
  for (final size in const [Size(393, 730), Size(360, 600)]) {
    testWidgets('painel da transmissão cabe inteiro, sem estouro, em ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
      final engine = await tester.runAsync(() async {
        final cache = VinylCacheService(storageDirectory: tempDir);
        await cache.init();
        final e = WaxClubEngine(
          recordService: _FakeRecord(),
          shazamService: _FakeShazam(),
          lyricsService: _FakeLyrics(),
          cacheService: cache,
          logService: SessionLogService(storageDirectory: tempDir),
          castService: CastSyncService(),
        );
        await e.startListening();
        return e;
      });

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: VinylControlCockpit(
            engine: engine!,
            onOpenCastDialog: () {},
            onDisconnectCast: () {},
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Estouro de layout é reportado como exceção pelo framework
      expect(tester.takeException(), isNull);
      expect(find.text('LISTEN / RESYNC'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);

      // O bloco de ajustes tem rolagem só como proteção: o conteúdo precisa caber sem rolar
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: find.byType(VinylControlCockpit), matching: find.byType(Scrollable)).first,
      );
      expect(scrollable.position.maxScrollExtent, 0.0, reason: 'os ajustes devem caber sem rolagem');

      engine.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async => engine.dispose());
    });
  }
}
