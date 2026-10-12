import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

class MockRecordServiceForPhase2 extends AudioRecordService {
  Uint8List? sampleToReturn;

  @override
  Future<Uint8List?> recordSample({Duration? duration, int sampleRate = 16000, RecordPriority priority = RecordPriority.user}) async {
    // Retorna sampleToReturn ou 100 bytes não-silenciosos por padrão
    return sampleToReturn ?? Uint8List.fromList(List.filled(100, 1));
  }

  @override
  Future<void> cancelRecording() async {}
}

class MockShazamServiceForPhase2 extends ShazamService {
  TrackInfo? nextResult;
  int recognitionCallCount = 0;

  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async {
    recognitionCallCount++;
    return nextResult;
  }
}

class MockLyricsProviderServiceForPhase2 extends LyricsProviderService {
  String? lastPreferredSourceRequested;

  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    lastPreferredSourceRequested = preferredSource;
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
  late MockRecordServiceForPhase2 recordService;
  late MockShazamServiceForPhase2 shazamService;
  late MockLyricsProviderServiceForPhase2 lyricsService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('engine_phase2_test_');
    cacheService = VinylCacheService(storageDirectory: tempDir);
    await cacheService.init();

    logService = SessionLogService(storageDirectory: tempDir);
    recordService = MockRecordServiceForPhase2();
    shazamService = MockShazamServiceForPhase2();
    lyricsService = MockLyricsProviderServiceForPhase2();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('WaxClubEngine Phase 2 Tests (T2.1 - T2.5)', () {
    test('T2.4: Nudge altera lyricBiasSeconds e sobrevive ao realinhamento acústico', () async {
      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      shazamService.nextResult = const TrackInfo(
        title: 'Música Nudge',
        artist: 'Artista Nudge',
        album: 'Álbum Nudge',
        offsetSeconds: 2.0,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      // Aplica nudge de +3.5s
      engine.nudgeSync(3.5);
      expect(engine.lyricBiasSeconds, closeTo(3.5, 0.001));

      // Com offset em 2.0s + nudge 3.5s = 5.5s (procurando linha das 5s)
      expect(engine.activeLineIndex, equals(1)); // Linha 5s

      // Simula realinhamento acústico aos 15s (que antes redefinia baseOffset e apagava o nudge)
      engine.seekTo(8.0);
      // Posição 8.0s + bias 3.5s = 11.5s -> linha das 10s
      expect(engine.lyricBiasSeconds, closeTo(3.5, 0.001));
      expect(engine.activeLineIndex, equals(2)); // Linha 10s

      engine.dispose();
    });

    test('T2.4: Nudge é persistido com debounce no cache e reaplicado ao recarregar a faixa', () async {
      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      shazamService.nextResult = const TrackInfo(
        title: 'Faixa Persistente',
        artist: 'Banda Persistente',
        album: 'Álbum Persistente',
        offsetSeconds: 0.0,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      // Aplica nudge de +1.2s
      engine.nudgeSync(1.2);

      // Aguarda o debounce de 3 segundos
      await Future.delayed(const Duration(milliseconds: 3200));

      final savedOffset = cacheService.getLyricOffsetMs('Faixa Persistente', 'Banda Persistente');
      expect(savedOffset, equals(1200));

      engine.dispose();

      // Recarrega uma nova instância do engine simulando nova reprodução da mesma música
      final newRecordService = MockRecordServiceForPhase2();
      final newEngine = WaxClubEngine(
        recordService: newRecordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      await newEngine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      // O bias salvo de 1.2s deve ter sido carregado e reaplicado automaticamente!
      expect(newEngine.lyricBiasSeconds, closeTo(1.2, 0.001));

      newEngine.dispose();
    });

    test('T2.3: Prior de velocidade calibrada é restaurado do cache quando válido e recente', () async {
      // Salva uma calibração recente de 1.025x (+2.5%)
      await cacheService.saveTurntableSpeed(1.025);

      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      // Aguarda inicialização assíncrona do cache
      await Future.delayed(const Duration(milliseconds: 100));

      expect(engine.telemetry.speedFactor, closeTo(1.025, 0.001));
      engine.dispose();
    });

    test('T2.3: Prior de velocidade com desvio > 5% é descartado e inicia em 1.000x', () async {
      // Salva valor aberrante de 1.15x (+15%)
      await cacheService.saveTurntableSpeed(1.150);

      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Deve manter nominal 1.000x
      expect(engine.telemetry.speedFactor, closeTo(1.000, 0.001));
      engine.dispose();
    });

    test('T2.2: Captura silenciosa não gasta chamada de rede ao Shazam na confirmação', () async {
      final entries = [
        const TrackEntry(position: 1, title: 'Faixa Silenciosa 1', number: '1'),
        const TrackEntry(position: 2, title: 'Faixa Silenciosa 2', number: '2'),
      ];

      await cacheService.saveTracklist(
        album: 'Álbum Silêncio',
        artist: 'Artista Silêncio',
        entries: entries,
        source: 'catalog',
      );

      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      shazamService.nextResult = const TrackInfo(
        title: 'Faixa Silenciosa 1',
        artist: 'Artista Silêncio',
        album: 'Álbum Silêncio',
        offsetSeconds: 10.0,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(shazamService.recognitionCallCount, equals(1)); // Primeira identificação

      // Configura o gravador para retornar silêncio absoluto (zeros) na próxima faixa
      recordService.sampleToReturn = Uint8List(16000 * 2 * 3); // 3 segundos de zeros
      shazamService.nextResult = const TrackInfo(
        title: 'Faixa Silenciosa 2',
        artist: 'Artista Silêncio',
        album: 'Álbum Silêncio',
        offsetSeconds: 5.0,
      );

      // Forçar término da faixa 1 para acionar predição e confirmação em background
      engine.seekTo(180.0);

      // Aguarda o delay inicial de confirmação (2s + tempo de gravação)
      await Future.delayed(const Duration(milliseconds: 2500));

      // Como o áudio era silêncio absoluto, o Shazam NÃO pode ter sido chamado novamente!
      expect(shazamService.recognitionCallCount, equals(1));
      // A letra da faixa prevista continua na tela durante o silêncio
      expect(engine.currentTrack?.title, equals('Faixa Silenciosa 2'));

      engine.dispose();
    });

    test('T2.4: Fonte preferida de letras salva no cache é repassada na consulta', () async {
      // Salva uma fonte preferida para a faixa
      await cacheService.saveLyricsSource('Música Fonte', 'Artista Fonte', 'netease');

      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      shazamService.nextResult = const TrackInfo(
        title: 'Música Fonte',
        artist: 'Artista Fonte',
        album: 'Álbum Fonte',
        offsetSeconds: 0.0,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      // Verifica que o LyricsProviderService recebeu preferredSource = 'netease'
      expect(lyricsService.lastPreferredSourceRequested, equals('netease'));

      engine.dispose();
    });
  });
}
