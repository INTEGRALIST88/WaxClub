import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/lyric_line.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/soundtrack_catalog.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

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
  TrackInfo? nextResult;
  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async => nextResult;
}

class _FakeLyrics extends LyricsProviderService {
  final List<String> requestedArtists = [];
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    requestedArtists.add('$trackName|$artistName');
    return const LrcResponse(syncedLyrics: '[00:01.00] linha', durationSeconds: 200, source: 'lrclib');
  }
}

class _Cast extends CastSyncService {
  final List<String?> sides = [];
  @override
  bool get isConnected => true;
  @override
  void sendTrack(TrackInfo track, List<LyricLine> lyrics, {String? side}) => sides.add(side);
  @override
  void sendSync({
    required double position,
    required int activeLineIndex,
    required double speedFactor,
    required String status,
    required String statusMessage,
    required bool isPaused,
    required bool isMicActive,
    String? nextTitle,
    double? speedStdErr,
    bool awaitingNeedle = false,
  }) {}
  @override
  void sendStop() {}
}

final _catalogJson = {
  'discs': [
    {
      'album': 'Babilônia trilha sonora volume 1',
      'network': 'Globo',
      'year': 2015,
      'cover': 'https://img/babilonia.jpg',
      'tracks': [
        {'title': 'Ink', 'artist': 'Coldplay', 'lengthMs': 228000},
        {'title': 'Eu Te Desejo Amor', 'artist': 'Maria Bethânia', 'lengthMs': 200000},
        {'title': 'Azul da Cor do Mar', 'artist': 'Tim Maia', 'lengthMs': 250000},
      ],
    },
    {
      'album': 'Corrida do Ouro trilha sonora',
      'network': 'Globo',
      'year': 1974,
      'cover': 'https://img/corrida.jpg',
      'tracks': [
        {'title': 'Azul da Cor do Mar', 'artist': 'Tim Maia', 'lengthMs': 250000},
        {'title': 'Faixa Dois', 'artist': 'Elis Regina', 'lengthMs': 180000},
        {'title': 'Faixa Três', 'artist': 'Gal Costa e Caetano Veloso', 'lengthMs': 190000},
        {'title': 'Faixa Quatro', 'artist': 'Jorge Ben', 'lengthMs': 240000},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catálogo de trilhas de novela', () {
    final catalog = SoundtrackCatalog.fromJson(_catalogJson);

    test('acha a trilha pela música e pelo artista, preferindo a mais antiga', () {
      expect(catalog.findFor('Azul da Cor do Mar', 'Tim Maia')!.album, 'Corrida do Ouro trilha sonora');
      expect(catalog.discsWith('Azul da Cor do Mar', 'Tim Maia').length, 2);
      expect(catalog.findFor('INK', 'Coldplay')!.album, 'Babilônia trilha sonora volume 1');
      expect(catalog.findFor('Ink', 'Outro Artista'), isNull, reason: 'mesmo título de outro artista não conta');
      expect(catalog.findFor('Faixa Três', 'Caetano Veloso'), isNotNull, reason: 'dueto: basta um dos artistas');
    });

    test('catálogo embutido no app carrega as trilhas com capa, artistas e durações', () async {
      final real = await SoundtrackCatalog.loadBundled();
      expect(real.discs.length, greaterThan(800));
      final babilonia = real.findFor('Ink', 'Coldplay');
      expect(babilonia?.album, 'Babilônia Volume 1');
      expect(babilonia?.coverUrl, isNull, reason: 'trilha em CD: sem capa do site de origem');
      // Capas só dos LPs, hospedadas pelo WaxClub no GitHub Pages
      final covers = real.discs.where((d) => d.coverUrl != null).toList();
      expect(covers.length, greaterThan(400));
      expect(covers.every((d) => d.isVinylEra), isTrue);
      expect(covers.every((d) => d.coverUrl!.startsWith('https://integralist88.github.io/WaxClub/covers/')), isTrue);
      expect(babilonia?.tracks.first.lengthMs, greaterThan(0));
      expect(babilonia?.tracks[1].artist, 'Maria Bethânia');
      // Nomes limpos: sem posição/vendagem do ranking e sem a palavra "trilha"
      expect(real.discs.where((d) => RegExp(r'cópias|^\d+\.\s|trilha', caseSensitive: false).hasMatch(d.album)), isEmpty);
      // Minutagem e lados do selo (Som Livre 590.002): "O Outro Internacional"
      final outro = real.findFor('Coming Around Again', 'Carly Simon');
      expect(outro?.album, 'O Outro Internacional');
      expect(outro?.tracks.first.lengthMs, 199000, reason: '3:19 no selo');
      expect(outro?.tracks.map((t) => t.side).join(), 'AAAAAAABBBBBBB');
      final withDuration = real.discs.expand((d) => d.tracks).where((t) => (t.lengthMs ?? 0) > 0).length;
      expect(withDuration, greaterThan(9000));
    });

    test('LP da época do vinil ganha lados A/B; CD fica com um lado só', () {
      final lp = catalog.discs.firstWhere((d) => d.year == 1974);
      expect(lp.isVinylEra, isTrue);
      expect(lp.tracks.map((t) => t.side).toSet(), {'A', 'B'});
      final cd = catalog.discs.firstWhere((d) => d.year == 2015);
      expect(cd.tracks.every((t) => t.side == 'A'), isTrue, reason: 'CD não pode pedir para virar o disco');
    });
  });

  group('Motor — trilha de novela como disco padrão', () {
    late Directory dir;
    late VinylCacheService cache;
    late _FakeLyrics lyrics;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('waxclub_soundtrack_');
      cache = VinylCacheService(storageDirectory: dir);
      await cache.init();
      lyrics = _FakeLyrics();
    });
    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    WaxClubEngine engineWith(_FakeShazam shazam, _Cast cast) => WaxClubEngine(
          recordService: _FakeRecord(),
          shazamService: shazam,
          lyricsService: lyrics,
          cacheService: cache,
          logService: SessionLogService(storageDirectory: dir),
          castService: cast,
          soundtrackCatalog: SoundtrackCatalog.fromJson(_catalogJson),
        );

    test('música de trilha trava a trilha, com capa e a próxima faixa do artista certo', () async {
      final shazam = _FakeShazam()
        ..nextResult = const TrackInfo(
            title: 'Ink', artist: 'Coldplay', album: 'Ghost Stories', offsetSeconds: 10.0);
      final engine = engineWith(shazam, _Cast());
      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 200));

      expect(engine.lockedAlbumName, 'Babilônia trilha sonora volume 1');
      expect(engine.lockedAlbumSource, 'soundtrack');
      expect(engine.currentTrack?.coverUrl, 'https://img/babilonia.jpg');
      expect(engine.lockedTracklist.length, 3);
      expect(engine.trackDurationSeconds, 228.0, reason: 'duração vinda do catálogo da trilha');
      expect(engine.telemetry.predictedNextTrackTitle, 'Eu Te Desejo Amor');
      // A letra da próxima faixa é buscada com o artista dela (não com o da faixa atual)
      expect(lyrics.requestedArtists, contains('Eu Te Desejo Amor|Maria Bethânia'));
      expect(cache.findCachedDisc('Babilônia trilha sonora volume 1', SoundtrackDisc.albumArtist)?.tracklist.length, 3);
      engine.dispose();
    });

    test('disco marcado pelo usuário tem prioridade sobre a trilha', () async {
      await cache.setPreferredAlbum('Ink', 'Coldplay', 'Ghost Stories', source: 'user');
      final shazam = _FakeShazam()
        ..nextResult = const TrackInfo(title: 'Ink', artist: 'Coldplay', album: 'Ghost Stories', offsetSeconds: 10.0);
      final engine = engineWith(shazam, _Cast());
      await engine.startListening();
      expect(engine.lockedAlbumName, 'Ghost Stories');
      expect(engine.lockedAlbumSource, 'user');
      engine.dispose();
    });

    test('a confirmação automática por sequência não sobrescreve a escolha do usuário', () async {
      await cache.setPreferredAlbum('Ink', 'Coldplay', 'Ghost Stories', source: 'user');
      await cache.setPreferredAlbum('Ink', 'Coldplay', 'Outra Coletânea');
      expect(cache.getPreferredAlbum('Ink', 'Coldplay'), 'Ghost Stories');
      expect(cache.getPreferredAlbumSource('Ink', 'Coldplay'), 'user');
    });
  });
}
