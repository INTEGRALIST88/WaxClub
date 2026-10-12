import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/lyric_line.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/album_catalog_service.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/discogs/discogs_auth_service.dart';
import 'package:waxclub/services/discogs/discogs_tracklist_provider.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
import 'package:waxclub/services/musicbrainz_tracklist_provider.dart';
import 'package:waxclub/services/session_log_service.dart';
import 'package:waxclub/services/shazam_service.dart';
import 'package:waxclub/services/tracklist_provider.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';
import 'package:waxclub/ui/widgets/album_picker_sheet.dart';

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
  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async =>
      const LrcResponse(syncedLyrics: '[00:01.00] linha', durationSeconds: 200, source: 'lrclib');
}

class _RecordingCast extends CastSyncService {
  final List<TrackInfo> sent = [];
  @override
  bool get isConnected => true;
  @override
  void sendTrack(TrackInfo track, List<LyricLine> lyrics, {String? side}) => sent.add(track);
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

const _discogsSearchJson = {
  'results': [
    {
      'id': 101,
      'master_id': 55,
      'title': 'Millencolin - Pennybridge Pioneers',
      'year': '2000',
      'country': 'Sweden',
      'format': ['CD', 'Album'],
      'thumb': 'https://img/cd.jpg',
    },
    {
      'id': 102,
      'master_id': 55,
      'title': 'Millencolin - Pennybridge Pioneers',
      'year': '2000',
      'country': 'Europe',
      'format': ['Vinyl', 'LP', 'Album'],
      'thumb': 'https://img/lp.jpg',
    },
    {
      'id': 300,
      'master_id': 0,
      'title': 'Various - Punk-O-Rama 5',
      'year': '2000',
      'format': ['CD', 'Compilation'],
      'thumb': '',
      'cover_image': 'https://img/comp.jpg',
    },
  ],
};

const _discogsReleaseJson = {
  'tracklist': [
    {'type_': 'heading', 'position': '', 'title': 'Side A'},
    {'type_': 'track', 'position': 'A1', 'title': 'No Cigar', 'duration': '2:58'},
    {'type_': 'track', 'position': 'A2', 'title': 'Fox', 'duration': '3:01'},
    {'type_': 'track', 'position': 'B1', 'title': 'Penguins & Polarbears', 'duration': '3:13'},
    {
      'type_': 'index',
      'position': 'B2',
      'title': 'Medley',
      'sub_tracks': [
        {'type_': 'track', 'position': '', 'title': 'Parte Um', 'duration': '1:00'},
      ],
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Discogs — leitura do catálogo', () {
    test('agrupa as edições do mesmo disco preferindo o vinil e marca coletâneas', () {
      final parsed = groupReleaseEditions(DiscogsTracklistProvider.parseSearchResults(_discogsSearchJson));
      expect(parsed.length, 2);
      final album = parsed.firstWhere((c) => c.albumTitle == 'Pennybridge Pioneers');
      expect(album.releaseId, '102', reason: 'a edição em vinil representa o grupo');
      expect(album.editions, 2);
      expect(album.artistName, 'Millencolin');
      expect(album.isVinyl, isTrue);
      final comp = parsed.firstWhere((c) => c.albumTitle == 'Punk-O-Rama 5');
      expect(comp.isCompilation, isTrue);
      expect(comp.coverUrl, 'https://img/comp.jpg');
    });

    test('lista de faixas com lados, durações e sub-faixas, sem títulos de seção', () {
      final tracks = DiscogsTracklistProvider.parseTracklist(_discogsReleaseJson);
      expect(tracks.map((t) => t.title), ['No Cigar', 'Fox', 'Penguins & Polarbears', 'Parte Um']);
      expect(tracks.map((t) => t.side), ['A', 'A', 'B', 'B']);
      expect(tracks.first.lengthMs, 178000);
      expect(tracks.map((t) => t.position), [1, 2, 3, 4]);
    });

    test('ordem: disco atual, estúdio em vinil, depois coletâneas', () {
      const list = [
        ReleaseCandidate(providerId: 'discogs', releaseId: '1', albumTitle: 'Coletânea X', secondaryTypes: ['Compilation'], artistName: 'Various', year: '1999'),
        ReleaseCandidate(providerId: 'discogs', releaseId: '2', albumTitle: 'Disco Estúdio', primaryType: 'Album', format: 'Vinyl, LP', artistName: 'Banda', year: '2001'),
        ReleaseCandidate(providerId: 'discogs', releaseId: '3', albumTitle: 'Disco Atual', primaryType: 'Album', artistName: 'Banda', year: '2010'),
      ];
      final sorted = AlbumCatalogService.sortForTrack(list, artist: 'Banda', currentAlbum: 'Disco Atual');
      expect(sorted.map((c) => c.releaseId), ['3', '2', '1']);
    });
  });

  group('Discogs — conta do usuário', () {
    test('token pessoal é verificado, guardado e recuperado na próxima abertura', () async {
      final store = MemoryDiscogsCredentialStore();
      final client = MockClient((req) async {
        expect(req.url.path, '/oauth/identity');
        expect(req.headers['Authorization'], 'Discogs token=abc123');
        return http.Response(jsonEncode({'username': 'colecionador'}), 200);
      });
      final auth = DiscogsAuthService(store: store, client: client, consumerKey: '', consumerSecret: '');
      await auth.load();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.supportsOAuthLogin, isFalse);

      await auth.loginWithPersonalToken(' abc123 ');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.isEnabled, isTrue);
      expect(auth.username, 'colecionador');

      final reopened = DiscogsAuthService(store: store, client: client, consumerKey: '', consumerSecret: '');
      await reopened.load();
      expect(reopened.isEnabled, isTrue, reason: 'as credenciais ficam guardadas para as próximas vezes');
      expect(reopened.username, 'colecionador');

      await reopened.logout();
      expect(reopened.isLoggedIn, isFalse);
    });

    test('login OAuth: pede token, captura o retorno e guarda o token definitivo', () async {
      final store = MemoryDiscogsCredentialStore();
      final client = MockClient((req) async {
        final authHeader = req.headers['Authorization'] ?? '';
        switch (req.url.path) {
          case '/oauth/request_token':
            expect(authHeader, contains('oauth_signature="segredo%26"'));
            expect(authHeader, contains('oauth_callback='));
            return http.Response('oauth_token=req&oauth_token_secret=reqsecret&oauth_callback_confirmed=true', 200);
          case '/oauth/access_token':
            expect(authHeader, contains('oauth_verifier="ver"'));
            expect(authHeader, contains('oauth_signature="segredo%26reqsecret"'));
            return http.Response('oauth_token=acc&oauth_token_secret=accsecret', 200);
          case '/oauth/identity':
            expect(authHeader, contains('oauth_token="acc"'));
            return http.Response(jsonEncode({'username': 'dj'}), 200);
        }
        return http.Response('not found', 404);
      });
      final auth = DiscogsAuthService(store: store, client: client, consumerKey: 'chave', consumerSecret: 'segredo');
      final token = await auth.requestToken();
      expect(token.authorizeUrl, contains('oauth_token=req'));
      final verifier = DiscogsAuthService.verifierFromCallback(
          'https://waxclub.app/discogs-callback?oauth_token=req&oauth_verifier=ver');
      expect(verifier, 'ver');
      expect(DiscogsAuthService.verifierFromCallback('https://www.discogs.com/login'), isNull);
      await auth.completeOAuth(token, verifier!);
      expect(auth.credentials!.isOAuth, isTrue);
      expect(auth.username, 'dj');
    });
  });

  group('Catálogo — base principal e reserva', () {
    test('Discogs fora do ar: mostra a base MusicBrainz com aviso', () async {
      final store = MemoryDiscogsCredentialStore();
      final auth = DiscogsAuthService(
        store: store,
        client: MockClient((_) async => http.Response(jsonEncode({'username': 'u'}), 200)),
        consumerKey: '',
        consumerSecret: '',
      );
      await auth.loginWithPersonalToken('t');
      final discogs = DiscogsTracklistProvider(
        auth: auth,
        client: MockClient((_) async => http.Response('erro', 502)),
      );
      final mb = MusicBrainzTracklistProvider(
        client: MockClient((req) async => http.Response(
              jsonEncode({
                'recordings': [
                  {
                    'releases': [
                      {
                        'id': 'mb-1',
                        'title': 'Disco Reserva',
                        'date': '1998-05-01',
                        'release-group': {'id': 'g1', 'primary-type': 'Album'},
                        'media': [
                          {'format': '12" Vinyl'}
                        ],
                      }
                    ],
                  }
                ],
              }),
              200,
            )),
      );
      final catalog = AlbumCatalogService(auth: auth, discogs: discogs, musicBrainz: mb);
      final result = await catalog.albumsForTrack(title: 'Faixa', artist: 'Banda');
      expect(result.source, 'musicbrainz');
      expect(result.notice, contains('Discogs indisponível'));
      expect(result.albums.single.albumTitle, 'Disco Reserva');
      expect(result.albums.single.year, '1998');
    });
  });

  group('Mudar disco — escolha do usuário', () {
    late Directory tempDir;
    setUp(() async => tempDir = await Directory.systemTemp.createTemp('waxclub_album_choice_'));
    tearDown(() async {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('trava o disco escolhido, atualiza a TV e o grava como padrão para as músicas dele', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();
      final shazam = _FakeShazam()
        ..nextResult = const TrackInfo(
            title: 'No Cigar', artist: 'Millencolin', album: 'Punk-O-Rama 5', offsetSeconds: 20.0);
      final cast = _RecordingCast();
      final engine = WaxClubEngine(
        recordService: _FakeRecord(),
        shazamService: shazam,
        lyricsService: _FakeLyrics(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: tempDir),
        castService: cast,
      );
      await engine.startListening();
      expect(engine.lockedAlbumName, 'Punk-O-Rama 5', reason: 'o Shazam indicou a coletânea');

      final tracks = DiscogsTracklistProvider.parseTracklist(_discogsReleaseJson);
      await engine.applyUserAlbumChoice(
        albumTitle: 'Pennybridge Pioneers',
        tracklist: tracks,
        coverUrl: 'https://img/lp.jpg',
        releaseId: '102',
        releaseFormat: 'Vinyl, LP',
        source: 'discogs',
      );

      expect(engine.lockedAlbumName, 'Pennybridge Pioneers');
      expect(engine.currentTrack?.album, 'Pennybridge Pioneers');
      expect(engine.currentTrack?.coverUrl, 'https://img/lp.jpg');
      expect(engine.currentSide, 'A');
      expect(engine.trackDurationSeconds, 178.0, reason: 'duração da lista de faixas escolhida');
      expect(cast.sent.last.album, 'Pennybridge Pioneers');
      expect(cache.getPreferredAlbum('No Cigar', 'Millencolin'), 'Pennybridge Pioneers');
      expect(cache.getPreferredAlbum('Fox', 'Millencolin'), 'Pennybridge Pioneers');
      expect(cache.getTracklist('Pennybridge Pioneers', 'Millencolin').length, 4);

      // Próxima vez que a música for reconhecida (mesmo com o Shazam dizendo "coletânea"): disco escolhido
      engine.stop();
      await engine.startListening();
      expect(engine.lockedAlbumName, 'Pennybridge Pioneers');
      expect(engine.lockedTracklist.length, 4);
      engine.dispose();
    });
  });

  group('Mudar disco — tela', () {
    testWidgets('marcar "Consultar Discogs" sem conta explica a vantagem e oferece OK', (tester) async {
      late WaxClubEngine engine;
      late Directory dir;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('waxclub_picker_');
        final cache = VinylCacheService(storageDirectory: dir);
        await cache.init();
        engine = WaxClubEngine(
          recordService: _FakeRecord(),
          shazamService: _FakeShazam()
            ..nextResult = const TrackInfo(title: 'No Cigar', artist: 'Millencolin', offsetSeconds: 5.0),
          lyricsService: _FakeLyrics(),
          cacheService: cache,
          logService: SessionLogService(storageDirectory: dir),
          castService: _RecordingCast(),
        );
        await engine.startListening();
      });
      final auth = DiscogsAuthService(
        store: MemoryDiscogsCredentialStore(),
        client: MockClient((_) async => http.Response('{}', 200)),
        consumerKey: '',
        consumerSecret: '',
      );
      final catalog = AlbumCatalogService(
        auth: auth,
        musicBrainz: MusicBrainzTracklistProvider(
          client: MockClient((_) async => http.Response(jsonEncode({'recordings': []}), 200)),
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AlbumPickerSheet(engine: engine, catalog: catalog)),
      ));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();

      expect(find.text('Consultar Discogs'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Conectar sua conta Discogs'), findsOneWidget);
      expect(find.textContaining('maior base de discos de vinil'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(auth.isEnabled, isFalse);

      engine.stop();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        engine.dispose();
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
    });
  });
}
