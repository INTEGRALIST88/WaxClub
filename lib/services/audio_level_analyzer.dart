import 'dart:math' as math;
import 'dart:typed_data';

/// Relatório de métricas de nível de áudio calculado sobre janelas RMS em dBFS.
class AudioLevelReport {
  final double medianDb;
  final double p90Db;
  final double peakDb;
  final bool isSilent;

  /// Instante (segundos desde o início do trecho) em que o som passa a ficar acima do limiar de
  /// silêncio de forma sustentada — ex.: a agulha encontrando a música. `null` se nunca acontece.
  final double? soundOnsetSeconds;

  /// Volume (dBFS) de cada janela de 100 ms, na ordem — para achar quedas curtas (sulco entre faixas).
  final List<double> windowDbs;

  const AudioLevelReport({
    required this.medianDb,
    required this.p90Db,
    required this.peakDb,
    required this.isSilent,
    this.soundOnsetSeconds,
    this.windowDbs = const [],
  });

  @override
  String toString() =>
      'AudioLevelReport(median: ${medianDb.toStringAsFixed(1)}dB, p90: ${p90Db.toStringAsFixed(1)}dB, peak: ${peakDb.toStringAsFixed(1)}dB, isSilent: $isSilent)';
}

/// Analisador puro e determinístico de nível de áudio em formato WAV PCM 16-bit mono 16 kHz.
class AudioLevelAnalyzer {
  static const int samplesPerWindow = 1600; // 100ms a 16 kHz
  static const double minDbFloor = -100.0;
  static const double absoluteSilenceThresholdDb = -55.0;
  static const int onsetSustainWindows = 3;

  /// Analisa os bytes brutos de um arquivo WAV e extrai o relatório de níveis de áudio.
  ///
  /// [referenceMusicDb] é a média móvel (EMA) do p90Db de capturas reconhecidas com sucesso.
  /// Se fornecido, o limiar de silêncio é max(referenceMusicDb - 15.0, -55.0).
  /// Caso contrário, utiliza apenas o limiar absoluto de -55.0 dBFS.
  static AudioLevelReport analyze(
    Uint8List wavBytes, {
    double? referenceMusicDb,
  }) {
    if (wavBytes.length < 12) {
      return const AudioLevelReport(
        medianDb: minDbFloor,
        p90Db: minDbFloor,
        peakDb: minDbFloor,
        isSilent: true,
      );
    }

    final pcmSamples = _extractPcm16Samples(wavBytes);
    if (pcmSamples.isEmpty) {
      return const AudioLevelReport(
        medianDb: minDbFloor,
        p90Db: minDbFloor,
        peakDb: minDbFloor,
        isSilent: true,
      );
    }

    final windowDbs = <double>[];
    int offset = 0;

    while (offset < pcmSamples.length) {
      final end = math.min(offset + samplesPerWindow, pcmSamples.length);
      final count = end - offset;

      double sumSquares = 0.0;
      for (int i = offset; i < end; i++) {
        final norm = pcmSamples[i] / 32768.0;
        sumSquares += norm * norm;
      }

      final rms = math.sqrt(sumSquares / count);
      final db = rms > 1e-9 ? 20.0 * (math.log(rms) / math.ln10) : minDbFloor;
      windowDbs.add(math.max(db, minDbFloor));

      offset = end;
    }

    if (windowDbs.isEmpty) {
      return const AudioLevelReport(
        medianDb: minDbFloor,
        p90Db: minDbFloor,
        peakDb: minDbFloor,
        isSilent: true,
      );
    }

    // Calcula pico absoluto das janelas
    double peakDb = windowDbs.reduce(math.max);

    // Ordena para cálculo de mediana e percentil 90
    final sortedDbs = List<double>.from(windowDbs)..sort();
    final medianDb = sortedDbs[sortedDbs.length ~/ 2];
    final p90Index = (sortedDbs.length * 0.90).floor().clamp(0, sortedDbs.length - 1);
    final p90Db = sortedDbs[p90Index];

    final effectiveThreshold = referenceMusicDb != null
        ? math.max(referenceMusicDb - 15.0, absoluteSilenceThresholdDb)
        : absoluteSilenceThresholdDb;

    final isSilent = p90Db < effectiveThreshold;

    // Início sustentado do som: 3 janelas seguidas (300ms) acima do limiar
    double? onset;
    int run = 0;
    for (int i = 0; i < windowDbs.length; i++) {
      if (windowDbs[i] >= effectiveThreshold) {
        run++;
        if (run >= onsetSustainWindows) {
          onset = (i - onsetSustainWindows + 1) * samplesPerWindow / 16000.0;
          break;
        }
      } else {
        run = 0;
      }
    }

    return AudioLevelReport(
      medianDb: medianDb,
      p90Db: p90Db,
      peakDb: peakDb,
      isSilent: isSilent,
      soundOnsetSeconds: onset,
      windowDbs: List.unmodifiable(windowDbs),
    );
  }

  /// Localiza o chunk 'data' no contêiner RIFF/WAV e extrai amostras Int16 (little-endian).
  static Int16List _extractPcm16Samples(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);

    // Verifica 'RIFF' e 'WAVE'
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 && // RIFF
        bytes[8] == 0x57 && bytes[9] == 0x41 && bytes[10] == 0x56 && bytes[11] == 0x45) { // WAVE

      int offset = 12;
      while (offset + 8 <= bytes.length) {
        final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final chunkSize = byteData.getUint32(offset + 4, Endian.little);
        final dataStart = offset + 8;

        if (chunkId == 'data') {
          final available = math.min(chunkSize, bytes.length - dataStart);
          final sampleCount = available ~/ 2;
          final samples = Int16List(sampleCount);
          for (int i = 0; i < sampleCount; i++) {
            samples[i] = byteData.getInt16(dataStart + (i * 2), Endian.little);
          }
          return samples;
        }

        // Avança para o próximo chunk (alinhado a 2 bytes em RIFF)
        offset += 8 + chunkSize + (chunkSize % 2);
      }
    }

    // Fallback: se não encontrou o cabeçalho 'data' mas tem pelo menos 44 bytes, lê a partir do byte 44
    if (bytes.length > 44) {
      final available = bytes.length - 44;
      final sampleCount = available ~/ 2;
      final samples = Int16List(sampleCount);
      for (int i = 0; i < sampleCount; i++) {
        samples[i] = byteData.getInt16(44 + (i * 2), Endian.little);
      }
      return samples;
    }

    return Int16List(0);
  }
}
