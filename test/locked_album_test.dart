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
import 'package:waxclub/services/owned_record_finder.dart';

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
    tempDir = await Directory.systemTemp.createTemp('locked_album_test_');
    cacheService = VinylCacheService(storageDirectory: tempDir);
    await cacheService.init();

    logService = SessionLogService(storageDirectory: tempDir);
    recordService = FakeAudioRecordService();
    shazamService = FakeShazamService();
    lyricsService = FakeLyricsProviderService();
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  test('a coleção vence o disco aprendido sozinho (mas não o escolhido à mão pelo usuário)', () async {
    // O app tinha aprendido sozinho a coletânea do reconhecimento como disco preferido destas músicas
    await cacheService.setPreferredAlbum('Animal Nitrate', 'The London Suede', 'Beautiful Ones: The Best of the London Suede');
    final engine = WaxClubEngine(
      recordService: recordService,
      shazamService: shazamService,
      lyricsService: lyricsService,
      cacheService: cacheService,
      logService: logService,
      castService: CastSyncService(),
    );
    engine.ownedRecordFinder = (title, artist, album) async => const OwnedRecord(
          album: 'The Best Of Suede. Beautiful Ones',
          artist: 'Suede',
          coverUrl: 'https://my/suede.jpg',
          tracklist: [
            TrackEntry(position: 1, title: 'The Drowners', side: 'A'),
            TrackEntry(position: 2, title: 'Animal Nitrate', side: 'A'),
          ],
        );
    shazamService.nextResult = const TrackInfo(
      title: 'Animal Nitrate',
      artist: 'The London Suede',
      album: 'Beautiful Ones: The Best of the London Suede 1992-2018',
      offsetSeconds: 25.0,
      durationMs: 206000,
    );
    await engine.startListening();
    expect(engine.lockedAlbumName, 'The Best Of Suede. Beautiful Ones', reason: 'o disco da coleção, não o aprendido');
    expect(engine.lockedAlbumCoverUrl, 'https://my/suede.jpg');
    expect(engine.lockedTracklist.length, 2);
    engine.dispose();

    // Escolhido à mão pelo usuário ("Change record"): esse vale mais que a coleção
    await cacheService.setPreferredAlbum('Animal Nitrate', 'The London Suede', 'Coming Up', source: 'user');
    final engine2 = WaxClubEngine(
      recordService: recordService,
      shazamService: shazamService,
      lyricsService: lyricsService,
      cacheService: cacheService,
      logService: logService,
      castService: CastSyncService(),
    )..ownedRecordFinder = (title, artist, album) async => const OwnedRecord(album: 'The Best Of Suede. Beautiful Ones', artist: 'Suede');
    await engine2.startListening();
    expect(engine2.lockedAlbumName, 'Coming Up');
    engine2.dispose();
  });

  test('Disco travado retém nome do álbum e capa física mesmo se Shazam retornar dados diferentes', () async {
    // 1. Cadastra disco físico no cache com 3 faixas e capa oficial
    await cacheService.saveTracklist(
      album: 'Coletânea Ouro',
      artist: 'Artista Teste',
      entries: [
        const TrackEntry(position: 1, title: 'Faixa Um', side: 'A'),
        const TrackEntry(position: 2, title: 'Faixa Dois', side: 'A'),
        const TrackEntry(position: 3, title: 'Faixa Tres', side: 'A'),
      ],
      source: 'catalog',
    );
    await cacheService.updateDiscCover(
      'Coletânea Ouro',
      'Artista Teste',
      'https://images.example.com/coletanea_ouro.jpg',
    );

    final engine = WaxClubEngine(
      recordService: recordService,
      shazamService: shazamService,
      lyricsService: lyricsService,
      cacheService: cacheService,
      logService: logService,
      castService: CastSyncService(),
    );

    // 2. Shazam reconhece a 1ª música informando nome de single avulso
    shazamService.nextResult = const TrackInfo(
      title: 'Faixa Um',
      artist: 'Artista Teste',
      album: 'Faixa Um - Single',
      coverUrl: 'https://images.example.com/faixa1_single.jpg',
      offsetSeconds: 5.0,
      durationMs: 180000,
    );

    await engine.startListening();

    // Valida que o engine identificou o disco no cache e travou
    expect(engine.isAlbumLocked, isTrue);
    expect(engine.lockedAlbumName, 'Coletânea Ouro');
    expect(engine.lockedAlbumCoverUrl, 'https://images.example.com/coletanea_ouro.jpg');
    expect(engine.lockedTracklist.length, 3);
    expect(engine.currentTrack?.album, 'Coletânea Ouro');
    expect(engine.currentTrack?.coverUrl, 'https://images.example.com/coletanea_ouro.jpg');
    expect(engine.currentTrack?.isAlbumLocked, isTrue);

    // 3. Simula transição para a próxima faixa com Shazam retornando álbum e capa diferentes
    shazamService.nextResult = const TrackInfo(
      title: 'Faixa Dois',
      artist: 'Artista Teste',
      album: 'Greatest Hits Vol 99',
      coverUrl: 'https://images.example.com/hits99.jpg',
      offsetSeconds: 2.0,
      durationMs: 180000,
    );

    // Engine transita para Faixa Dois
    // Como Faixa Dois pertence à tracklist de 'Coletânea Ouro', o disco DEVE PERMANECER TRAVADO
    // e os metadados do Shazam (Greatest Hits Vol 99 e hits99.jpg) devem ser descartados!
    await engine.handleManualTrackTransitionForTesting(
      shazamService.nextResult!,
      DateTime.now(),
    );

    expect(engine.isAlbumLocked, isTrue);
    expect(engine.lockedAlbumName, 'Coletânea Ouro');
    expect(engine.lockedAlbumCoverUrl, 'https://images.example.com/coletanea_ouro.jpg');
    expect(engine.currentTrack?.album, 'Coletânea Ouro');
    expect(engine.currentTrack?.coverUrl, 'https://images.example.com/coletanea_ouro.jpg');
    expect(engine.currentTrack?.title, 'Faixa Dois');
    expect(engine.currentTrack?.isAlbumLocked, isTrue);

    // 4. Detecção de anomalia: toca uma música fora da tracklist
    shazamService.nextResult = const TrackInfo(
      title: 'Música Estranha de Outro Disco',
      artist: 'Outro Artista',
      album: 'Outro Disco Estranho',
      coverUrl: 'https://images.example.com/estranho.jpg',
      offsetSeconds: 10.0,
      durationMs: 200000,
    );

    await engine.handleManualTrackTransitionForTesting(
      shazamService.nextResult!,
      DateTime.now(),
    );

    // O disco agora foi DESTRAVADO pois a faixa não pertence à tracklist travada
    expect(engine.lockedAlbumName, isNot('Coletânea Ouro'));

    engine.dispose();
  });

  test('Predição da próxima faixa contígua utiliza metadados e capa do disco travado', () async {
    await cacheService.saveTracklist(
      album: 'Disco Estúdio Especial',
      artist: 'Banda Clássica',
      entries: [
        const TrackEntry(position: 1, title: 'Faixa Alpha', side: 'A'),
        const TrackEntry(position: 2, title: 'Faixa Beta', side: 'A'),
      ],
      source: 'catalog',
    );
    await cacheService.updateDiscCover(
      'Disco Estúdio Especial',
      'Banda Clássica',
      'https://images.example.com/estudio.jpg',
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
      title: 'Faixa Alpha',
      artist: 'Banda Clássica',
      album: 'Faixa Alpha Single',
      coverUrl: 'https://images.example.com/alpha_single.jpg',
      offsetSeconds: 0.0,
      durationMs: 180000,
    );

    await engine.startListening();

    expect(engine.isAlbumLocked, isTrue);

    // Testa predição
    final predicted = await engine.predictNextTrackForTesting();
    expect(predicted, isNotNull);
    expect(predicted!.title, 'Faixa Beta');
    expect(predicted.album, 'Disco Estúdio Especial');
    expect(predicted.coverUrl, 'https://images.example.com/estudio.jpg');
    expect(predicted.isAlbumLocked, isTrue);

    engine.dispose();
  });
}
