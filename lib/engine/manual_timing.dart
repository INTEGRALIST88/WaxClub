/// Peças do Modo Manual que não dependem do microfone nem do relógio do app (testáveis isoladas):
/// o detector do sulco entre faixas e o estimador da rotação da vitrola na sessão.
library;

/// Fim de uma faixa e começo da seguinte, achados pelo volume do microfone.
class ManualBoundary {
  /// Quando o som da faixa acabou (começo do silêncio do sulco entre faixas).
  final DateTime silenceStart;

  /// Quando a faixa seguinte começou (primeiro som depois do silêncio).
  final DateTime onset;

  const ManualBoundary({required this.silenceStart, required this.onset});

  double get gapSeconds => onset.difference(silenceStart).inMilliseconds / 1000.0;
}

/// Acha o sulco entre faixas: silêncio de [minGapSeconds] a [maxGapSeconds] seguido de som.
/// Recebe as capturas curtas do microfone na ordem ([feed]); um silêncio curto demais é uma pausa
/// da própria música, e um longo demais não é o espaço entre faixas (fim do lado, agulha levantada).
class ManualBoundaryDetector {
  /// O espaço entre faixas num LP fica em torno de 1 a 3 segundos.
  static const double minGapSeconds = 0.4;
  static const double maxGapSeconds = 3.5;

  DateTime? _silenceStart;

  /// Está no meio de um silêncio (talvez o sulco entre faixas).
  bool get inGap => _silenceStart != null;
  DateTime? get silenceStart => _silenceStart;

  /// Silêncio já passou do tamanho máximo do sulco entre faixas.
  bool gapTooLong(DateTime now) =>
      _silenceStart != null && now.difference(_silenceStart!).inMilliseconds / 1000.0 > maxGapSeconds;

  void reset() => _silenceStart = null;

  /// Uma captura: [start] = começo dela, [silent] = só silêncio, [soundOnset] = onde o som começou nela.
  /// Devolve o limite entre as faixas quando o som volta depois de um silêncio do tamanho certo.
  ManualBoundary? feed({required DateTime start, required bool silent, DateTime? soundOnset}) {
    if (silent) {
      _silenceStart ??= start;
      return null;
    }
    final silenceStart = _silenceStart;
    _silenceStart = null;
    if (silenceStart == null) return null;
    final onset = soundOnset ?? start;
    final gap = onset.difference(silenceStart).inMilliseconds / 1000.0;
    if (gap < minGapSeconds || gap > maxGapSeconds) return null;
    return ManualBoundary(silenceStart: silenceStart, onset: onset);
  }
}

/// Estimativa da rotação da vitrola durante a sessão do Modo Manual.
///
/// Duas fontes:
/// * **ajustes do usuário (±0.5 s):** o primeiro acerta o começo; um ajuste feito mais de
///   [minNudgeIntervalSeconds] depois do anterior mostra quanto a letra escorregou nesse tempo, ou seja,
///   o quanto a vitrola gira mais rápido ou mais devagar (correção = ajuste ÷ intervalo);
/// * **microfone:** a duração medida de uma faixa (do começo dela até o silêncio do fim) comparada com a
///   minutagem da prensagem — só quando a minutagem vem de fonte confiável.
class ManualTimingEstimator {
  static const double minNudgeIntervalSeconds = 60;

  /// A rotação estimada nunca passa de ±4% da nominal (mais que isso é engano de medida).
  static const double maxCorrection = 0.04;

  /// Uma faixa medida pelo microfone só conta se a razão ficar em ±4% (fade-out, faixa escondida...).
  static const double maxMeasuredDeviation = 0.04;

  double? _anchorTimeline;
  double? _measuredRatio;
  int _measuredCount = 0;

  /// Rotação medida pelo microfone (média das faixas válidas), ou nula.
  double? get measuredRatio => _measuredRatio;

  void reset() {
    _anchorTimeline = null;
    _measuredRatio = null;
    _measuredCount = 0;
  }

  /// Recomeça a referência dos ajustes (ex.: virou o disco; a agulha recomeça pelo microfone).
  void resetNudgeAnchor() => _anchorTimeline = null;

  /// Ajuste do usuário de [deltaSeconds] no ponto [timelineSeconds] do lado (tempo do disco).
  /// Devolve a correção de rotação (fração, ex.: 0.008 = 0,8% mais rápido) quando o ajuste anterior
  /// foi há mais de [minNudgeIntervalSeconds]; senão, nula (ajuste de começo ou em sequência).
  double? addNudge(double timelineSeconds, double deltaSeconds) {
    final anchor = _anchorTimeline;
    _anchorTimeline = timelineSeconds;
    if (anchor == null) return null;
    final interval = timelineSeconds - anchor;
    if (interval < minNudgeIntervalSeconds) return null;
    return (deltaSeconds / interval).clamp(-maxCorrection, maxCorrection);
  }

  /// Faixa medida: [listedSeconds] pela minutagem e [measuredRealSeconds] tocando de verdade.
  /// Devolve a rotação estimada (média das faixas válidas) ou nula se a medida não for confiável.
  double? addTrackMeasurement(double listedSeconds, double measuredRealSeconds) {
    if (listedSeconds <= 30 || measuredRealSeconds <= 0) return null;
    final ratio = listedSeconds / measuredRealSeconds;
    if ((ratio - 1).abs() > maxMeasuredDeviation) return null;
    _measuredCount++;
    _measuredRatio = _measuredRatio == null ? ratio : _measuredRatio! + (ratio - _measuredRatio!) / _measuredCount;
    return _measuredRatio;
  }
}
