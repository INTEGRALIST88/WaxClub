import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'fft_service.dart';

/// Representa um pico de frequência extraído do espectrograma.
class FrequencyPeak {
  final int fftPassNumber;
  final int peakMagnitude;
  final int correctedPeakFrequencyBin;

  FrequencyPeak({
    required this.fftPassNumber,
    required this.peakMagnitude,
    required this.correctedPeakFrequencyBin,
  });
}

/// Metadados extraídos do cabeçalho WAV.
class WavInfo {
  final int sampleRate;
  final int numChannels;
  final int dataOffset;
  final int dataLength;

  const WavInfo({
    required this.sampleRate,
    required this.numChannels,
    required this.dataOffset,
    required this.dataLength,
  });
}

/// Gerador da assinatura digital (fingerprint) do Shazam em puro Dart.
/// Implementa a decomposição espectral em 4 bandas e codificação binária Little-Endian.
class ShazamSignatureGenerator {
  static const String dataUriPrefix = 'data:audio/vnd.shazam.sig;base64,';

  /// Extrai informações de cabeçalho WAV (sampleRate, canais, tamanho).
  static WavInfo parseWavInfo(Uint8List bytes) {
    int sampleRate = 16000;
    int numChannels = 1;
    int dataOffset = 0;
    int dataLength = bytes.length;

    if (bytes.length > 44 &&
        bytes[0] == 0x52 && // 'R'
        bytes[1] == 0x49 && // 'I'
        bytes[2] == 0x46 && // 'F'
        bytes[3] == 0x46) { // 'F'
      int i = 12;
      while (i < bytes.length - 8) {
        final chunkId = String.fromCharCodes(bytes.sublist(i, i + 4));
        final chunkSize = ByteData.sublistView(bytes, i + 4, i + 8).getUint32(0, Endian.little);

        if (chunkId == 'fmt ' && i + 8 + 16 <= bytes.length) {
          final fmtData = ByteData.sublistView(bytes, i + 8, i + 8 + 16);
          numChannels = fmtData.getUint16(2, Endian.little);
          sampleRate = fmtData.getUint32(4, Endian.little);
        } else if (chunkId == 'data') {
          dataOffset = i + 8;
          dataLength = math.min(chunkSize, bytes.length - dataOffset);
          break;
        }

        i += 8 + chunkSize;
      }
    }

    return WavInfo(
      sampleRate: sampleRate,
      numChannels: numChannels,
      dataOffset: dataOffset,
      dataLength: dataLength,
    );
  }

  /// Diagnóstico da última extração de picos espectrais
  static int lastExtractedPeaksCount = 0;
  static List<int> lastBandsPeaksCount = const [0, 0, 0, 0];

  /// Quantidade de amostras (16 kHz) da última assinatura, já com o preenchimento final.
  static int lastNumberSamples = 0;

  /// Silêncio anexado ao fim da gravação: 46 blocos de atraso da detecção + 1 janela de FFT.
  static const int tailPaddingSamples = 46 * 128 + 2048;

  /// Converte áudio (WAV ou PCM 16-bit) para a assinatura Shazam compatível (estilo shazamio, PCM cru).
  static String generateSignatureFromAudio(Uint8List audioBytes, {int? originalSampleRate}) {
    final wavInfo = parseWavInfo(audioBytes);
    // Prioriza SEMPRE o sample rate real do cabeçalho WAV (chunk fmt) se presente
    final effectiveSampleRate = wavInfo.dataOffset > 0 ? wavInfo.sampleRate : (originalSampleRate ?? 16000);

    // 1. Extrai amostras PCM 16-bit mono cruas (fazendo downmix de estéreo se necessário)
    final pcmSamples = _extractPcm16Samples(audioBytes, wavInfo);

    // 2. Reamostra para 16000 Hz caso o áudio original não seja 16 kHz (PCM cru direto, como shazamio)
    final samples16k = effectiveSampleRate == 16000
        ? pcmSamples
        : _resampleTo16kHz(pcmSamples, effectiveSampleRate);

    // 3. Preenche o fim com silêncio (como o SongRec): a detecção de picos ocorre 46 blocos de 128
    //    amostras depois da FFT, então sem isso os últimos ~0.4s da gravação nunca seriam analisados.
    final padded = Int16List(samples16k.length + tailPaddingSamples)..setAll(0, samples16k);

    // 4. Executa o algoritmo de extração de picos diretamente no PCM cru
    final bands = _extractPeaks(padded);
    lastExtractedPeaksCount = bands.fold(0, (sum, b) => sum + b.length);
    lastBandsPeaksCount = bands.map((b) => b.length).toList();
    lastNumberSamples = padded.length;

    // 5. Codifica em formato binário Shazam com CRC-32
    final binary = _encodeToBinary(
      sampleRateHz: 16000,
      numberSamples: padded.length,
      bands: bands,
    );

    return '$dataUriPrefix${base64Encode(binary)}';
  }

