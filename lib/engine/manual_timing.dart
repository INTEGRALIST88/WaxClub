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

/// Acha o sulco entre faixas pelo volume do microfone, em janelas de 100 ms, **relativo à música**:
/// o volume de referência é o da própria faixa (percentil 70 dos últimos ~8 s); o sulco é uma queda de
/// pelo menos [dropDb] abaixo dele, durando de [minGapSeconds] a [maxGapSeconds], seguida da volta do som
/// (3 janelas seguidas a menos de [returnDb] da referência). Assim o chiado do disco e o barulho da sala
/// não atrapalham (não depende de um silêncio absoluto). Quem chama decide se a queda está perto do fim
/// esperado pela minutagem.
class ManualBoundaryDetector {
  static const double minGapSeconds = 0.4;
  static const double maxGapSeconds = 3.5;
  static const double dropDb = 12.0;
  static const double returnDb = 8.0;
  static const double windowSeconds = 0.1;
  static const int _refWindows = 80; // ~8 s de música
  static const int _returnRun = 3;

  final List<double> _music = [];
  DateTime? _gapStart;
  DateTime? _returnStart;
  int _aboveRun = 0;

  /// Silêncio longo demais (fim do lado, agulha levantada): ignora até a música voltar.
  bool _longSilence = false;

  bool get inGap => _gapStart != null;
  DateTime? get silenceStart => _gapStart;

  /// Volume de referência da música (nulo enquanto não ouviu o bastante).
  double? get musicLevel {
    if (_music.length < 10) return null;
    final sorted = List<double>.from(_music)..sort();
    return sorted[(sorted.length * 0.7).floor().clamp(0, sorted.length - 1)];
  }

  bool gapTooLong(DateTime now) =>
      _gapStart != null && now.difference(_gapStart!).inMilliseconds / 1000.0 > maxGapSeconds;

  void reset() {
    _music.clear();
    _gapStart = null;
    _returnStart = null;
    _aboveRun = 0;
    _longSilence = false;
  }

  /// Uma captura: [start] = começo dela, [dbs] = volume de cada janela de 100 ms. Devolve a primeira
  /// queda do tamanho do sulco seguida da volta do som (o começo da faixa seguinte), se houver.
  ManualBoundary? feedWindows(DateTime start, List<double> dbs) {
    ManualBoundary? found;
    for (var i = 0; i < dbs.length; i++) {
      final t = start.add(Duration(milliseconds: (i * windowSeconds * 1000).round()));
      final b = _feed(t, dbs[i]);
      if (b != null && found == null) found = b;
    }
    return found;
  }

  ManualBoundary? _feed(DateTime t, double db) {
    final ref = musicLevel;
    if (ref == null) {
      _music.add(db);
      return null;
    }
    if (_longSilence) {
      if (db >= ref - returnDb) _longSilence = false;
      return null;
    }
    if (_gapStart == null) {
      if (db < ref - dropDb) {
        _gapStart = t;
        _aboveRun = 0;
        _returnStart = null;
      } else {
        _music.add(db);
        if (_music.length > _refWindows) _music.removeAt(0);
      }
      return null;
    }
    // Dentro da queda: espera o som voltar de forma sustentada
    if (db >= ref - returnDb) {
      _returnStart ??= t;
      _aboveRun++;
      if (_aboveRun >= _returnRun) {
        final gapStart = _gapStart!;
        final onset = _returnStart!;
        _gapStart = null;
        _returnStart = null;
        _aboveRun = 0;
        final gap = onset.difference(gapStart).inMilliseconds / 1000.0;
        if (gap >= minGapSeconds && gap <= maxGapSeconds) {
          return ManualBoundary(silenceStart: gapStart, onset: onset);
        }
      }
    } else {
      _aboveRun = 0;
      _returnStart = null;
      // Silêncio comprido demais: não é o sulco entre faixas (fim do lado, agulha levantada)
      if (t.difference(_gapStart!).inMilliseconds / 1000.0 > maxGapSeconds + 1) {
        _gapStart = null;
        _longSilence = true;
      }
    }
    return null;
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
