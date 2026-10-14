import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/account/account_service.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
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

class _Shazam extends ShazamService {
  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async =>
      const TrackInfo(title: 'Canção', artist: 'Banda', album: 'Disco', offsetSeconds: 20);
}

/// Fontes de letras de mentira: só respondem se o plugin da fonte estiver ligado.
class _Lyrics extends LyricsProviderService {
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    for (final e in LyricsProviderService.sourceOrder()) {
      if (!LyricsProviderService.sourceEnabled(e)) continue;
      if (e == 'lrclib') return const LrcResponse(syncedLyrics: '[00:10.00] da lrclib', durationSeconds: 200, source: 'lrclib');
      if (e == 'netease') return const LrcResponse(syncedLyrics: '[00:10.00] da netease', durationSeconds: 200, source: 'netease');
    }
    return null;
  }
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_reload_'));
  tearDown(() async {
    LyricsProviderService.sourceEnabled = (_) => true;
    LyricsProviderService.sourceOrder = () => const ['local', 'lrclib', 'netease', 'megalobiz', 'lyrics.ovh'];
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('desligar a fonte em uso busca a letra de novo na próxima; desligar todas tira a letra', () async {
    final cache = VinylCacheService(storageDirectory: dir);
    await cache.init();
    final engine = WaxClubEngine(
      recordService: _FakeRecord(),
      shazamService: _Shazam(),
      lyricsService: _Lyrics(),
      cacheService: cache,
      logService: SessionLogService(storageDirectory: dir),
    );
    var on = {'lrclib', 'netease'};
    LyricsProviderService.sourceEnabled = (s) => on.contains(s);
    LyricsProviderService.sourceOrder = () => const ['lrclib', 'netease'];

    await engine.startListening();
    expect(engine.lyricsSource, 'lrclib', reason: 'o painel marca a S1');
    expect(engine.lyrics.first.text, 'da lrclib');

    on = {'netease'}; // desligou a S1 no painel
    await engine.reloadLyricsForCurrentTrack();
    expect(engine.lyricsSource, 'netease');
    expect(engine.lyrics.first.text, 'da netease');

    on = {}; // nenhuma fonte ligada
    await engine.reloadLyricsForCurrentTrack();
    expect(engine.lyrics, isEmpty);
    expect(engine.lyricsSource, isNull);
    engine.stop();
    engine.dispose();
  });

  test('fotos do disco: lista, envia os bytes da imagem e apaga, sempre com a sessão', () async {
    final seen = <String>[];
    final client = MockClient((req) async {
      seen.add('${req.method} ${req.url.path}?${req.url.query}');
      expect(req.headers['Authorization'], 'Bearer T');
      if (req.method == 'GET' && req.url.path == '/v1/photos') {
        expect(req.url.queryParameters['item'], 'abbey road|the beatles');
        return http.Response(jsonEncode({'photos': [{'id': 7, 'width': 1600, 'height': 1200, 'size': 180000}]}), 200);
      }
      if (req.method == 'POST' && req.url.path == '/v1/photos') {
        expect(req.bodyBytes, [1, 2, 3]);
        return http.Response(jsonEncode({'photo': {'id': 8, 'width': 800, 'height': 600, 'size': 3}}), 201);
      }
      if (req.method == 'DELETE' && req.url.path == '/v1/photos/7') return http.Response(jsonEncode({'deleted': 7}), 200);
      if (req.url.path == '/v1/me') {
        return http.Response(jsonEncode({'user': {'id': 1, 'email': 'a@b.c', 'username': 'gus', 'country': 'BR', 'profileComplete': true}}), 200);
      }
      return http.Response('{}', 404);
    });
    final store = MemoryAccountStore();
    await store.write('waxclub.account.token', 'T');
    final account = AccountService(baseUrl: 'https://api.test/v1', store: store, client: client);
    await account.load();

    final list = await account.listPhotos('abbey road|the beatles');
    expect(list.single.id, 7);
    expect(list.single.width, 1600);
    final added = await account.uploadPhoto('abbey road|the beatles', Uint8List.fromList([1, 2, 3]));
    expect(added.id, 8);
    await account.deletePhoto(7);
    expect(account.photoUrl(8), 'https://api.test/v1/photos/8');
    expect(account.authHeaders['Authorization'], 'Bearer T');
  });
}
