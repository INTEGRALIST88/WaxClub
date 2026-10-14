import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/recognition_catalog_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
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

class _CountingShazam extends ShazamService {
  int calls = 0;
  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async {
    calls++;
    return null;
  }
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
      LrcResponse(syncedLyrics: '[00:00.10] $trackName', durationSeconds: 999, source: 'lrclib');
}

// LP com 2 faixas no lado A e 1 no lado B (durações curtas para o teste)
final _lp = [
  const TrackEntry(position: 1, title: 'Faixa A1', number: 'A1', side: 'A', lengthMs: 300),
  const TrackEntry(position: 2, title: 'Faixa A2', number: 'A2', side: 'A', lengthMs: 300),
  const TrackEntry(position: 3, title: 'Faixa B1', number: 'B1', side: 'B', lengthMs: 300),
];

Future<void> _waitFor(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('condição não alcançada em $timeout');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('verificação no catálogo de reconhecimento', () {
    test('encontrado se pelo menos metade das faixas bater', () {
      expect(RecognitionCatalogService.evaluate(['Faixa A1', 'Faixa A2'], _lp).found, isTrue);
      expect(RecognitionCatalogService.evaluate(['Outra'], _lp).found, isFalse);
      expect(RecognitionCatalogService.evaluate(const [], _lp).found, isFalse);
    });

    test('pelo código de barras (iTunes lookup?upc=)', () async {
      final client = MockClient((req) async {
        expect(req.url.queryParameters['upc'], '7891234567895');
        return http.Response.bytes(utf8.encode(jsonEncode({
          'results': [
            {'wrapperType': 'collection', 'collectionName': 'Disco'},
            {'wrapperType': 'track', 'trackName': 'Faixa A1'},
            {'wrapperType': 'track', 'trackName': 'Faixa A2'},
            {'wrapperType': 'track', 'trackName': 'Faixa B1'},
          ]
        })), 200);
      });
      final r = await RecognitionCatalogService(client: client)
          .check(barcode: '7891234567895', artist: 'Banda', album: 'Disco', tracklist: _lp);
      expect(r!.found, isTrue);
      expect(r.matchedTracks, 3);
    });

    test('busca de texto do iTunes não acha o disco: procura na discografia do artista (Favourite Worst Nightmare)', () async {
      final client = MockClient((req) async {
        final q = req.url.queryParameters;
        Map<String, dynamic> body;
        if (req.url.path == '/search' && q['entity'] == 'album') {
          body = {'resultCount': 0, 'results': []}; // a busca de texto falha com este título
        } else if (req.url.path == '/search' && q['entity'] == 'musicArtist') {
          body = {
            'results': [
              {'wrapperType': 'artist', 'artistId': 62820413, 'artistName': 'Arctic Monkeys'}
            ]
          };
        } else if (q['entity'] == 'album') {
          body = {
            'results': [
              {'wrapperType': 'artist', 'artistName': 'Arctic Monkeys'},
              {'wrapperType': 'collection', 'collectionId': 663097964, 'artistName': 'Arctic Monkeys', 'collectionName': 'AM'},
              {'wrapperType': 'collection', 'collectionId': 251499221, 'artistName': 'Arctic Monkeys', 'collectionName': 'Favourite Worst Nightmare'},
            ]
          };
        } else {
          expect(q['id'], '251499221');
          body = {
            'results': [
              for (final t in ['Brianstorm', 'Teddy Picker', 'D Is for Dangerous', 'Balaclava'])
                {'wrapperType': 'track', 'trackName': t}
            ]
          };
        }
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      });
      final r = await RecognitionCatalogService(client: client).check(
        artist: 'Arctic Monkeys',
        album: 'Favourite Worst Nightmare',
        tracklist: const [
          TrackEntry(position: 1, title: 'Brianstorm'),
          TrackEntry(position: 2, title: 'Teddy Picker'),
          TrackEntry(position: 3, title: 'D Is For Dangerous'),
          TrackEntry(position: 4, title: 'Balaclava'),
        ],
      );
      expect(r!.found, isTrue, reason: 'o disco está no catálogo; o Modo Manual não deve ligar');
      expect(r.matchedTracks, 4);
    });

    test('sem código: busca o álbum por artista + título; ausente = não encontrado', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/search') return http.Response(jsonEncode({'results': []}), 200);
        return http.Response('{}', 404);
      });
      final r = await RecognitionCatalogService(client: client).check(artist: 'Banda Rara', album: 'Disco Raro', tracklist: _lp);
      expect(r!.found, isFalse);
    });

    test('sem rede: nulo (o app segue no automático)', () async {
      final client = MockClient((_) async => throw const SocketException('offline'));
      expect(await RecognitionCatalogService(client: client).check(artist: 'X', album: 'Y', tracklist: _lp), isNull);
    });
  });

  group('Modo Manual (minutagem, sem Shazam)', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('waxclub_manual_');
      WaxClubEngine.manualGapSeconds = 0.05;
    });
    tearDown(() async {
      WaxClubEngine.manualGapSeconds = 2.0;
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('toca o lado pela minutagem, pede para virar, e desliga a chave no fim do disco', () async {
      final cache = VinylCacheService(storageDirectory: dir);
      await cache.init();
      final shazam = _CountingShazam();
      final engine = WaxClubEngine(
        recordService: _FakeRecord(),
        shazamService: shazam,
        lyricsService: _FakeLyrics(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: dir),
      );
      await engine.prepareScannedRecord(albumTitle: 'Disco', artist: 'Banda', tracklist: _lp, source: 'discogs');
      expect(engine.manualRecordTracklist.length, 3, reason: 'o disco escaneado fica travado para o Modo Manual');

      engine.setManualMode(true);
      expect(await engine.startManualPlayback(trackIndex: 0, useMic: false), isTrue);
      expect(engine.isManualPlaying, isTrue);
      expect(engine.currentTrack?.title, 'Faixa A1');
      expect(engine.telemetry.trackDurationSeconds, closeTo(0.3, 0.001), reason: 'duração do LP, não a do provedor de letras');

      // A1 termina → A2 começa sozinha (mesmo lado)
      await _waitFor(() => engine.currentTrack?.title == 'Faixa A2');
      // A2 termina → fim do lado A: espera virar o disco
      await _waitFor(() => engine.manualPendingIndex == 2);
      expect(engine.isManualPlaying, isFalse);
      expect(engine.isManualMode, isTrue, reason: 'fim do lado A não é o fim do disco');

      // Vira o disco e toca ▶ → B1
      expect(await engine.startManualPending(), isTrue);
      expect(engine.currentTrack?.title, 'Faixa B1');
      // B1 é a última do último lado → fim do disco, chave desliga
      await _waitFor(() => !engine.isManualMode);
      expect(engine.isManualPlaying, isFalse);
      expect(shazam.calls, 0, reason: 'o Modo Manual nunca consulta o Shazam');
      engine.dispose();
    });

    test('ajuste ±0.5 s no Modo Manual move o relógio do disco: a troca de faixa muda e o ajuste vale para a próxima', () async {
      final cache = VinylCacheService(storageDirectory: dir);
      await cache.init();
      final engine = WaxClubEngine(
        recordService: _FakeRecord(),
        shazamService: _CountingShazam(),
        lyricsService: _FakeLyrics(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: dir),
      );
      final longLp = [
        const TrackEntry(position: 1, title: 'Longa A1', number: 'A1', side: 'A', lengthMs: 3000),
        const TrackEntry(position: 2, title: 'Longa A2', number: 'A2', side: 'A', lengthMs: 3000),
      ];
      await engine.prepareScannedRecord(albumTitle: 'Disco Longo', artist: 'Banda', tracklist: longLp, source: 'discogs');
      expect(await engine.startManualPlayback(trackIndex: 0, useMic: false), isTrue);
      final started = DateTime.now();

      // Letra atrasada: o usuário adianta 2,5 s → a faixa de 3 s acaba ~0,5 s depois, não 3 s
      engine.nudgeSync(0.5);
      engine.nudgeSync(1.0);
      engine.nudgeSync(1.0);
      expect(engine.lyricBiasSeconds, closeTo(2.5, 0.001));
      expect(engine.telemetry.currentPositionSeconds, greaterThanOrEqualTo(2.5));

      await _waitFor(() => engine.currentTrack?.title == 'Longa A2');
      expect(DateTime.now().difference(started).inMilliseconds, lessThan(2000),
          reason: 'a troca de faixa foi reagendada com o ajuste');
      expect(engine.lyricBiasSeconds, closeTo(2.5, 0.001), reason: 'o ajuste vale para o resto do lado');
      engine.stopManual();
      expect(engine.lyricBiasSeconds, 0, reason: 'parar encerra a sessão do ajuste');
      engine.dispose();
    });

    test('tocar na linha cantada no Modo Manual acerta o relógio do disco (e não agenda a escuta do automático)', () async {
      final cache = VinylCacheService(storageDirectory: dir);
      await cache.init();
      final engine = WaxClubEngine(
        recordService: _FakeRecord(),
        shazamService: _CountingShazam(),
        lyricsService: _FakeLyrics(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: dir),
      );
      final lp = [
        const TrackEntry(position: 1, title: 'Linha A1', number: 'A1', side: 'A', lengthMs: 60000),
        const TrackEntry(position: 2, title: 'Linha A2', number: 'A2', side: 'A', lengthMs: 60000),
      ];
      await engine.prepareScannedRecord(albumTitle: 'Disco Linhas', artist: 'Banda', tracklist: lp, source: 'discogs');
      await engine.startManualPlayback(trackIndex: 0, useMic: false);
      // A música já está nos 20 s, mas a letra ficou no começo: o usuário toca na linha dos 20 s
      engine.syncToLine(20.0);
      expect(engine.telemetry.currentPositionSeconds, closeTo(20.0, 0.1));
      expect(engine.lyricBiasSeconds, closeTo(20.0, 0.1), reason: 'o deslocamento vale para o resto do lado');
      expect(engine.isManualPlaying, isTrue);
      engine.stopManual();
      engine.dispose();
    });

    test('desligar a chave encerra a escuta manual; sem disco não começa', () async {
      final cache = VinylCacheService(storageDirectory: dir);
      await cache.init();
      final engine = WaxClubEngine(
        recordService: _FakeRecord(),
        shazamService: _CountingShazam(),
        lyricsService: _FakeLyrics(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: dir),
      );
      expect(await engine.startManualPlayback(trackIndex: 0, useMic: false), isFalse, reason: 'sem lista de faixas');

      await engine.prepareScannedRecord(albumTitle: 'Disco', artist: 'Banda', tracklist: _lp, source: 'discogs');
      WaxClubEngine.manualGapSeconds = 30; // não deixa a faixa avançar durante o teste
      await engine.startManualPlayback(trackIndex: 1, useMic: false);
      expect(engine.currentTrack?.title, 'Faixa A2');
      engine.setManualMode(false);
      expect(engine.isManualPlaying, isFalse);
      engine.dispose();
    });
  });
}
