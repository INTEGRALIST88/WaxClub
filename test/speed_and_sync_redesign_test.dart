import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/speed_estimator.dart';
import 'package:waxclub/engine/waxclub_engine.dart';
import 'package:waxclub/models/lyric_line.dart';
import 'package:waxclub/models/sync_state.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/audio_record_service.dart';
import 'package:waxclub/services/cast_sync_service.dart';
import 'package:waxclub/services/cast_v2_client.dart';
import 'package:waxclub/services/lrclib_service.dart';
import 'package:waxclub/services/lyrics_provider_service.dart';
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

/// Microfone roteirizado: silêncio (agulha ainda fora do disco) ou som (música tocando).
class _ScriptedRecordService extends AudioRecordService {
  bool silent = false;

  @override
  Future<Uint8List?> recordSample({
    Duration duration = const Duration(milliseconds: 5000),
    int sampleRate = 16000,
    RecordPriority priority = RecordPriority.user,
  }) async {
    await Future.delayed(const Duration(milliseconds: 20));
    return Uint8List.fromList(List.filled(100, silent ? 0 : 1));
  }

  @override
  Future<void> cancelRecording() async {}
}

class _FakeShazamService extends ShazamService {
  TrackInfo? nextResult;

  @override
  Future<TrackInfo?> recognizeAudio(Uint8List audioBytes, {int? sampleRate}) async => nextResult;
}

/// Letras com duração configurável por faixa (permite simular faixas curtas).
class _FakeLyricsService extends LyricsProviderService {
  final Map<String, double> durations = {};

  @override
  Future<LrcResponse?> fetchLyricsDetails({
    required String trackName,
    required String artistName,
    String? albumName,
    int? durationSeconds,
    String? preferredSource,
  }) async {
    return LrcResponse(
      syncedLyrics: '[00:01.00] Linha 1\n[00:03.00] Linha 2',
      albumName: albumName,
      durationSeconds: durations[trackName] ?? 180.0,
      source: 'lrclib',
    );
  }
}

/// Cast "conectado" que apenas registra as faixas enviadas para a TV.
class _RecordingCastService extends CastSyncService {
  final List<String> sentTitles = [];
  final List<String?> sideFlips = [];

  @override
  void sendSideFlip({String? nextSide}) => sideFlips.add(nextSide);

  @override
  bool get isConnected => true;

  @override
  void sendTrack(TrackInfo track, List<LyricLine> lyrics, {String? side}) {
    if (sentTitles.isEmpty || sentTitles.last != track.title) sentTitles.add(track.title);
  }

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
  }) {
    syncs.add((position: position, isPaused: isPaused, awaitingNeedle: awaitingNeedle));
  }

  final List<({double position, bool isPaused, bool awaitingNeedle})> syncs = [];

  @override
  void sendStop() {}
}

class _FakeCastSocket implements CastSocket {
  final StreamController<List<int>> _controller = StreamController<List<int>>();
  final List<CastMessage> sent = [];

  @override
  Stream<List<int>> get stream => _controller.stream;

