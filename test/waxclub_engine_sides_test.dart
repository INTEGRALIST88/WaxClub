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

class FakeAudioRecordService extends AudioRecordService {
  @override
  Future<Uint8List?> recordSample({Duration? duration, int sampleRate = 16000, RecordPriority priority = RecordPriority.user}) async {
    return Uint8List.fromList(List.filled(100, 1));
  }

  @override
  Future<void> cancelRecording() async {}
}

class FakeShazamService extends ShazamService {
  TrackInfo? nextResult;

  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async {
    return nextResult;
  }
}

class FakeLyricsProviderService extends LyricsProviderService {
  final Map<String, String> lyricsMap = {};

  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    final lrc = lyricsMap[trackName] ?? '[00:01.00] Linha 1\n[00:05.00] Linha 2';
    return LrcResponse(
      syncedLyrics: lrc,
      albumName: albumName,
      durationSeconds: durationSeconds?.toDouble() ?? 180.0,
    );
  }

  @override
  Future<String?> fetchSyncedLyrics({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
  }) async {
    return lyricsMap[trackName] ?? '[00:01.00] Linha 1\n[00:05.00] Linha 2';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late VinylCacheService cacheService;
  late SessionLogService logService;
  late FakeAudioRecordService recordService;
  late FakeShazamService shazamService;
  late FakeLyricsProviderService lyricsService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('engine_sides_test_');
    cacheService = VinylCacheService(storageDirectory: tempDir);
    await cacheService.init();

    logService = SessionLogService(storageDirectory: tempDir);
    recordService = FakeAudioRecordService();
    shazamService = FakeShazamService();
    lyricsService = FakeLyricsProviderService();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('WaxClubEngine Sides & Prediction Tests (T1.4 / T1.6)', () {
    test('Término da última faixa do Lado A entra em waitingEndOfSide e NÃO exibe B1', () async {
      // Pré-configurar álbum com 2 faixas no Lado A e 2 no Lado B
      final entries = [
        const TrackEntry(position: 1, title: 'Faixa A1', number: 'A1', lengthMs: 180000),
        const TrackEntry(position: 2, title: 'Faixa A2', number: 'A2', lengthMs: 180000),
        const TrackEntry(position: 3, title: 'Faixa B1', number: 'B1', lengthMs: 180000),
        const TrackEntry(position: 4, title: 'Faixa B2', number: 'B2', lengthMs: 180000),
      ];

      await cacheService.saveTracklist(
        album: 'Disco Duplo',
        artist: 'Artista Teste',
        entries: entries,
        source: 'catalog',
        sideSource: 'catalog',
      );

      final engine = WaxClubEngine(
        recordService: recordService,
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: CastSyncService(),
      );

      // Simular reconhecimento da última faixa do Lado A (Faixa A2)
      shazamService.nextResult = const TrackInfo(
        title: 'Faixa A2',
        artist: 'Artista Teste',
        album: 'Disco Duplo',
        offsetSeconds: 175.0, // Faltam 5s para acabar
        durationMs: 180000,
      );

      await engine.startListening();
      expect(engine.currentTrack?.title, equals('Faixa A2'));

      // Aguardar prefetch processar tracklist
      await Future.delayed(const Duration(milliseconds: 100));

      // Verificar que o prefetch detectou que A2 é a última do Lado A
      expect(engine.telemetry.sideEndLabel, contains('Fim do lado A'));

      // Chamar autoListenNextTrack (término da faixa)
      // Como é fim do lado A, o engine deve entrar em waitingEndOfSide
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 50));

      // Status deve ser waitingEndOfSide
      expect(engine.telemetry.status, equals(CalibrationStatus.waitingEndOfSide));
      // Faixa atual ainda deve ser Faixa A2 (tela congelada)
      expect(engine.currentTrack?.title, equals('Faixa A2'));
      // A letra NÃO mudou para Faixa B1
      expect(engine.lyrics.isNotEmpty, isTrue);

      engine.dispose();
    });

    test('Toque durante waitingEndOfSide executa sondagem e transita para Lado B', () async {
      final entries = [
        const TrackEntry(position: 1, title: 'Faixa A1', number: 'A1', lengthMs: 180000),
        const TrackEntry(position: 2, title: 'Faixa B1', number: 'B1', lengthMs: 180000),
      ];

      await cacheService.saveTracklist(
        album: 'Disco Teste',
        artist: 'Artista Teste',
        entries: entries,
        source: 'catalog',
        sideSource: 'catalog',
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
        title: 'Faixa A1',
        artist: 'Artista Teste',
        album: 'Disco Teste',
        offsetSeconds: 178.0,
        durationMs: 180000,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 100));

      // Forçar fim de faixa
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(engine.telemetry.status, equals(CalibrationStatus.waitingEndOfSide));

      // Agora agulha toca Lado B
      shazamService.nextResult = const TrackInfo(
        title: 'Faixa B1',
        artist: 'Artista Teste',
        album: 'Disco Teste',
        offsetSeconds: 5.0,
        durationMs: 180000,
      );

      // Usuário toca no microfone para avisar que virou o disco
      await engine.startListening();

      expect(engine.currentTrack?.title, equals('Faixa B1'));
      expect(engine.telemetry.status, isNot(CalibrationStatus.waitingEndOfSide));
      // B1 é a última faixa do Lado B neste disco de 2 faixas
      expect(engine.telemetry.sideEndLabel, equals('Fim do lado B'));

      engine.dispose();
    });

    test('Regra de pelo menos 3 confirmações em ordem antes de persistir preferredAlbum', () async {
      final entries = [
        const TrackEntry(position: 1, title: 'Musica 1', number: '1'),
        const TrackEntry(position: 2, title: 'Musica 2', number: '2'),
        const TrackEntry(position: 3, title: 'Musica 3', number: '3'),
      ];

      await cacheService.saveTracklist(
        album: 'Album Alpha',
        artist: 'Banda Alpha',
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

      // Faixa 1 do Álbum Alpha
      shazamService.nextResult = const TrackInfo(
        title: 'Musica 1',
        artist: 'Banda Alpha',
        album: 'Album Alpha',
        offsetSeconds: 10.0,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      // Após a primeira faixa, ainda NÃO deve haver álbum preferencial confirmado
      var pref = cacheService.getPreferredAlbum('Musica 1', 'Banda Alpha');
      expect(pref, isNull);

      // Faixa 2 consecutiva do mesmo Álbum Alpha
      shazamService.nextResult = const TrackInfo(
        title: 'Musica 2',
        artist: 'Banda Alpha',
        album: 'Album Alpha',
        offsetSeconds: 5.0,
      );

      // Forçar término da Musica 1 para que o engine acione a próxima faixa automaticamente
      engine.seekTo(180.0);
      // Aguardar confirmação em background da Musica 2 (delay de 2s)
      await Future.delayed(const Duration(milliseconds: 2500));

      // Após a segunda faixa, AINDA NÃO deve haver álbum preferencial confirmado (requer >= 3 faixas)
      pref = cacheService.getPreferredAlbum('Musica 1', 'Banda Alpha');
      expect(pref, isNull);

      // Faixa 3 consecutiva do mesmo Álbum Alpha
      shazamService.nextResult = const TrackInfo(
        title: 'Musica 3',
        artist: 'Banda Alpha',
        album: 'Album Alpha',
        offsetSeconds: 5.0,
      );

      // Forçar término da Musica 2 para acionar a 3ª faixa
      engine.seekTo(180.0);
      // Aguardar confirmação em background da Musica 3 (delay de 2s)
      await Future.delayed(const Duration(milliseconds: 2500));

      // 3ª faixa consecutiva em ordem: agora sim o álbum preferencial deve estar persistido!
      pref = cacheService.getPreferredAlbum('Musica 1', 'Banda Alpha');
      expect(pref, equals('Album Alpha'));
      expect(cacheService.getPreferredAlbum('Musica 2', 'Banda Alpha'), equals('Album Alpha'));
      expect(cacheService.getPreferredAlbum('Musica 3', 'Banda Alpha'), equals('Album Alpha'));

      engine.dispose();
    });

    test('Previsão errada corrige para a faixa real sem gravar álbum incorreto', () async {
      final entries = [
        const TrackEntry(position: 1, title: 'Faixa 1', number: '1'),
        const TrackEntry(position: 2, title: 'Faixa 2 Prevista', number: '2'),
      ];

      await cacheService.saveTracklist(
        album: 'Album Errado',
        artist: 'Artista X',
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

      // Iniciar com Faixa 1
      shazamService.nextResult = const TrackInfo(
        title: 'Faixa 1',
        artist: 'Artista X',
        album: 'Album Errado',
        offsetSeconds: 10.0,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 100));

      // Na confirmação de background da próxima faixa, toca outra música totalmente diferente de outro álbum
      shazamService.nextResult = const TrackInfo(
        title: 'Outra Musica',
        artist: 'Artista X',
        album: 'Outro Album',
        offsetSeconds: 15.0,
      );

      // Fim da Faixa 1 -> auto-listen exibe "Faixa 2 Prevista" e confirma em background
      engine.seekTo(180.0);
      // Aguardar delay de 2s da confirmação em background
      await Future.delayed(const Duration(milliseconds: 2500));

      expect(engine.currentTrack?.title, equals('Outra Musica'));
      expect(engine.currentTrack?.album, equals('Outro Album'));

      // Verificar que não gravou Album Errado como preferencial
      final pref = cacheService.getPreferredAlbum('Faixa 1', 'Artista X');
      expect(pref, isNot('Album Errado'));

      engine.dispose();
    });

    test('Coletânea com ordem invertida é rejeitada e não é gravada como preferencial', () async {
      // Coletânea Invertida: Faixa Beta antes de Faixa Alpha
      await cacheService.saveTracklist(
        album: 'Coletanea Invertida',
        artist: 'Artista Y',
        entries: [
          const TrackEntry(position: 1, title: 'Faixa Beta', number: '1'),
          const TrackEntry(position: 2, title: 'Faixa Alpha', number: '2'),
          const TrackEntry(position: 3, title: 'Faixa Gamma', number: '3'),
        ],
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

      // Toca Faixa Alpha (1ª música tocada na vitrola)
      shazamService.nextResult = const TrackInfo(
        title: 'Faixa Alpha',
        artist: 'Artista Y',
        album: 'Coletanea Invertida',
        offsetSeconds: 10.0,
      );
      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 50));

      // Toca Faixa Beta (2ª música tocada na vitrola)
      shazamService.nextResult = const TrackInfo(
        title: 'Faixa Beta',
        artist: 'Artista Y',
        album: 'Coletanea Invertida',
        offsetSeconds: 5.0,
      );
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 2500));

      // Toca Faixa Gamma (3ª música tocada na vitrola)
      shazamService.nextResult = const TrackInfo(
        title: 'Faixa Gamma',
        artist: 'Artista Y',
        album: 'Coletanea Invertida',
        offsetSeconds: 5.0,
      );
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 2500));

      // Como a vitrola tocou Alpha -> Beta -> Gamma, mas a Coletanea Invertida tem Beta -> Alpha,
      // a ordem NÃO bateu! Logo, Coletanea Invertida NÃO pode ser o preferredAlbum!
      final pref = cacheService.getPreferredAlbum('Faixa Alpha', 'Artista Y');
      expect(pref, isNot('Coletanea Invertida'));

      engine.dispose();
    });
  });
}
