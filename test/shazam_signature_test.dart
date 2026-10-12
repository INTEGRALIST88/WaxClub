import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/fft_service.dart';
import 'package:waxclub/services/shazam_signature_generator.dart';
import 'package:waxclub/services/audio_record_service.dart';

Uint8List _createSyntheticWav({
  required int sampleRate,
  required int numChannels,
  required int bitsPerSample,
  required int durationSeconds,
}) {
  final numSamples = sampleRate * durationSeconds * numChannels;
  final bytesPerSample = bitsPerSample ~/ 8;
  final dataSize = numSamples * bytesPerSample;
  final totalSize = 36 + dataSize;

  final buffer = Uint8List(44 + dataSize);
  final bd = ByteData.sublistView(buffer);

  // 'RIFF'
  buffer.setRange(0, 4, 'RIFF'.codeUnits);
  bd.setUint32(4, totalSize, Endian.little);
  // 'WAVE'
  buffer.setRange(8, 12, 'WAVE'.codeUnits);
  // 'fmt '
  buffer.setRange(12, 16, 'fmt '.codeUnits);
  bd.setUint32(16, 16, Endian.little); // Subchunk1Size
  bd.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
  bd.setUint16(22, numChannels, Endian.little); // NumChannels
  bd.setUint32(24, sampleRate, Endian.little); // SampleRate
  bd.setUint32(28, sampleRate * numChannels * bytesPerSample, Endian.little); // ByteRate
  bd.setUint16(32, numChannels * bytesPerSample, Endian.little); // BlockAlign
  bd.setUint16(34, bitsPerSample, Endian.little); // BitsPerSample
  // 'data'
  buffer.setRange(36, 40, 'data'.codeUnits);
  bd.setUint32(40, dataSize, Endian.little);

  return buffer;
}

void main() {
  group('Shazam Signature Generator Tests', () {
    test('deve gerar assinatura com prefixo data URI oficial do Shazam', () {
      const sampleRate = 44100;
      const numSamples = sampleRate * 4;
      final pcmBytes = Uint8List(numSamples * 2);

      final signatureUri = ShazamSignatureGenerator.generateSignatureFromAudio(
        pcmBytes,
        originalSampleRate: sampleRate,
      );

      expect(signatureUri, startsWith(ShazamSignatureGenerator.dataUriPrefix));

      final base64Part = signatureUri.substring(ShazamSignatureGenerator.dataUriPrefix.length);
      final binaryData = base64Decode(base64Part);

      expect(binaryData.length, greaterThanOrEqualTo(48));

      final byteData = ByteData.sublistView(binaryData);
      expect(byteData.getUint32(0, Endian.little), equals(0xcafe2580));
      expect(byteData.getUint32(12, Endian.little), equals(0x94119c00));
      expect(byteData.getUint32(28, Endian.little), equals(3 << 27));
    });

    test('deve detectar sampleRate 48 kHz do cabeçalho WAV e resamplear para 16 kHz', () {
      final wav48k = _createSyntheticWav(
        sampleRate: 48000,
        numChannels: 1,
        bitsPerSample: 16,
        durationSeconds: 4,
      );

      // Passando sem originalSampleRate ou com valor divergente (16000), o cabeçalho WAV 48k deve prevalecer
      final signatureUri = ShazamSignatureGenerator.generateSignatureFromAudio(
        wav48k,
        originalSampleRate: 16000,
      );

      expect(signatureUri, startsWith(ShazamSignatureGenerator.dataUriPrefix));

      final base64Part = signatureUri.substring(ShazamSignatureGenerator.dataUriPrefix.length);
      final binaryData = base64Decode(base64Part);

      expect(binaryData.length, greaterThanOrEqualTo(48));
      final byteData = ByteData.sublistView(binaryData);
      expect(byteData.getUint32(0, Endian.little), equals(0xcafe2580));
      expect(byteData.getUint32(28, Endian.little), equals(3 << 27));
    });

    test('AudioRecordService usa sempre o microfone interno do aparelho', () {
      final recordService = AudioRecordService();
      expect(recordService.activeDeviceName, equals('Built-in microphone'));
    });
  });

  group('Alinhamento com a referência SongRec', () {
    test('janela de Hanning igual a hanning(2050)[1:-1] (hanning.rs do SongRec)', () {
      expect(FftService.hanningWindow[0], closeTo(0.0000023508, 1e-9));
      expect(FftService.hanningWindow[1], closeTo(0.0000094032, 1e-9));
      expect(FftService.hanningWindow[2047], closeTo(FftService.hanningWindow[0], 1e-9));
    });

    test('assinatura inclui o preenchimento final e o header declara esse total de amostras', () {
      final wav = _createSyntheticWav(sampleRate: 16000, numChannels: 1, bitsPerSample: 16, durationSeconds: 6);
      final uri = ShazamSignatureGenerator.generateSignatureFromAudio(wav);
      const expectedSamples = 6 * 16000 + ShazamSignatureGenerator.tailPaddingSamples;
      expect(ShazamSignatureGenerator.lastNumberSamples, equals(expectedSamples));

      final bin = base64Decode(uri.substring(ShazamSignatureGenerator.dataUriPrefix.length));
      final header = ByteData.sublistView(bin);
      expect(header.getUint32(40, Endian.little), equals((expectedSamples + 16000 * 0.24).round()));
    });
  });
}
