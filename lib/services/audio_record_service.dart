import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Prioridade da requisição de gravação.
enum RecordPriority {
  /// Gravação disparada diretamente pelo usuário (início de escuta, FAB).
  /// Possui prioridade máxima e preempta gravações em background.
  user,

  /// Gravação automática em segundo plano (calibrações, confirmação preditiva, watchdog).
  /// Descarta a execução se o microfone já estiver ocupado.
  background,
}

/// Interface de abstração do backend nativo de gravação para testes e injeção de dependência.
abstract class AudioRecorderBackend {
  Future<bool> hasPermission();
  Future<bool> isRecording();
  Future<void> start(RecordConfig config, {required String path});

  /// Grava em fluxo contínuo de PCM 16-bit (sem arquivo), entregando os blocos conforme chegam.
  Future<Stream<Uint8List>> startStream(RecordConfig config);
  Future<String?> stop();
  Future<void> dispose();
}

/// Envolve PCM 16-bit mono cru num cabeçalho WAV (RIFF) para o restante do pipeline (Shazam, nível de áudio).
Uint8List wrapPcm16AsWav(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
  final byteRate = sampleRate * channels * 2;
  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, channels * 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  final out = Uint8List(44 + pcm.length);
  out.setRange(0, 44, header.buffer.asUint8List());
  out.setRange(44, out.length, pcm);
  return out;
}

/// Implementação padrão da abstração baseada no plugin oficial [AudioRecorder].
class RecordPluginBackend implements AudioRecorderBackend {
  final AudioRecorder _recorder;
  RecordPluginBackend([AudioRecorder? recorder]) : _recorder = recorder ?? AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<bool> isRecording() => _recorder.isRecording();

  @override
  Future<void> start(RecordConfig config, {required String path}) =>
      _recorder.start(config, path: path);

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) => _recorder.startStream(config);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Serviço responsável pela captura de áudio ambiental através do microfone interno do smartphone.
/// Suporta exclusão mútua por tokens e preempção limpa entre usuário e background.
class AudioRecordService {
  final AudioRecorderBackend _backend;
  final Directory? _tempDirectory;

  AudioRecordService({AudioRecorderBackend? backend, Directory? tempDirectory})
      : _backend = backend ?? RecordPluginBackend(),
        _tempDirectory = tempDirectory;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Controle de exclusão mútua e tokens de concorrência
  int _currentToken = 0;
  RecordPriority? _activePriority;
  RecordPriority? get activePriority => _activePriority;
  Completer<void>? _activeRecordingCompleter;

  /// Timestamp exato em que o hardware nativo de áudio iniciou a gravação do último sample
  DateTime? _lastRecordStartTime;
  DateTime? get lastRecordStartTime => _lastRecordStartTime;

  /// Nome formatado do microfone em uso para exibição na UI.
  String get activeDeviceName => 'Built-in microphone';

  /// Mensagem amigável para o usuário quando a permissão de microfone for negada.
  String? _permissionHint;
  String? get permissionHint => _permissionHint;

  /// Verifica e solicita a permissão de gravação de áudio em tempo de execução.
  /// Se negada, gera uma mensagem orientando o usuário a habilitar manualmente em Configurações > Apps.
  Future<bool> hasPermission() async {
    if (kIsWeb) return false;
    _permissionHint = null;

    // Em desktop (Windows/Linux/macOS), usamos diretamente o backend
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return await _backend.hasPermission();
    }

    // No Android móvel, solicitamos via permission_handler
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.microphone.request();
    if (result.isGranted) {
      return true;
    }

    // Permissão negada (ou negada permanentemente, quando o pop-up não aparece mais):
    // gera mensagem amigável para o usuário.
    if (result.isPermanentlyDenied || result.isDenied) {
      _permissionHint =
        '🎤 Microphone permission denied.\n\n'
        'To enable it manually:\n'
        '  Settings → Apps → WaxClub → Permissions → Microphone → Allow\n\n'
        'Then try again.';
      debugPrint('[AudioRecordService] ⚠️ Permissão negada. Hint gerado para o usuário.');
    }

