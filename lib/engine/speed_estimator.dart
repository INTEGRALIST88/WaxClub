import 'dart:math' as math;

/// Uma escuta reconhecida: instante real do início da captura e a posição da música informada pelo Shazam.
class SpeedObservation {
  /// Instante real do início da captura, em segundos (relógio de parede).
  final double realSeconds;

  /// Posição da música (offset do Shazam) correspondente ao início da captura, em segundos.
  final double musicSeconds;

  const SpeedObservation(this.realSeconds, this.musicSeconds);
}

/// Estimativa de rotação com a sua incerteza (desvio-padrão).
class SpeedEstimate {
  final double speed;
  final double standardError;
  final int samples;
  final double spanSeconds;

  const SpeedEstimate({
    required this.speed,
    required this.standardError,
    required this.samples,
    required this.spanSeconds,
  });

  double get variance => standardError * standardError;

  @override
  String toString() =>
      'SpeedEstimate(${speed.toStringAsFixed(4)}x ±${(standardError * 100).toStringAsFixed(2)}%, n=$samples, span=${spanSeconds.toStringAsFixed(0)}s)';
}

/// Ajuste da rotação dentro de UMA faixa por regressão linear (mínimos quadrados).
///
/// Cada escuta reconhecida fornece um par (tempo real, posição na música). Se o disco gira com
/// fator de velocidade `s`, então `posição = s * tempoReal + c`: a inclinação da reta é a rotação.
/// Ao contrário da razão entre duas amostras, a regressão usa todas as escutas da faixa e o erro
/// cai com o intervalo coberto (≈ ruído / intervalo), sem zona morta que force 1.000x.
class TrackSpeedFit {
  /// Ruído típico do carimbo de tempo do Shazam + latência de captura (desvio-padrão, segundos).
  static const double offsetNoiseSeconds = 0.15;

  /// Intervalo mínimo entre a primeira e a última escuta para produzir estimativa.
  static const double minSpanSeconds = 15.0;

  /// Resíduo acima do qual uma escuta é descartada como outlier (pulo de agulha, match errado).
  static const double outlierResidualSeconds = 1.0;

  final List<SpeedObservation> _observations = [];

  List<SpeedObservation> get observations => List.unmodifiable(_observations);
  int get length => _observations.length;

  void add(SpeedObservation observation) => _observations.add(observation);

  void clear() => _observations.clear();

  /// Estimativa atual da rotação nesta faixa, ou `null` se ainda não há dados suficientes.
  SpeedEstimate? estimate() {
    var points = List<SpeedObservation>.from(_observations);

    // Rejeição iterativa de outliers: com 3+ pontos, remove o pior resíduo se exceder o limite.
    while (points.length >= 3) {
      final fit = _ols(points);
      if (fit == null) return null;
      int worst = -1;
      double worstResidual = 0.0;
      for (int i = 0; i < points.length; i++) {
        final predicted = fit.slope * points[i].realSeconds + fit.intercept;
        final residual = (points[i].musicSeconds - predicted).abs();
        if (residual > worstResidual) {
          worstResidual = residual;
          worst = i;
        }
      }
      if (worstResidual <= outlierResidualSeconds) break;
      points = List.of(points)..removeAt(worst);
    }

    if (points.length < 2) return null;
    final fit = _ols(points);
    if (fit == null) return null;

    final span = points.map((p) => p.realSeconds).reduce(math.max) -
        points.map((p) => p.realSeconds).reduce(math.min);
    if (span < minSpanSeconds) return null;

    // Ruído: usa o resíduo medido quando há graus de liberdade, nunca abaixo do ruído típico.
    double sigma = offsetNoiseSeconds;
    if (points.length >= 3) {
      double ssr = 0.0;
      for (final p in points) {
        final r = p.musicSeconds - (fit.slope * p.realSeconds + fit.intercept);
        ssr += r * r;
      }
      sigma = math.max(sigma, math.sqrt(ssr / (points.length - 2)));
    }
    final standardError = sigma / math.sqrt(fit.sxx);

    return SpeedEstimate(
      speed: fit.slope,
      standardError: standardError,
      samples: points.length,
      spanSeconds: span,
    );
  }

