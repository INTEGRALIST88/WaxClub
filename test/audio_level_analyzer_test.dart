import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/audio_level_analyzer.dart';

Uint8List createWavBytes({
  required List<int> samples,
  int sampleRate = 16000,
  bool includeExtraChunk = false,
}) {
  final dataLength = samples.length * 2;
  final extraChunkLength = includeExtraChunk ? 16 : 0;
  final totalLength = 44 + extraChunkLength + dataLength;

  final bytes = Uint8List(totalLength);
  final bd = ByteData.sublistView(bytes);

  // 'RIFF'
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bd.setUint32(4, totalLength - 8, Endian.little);
  // 'WAVE'
  bytes.setRange(8, 12, 'WAVE'.codeUnits);

  int offset = 12;

  // 'fmt ' chunk (16 bytes)
  bytes.setRange(offset, offset + 4, 'fmt '.codeUnits);
  bd.setUint32(offset + 4, 16, Endian.little);
  bd.setUint16(offset + 8, 1, Endian.little); // PCM
  bd.setUint16(offset + 10, 1, Endian.little); // 1 channel
  bd.setUint32(offset + 12, sampleRate, Endian.little);
  bd.setUint32(offset + 16, sampleRate * 2, Endian.little); // Byte rate
  bd.setUint16(offset + 20, 2, Endian.little); // Block align
  bd.setUint16(offset + 22, 16, Endian.little); // Bits per sample
  offset += 24;

  if (includeExtraChunk) {
    // Custom chunk 'LIST' with 8 bytes payload (padded)
    bytes.setRange(offset, offset + 4, 'LIST'.codeUnits);
    bd.setUint32(offset + 4, 8, Endian.little);
    bytes.setRange(offset + 8, offset + 16, 'INFOtest'.codeUnits);
    offset += 16;
  }

  // 'data' chunk
  bytes.setRange(offset, offset + 4, 'data'.codeUnits);
  bd.setUint32(offset + 4, dataLength, Endian.little);
  offset += 8;

  for (int i = 0; i < samples.length; i++) {
    bd.setInt16(offset + (i * 2), samples[i], Endian.little);
  }

  return bytes;
}

void main() {
  group('AudioLevelAnalyzer Tests', () {
    test('WAV sintético de silêncio absoluto retorna isSilent == true', () {
      final samples = List<int>.filled(16000 * 3, 0); // 3 segundos de zeros
      final wav = createWavBytes(samples: samples);

      final report = AudioLevelAnalyzer.analyze(wav);

      expect(report.isSilent, isTrue);
      expect(report.p90Db, lessThan(-55.0));
      expect(report.peakDb, lessThan(-55.0));
    });

    test('WAV sintético com ruído ínfimo de fundo é classificado como silêncio', () {
      // Amostras com amplitude +/- 10 (cerca de -70 dBFS)
      final samples = List<int>.generate(16000 * 2, (i) => (i % 2 == 0 ? 10 : -10));
      final wav = createWavBytes(samples: samples);

      final report = AudioLevelAnalyzer.analyze(wav);

      expect(report.isSilent, isTrue);
      expect(report.p90Db, lessThan(-55.0));
    });

    test('Tom contínuo alto (senoide) NÃO é classificado como silêncio', () {
      // Tom senoidal de 440 Hz com amplitude 20.000 (aprox. -4.3 dBFS)
      const sampleRate = 16000;
      final samples = List<int>.generate(sampleRate * 3, (i) {
        final t = i / sampleRate;
        return (math.sin(2 * math.pi * 440 * t) * 20000).round();
      });
      final wav = createWavBytes(samples: samples);

      final report = AudioLevelAnalyzer.analyze(wav);

      expect(report.isSilent, isFalse);
      expect(report.p90Db, greaterThan(-10.0));
      expect(report.peakDb, greaterThan(-10.0));
    });

    test('3s de silêncio seguido de 2s de tom alto identifica o sinal e não silencia', () {
      const sampleRate = 16000;
      final silentSamples = List<int>.filled(sampleRate * 3, 0);
      final toneSamples = List<int>.generate(sampleRate * 2, (i) {
        final t = i / sampleRate;
        return (math.sin(2 * math.pi * 440 * t) * 18000).round();
      });
      final combined = [...silentSamples, ...toneSamples];
      final wav = createWavBytes(samples: combined);

      final report = AudioLevelAnalyzer.analyze(wav);

      expect(report.isSilent, isFalse);
      // O pico de áudio deve ser expressivo
      expect(report.peakDb, greaterThan(-15.0));
    });

    test('WAV com chunk extra LIST antes de data é parseado corretamente', () {
      const sampleRate = 16000;
      final samples = List<int>.generate(sampleRate * 2, (i) {
        return (math.sin(2 * math.pi * 200 * (i / sampleRate)) * 15000).round();
      });
      final wav = createWavBytes(samples: samples, includeExtraChunk: true);

      final report = AudioLevelAnalyzer.analyze(wav);

      expect(report.isSilent, isFalse);
      expect(report.peakDb, greaterThan(-15.0));
    });

    test('Limiar de silêncio adaptativo com referenceMusicDb', () {
      // Tom com amplitude 200 (~ -44 dBFS)
      // Se referenceMusicDb for -20 dBFS, o limiar é max(-35, -55) = -35 dBFS
      // Como -44 dBFS < -35 dBFS, deve ser considerado silencioso relativo à música alta
      const sampleRate = 16000;
      final samples = List<int>.generate(sampleRate * 2, (i) => ((i % 4) - 2) * 100);
      final wav = createWavBytes(samples: samples);

      final reportSemRef = AudioLevelAnalyzer.analyze(wav);
      // Sem referência, limiar absoluto é -55 dBFS. Como está em ~ -44 dBFS, reportSemRef.isSilent é falso
      expect(reportSemRef.p90Db, greaterThan(-55.0));

      // Com música alta reconhecida anteriormente (-15 dBFS)
      final reportComRef = AudioLevelAnalyzer.analyze(wav, referenceMusicDb: -15.0);
      expect(reportComRef.isSilent, isTrue);
    });
  });
}