  /// Extrai amostras PCM 16-bit mono de um buffer (suportando cabeçalhos RIFF WAV e estéreo).
  static Int16List _extractPcm16Samples(Uint8List bytes, WavInfo info) {
    final totalRawBytes = info.dataLength;
    final totalRawSamples = totalRawBytes ~/ 2;
    if (totalRawSamples <= 0) return Int16List(0);

    final byteData = ByteData.sublistView(bytes, info.dataOffset, info.dataOffset + totalRawBytes);

    if (info.numChannels == 2) {
      // Converte estéreo para mono fazendo a média de L e R
      final monoCount = totalRawSamples ~/ 2;
      final mono = Int16List(monoCount);
      for (int i = 0; i < monoCount; i++) {
        final left = byteData.getInt16(i * 4, Endian.little);
        final right = byteData.getInt16(i * 4 + 2, Endian.little);
        mono[i] = ((left + right) ~/ 2).clamp(-32768, 32767);
      }
      return mono;
    } else {
      // Mono nativo
      final samples = Int16List(totalRawSamples);
      for (int i = 0; i < totalRawSamples; i++) {
        samples[i] = byteData.getInt16(i * 2, Endian.little);
      }
      return samples;
    }
  }

  /// Reamostragem linear de áudio para 16 kHz mono.
  static Int16List _resampleTo16kHz(Int16List input, int fromRate) {
    if (input.isEmpty || fromRate <= 0) return input;
    final ratio = 16000.0 / fromRate;
    final outputLength = (input.length * ratio).toInt();
    final output = Int16List(outputLength);

    for (int i = 0; i < outputLength; i++) {
      final srcIndex = i / ratio;
      final idx0 = srcIndex.floor();
      final idx1 = math.min(idx0 + 1, input.length - 1);
      final frac = srcIndex - idx0;
      final val = (input[idx0] * (1.0 - frac) + input[idx1] * frac).round();
      output[i] = val.clamp(-32768, 32767);
    }
    return output;
  }