  static _OlsResult? _ols(List<SpeedObservation> points) {
    final n = points.length;
    if (n < 2) return null;
    double meanX = 0.0, meanY = 0.0;
    for (final p in points) {
      meanX += p.realSeconds;
      meanY += p.musicSeconds;
    }
    meanX /= n;
    meanY /= n;
    double sxx = 0.0, sxy = 0.0;
    for (final p in points) {
      final dx = p.realSeconds - meanX;
      sxx += dx * dx;
      sxy += dx * (p.musicSeconds - meanY);
    }
    if (sxx <= 1e-9) return null;
    final slope = sxy / sxx;
    return _OlsResult(slope, meanY - slope * meanX, sxx);
  }
}

class _OlsResult {
  final double slope;
  final double intercept;
  final double sxx;
  const _OlsResult(this.slope, this.intercept, this.sxx);
}

/// Modelo bayesiano da rotação do toca-discos (propriedade do hardware, não da faixa).
///
/// Mantém média e variância. Cada faixa concluída contribui com o seu ajuste ponderado pela
/// precisão (inverso da variância); a faixa em curso é combinada com esse conhecimento prévio.
class TurntableSpeedModel {
  /// Faixa física plausível de rotação (±6%).
  static const double minSpeed = 0.94;
  static const double maxSpeed = 1.06;

  /// Incerteza inicial sem nenhuma informação (desvio-padrão de 2%).
  static const double defaultStdDev = 0.02;

  /// Piso de incerteza: a correia/motor podem variar levemente entre faixas e sessões.
  static const double minStdDev = 0.0015;

  /// Divergência (em desvios-padrão combinados) a partir da qual a faixa indica outro hardware/fonte
  /// (ex.: troca de áudio digital para um toca-discos real). O conhecimento prévio é então descartado.
  static const double changeDetectionSigmas = 4.0;

  /// Abaixo desta incerteza a rotação é considerada calibrada.
  static const double calibratedStdDev = 0.003;

  double _mean;
  double _variance;

  TurntableSpeedModel({double mean = 1.0, double stdDev = defaultStdDev})
      : _mean = mean.clamp(minSpeed, maxSpeed),
        _variance = math.pow(math.max(stdDev, minStdDev), 2).toDouble();

  double get mean => _mean;
  double get stdDev => math.sqrt(_variance);
  bool get isCalibrated => stdDev <= calibratedStdDev;

  /// Incorpora a estimativa de uma faixa concluída (fusão por inverso da variância).
  void addTrackEstimate(SpeedEstimate estimate) {
    if (estimate.speed < minSpeed || estimate.speed > maxSpeed) return;
    if (isChange(estimate)) {
      // Outra fonte/hardware: recomeça a partir da medição desta faixa
      _mean = estimate.speed;
      _variance = math.max(estimate.variance, minStdDev * minStdDev);
      return;
    }
    final combined = combine(estimate);
    _mean = combined.speed;
    _variance = math.max(combined.variance, minStdDev * minStdDev);
  }

  /// A medição é incompatível com o conhecimento prévio (provável troca de toca-discos/fonte de áudio)?
  bool isChange(SpeedEstimate estimate) {
    final combinedStd = math.sqrt(_variance + estimate.variance);
    return (estimate.speed - _mean).abs() > changeDetectionSigmas * combinedStd;
  }

  /// Melhor estimativa para a faixa atual: conhecimento prévio do hardware + ajuste da faixa.
  SpeedEstimate combine(SpeedEstimate? current) {
    if (current == null || current.speed < minSpeed || current.speed > maxSpeed) {
      return SpeedEstimate(speed: _mean, standardError: stdDev, samples: 0, spanSeconds: 0);
    }
    if (isChange(current)) {
      // Faixa atual claramente em outra rotação: confia na própria medição
      return current;
    }
    final wPrior = 1.0 / _variance;
    final wCurrent = 1.0 / current.variance;
    final speed = ((_mean * wPrior) + (current.speed * wCurrent)) / (wPrior + wCurrent);
    return SpeedEstimate(
      speed: speed.clamp(minSpeed, maxSpeed),
      standardError: math.sqrt(1.0 / (wPrior + wCurrent)),
      samples: current.samples,
      spanSeconds: current.spanSeconds,
    );
  }
}
