import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

class MockRecordServiceForSpeedTest extends AudioRecordService {
  @override
  Future<Uint8List?> recordSample({
    Duration duration = const Duration(seconds: 4),
    int sampleRate = 16000,
    RecordPriority priority = RecordPriority.background,
  }) async {
    return Uint8List(100);
  }
}

class MockShazamServiceForSpeedTest extends ShazamService {
  TrackInfo? nextResult;

  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async {
    return nextResult;
  }
}

class MockLyricsServiceForSpeedTest extends LyricsProviderService {
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    return LrcResponse(
      syncedLyrics: '[00:00.00] Linha 0\n[00:05.00] Linha 5s\n[00:10.00] Linha 10s',
      albumName: albumName,
      durationSeconds: durationSeconds?.toDouble() ?? 180.0,
      source: preferredSource ?? 'lrclib',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VinylCacheService cacheService;
  late SessionLogService logService;
  late MockRecordServiceForSpeedTest recordService;
  late MockShazamServiceForSpeedTest shazamService;
  late MockLyricsServiceForSpeedTest lyricsService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('waxclub_speed_test_');
    cacheService = VinylCacheService(storageDirectory: tempDir);
    await cacheService.init();
    logService = SessionLogService(storageDirectory: tempDir);
    recordService = MockRecordServiceForSpeedTest();
    shazamService = MockShazamServiceForSpeedTest();
    lyricsService = MockLyricsServiceForSpeedTest();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Speed Calibration Independence and Isolation Tests', () {
    test('Faixas consecutivas iniciam limpas sem acumular resíduo de velocidade de faixas anteriores', () async {
      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      shazamService.nextResult = const TrackInfo(
        title: 'Música 1',
        artist: 'Artista Teste',
        offsetSeconds: 5.0,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(engine.telemetry.speedFactor, equals(1.0));

      // Simula transição para a Música 2
      await engine.handleManualTrackTransitionForTesting(
        const TrackInfo(
          title: 'Música 2',
          artist: 'Artista Teste',
          offsetSeconds: 2.0,
        ),
      );

      // Música 2 deve iniciar com velocidade nominal e isolada (1.000x)
      expect(engine.telemetry.speedFactor, equals(1.0));

      // Simula transição para a Música 3
      await engine.handleManualTrackTransitionForTesting(
        const TrackInfo(
          title: 'Música 3',
          artist: 'Artista Teste',
          offsetSeconds: 1.0,
        ),
      );

      // Música 3 DEVE iniciar estritamente com velocidade nominal (1.000x), sem qualquer aceleração indevida
      expect(engine.telemetry.speedFactor, equals(1.0));

      engine.dispose();
    });

    test('Quando velocidade do toca-discos é confirmada, nova faixa herda a velocidade estável sem sofrer drift', () async {
      // Salva uma calibração estável de 1.015x
      await cacheService.saveTurntableSpeed(1.015);

      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Deve herdar o prior estável de 1.015x
      expect(engine.telemetry.speedFactor, closeTo(1.015, 0.001));
      expect(engine.isHardwareSpeedCalibrated, isTrue);

      // Transita para a faixa 2 e faixa 3
      await engine.handleManualTrackTransitionForTesting(
        const TrackInfo(
          title: 'Música 2',
          artist: 'Artista Teste',
          offsetSeconds: 2.0,
        ),
      );
      expect(engine.telemetry.speedFactor, closeTo(1.015, 0.001));

      await engine.handleManualTrackTransitionForTesting(
        const TrackInfo(
          title: 'Música 3',
          artist: 'Artista Teste',
          offsetSeconds: 0.0,
        ),
      );
      // Na música 3, a velocidade permanece exatamente 1.015x (estável), sem saltos espúrios
      expect(engine.telemetry.speedFactor, closeTo(1.015, 0.001));

      engine.dispose();
    });
  });
}
