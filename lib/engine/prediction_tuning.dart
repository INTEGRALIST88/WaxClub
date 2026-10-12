/// Constantes de temporização e calibração para o sistema de predição do vinil.
class PredictionTuning {
  /// Atraso inicial antes da primeira escuta silenciosa de confirmação.
  static const Duration initialConfirmationDelay = Duration(seconds: 2);

  /// Intervalo até a primeira sondagem acústica após o fim de um lado (run-out).
  static const Duration sideFlipFirstProbe = Duration(seconds: 10);

  /// Intervalo entre sondagens acústicas consecutivas no modo esperando virar o disco.
  static const Duration sideFlipProbeInterval = Duration(seconds: 25);

  /// Tempo máximo de espera no estado waitingEndOfSide antes de retornar a idle.
  static const Duration sideFlipMaxWait = Duration(minutes: 10);

  /// Escalonamento de tentativas persistentes para confirmação e identificação de faixa (+0s, +8s, +20s, +35s, +55s, +80s).
  static const List<int> retryDelaysSeconds = [0, 8, 20, 35, 55, 80];

  /// Tempo máximo de espera na política de retentativas antes de desistir (90s).
  static const Duration giveUpAfter = Duration(seconds: 90);

  /// Habilita uso do speedFactor persistido no cache como prior inicial da sessão.
  static const bool kUsePersistedSpeedPrior = true;

  /// Crescimento da variância da rotação persistida por dia sem medição (≈ ±0.1% por dia, em variância).
  static const double speedDriftVariancePerDay = 0.000001;

  /// Intervalos (s) entre checagens de sincronia na mesma faixa: 1ª aos 20s, 2ª +45s, depois a cada 75s.
  /// Cada escuta reconhecida realinha a letra e entra na regressão de rotação.
  static const List<int> syncCheckDelaysSeconds = [20, 45, 75];

  /// Não agenda checagem se restarem menos que (intervalo + esta margem) segundos de faixa.
  static const int syncCheckEndMarginSeconds = 16;

  /// Duração da captura de cada checagem de sincronia. 12s: no logcat, capturas de ~5.6s de faixas menos
  /// conhecidas (ex.: Radish) quase nunca casavam no Shazam, e a letra deixava de ser realinhada.
  static const Duration syncCheckSampleDuration = Duration(seconds: 12);

  /// Atraso da checagem de ressincronia logo após retomar de uma pausa.
  static const int resumeResyncDelaySeconds = 5;

  /// Duração da 1ª escuta de identificação (resposta rápida para músicas populares).
  static const Duration initialRecognitionDuration = Duration(seconds: 6);

  /// Duração das tentativas seguintes: 12s, o mesmo buffer usado pelo SongRec no modo microfone.
  /// Amostras curtas (5s) não casam com faixas menos conhecidas no catálogo do Shazam.
  static const Duration recognitionRetryDuration = Duration(seconds: 12);

  /// Duração da captura na tentativa [attempt] (0 = primeira) das escutas de próxima faixa/confirmação.
  static Duration identificationCaptureFor(int attempt) =>
      attempt == 0 ? initialRecognitionDuration : recognitionRetryDuration;

  /// Marcos da escuta progressiva na tentativa [attempt]: a 1ª consulta o Shazam já aos 4s (rápida
  /// para músicas fáceis) e, sem recomeçar a gravação, de novo aos 8s e 12s (robusta para as difíceis).
  /// As tentativas seguintes começam direto pelo trecho mais longo.
  static List<Duration> identificationCheckpointsFor(int attempt) =>
      attempt == 0 ? fastFirstCheckpoints : robustCheckpoints;

  static const List<Duration> fastFirstCheckpoints = [
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 12),
  ];
  static const List<Duration> robustCheckpoints = [Duration(seconds: 8), Duration(seconds: 12)];

  /// Marcos das checagens de sincronia (a faixa já é conhecida; basta casar o trecho).
  static const List<Duration> syncCheckCheckpoints = [Duration(seconds: 6), Duration(seconds: 12)];

  /// Limite máximo do bias manual de letras aplicado via nudge (+/- 5.0s).
  static const double maxNudgeBiasSeconds = 5.0;

  /// Tempo de debounce para persistência do deslocamento (nudge) de letra no cache.
  static const Duration nudgeDebounceDuration = Duration(seconds: 3);
}
