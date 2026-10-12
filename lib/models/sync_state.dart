/// Estados possíveis do ciclo de vida e calibração de sincronismo do vinil.
enum CalibrationStatus {
  /// Em repouso, aguardando início da escuta.
  idle,

  /// Gravando a 1ª amostra ambiental (4-5s).
  listeningSample1,

  /// Identificando a faixa e o timestamp inicial via fingerprinting.
  recognizingSample1,

  /// Buscando letra sincronizada na LRCLIB.
  fetchingLyrics,

  /// Em reprodução pré-calibrada (aguardando 25-30s com velocidade 1.0x).
  playingUncalibrated,

  /// Gravando a 2ª amostra ambiental para cálculo de rotação do vinil.
  listeningSample2,

  /// Calculando a variação mecânica e speed_factor da vitrola.
  calculatingSpeedFactor,

  /// Rotação calibrada com compensação contínua de velocidade.
  calibrated,

  /// Watchdog em background checando possível salto de agulha (needle skip).
  resyncingCheck,

  /// Sincronização pausada pelo usuário.
  paused,

  /// Escutando automaticamente para identificar a próxima faixa do disco.
  listeningNextTrack,

  /// Run-out groove detectado — aguardando o usuário virar o disco.
  waitingEndOfSide,

  /// Exibindo letra da próxima faixa prevista enquanto confirmação ocorre em background.
  confirmingPrediction,

  /// Ocorreu um erro no reconhecimento, rede ou permissão.
  error,
}

/// Telemetria em tempo real do motor de sincronização analógica.
class VinylTelemetry {
  /// Fator de velocidade medido (1.0 = velocidade nominal de gravação de estúdio).
  final double speedFactor;

  /// Variação percentual do pitch em relação à velocidade normal (ex: +1.8%).
  double get pitchPercent => (speedFactor - 1.0) * 100.0;

  /// RPM estimado com base no disco padrão de 33 ⅓ RPM.
  double get estimatedRpm33 => 33.3333 * speedFactor;

  /// RPM estimado com base no compacto de 45 RPM.
  double get estimatedRpm45 => 45.0 * speedFactor;

  /// Posição temporal atual calculada na faixa musical (em segundos).
  final double currentPositionSeconds;

  /// Índice da linha ativa de letra destacada no momento.
  final int activeLineIndex;

  /// Estado atual do motor.
  final CalibrationStatus status;

  /// Mensagem textual descritiva para exibição na UI.
  final String statusMessage;

  /// Segundos restantes para a próxima checagem ou calibração.
  final int countdownSeconds;

  /// Indica se a reprodução/sincronização está pausada.
  final bool isPaused;

  /// Indica se o microfone está ativamente capturando áudio neste momento.
  final bool isMicActive;

  /// Indica se a escuta/gravação foi expressamente iniciada pelo usuário via botão.
  final bool isUserListening;

  /// Duração total estimada da faixa atual em segundos (se disponível).
  final double? trackDurationSeconds;

  /// Nome amigável do microfone atualmente ativo (ex: "Microfone interno").
  final String activeMicrophoneName;

  /// Indica se o usuário travou a rotação do vinil (Pitch Lock).
  final bool isPitchLocked;

  /// Título da próxima faixa prevista do disco/álbum.
  final String? predictedNextTrackTitle;

  /// Mensagem de diagnóstico acústico e estado do motor (ex: ruído de agulha filtrado, sinal forte).
  final String? diagnosticMessage;

  /// Percentual de qualidade acústica do sinal captado (0% a 100%).
  final double signalQuality;

  /// Indica se a letra da próxima faixa prevista já está pronta em cache/memória.
  final bool nextLyricsReady;

  /// Rótulo descritivo de fim de lado (ex: "Fim do lado A").
  final String? sideEndLabel;

  /// Indica se a velocidade mecânica do hardware (toca-discos) foi aferida e estabilizada.
  final bool isHardwareSpeedCalibrated;

  const VinylTelemetry({
    this.speedFactor = 1.0,
    this.currentPositionSeconds = 0.0,
    this.activeLineIndex = -1,
    this.status = CalibrationStatus.idle,
    this.statusMessage = 'Microphone off',
    this.countdownSeconds = 0,
    this.isPaused = false,
    this.isMicActive = false,
    this.isUserListening = false,
    this.trackDurationSeconds,
    this.activeMicrophoneName = 'Built-in microphone',
    this.isPitchLocked = false,
    this.predictedNextTrackTitle,
    this.diagnosticMessage,
    this.signalQuality = 1.0,
    this.nextLyricsReady = false,
    this.sideEndLabel,
    this.isHardwareSpeedCalibrated = false,
  });

  VinylTelemetry copyWith({
    double? speedFactor,
    double? currentPositionSeconds,
    int? activeLineIndex,
    CalibrationStatus? status,
    String? statusMessage,
    int? countdownSeconds,
    bool? isPaused,
    bool? isMicActive,
    bool? isUserListening,
    double? trackDurationSeconds,
    bool clearTrackDuration = false,
    String? activeMicrophoneName,
    bool? isPitchLocked,
    String? predictedNextTrackTitle,
    bool clearPredictedNext = false,
    String? diagnosticMessage,
    bool clearDiagnosticMessage = false,
    double? signalQuality,
    bool? nextLyricsReady,
    String? sideEndLabel,
    bool clearSideEndLabel = false,
    bool? isHardwareSpeedCalibrated,
  }) {
    return VinylTelemetry(
      speedFactor: speedFactor ?? this.speedFactor,
      currentPositionSeconds: currentPositionSeconds ?? this.currentPositionSeconds,
      activeLineIndex: activeLineIndex ?? this.activeLineIndex,
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      isPaused: isPaused ?? this.isPaused,
      isMicActive: isMicActive ?? this.isMicActive,
      isUserListening: isUserListening ?? this.isUserListening,
      trackDurationSeconds: clearTrackDuration ? null : (trackDurationSeconds ?? this.trackDurationSeconds),
      activeMicrophoneName: activeMicrophoneName ?? this.activeMicrophoneName,
      isPitchLocked: isPitchLocked ?? this.isPitchLocked,
      predictedNextTrackTitle: clearPredictedNext ? null : (predictedNextTrackTitle ?? this.predictedNextTrackTitle),
      diagnosticMessage: clearDiagnosticMessage ? null : (diagnosticMessage ?? this.diagnosticMessage),
      signalQuality: signalQuality ?? this.signalQuality,
      nextLyricsReady: nextLyricsReady ?? this.nextLyricsReady,
      sideEndLabel: clearSideEndLabel ? null : (sideEndLabel ?? this.sideEndLabel),
      isHardwareSpeedCalibrated: isHardwareSpeedCalibrated ?? this.isHardwareSpeedCalibrated,
    );
  }
}