  /// Processamento espectrograma e seleção de picos de harmônicos.
  static List<List<FrequencyPeak>> _extractPeaks(Int16List samples) {
    final List<List<FrequencyPeak>> bands = List.generate(4, (_) => []);
    if (samples.length < 2048) return bands;

    final ringBuffer = Int16List(2048);
    int ringBufferIndex = 0;

    final reordered = Float32List(2048);
    final imagBuffer = Float32List(2048);

    // Buffers circulares de histórico de FFT
    final List<Float32List> fftOutputs = List.generate(256, (_) => Float32List(1025));
    final List<Float32List> spreadOutputs = List.generate(256, (_) => Float32List(1025));

    int fftIndex = 0;
    int spreadIndex = 0;
    int numSpreadFftsDone = 0;

    const chunkSize = 128;
    final totalChunks = samples.length ~/ chunkSize;

    for (int chunk = 0; chunk < totalChunks; chunk++) {
      final chunkOffset = chunk * chunkSize;

      // 1. Copia bloco de 128 amostras no ring buffer
      for (int i = 0; i < chunkSize; i++) {
        ringBuffer[(ringBufferIndex + i) & 2047] = samples[chunkOffset + i];
      }
      ringBufferIndex = (ringBufferIndex + chunkSize) & 2047;

      // 2. Aplica Janela de Hanning
      for (int i = 0; i < 2048; i++) {
        final sampleVal = ringBuffer[(i + ringBufferIndex) & 2047];
        reordered[i] = sampleVal * FftService.hanningWindow[i];
        imagBuffer[i] = 0.0;
      }

      // 3. FFT e Potência espectral
      final powerSpectrum = FftService.computePowerSpectrum(reordered, imagBuffer);
      fftOutputs[fftIndex % 256].setAll(0, powerSpectrum);
      fftIndex = (fftIndex + 1) % 256;

      // 4. Espalhamento de picos no domínio da frequência
      final currentSpread = spreadOutputs[spreadIndex % 256];
      final currentFft = fftOutputs[(fftIndex - 1 + 256) % 256];
      currentSpread.setAll(0, currentFft);

      for (int pos = 0; pos <= 1022; pos++) {
        final m1 = currentSpread[pos];
        final m2 = currentSpread[pos + 1];
        final m3 = currentSpread[pos + 2];
        currentSpread[pos] = math.max(m1, math.max(m2, m3));
      }

      // 5. Espalhamento no domínio do tempo para FFTs anteriores (1, 3, 6)
      for (int former in [1, 3, 6]) {
        final targetSpread = spreadOutputs[(spreadIndex - former + 256) % 256];
        for (int pos = 0; pos <= 1024; pos++) {
          if (currentSpread[pos] > targetSpread[pos]) {
            targetSpread[pos] = currentSpread[pos];
          }
        }
      }

      spreadIndex = (spreadIndex + 1) % 256;
      numSpreadFftsDone++;

      // 6. Reconhecimento de picos após acúmulo de 46 passes
      if (numSpreadFftsDone >= 46) {
        final fftMinus46 = fftOutputs[(fftIndex - 46 + 256) % 256];
        final fftMinus49 = spreadOutputs[(spreadIndex - 49 + 256) % 256];

        for (int bin = 10; bin <= 1014; bin++) {
          final val = fftMinus46[bin];
          if (val >= 1.0 / 64.0 && val >= fftMinus49[bin - 1]) {
            // Máximo dos vizinhos em frequência
            double maxNeighborFreq = 0.0;
            for (int offset in [-10, -7, -4, -3, 1, 2, 5, 8]) {
              final neighborVal = fftMinus49[bin + offset];
              if (neighborVal > maxNeighborFreq) maxNeighborFreq = neighborVal;
            }

            if (val > maxNeighborFreq) {
              // Máximo dos vizinhos em tempo
              double maxNeighborTime = maxNeighborFreq;
              for (int otherOffset in [-53, -45, 165, 172, 179, 186, 193, 200, 214, 221, 228, 235, 242, 249]) {
                final otherFft = spreadOutputs[(spreadIndex + otherOffset) % 256];
                if (otherFft[bin - 1] > maxNeighborTime) maxNeighborTime = otherFft[bin - 1];
              }

              if (val > maxNeighborTime) {
                // Pico confirmado!
                final fftPassNumber = numSpreadFftsDone - 46;

                final pMag = math.log(math.max(val, 1.0 / 64.0)) * 1477.3 + 6144.0;
                final pMagBefore = math.log(math.max(fftMinus46[bin - 1], 1.0 / 64.0)) * 1477.3 + 6144.0;
                final pMagAfter = math.log(math.max(fftMinus46[bin + 1], 1.0 / 64.0)) * 1477.3 + 6144.0;

                final peakVar1 = pMag * 2.0 - pMagBefore - pMagAfter;
                final peakVar2 = peakVar1 > 0 ? (pMagAfter - pMagBefore) * 32.0 / peakVar1 : 0.0;
                final correctedBin = ((bin * 64) + peakVar2.round()).clamp(0, 65535);

                // Converte bin corrigido para Hz (16 kHz / 2 / 1024 / 64)
                final frequencyHz = correctedBin * (16000.0 / 2.0 / 1024.0 / 64.0);

                int? bandIndex;
                if (frequencyHz >= 250 && frequencyHz < 520) {
                  bandIndex = 0;
                } else if (frequencyHz >= 520 && frequencyHz < 1450) {
                  bandIndex = 1;
                } else if (frequencyHz >= 1450 && frequencyHz < 3500) {
                  bandIndex = 2;
                } else if (frequencyHz >= 3500 && frequencyHz <= 5500) {
                  bandIndex = 3;
                }

                if (bandIndex != null) {
                  bands[bandIndex].add(FrequencyPeak(
                    fftPassNumber: fftPassNumber,
                    peakMagnitude: pMag.clamp(0, 65535).toInt(),
                    correctedPeakFrequencyBin: correctedBin,
                  ));
                }
              }
            }
          }
        }
      }
    }

    return bands;
  }