    return false;
  }

  /// Cancela imediatamente a gravação em andamento aguardando a finalização limpa do hardware.
  Future<void> cancelAndWait({Duration timeout = const Duration(milliseconds: 2000)}) async {
    final completer = _activeRecordingCompleter;
    if (_isRecording && completer != null && !completer.isCompleted) {
      _currentToken++; // Invalida imediatamente o token da gravação anterior
      try {
        if (await _backend.isRecording()) {
          await _backend.stop();
        }
      } catch (e) {
        debugPrint('[AudioRecordService] Erro ao parar backend em cancelAndWait: $e');
      }

      try {
        await completer.future.timeout(timeout);
      } catch (_) {
        debugPrint('[AudioRecordService] Timeout ao aguardar finalização da gravação.');
      }
    }
    _isRecording = false;
    _activePriority = null;
    _activeRecordingCompleter = null;
  }

  /// Cancela imediatamente a gravação em andamento e desativa o microfone.
  Future<void> cancelRecording() async {
    _currentToken++; // Invalida o token em curso
    _isRecording = false;
    _activePriority = null;
    try {
      if (await _backend.isRecording()) {
        await _backend.stop();
      }
    } catch (_) {}
    if (_activeRecordingCompleter != null && !_activeRecordingCompleter!.isCompleted) {
      _activeRecordingCompleter!.complete();
    }
    _activeRecordingCompleter = null;
  }

  /// Grava uma amostra curta de áudio mono em formato WAV PCM 16-bit pelo microfone padrão do sistema.
  /// Retorna os bytes brutos do áudio gravado ou `null` em caso de cancelamento/concorrência.
  Future<Uint8List?> recordSample({
    Duration duration = const Duration(milliseconds: 5000),
    int sampleRate = 16000,
    RecordPriority priority = RecordPriority.user,
  }) async {
    // ═══════════════════════════════════════════════════════════════
    // GESTÃO DE CONCORRÊNCIA E PRIORIDADE
    // ═══════════════════════════════════════════════════════════════
    if (_isRecording) {
      if (priority == RecordPriority.background) {
        debugPrint('[AudioRecordService] Gravação background ignorada pois gravação está em andamento (prioridade atual: $_activePriority).');
        return null;
      }

      // Prioridade de usuário preempta qualquer gravação em andamento
      debugPrint('[AudioRecordService] Preemptando gravação em andamento para atender solicitação do usuário.');
      await cancelAndWait();
    }

    final granted = await hasPermission();
    if (!granted) {
      final hint = _permissionHint ?? '';
      throw Exception('Microphone permission not granted.\n$hint');
    }

    // Garante que o gravador não está preso em estado anterior
    try {
      if (await _backend.isRecording()) {
        await _backend.stop();
      }
    } catch (_) {}

    final myToken = ++_currentToken;
    _activePriority = priority;
    final recordingCompleter = Completer<void>();
    _activeRecordingCompleter = recordingCompleter;
    _isRecording = true;

    final tempDir = _tempDirectory ?? await getTemporaryDirectory();
    final samplePath = '${tempDir.path}/vinyl_sample_${DateTime.now().millisecondsSinceEpoch}_$myToken.wav';

    const recordConfig = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1, // Mono
      bitRate: 128000,
      // Fonte VOICE_RECOGNITION: definida pelo Android para reconhecimento, sem AGC/supressão de ruído
      // (a fonte DEFAULT em muitos aparelhos, ex.: Samsung, aplica processamento de voz que degrada a
      // assinatura acústica da música).
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
    );

    String? recordedPath;
    try {
      await _backend.start(recordConfig, path: samplePath);
      _lastRecordStartTime = DateTime.now();

      // Aguarda a duração permitindo cancelamento/preempção imediata
      final steps = (duration.inMilliseconds / 100).ceil();
      for (int i = 0; i < steps; i++) {
        if (_currentToken != myToken) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      if (_currentToken == myToken) {
        _isRecording = false;
        _activePriority = null;
        try {
          if (await _backend.isRecording()) {
            recordedPath = await _backend.stop();
          }
        } catch (e) {
          debugPrint('[AudioRecordService] Erro ao parar gravação final: $e');
        }
        if (!recordingCompleter.isCompleted) {
          recordingCompleter.complete();
        }
      } else {
        // Preemptado por gravação com token mais recente
        if (!recordingCompleter.isCompleted) {
          recordingCompleter.complete();
        }
      }
    }

    if (_currentToken != myToken || recordedPath == null) return null;

    final sampleFile = File(recordedPath);
    if (!await sampleFile.exists()) return null;

    final bytes = await sampleFile.readAsBytes();

    // Limpeza assíncrona do arquivo temporário
    unawaited(sampleFile.delete().catchError((_) => sampleFile));

    return bytes;
  }

  /// Gravação progressiva: uma única escuta contínua, com o áudio acumulado entregue (em WAV) a
  /// [onCheckpoint] em cada marco de [checkpoints] (ex.: 4s, 8s, 12s). Se [onCheckpoint] devolver
  /// `true` (ex.: música reconhecida), a gravação termina ali — rápido para músicas fáceis e robusto
  /// (até o último marco, sem recomeçar do zero) para as difíceis.
  ///
  /// Retorna o instante real de início da captura, ou `null` se foi cancelada/preemptada.
  /// Se o fluxo contínuo não estiver disponível, recorre a uma gravação única até o último marco.
  Future<DateTime?> recordProgressive({
    required List<Duration> checkpoints,
    required Future<bool> Function(Uint8List wavBytes, DateTime captureStart) onCheckpoint,
    RecordPriority priority = RecordPriority.user,
  }) async {
    assert(checkpoints.isNotEmpty);
    try {
      return await _recordProgressiveStreaming(
        checkpoints: checkpoints,
        onCheckpoint: onCheckpoint,
        priority: priority,
      );
    } on _CaptureCancelled {
      return null;
    } catch (e) {
      debugPrint('[AudioRecordService] Fluxo contínuo indisponível ($e). Usando gravação única de ${checkpoints.last.inSeconds}s.');
      final startedBefore = DateTime.now();
      final bytes = await recordSample(duration: checkpoints.last, priority: priority);
      if (bytes == null || bytes.isEmpty) return null;
      final captureStart = _lastRecordStartTime ?? startedBefore;
      await onCheckpoint(bytes, captureStart);
      return captureStart;
    }
  }

  Future<DateTime?> _recordProgressiveStreaming({
    required List<Duration> checkpoints,
    required Future<bool> Function(Uint8List wavBytes, DateTime captureStart) onCheckpoint,
    required RecordPriority priority,
  }) async {
    if (_isRecording) {
      if (priority == RecordPriority.background) {
        debugPrint('[AudioRecordService] Escuta progressiva em background ignorada: microfone ocupado ($_activePriority).');
        throw _CaptureCancelled();
      }
      await cancelAndWait();
    }

    final granted = await hasPermission();
    if (!granted) {
      throw Exception('Microphone permission not granted.\n${_permissionHint ?? ''}');
    }

    final myToken = ++_currentToken;
    _activePriority = priority;
    final recordingCompleter = Completer<void>();
    _activeRecordingCompleter = recordingCompleter;
    _isRecording = true;

    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
    );
    const bytesPerSecond = 16000 * 2;

    final buffer = BytesBuilder(copy: false);
    final done = Completer<void>();
    StreamSubscription<Uint8List>? sub;
    Timer? watchdog;
    DateTime? captureStart;
    int nextCheckpoint = 0;
    bool busy = false;
    bool finished = false;

    void finish() {
      if (finished) return;
      finished = true;
      if (!done.isCompleted) done.complete();
    }

    Future<void> maybeCheckpoint() async {
      final start = captureStart;
      if (busy || finished || start == null) return;
      if (_currentToken != myToken) {
        finish();
        return;
      }
      if (nextCheckpoint >= checkpoints.length) {
        finish();
        return;
      }
      final needed = checkpoints[nextCheckpoint].inMilliseconds * bytesPerSecond ~/ 1000;
      if (buffer.length < needed) return;
      busy = true;
      final isLast = nextCheckpoint == checkpoints.length - 1;
      nextCheckpoint++;
      final snapshot = wrapPcm16AsWav(Uint8List.fromList(buffer.toBytes()));
      bool stop = false;
      try {
        stop = await onCheckpoint(snapshot, start);
      } catch (e) {
        debugPrint('[AudioRecordService] Erro no processamento do marco: $e');
      }
      busy = false;
      if (stop || isLast || _currentToken != myToken) {
        finish();
      } else {
        // Se o próximo marco já foi alcançado durante o processamento, segue imediatamente
        unawaited(maybeCheckpoint());
      }
    }

    try {
      final stream = await _backend.startStream(config);
      captureStart = DateTime.now();
      _lastRecordStartTime = captureStart;
      sub = stream.listen(
        (chunk) {
          if (_currentToken != myToken) {
            finish();
            return;
          }
          buffer.add(chunk);
          unawaited(maybeCheckpoint());
        },
        onError: (Object e) => finish(),
        onDone: finish,
      );
      // Vigia: encerra assim que outra gravação/cancelamento invalidar o token, mesmo sem novos blocos
      watchdog = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (_currentToken != myToken) finish();
      });
      // Proteção: o último marco + margem para a consulta ao Shazam
      await done.future.timeout(checkpoints.last + const Duration(seconds: 20), onTimeout: () {});
    } finally {
      watchdog?.cancel();
      await sub?.cancel();
      if (_currentToken == myToken) {
        _isRecording = false;
        _activePriority = null;
        try {
          if (await _backend.isRecording()) await _backend.stop();
        } catch (e) {
          debugPrint('[AudioRecordService] Erro ao parar escuta progressiva: $e');
        }
      }
      if (!recordingCompleter.isCompleted) recordingCompleter.complete();
    }

    if (_currentToken != myToken) return null; // preemptada por outra gravação
    return captureStart;
  }

  /// Libera os recursos do gravador.
  void dispose() {
    _backend.dispose();
  }
}

/// Gravação progressiva descartada (microfone ocupado por gravação de maior prioridade).
class _CaptureCancelled implements Exception {}
