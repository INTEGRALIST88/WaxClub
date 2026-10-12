import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/sync_state.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

class MockAudioRecordService extends AudioRecordService {
  @override
  Future<Uint8List?> recordSample({Duration? duration, int sampleRate = 16000, RecordPriority priority = RecordPriority.user}) async {
    return Uint8List.fromList(List.filled(100, 1));
  }

  @override
  Future<void> cancelRecording() async {}
}

class MockShazamService extends ShazamService {
  TrackInfo? nextResult;

  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async {
    return nextResult;
  }
}

class MockLyricsProviderService extends LyricsProviderService {
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    return LrcResponse(
      syncedLyrics: '[00:01.00] Linha 1\n[00:05.00] Linha 2\n[02:50.00] Fim',
      albumName: albumName ?? 'Disco Teste',
      durationSeconds: 180.0,
    );
  }

  @override
  Future<String?> fetchSyncedLyrics({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    return '[00:01.00] Linha 1\n[00:05.00] Linha 2\n[02:50.00] Fim';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VinylCacheService cacheService;
  late SessionLogService logService;
  late MockAudioRecordService recordService;
  late MockShazamService shazamService;
  late MockLyricsProviderService lyricsService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fixes_test_');
    cacheService = VinylCacheService(storageDirectory: tempDir);
    await cacheService.init();

    logService = SessionLogService(storageDirectory: tempDir);
    recordService = MockAudioRecordService();
    shazamService = MockShazamService();
    lyricsService = MockLyricsProviderService();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('Capa do disco é preservada durante a predição da próxima faixa', () async {
    await cacheService.saveTracklist(
      album: 'Album Clássico',
      artist: 'Banda X',
      entries: const [
        TrackEntry(position: 1, title: 'Musica 1', side: 'A', lengthMs: 180000),
        TrackEntry(position: 2, title: 'Musica 2', side: 'A', lengthMs: 180000),
        TrackEntry(position: 3, title: 'Musica 3', side: 'B', lengthMs: 180000),
      ],
      source: 'catalog',
    );
    await cacheService.updateDiscCover('Album Clássico', 'Banda X', 'https://covers.com/album.jpg');

    final engine = WaxClubEngine(
      recordService: recordService,
      shazamService: shazamService,
      lyricsService: lyricsService,
      castService: CastSyncService(),
      cacheService: cacheService,
      logService: logService,
    );

    // Música 1 identificada
    shazamService.nextResult = const TrackInfo(
      title: 'Musica 1',
      artist: 'Banda X',
      album: 'Album Clássico',
      offsetSeconds: 10.0,
      coverUrl: 'https://covers.com/album.jpg',
    );

    await engine.startListening();
    expect(engine.currentTrack?.coverUrl, 'https://covers.com/album.jpg');

    // Nudge para o fim da música para disparar autoListenNextTrack
    shazamService.nextResult = const TrackInfo(
      title: 'Musica 2',
      artist: 'Banda X',
      album: 'Album Clássico',
      offsetSeconds: 5.0,
    );

    engine.seekTo(179.9);
    await Future.delayed(const Duration(milliseconds: 250));

    // A faixa prevista deve carregar a capa herdada
    expect(engine.currentTrack?.title, 'Musica 2');
    expect(engine.currentTrack?.coverUrl, isNotNull);
    expect(engine.currentTrack?.coverUrl, 'https://covers.com/album.jpg');

    engine.stop();
    engine.dispose();
  });

  test('startListening chamado do zero reinicia a sessão de forma limpa', () async {
    final engine = WaxClubEngine(
      recordService: recordService,
      shazamService: shazamService,
      lyricsService: lyricsService,
      castService: CastSyncService(),
      cacheService: cacheService,
      logService: logService,
    );

    shazamService.nextResult = const TrackInfo(
      title: 'Musica A',
      artist: 'Artista A',
      album: 'Disco A',
      offsetSeconds: 20.0,
    );

    await engine.startListening();
    expect(engine.currentTrack?.title, 'Musica A');
    expect(engine.telemetry.status, isNot(CalibrationStatus.idle));

    // Segundo toque inicia nova identificação limpa
    shazamService.nextResult = const TrackInfo(
      title: 'Musica B',
      artist: 'Artista B',
      album: 'Disco B',
      offsetSeconds: 12.0,
    );

    await engine.startListening();
    expect(engine.currentTrack?.title, 'Musica B');

    engine.stop();
    engine.dispose();
  });
}