  /// Codifica os dados estruturados no formato binário oficial do Shazam com checksum CRC-32.
  static Uint8List _encodeToBinary({
    required int sampleRateHz,
    required int numberSamples,
    required List<List<FrequencyPeak>> bands,
  }) {
    final builder = BytesBuilder();

    // Cabeçalho de 48 bytes
    final header = ByteData(48);
    header.setUint32(0, 0xcafe2580, Endian.little); // Magic 1
    header.setUint32(4, 0, Endian.little); // CRC32 (preenchido no final)
    header.setUint32(8, 0, Endian.little); // Tamanho menos cabeçalho (preenchido no final)
    header.setUint32(12, 0x94119c00, Endian.little); // Magic 2
    header.setUint32(16, 0, Endian.little);
    header.setUint32(20, 0, Endian.little);
    header.setUint32(24, 0, Endian.little);
    header.setUint32(28, 3 << 27, Endian.little); // 3 = 16000 Hz
    header.setUint32(32, 0, Endian.little);
    header.setUint32(36, 0, Endian.little);
    header.setUint32(40, (numberSamples + (sampleRateHz * 0.24)).round(), Endian.little);
    header.setUint32(44, (15 << 19) + 0x40000, Endian.little); // Fixed value

    builder.add(header.buffer.asUint8List());

    // Bloco fixo 0x40000000
    final chunkHeader = ByteData(8);
    chunkHeader.setUint32(0, 0x40000000, Endian.little);
    chunkHeader.setUint32(4, 0, Endian.little); // Tamanho menos cabeçalho
    builder.add(chunkHeader.buffer.asUint8List());

    // Codifica cada uma das 4 bandas de frequência
    for (int bandIndex = 0; bandIndex < bands.length; bandIndex++) {
      final peaks = bands[bandIndex];
      if (peaks.isEmpty) continue;

      final peaksBuilder = BytesBuilder();
      int lastFftPassNumber = 0;

      for (final peak in peaks) {
        final diff = peak.fftPassNumber - lastFftPassNumber;
        if (diff >= 255) {
          peaksBuilder.addByte(0xff);
          final passData = ByteData(4)..setUint32(0, peak.fftPassNumber, Endian.little);
          peaksBuilder.add(passData.buffer.asUint8List());
          lastFftPassNumber = peak.fftPassNumber;
        }

        final delta = peak.fftPassNumber - lastFftPassNumber;
        peaksBuilder.addByte(delta.clamp(0, 254));

        final peakData = ByteData(4);
        peakData.setUint16(0, peak.peakMagnitude, Endian.little);
        peakData.setUint16(2, peak.correctedPeakFrequencyBin, Endian.little);
        peaksBuilder.add(peakData.buffer.asUint8List());

        lastFftPassNumber = peak.fftPassNumber;
      }

      final peaksBytes = peaksBuilder.toBytes();

      final bandHeader = ByteData(8);
      bandHeader.setUint32(0, 0x60030040 + bandIndex, Endian.little);
      bandHeader.setUint32(4, peaksBytes.length, Endian.little);
      builder.add(bandHeader.buffer.asUint8List());
      builder.add(peaksBytes);

      // Alinhamento em 4 bytes (padding com zeros)
      final padding = (4 - (peaksBytes.length % 4)) % 4;
      for (int p = 0; p < padding; p++) {
        builder.addByte(0);
      }
    }

    final fullData = builder.toBytes();
    final sizeMinusHeader = fullData.length - 48;

    // Atualiza tamanhos nos offsets 8 e 52
    final dataView = ByteData.sublistView(fullData);
    dataView.setUint32(8, sizeMinusHeader, Endian.little);
    dataView.setUint32(52, sizeMinusHeader, Endian.little);

    // Calcula CRC-32 sobre os dados a partir do offset 8
    final crc = _computeCrc32(fullData.sublist(8));
    dataView.setUint32(4, crc, Endian.little);

    return fullData;
  }

  /// Tabela CRC32 IEEE 802.3
  static final Uint32List _crc32Table = () {
    final table = Uint32List(256);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int j = 0; j < 8; j++) {
        c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      table[i] = c;
    }
    return table;
  }();

  static int _computeCrc32(Uint8List bytes) {
    int crc = 0xFFFFFFFF;
    for (int i = 0; i < bytes.length; i++) {
      final index = (crc ^ bytes[i]) & 0xFF;
      crc = (crc >>> 8) ^ _crc32Table[index];
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
