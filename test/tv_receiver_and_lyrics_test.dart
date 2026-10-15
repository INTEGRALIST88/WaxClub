import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/engine/speed_estimator.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/cast_v2_client.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/tv_web_receiver_html.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

const _syncedMrClean = '[00:00.88] Mr. Clean tell me is that really you\n[00:04.64] I wonder what you\'ve done\n'
    '[01:48.83] Looking back at the days when we were friends\n[02:25.10] ';

class _FakeRecordService extends AudioRecordService {
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

class _FakeShazamService extends ShazamService {
  TrackInfo? nextResult;
  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async => nextResult;
}

class _SyncedLyricsService extends LyricsProviderService {
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async =>
      const LrcResponse(syncedLyrics: _syncedMrClean, durationSeconds: 162, source: 'lrclib');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tela da TV', () {
    test('receptor servido pelo celular é o mesmo layout do receptor oficial do Cast', () {
      // Quebras de linha normalizadas: o Git pode gravar o HTML com CRLF no Windows
      final index = File('web_receiver/index.html').readAsStringSync().replaceAll('\r\n', '\n');
      final expected = index
          .replaceAll(RegExp(r'^[ \t]*<!-- Google Cast Application Framework.*?-->\r?\n', multiLine: true), '')
          .replaceAll(RegExp(r'^[ \t]*<script src="//www\.gstatic\.com/cast/[^"]*"></script>\r?\n', multiLine: true), '');
      expect(TvWebReceiverHtml.build().replaceAll('\r\n', '\n'), equals(expected),
          reason: 'Rode tool/sync_tv_receiver.ps1 após editar web_receiver/index.html');
      expect(TvWebReceiverHtml.build(), isNot(contains('cast_receiver_framework')));
    });

    test('receptor trata os pacotes do celular no canal certo', () {
      final index = File('web_receiver/index.html').readAsStringSync();
      expect(index, contains("'${CastV2Client.nsCustomSync}'"));
      for (final type in ['track_loaded', 'sync_update', 'stop']) {
        expect(index, contains("data.type === '$type'"));
      }
    });
  });

  group('Letras — LRCLIB', () {
    test('Mr. Clean: /get só tem texto simples → busca ampla encontra a versão sincronizada correta', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/api/get')) {
          return http.Response(
            jsonEncode({
              'trackName': 'Mr. Clean',
              'artistName': 'Millencolin',
              'albumName': 'Same Old Tunes',
              'duration': 162.0,
              'plainLyrics': 'Mr. Clean tell me is that really you',
              'syncedLyrics': null,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/api/search')) {
          return http.Response(
            jsonEncode([
              // Outro artista com LRC: não pode ser aceito
              {'trackName': 'Mr. Clean', 'artistName': 'Outra Banda', 'duration': 162.0, 'syncedLyrics': '[00:01.00] errada'},
              // LRC termina em 2:25 mas a duração declarada é 64s: inconsistente
              {'trackName': 'Mr. Clean', 'artistName': 'Millencolin', 'albumName': 'Punk-O-Rama 4', 'duration': 64.0, 'syncedLyrics': _syncedMrClean},
              {'trackName': 'Mr. Clean', 'artistName': 'Millencolin', 'albumName': 'Punk-O-Rama, Volume 4', 'duration': 162.0, 'syncedLyrics': _syncedMrClean},
            ]),
            200,
          );
        }
        return http.Response('not found', 404);
      });

      final result = await LrcLibService(client: client).fetchLyricsDetails(
        trackName: 'Mr. Clean',
        artistName: 'Millencolin',
      );

      expect(result, isNotNull);
      expect(result!.syncedLyrics, contains('[00:00.88]'));
      expect(result.durationSeconds, equals(162.0));
      expect(result.albumName, equals('Punk-O-Rama, Volume 4'));
    });

    test('sem LRC em nenhuma fonte, o texto simples da LRCLIB não serve: sem letra e LRCLIB vermelha', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/api/get')) {
          return http.Response(
            jsonEncode({'trackName': 'Rara', 'artistName': 'Banda', 'duration': 120.0, 'plainLyrics': 'linha simples\nsegunda linha\nterceira linha\nquarta linha', 'syncedLyrics': null}),
            200,
          );
        }
        if (request.url.path.endsWith('/api/search')) return http.Response('[]', 200);
        return http.Response('not found', 404);
      });
      final service = LyricsProviderService(client: client);
      final result = await service.fetchLyricsDetails(trackName: 'Rara', artistName: 'Banda');
      expect(result, isNull);
      expect(service.lastAttempts['lrclib'], LyricsAttempt.notFound);
    });
  });

  group('Letras — cache', () {
    late Directory tempDir;
    setUp(() async => tempDir = await Directory.systemTemp.createTemp('waxclub_lyrics_cache_test_'));
    tearDown(() async {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('letra simples guardada no cache é trocada pela versão sincronizada da rede', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();
      await cache.cacheTrack(
        const TrackInfo(title: 'Mr. Clean', artist: 'Millencolin', offsetSeconds: 0),
        'Mr. Clean tell me is that really you\nI wonder what you\'ve done',
      );

      final shazam = _FakeShazamService()
        ..nextResult = const TrackInfo(title: 'Mr. Clean', artist: 'Millencolin', offsetSeconds: 10.0);
      final engine = WaxClubEngine(
        recordService: _FakeRecordService(),
        shazamService: shazam,
        lyricsService: _SyncedLyricsService(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: tempDir),
        castService: CastSyncService(),
      );
      await engine.startListening();

      expect(engine.lyrics.first.text, equals('Mr. Clean tell me is that really you'));
      expect(engine.lyrics.first.timestamp, equals(const Duration(milliseconds: 880)));
      expect(cache.findCachedLyrics('Mr. Clean', 'Millencolin'), contains('[00:00.88]'));
      engine.dispose();
    });
  });

  group('Rotação — troca de hardware', () {
    test('medição precisa muito diferente do histórico (digital → vitrola real) substitui o modelo', () {
      final model = TurntableSpeedModel(mean: 1.0, stdDev: TurntableSpeedModel.minStdDev);
      const vinyl = SpeedEstimate(speed: 1.018, standardError: 0.002, samples: 5, spanSeconds: 140);
      expect(model.isChange(vinyl), isTrue);
      expect(model.combine(vinyl).speed, closeTo(1.018, 0.0001));
      model.addTrackEstimate(vinyl);
      expect(model.mean, closeTo(1.018, 0.0001));
    });

    test('medição ruidosa do início da faixa não dispara troca de hardware', () {
      final model = TurntableSpeedModel(mean: 1.0, stdDev: TurntableSpeedModel.minStdDev);
      const early = SpeedEstimate(speed: 1.012, standardError: 0.01, samples: 2, spanSeconds: 20);
      expect(model.isChange(early), isFalse);
    });
  });
}
