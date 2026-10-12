import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:waxclub/services/audio_record_service.dart';

class FakeAudioRecorderBackend implements AudioRecorderBackend {
  bool _recording = false;
  String? _lastPath;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isRecording() async => _recording;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    _recording = true;
    _lastPath = path;
    // Cria arquivo simulado com alguns bytes WAV
    final file = File(path);
    await file.writeAsBytes(Uint8List.fromList([0, 1, 2, 3, 4]));
  }

  StreamController<Uint8List>? _stream;
  Timer? _ticker;

  /// Simula o microfone em fluxo contínuo: 1 s de PCM (32000 bytes) a cada 20 ms reais.
  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    _recording = true;
    final controller = StreamController<Uint8List>();
    _stream = controller;
    _ticker = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!controller.isClosed) controller.add(Uint8List(32000));
    });
    return controller.stream;
  }

  @override
  Future<String?> stop() async {
    _recording = false;
    _ticker?.cancel();
    await _stream?.close();
    _stream = null;
    return _lastPath;
  }

  @override
  Future<void> dispose() async {
    _recording = false;
  }
}

void main() {
  late Directory tempDir;
  late FakeAudioRecorderBackend backend;
  late AudioRecordService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_record_test_');
    backend = FakeAudioRecorderBackend();
    service = AudioRecordService(backend: backend, tempDirectory: tempDir);
  });

  tearDown(() async {
    service.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AudioRecordService Mutex & Preemption Tests (T0.2 / T0.3)', () {
    test('gravação básica pelo usuário completa e devolve bytes', () async {
      final bytes = await service.recordSample(
        duration: const Duration(milliseconds: 200),
        priority: RecordPriority.user,
      );

      expect(bytes, isNotNull);
      expect(bytes!.length, 5);
      expect(service.isRecording, isFalse);
    });

    test('duas gravações em background simultâneas: segunda é descartada sem interferir', () async {
      final future1 = service.recordSample(
        duration: const Duration(milliseconds: 400),
        priority: RecordPriority.background,
      );

      // Aguarda 50ms para garantir início da primeira
      await Future.delayed(const Duration(milliseconds: 50));
      expect(service.isRecording, isTrue);

      final future2 = service.recordSample(
        duration: const Duration(milliseconds: 200),
        priority: RecordPriority.background,
      );

      final result2 = await future2;
      expect(result2, isNull, reason: 'Gravação background simultânea deve ser ignorada imediatamente');

      final result1 = await future1;
      expect(result1, isNotNull, reason: 'Primeira gravação de background deve continuar e concluir');
    });

    test('gravação do usuário preempta e cancela gravação em background', () async {
      final bgFuture = service.recordSample(
        duration: const Duration(milliseconds: 600),
        priority: RecordPriority.background,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(service.isRecording, isTrue);
      expect(service.activePriority, RecordPriority.background);

      // Usuário aperta o botão para identificar nova música
      final userFuture = service.recordSample(
        duration: const Duration(milliseconds: 200),
        priority: RecordPriority.user,
      );

      final bgResult = await bgFuture;
      expect(bgResult, isNull, reason: 'Gravação em background deve retornar null ao ser preemptada');

      final userResult = await userFuture;
      expect(userResult, isNotNull, reason: 'Gravação do usuário deve ter sucesso e retornar áudio');
      expect(service.isRecording, isFalse);
    });

    test('cancelRecording cancela gravação imediatamente', () async {
      final future = service.recordSample(
        duration: const Duration(milliseconds: 500),
        priority: RecordPriority.user,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(service.isRecording, isTrue);

      await service.cancelRecording();
      final result = await future;

      expect(result, isNull);
      expect(service.isRecording, isFalse);
    });
  });

  group('Gravação progressiva (reconhecimento rápido primeiro, robusto depois)', () {
    test('para no primeiro marco em que o callback reconhece', () async {
      final seen = <int>[];
      final start = await service.recordProgressive(
        checkpoints: const [Duration(seconds: 4), Duration(seconds: 8), Duration(seconds: 12)],
        onCheckpoint: (wav, _) async {
          seen.add(wav.length);
          return seen.length == 2; // reconhece no 2º marco (8 s)
        },
      );
      expect(start, isNotNull);
      expect(seen.length, 2);
      // WAV = cabeçalho de 44 bytes + PCM acumulado (o segundo marco contém o áudio do primeiro)
      expect(seen[0], greaterThanOrEqualTo(44 + 4 * 32000));
      expect(seen[1], greaterThanOrEqualTo(44 + 8 * 32000));
      expect(service.isRecording, isFalse);
    });

    test('sem reconhecimento percorre todos os marcos e encerra', () async {
      var calls = 0;
      final start = await service.recordProgressive(
        checkpoints: const [Duration(seconds: 4), Duration(seconds: 8), Duration(seconds: 12)],
        onCheckpoint: (_, __) async {
          calls++;
          return false;
        },
      );
      expect(start, isNotNull);
      expect(calls, 3);
      expect(service.isRecording, isFalse);
    });

    test('escuta progressiva em background é preemptada pelo usuário', () async {
      var bgCalls = 0;
      final bg = service.recordProgressive(
        checkpoints: const [Duration(seconds: 40), Duration(seconds: 80)],
        priority: RecordPriority.background,
        onCheckpoint: (_, __) async {
          bgCalls++;
          return false;
        },
      );
      await Future.delayed(const Duration(milliseconds: 60));
      expect(service.activePriority, RecordPriority.background);
      final user = await service.recordSample(duration: const Duration(milliseconds: 100));
      expect(user, isNotNull);
      expect(await bg, isNull);
      expect(bgCalls, 0);
    });

    test('wrapPcm16AsWav gera cabeçalho RIFF válido', () {
      final wav = wrapPcm16AsWav(Uint8List(3200));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(wav.length, 44 + 3200);
    });
  });
}
