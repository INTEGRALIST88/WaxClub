import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/engine/prediction_tuning.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/sync_state.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/prefetch_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

class _FakeRecordService extends AudioRecordService {
  @override
  Future<Uint8List?> recordSample({
    Duration duration = const Duration(milliseconds: 5000),
    int sampleRate = 16000,
    RecordPriority priority = RecordPriority.user,
  }) async {
    return Uint8List.fromList(List.filled(100, 1));
  }

  @override
  Future<void> cancelRecording() async {}
}

class _FakeShazamService extends ShazamService {
  TrackInfo? nextResult;

  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async => nextResult;
}

class _FakeLyricsService extends LyricsProviderService {
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    return LrcResponse(
      syncedLyrics: '[00:01.00] Linha 1\n[00:05.00] Linha 2',
      albumName: albumName,
      durationSeconds: 180.0,
      source: 'lrclib',
    );
  }
}

/// Prefetch cuja resolução de capa só termina quando o teste mandar (simula rede lenta).
class _SlowCoverPrefetchService extends PrefetchService {
  final Completer<AlbumResolutionResult?> pending = Completer();
  bool called = false;

  _SlowCoverPrefetchService({required super.cacheService, super.lyricsService});

  @override
  Future<AlbumResolutionResult?> resolveAlbumCover({
    TrackInfo? firstTrack,
    TrackInfo? secondTrack,
    List<TrackInfo>? sessionTracks,
  }) {
    called = true;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VinylCacheService cacheService;
  late SessionLogService logService;
  late _FakeRecordService recordService;
  late _FakeShazamService shazamService;
  late _FakeLyricsService lyricsService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('waxclub_bugfix_test_');
    cacheService = VinylCacheService(storageDirectory: tempDir);
    await cacheService.init();
    logService = SessionLogService(storageDirectory: tempDir);
    recordService = _FakeRecordService();
    shazamService = _FakeShazamService();
    lyricsService = _FakeLyricsService();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  WaxClubEngine buildEngine({PrefetchService? prefetchService}) => WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
        prefetchService: prefetchService,
      );

  test('Bug 1: velocidade persistida do toca-discos sobrevive ao startListening', () async {
    await cacheService.saveTurntableSpeed(1.015);
    final engine = buildEngine();
    await Future.delayed(const Duration(milliseconds: 100));

    shazamService.nextResult = const TrackInfo(title: 'Faixa 1', artist: 'Artista', offsetSeconds: 10.0);
    await engine.startListening();

    expect(engine.isHardwareSpeedCalibrated, isTrue);
    expect(engine.telemetry.speedFactor, closeTo(1.015, 0.001));
    engine.dispose();
  });

  test('Bug 3: retificação de capa tardia é descartada após stop()', () async {
    final prefetch = _SlowCoverPrefetchService(cacheService: cacheService, lyricsService: lyricsService);
    final engine = buildEngine(prefetchService: prefetch);

    shazamService.nextResult = const TrackInfo(title: 'Faixa 1', artist: 'Artista', offsetSeconds: 10.0);
    await engine.startListening();
    await engine.handleManualTrackTransitionForTesting(
      const TrackInfo(title: 'Faixa 2', artist: 'Artista', offsetSeconds: 2.0),
    );
    expect(prefetch.called, isTrue);

    engine.stop();
    prefetch.pending.complete(const AlbumResolutionResult(
      albumName: 'Album Tardio',
      coverUrl: 'https://example.com/capa.jpg',
      tracklist: [TrackEntry(position: 1, title: 'Faixa 1')],
    ));
    await Future.delayed(const Duration(milliseconds: 20));

    expect(engine.isAlbumLocked, isFalse);
    expect(engine.lockedAlbumName, isNull);
    expect(engine.currentTrack, isNull);
    engine.dispose();
  });

  test('Bug 4: nudge em debounce é gravado ao parar a escuta', () async {
    final engine = buildEngine();
    shazamService.nextResult = const TrackInfo(title: 'Faixa Nudge', artist: 'Artista', offsetSeconds: 10.0);
    await engine.startListening();

    engine.nudgeSync(0.5);
    engine.stop(); // antes dos 3s de debounce

    expect(cacheService.getLyricOffsetMs('Faixa Nudge', 'Artista'), equals(500));
    engine.dispose();
  });

  test('Bug 5a: pausar/retomar agenda ressincronia rápida pelo microfone', () async {
    final engine = buildEngine();
    shazamService.nextResult = const TrackInfo(
      title: 'Faixa Longa',
      artist: 'Artista',
      offsetSeconds: 10.0,
      durationMs: 180000,
    );
    await engine.startListening();
    expect(engine.isHardwareSpeedCalibrated, isFalse);

    engine.pause();
    engine.resume();

    // Ressincronia agendada logo após a retomada (a posição real após a pausa é desconhecida)
    expect(engine.telemetry.countdownSeconds, equals(PredictionTuning.resumeResyncDelaySeconds));
    engine.dispose();
  });

  test('Bug 5b: pausar/retomar em "Vire o disco" volta a aguardar a virada', () async {
    await cacheService.saveTracklist(
      album: 'Disco Teste',
      artist: 'Artista',
      entries: const [
        TrackEntry(position: 1, title: 'Faixa A1', number: 'A1', lengthMs: 180000),
        TrackEntry(position: 2, title: 'Faixa B1', number: 'B1', lengthMs: 180000),
      ],
      source: 'catalog',
      sideSource: 'catalog',
    );
    final engine = buildEngine();
    shazamService.nextResult = const TrackInfo(
      title: 'Faixa A1',
      artist: 'Artista',
      album: 'Disco Teste',
      offsetSeconds: 178.0,
      durationMs: 180000,
    );
    await engine.startListening();
    await Future.delayed(const Duration(milliseconds: 100));
    engine.seekTo(180.0);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(engine.telemetry.status, equals(CalibrationStatus.waitingEndOfSide));

    engine.pause();
    expect(engine.telemetry.status, equals(CalibrationStatus.paused));
    engine.resume();

    expect(engine.telemetry.status, equals(CalibrationStatus.waitingEndOfSide));
    expect(engine.telemetry.statusMessage, contains('Vire o disco'));
    engine.dispose();
  });

  test('Bug 7: fonte preferida lyrics.ovh continua sendo aceita na cascata', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'api.lyrics.ovh') {
        return http.Response(jsonEncode({'lyrics': 'Linha um\nLinha dois'}), 200);
      }
      return http.Response('not found', 404);
    });
    final service = LyricsProviderService(client: client);

    final result = await service.fetchLyricsDetails(
      trackName: 'Musica Rara',
      artistName: 'Artista',
      preferredSource: 'lyrics.ovh',
    );

    expect(result, isNotNull);
    expect(result!.source, equals('lyrics.ovh'));
    expect(result.syncedLyrics, contains('Linha um'));
  });
}