  @override
  void add(List<int> data) {
    final len = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 4))).getUint32(0, Endian.big);
    sent.add(CastMessage.fromProtobufBytes(Uint8List.fromList(data.sublist(4, 4 + len))));
  }

  void emitMessage(CastMessage msg) => _controller.add(msg.toProtobufBytes());

  @override
  Future<void> close() async => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrackSpeedFit — regressão de rotação', () {
    test('mede rotação real de +1.2% (antes a zona morta de ±2% travava em 1.000x)', () {
      final fit = TrackSpeedFit();
      for (final t in [0.0, 20.0, 65.0, 140.0]) {
        fit.add(SpeedObservation(1000.0 + t, 30.0 + 1.012 * t));
      }
      final est = fit.estimate()!;
      expect(est.speed, closeTo(1.012, 0.0005));
      expect(est.standardError, lessThan(0.003));
    });

    test('com ruído de ±0.15s no carimbo do Shazam, erro fica abaixo de 0.3% em 2 minutos', () {
      final fit = TrackSpeedFit();
      const noise = [0.15, -0.12, 0.08, -0.15, 0.10];
      const times = [0.0, 20.0, 65.0, 100.0, 140.0];
      for (int i = 0; i < times.length; i++) {
        fit.add(SpeedObservation(times[i], 5.0 + 0.985 * times[i] + noise[i]));
      }
      final est = fit.estimate()!;
      expect((est.speed - 0.985).abs(), lessThan(0.003));
    });

    test('não estima com intervalo curto demais', () {
      final fit = TrackSpeedFit()
        ..add(const SpeedObservation(0, 10))
        ..add(const SpeedObservation(8, 18));
      expect(fit.estimate(), isNull);
    });

    test('descarta outlier (pulo de agulha / match errado) e mantém a rotação correta', () {
      final fit = TrackSpeedFit();
      for (final t in [0.0, 20.0, 65.0, 140.0]) {
        fit.add(SpeedObservation(t, 1.01 * t));
      }
      fit.add(const SpeedObservation(100.0, 100.0 * 1.01 + 6.0)); // 6s fora da reta
      final est = fit.estimate()!;
      expect(est.speed, closeTo(1.01, 0.001));
      expect(est.samples, equals(4));
    });

    test('áudio digital converge para 1.000x sem precisar de zona morta', () {
      final fit = TrackSpeedFit();
      for (final t in [0.0, 20.0, 65.0, 140.0]) {
        fit.add(SpeedObservation(t, 12.0 + t));
      }
      expect(fit.estimate()!.speed, closeTo(1.0, 0.0001));
    });
  });

  group('TurntableSpeedModel — rotação do toca-discos', () {
    test('medição precisa domina o conhecimento prévio vago', () {
      final model = TurntableSpeedModel();
      model.addTrackEstimate(const SpeedEstimate(speed: 1.015, standardError: 0.002, samples: 4, spanSeconds: 140));
      expect(model.mean, closeTo(1.015, 0.0005));
      expect(model.isCalibrated, isTrue);
    });

    test('faixas sucessivas refinam a média ponderada pela precisão', () {
      final model = TurntableSpeedModel();
      model.addTrackEstimate(const SpeedEstimate(speed: 1.010, standardError: 0.003, samples: 3, spanSeconds: 90));
      model.addTrackEstimate(const SpeedEstimate(speed: 1.014, standardError: 0.003, samples: 3, spanSeconds: 90));
      expect(model.mean, closeTo(1.012, 0.0007));
      expect(model.stdDev, lessThan(0.003));
    });

    test('rejeita estimativa fisicamente impossível', () {
      final model = TurntableSpeedModel(mean: 1.0);
      model.addTrackEstimate(const SpeedEstimate(speed: 1.20, standardError: 0.001, samples: 3, spanSeconds: 90));
      expect(model.mean, equals(1.0));
    });
  });

  group('Motor — continuidade entre faixas e TV', () {
    late Directory tempDir;
    late VinylCacheService cacheService;
    late SessionLogService logService;
    late _FakeShazamService shazamService;
    late _FakeLyricsService lyricsService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('waxclub_redesign_test_');
      cacheService = VinylCacheService(storageDirectory: tempDir);
      await cacheService.init();
      logService = SessionLogService(storageDirectory: tempDir);
      shazamService = _FakeShazamService();
      lyricsService = _FakeLyricsService();
      await cacheService.saveTracklist(
        album: 'Disco Continuo',
        artist: 'Banda',
        entries: const [
          TrackEntry(position: 1, title: 'Faixa Um', number: '1'),
          TrackEntry(position: 2, title: 'Faixa Dois', number: '2'),
          TrackEntry(position: 3, title: 'Faixa Tres', number: '3'),
        ],
        source: 'catalog',
      );
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('com rotação já calibrada, o app segue para a 3ª música sozinho (antes parava após a 2ª)', () async {
      // Rotação persistida e calibrada: era exatamente o cenário que deixava a 2ª faixa sem agendamento
      await cacheService.saveTurntableSpeed(1.0, stdDev: 0.001);
      lyricsService.durations['Faixa Dois'] = 9.0; // faixa curta para o teste não demorar
      final cast = _RecordingCastService();
      final engine = WaxClubEngine(
        recordService: _FakeRecordService(),
        shazamService: shazamService,
        lyricsService: lyricsService,
        cacheService: cacheService,
        logService: logService,
        castService: cast,
      );
      await Future.delayed(const Duration(milliseconds: 100));
      expect(engine.isHardwareSpeedCalibrated, isTrue);

      shazamService.nextResult =
          const TrackInfo(title: 'Faixa Um', artist: 'Banda', album: 'Disco Continuo', offsetSeconds: 10.0);
      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 100));

      // Fim da faixa 1 → previsão "Faixa Dois", confirmada pelo microfone após ~2s
      shazamService.nextResult =
          const TrackInfo(title: 'Faixa Dois', artist: 'Banda', album: 'Disco Continuo', offsetSeconds: 4.0);
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 2600));
      expect(engine.currentTrack?.title, equals('Faixa Dois'));
      expect(engine.telemetry.status, isNot(equals(CalibrationStatus.idle)));

      // A faixa 2 (9s) termina sozinha e o modo preditivo exibe a 3ª, sem toque do usuário
      shazamService.nextResult =
          const TrackInfo(title: 'Faixa Tres', artist: 'Banda', album: 'Disco Continuo', offsetSeconds: 3.0);
      await Future.delayed(const Duration(milliseconds: 6500));
      expect(engine.currentTrack?.title, equals('Faixa Tres'));

      // A TV recebeu todas as faixas, inclusive as exibidas pelo modo preditivo
      expect(cast.sentTitles, containsAllInOrder(['Faixa Um', 'Faixa Dois', 'Faixa Tres']));

      engine.dispose();
    });
  });

  group('Motor — botão "Vire o disco"', () {
    late Directory tempDir;
    setUp(() async => tempDir = await Directory.systemTemp.createTemp('waxclub_flip_test_'));
    tearDown(() async {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('virar o disco anuncia o giro à TV com o lado B e mantém o disco travado', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();
      await cache.saveTracklist(
        album: 'Disco Teste',
        artist: 'Banda',
        entries: const [
          TrackEntry(position: 1, title: 'Faixa A1', number: 'A1', lengthMs: 180000),
          TrackEntry(position: 2, title: 'Faixa B1', number: 'B1', lengthMs: 180000),
        ],
        source: 'catalog',
        sideSource: 'catalog',
      );
      final shazam = _FakeShazamService()
        ..nextResult = const TrackInfo(title: 'Faixa A1', artist: 'Banda', album: 'Disco Teste', offsetSeconds: 178.0);
      final cast = _RecordingCastService();
      final engine = WaxClubEngine(
        recordService: _FakeRecordService(),
        shazamService: shazam,
        lyricsService: _FakeLyricsService(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: tempDir),
        castService: cast,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 150));
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(engine.isAwaitingSideFlip, isTrue);

      shazam.nextResult = const TrackInfo(title: 'Faixa B1', artist: 'Banda', album: 'Disco Teste', offsetSeconds: 4.0);
      await engine.flipSide();

      expect(cast.sideFlips, equals(['B']), reason: 'a TV deve receber um único aviso de virada para o lado B');
      expect(engine.currentTrack?.title, equals('Faixa B1'));
      expect(engine.isAwaitingSideFlip, isFalse);
      expect(engine.isAlbumLocked, isTrue, reason: 'virar o disco não pode recomeçar a sessão');
      engine.dispose();
    });

    test('ao tocar em "Vire o disco", a 1ª faixa do lado B aparece na hora e espera a agulha em 0:00', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();
      await cache.saveTracklist(
        album: 'Disco Teste',
        artist: 'Banda',
        entries: const [
          TrackEntry(position: 1, title: 'Faixa A1', number: 'A1', lengthMs: 180000),
          TrackEntry(position: 2, title: 'Faixa B1', number: 'B1', lengthMs: 180000),
        ],
        source: 'catalog',
        sideSource: 'catalog',
      );
      final mic = _ScriptedRecordService();
      final shazam = _FakeShazamService()
        ..nextResult = const TrackInfo(title: 'Faixa A1', artist: 'Banda', album: 'Disco Teste', offsetSeconds: 178.0);
      final cast = _RecordingCastService();
      final engine = WaxClubEngine(
        recordService: mic,
        shazamService: shazam,
        lyricsService: _FakeLyricsService(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: tempDir),
        castService: cast,
      );

      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 150));
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(engine.isAwaitingSideFlip, isTrue);

      // Usuário toca no botão ANTES de virar o disco: silêncio e nada reconhecido
      mic.silent = true;
      shazam.nextResult = null;
      await engine.flipSide();

      expect(engine.currentTrack?.title, equals('Faixa B1'), reason: 'a letra do lado B deve aparecer na hora');
      expect(engine.isAwaitingNeedle, isTrue);
      expect(cast.sentTitles.last, equals('Faixa B1'));
      expect(cast.syncs.last.awaitingNeedle, isTrue);
      expect(cast.syncs.last.isPaused, isTrue, reason: 'a TV deixa a agulha parada no início');

      await Future.delayed(const Duration(milliseconds: 700));
      expect(engine.currentPositionSeconds, equals(0.0), reason: 'sem som, a letra fica parada em 0:00');

      // A agulha toca o disco: há som, mas o Shazam ainda não reconhece → a letra começa a correr
      mic.silent = false;
      await Future.delayed(const Duration(milliseconds: 700));
      expect(engine.isAwaitingNeedle, isFalse);
      final runningAt = engine.currentPositionSeconds;
      await Future.delayed(const Duration(milliseconds: 300));
      expect(engine.currentPositionSeconds, greaterThan(runningAt));

      // O Shazam reconhece e corrige o timestamp exato
      shazam.nextResult = const TrackInfo(title: 'Faixa B1', artist: 'Banda', album: 'Disco Teste', offsetSeconds: 30.0);
      await Future.delayed(const Duration(milliseconds: 900));
      expect(engine.currentPositionSeconds, closeTo(30.0, 2.0));
      expect(engine.telemetry.status, equals(CalibrationStatus.calibrated));
      expect(cast.sideFlips, equals(['B']));
      engine.dispose();
    });

    test('virada com a música errada prevista troca para a faixa ouvida', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();
      await cache.saveTracklist(
        album: 'Disco Teste',
        artist: 'Banda',
        entries: const [
          TrackEntry(position: 1, title: 'Faixa A1', number: 'A1', lengthMs: 180000),
          TrackEntry(position: 2, title: 'Faixa B1', number: 'B1', lengthMs: 180000),
          TrackEntry(position: 3, title: 'Faixa B2', number: 'B2', lengthMs: 180000),
        ],
        source: 'catalog',
        sideSource: 'catalog',
      );
      final mic = _ScriptedRecordService();
      final shazam = _FakeShazamService()
        ..nextResult = const TrackInfo(title: 'Faixa A1', artist: 'Banda', album: 'Disco Teste', offsetSeconds: 178.0);
      final engine = WaxClubEngine(
        recordService: mic,
        shazamService: shazam,
        lyricsService: _FakeLyricsService(),
        cacheService: cache,
        logService: SessionLogService(storageDirectory: tempDir),
        castService: _RecordingCastService(),
      );
      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 150));
      engine.seekTo(180.0);
      await Future.delayed(const Duration(milliseconds: 50));

      // Usuário pôs o lado B direto na 2ª faixa
      shazam.nextResult = const TrackInfo(title: 'Faixa B2', artist: 'Banda', album: 'Disco Teste', offsetSeconds: 12.0);
      await engine.flipSide();
      await Future.delayed(const Duration(milliseconds: 600));
      expect(engine.currentTrack?.title, equals('Faixa B2'));
      expect(engine.isAwaitingNeedle, isFalse);
      engine.dispose();
    });
  });

  group('Motor — duração inconsistente (caso Radish "Sugar Free")', () {
    late Directory tempDir;
    setUp(() async => tempDir = await Directory.systemTemp.createTemp('waxclub_duration_test_'));
    tearDown(() async {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
    });

    test('música ouvida além da duração do provedor de letras não faz o app pular para a próxima', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();
      final lyrics = _FakeLyricsService()..durations['Sugar Free'] = 114.0; // duração de outra edição
      final engine = WaxClubEngine(
        recordService: _FakeRecordService(),
        shazamService: _FakeShazamService(),
        lyricsService: lyrics,
        cacheService: cache,
        logService: SessionLogService(storageDirectory: tempDir),
        castService: CastSyncService(),
      );

      // O microfone ouve "Sugar Free" em 154s, além dos 114s informados
      await engine.handleManualTrackTransitionForTesting(
        const TrackInfo(title: 'Sugar Free', artist: 'Radish', offsetSeconds: 154.0),
      );
      await Future.delayed(const Duration(milliseconds: 300));

      expect(engine.currentTrack?.title, equals('Sugar Free'));
      expect(engine.trackDurationSeconds, isNull, reason: 'duração inconsistente deve ser descartada');
      engine.dispose();
    });

    test('duração da tracklist do disco tem prioridade sobre a do provedor de letras', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();
      await cache.saveTracklist(
        album: 'Restraining Bolt',
        artist: 'Radish',
        entries: const [
          TrackEntry(position: 1, title: 'Dear Aunt Arctica', number: '1', lengthMs: 270000),
          TrackEntry(position: 2, title: 'Sugar Free', number: '2', lengthMs: 236000),
        ],
        source: 'catalog',
      );
      final lyrics = _FakeLyricsService()..durations['Sugar Free'] = 114.0;
      final shazam = _FakeShazamService()
        ..nextResult = const TrackInfo(title: 'Dear Aunt Arctica', artist: 'Radish', album: 'Restraining Bolt', offsetSeconds: 10.0);
      final engine = WaxClubEngine(
        recordService: _FakeRecordService(),
        shazamService: shazam,
        lyricsService: lyrics,
        cacheService: cache,
        logService: SessionLogService(storageDirectory: tempDir),
        castService: CastSyncService(),
      );
      await Future.delayed(const Duration(milliseconds: 100));
      await engine.startListening();
      await Future.delayed(const Duration(milliseconds: 200));

      await engine.handleManualTrackTransitionForTesting(
        const TrackInfo(title: 'Sugar Free', artist: 'Radish', album: 'Restraining Bolt', offsetSeconds: 20.0),
      );
      expect(engine.trackDurationSeconds, closeTo(236.0, 0.01));
      engine.dispose();
    });
  });

  group('Cast — telas apenas e desconexão', () {
    test('modelos de caixa de som são classificados como só-áudio; Nest Hub e TVs não', () {
      expect(CastSyncService.isAudioOnlyModel('Google Home Mini'), isTrue);
      expect(CastSyncService.isAudioOnlyModel('Google Nest Mini'), isTrue);
      expect(CastSyncService.isAudioOnlyModel('Nest Audio'), isTrue);
      expect(CastSyncService.isAudioOnlyModel('Chromecast Audio'), isTrue);
      expect(CastSyncService.isAudioOnlyModel('Google Cast Group'), isTrue);
      expect(CastSyncService.isAudioOnlyModel('Google Nest Hub'), isFalse);
      expect(CastSyncService.isAudioOnlyModel('Chromecast'), isFalse);
      expect(CastSyncService.isAudioOnlyModel('Mi TV Stick'), isFalse);
      expect(CastSyncService.isAudioOnlyModel('SmartTV 4K'), isFalse);
    });

    test('registro não reclassifica como TV um aparelho já identificado como só-áudio', () {
      final registry = CastDeviceRegistry();
      registry.upsert(const CastDevice(id: 'a', name: 'Sala Som', host: '192.168.0.20', port: 8009, isAudioOnly: true));
      registry.upsert(const CastDevice(id: 'a', name: 'TV (192.168.0.20)', host: '192.168.0.20', port: 8009));
      expect(registry.devices.single.isAudioOnly, isTrue);
      registry.dispose();
    });

    test('desconectar pelo usuário envia STOP para fechar o app na TV', () async {
      late _FakeCastSocket socket;
      final client = CastV2Client(
        socketConnector: (host, port, {Duration timeout = const Duration(seconds: 8)}) async {
          socket = _FakeCastSocket();
          Future.delayed(const Duration(milliseconds: 20), () {
            socket.emitMessage(CastMessage(
              sourceId: 'receiver-0',
              destinationId: 'sender-0',
              namespace: CastV2Client.nsReceiver,
              payloadUtf8: jsonEncode({
                'type': 'RECEIVER_STATUS',
                'status': {
                  'applications': [
                    {
                      'appId': CastV2Client.defaultAppId,
                      'transportId': 'transport-1',
                      'sessionId': 'session-abc',
                    }
                  ]
                }
              }),
            ));
          });
          return socket;
        },
      );

      expect(await client.launchApp(host: '192.168.0.10'), isTrue);
      await client.disconnect(stopReceiverApp: true);

      final stop = socket.sent.where((m) =>
          m.namespace == CastV2Client.nsReceiver && (jsonDecode(m.payloadUtf8) as Map)['type'] == 'STOP');
      expect(stop, hasLength(1));
      expect((jsonDecode(stop.single.payloadUtf8) as Map)['sessionId'], equals('session-abc'));
      expect(client.isConnected, isFalse);
    });
  });
}
