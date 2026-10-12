import 'dart:math' as math;
import 'dart:typed_data';

/// Serviço de Processamento Digital de Sinais (DSP) com FFT Radix-2 e Janela de Hanning.
class FftService {
  static const int fftSize = 2048;

  // Janela de Hanning de 2048 pontos idêntica à de referência (SongRec/shazamio): hanning(2050)[1:-1],
  // ou seja, sem os zeros das bordas — w[i] = 0.5 * (1 - cos(2π(i+1)/2049)).
  static final Float32List hanningWindow = () {
    final window = Float32List(fftSize);
    for (int i = 0; i < fftSize; i++) {
      window[i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * (i + 1) / (fftSize + 1)));
    }
    return window;
  }();

  // Tabelas de Seno e Cosseno pré-computadas para Cooley-Tukey FFT.
  static final Float32List cosTable = Float32List(fftSize ~/ 2);
  static final Float32List sinTable = Float32List(fftSize ~/ 2);
  static final Uint16List bitReversalTable = Uint16List(fftSize);

  static bool _tablesInitialized = false;

  static void initTables() {
    if (_tablesInitialized) return;
    for (int i = 0; i < fftSize ~/ 2; i++) {
      final angle = -2.0 * math.pi * i / fftSize;
      cosTable[i] = math.cos(angle);
      sinTable[i] = math.sin(angle);
    }

    // Pré-calcula inversão de bits para N = 2048 (11 bits)
    const int bits = 11;
    for (int i = 0; i < fftSize; i++) {
      int rev = 0;
      int temp = i;
      for (int j = 0; j < bits; j++) {
        rev = (rev << 1) | (temp & 1);
        temp >>= 1;
      }
      bitReversalTable[i] = rev;
    }
    _tablesInitialized = true;
  }

  /// Aplica a Transformada Rápida de Fourier (FFT Radix-2) in-place sobre vetores real e imaginário.
  /// Retorna as potências espectrais normalizadas dos 1024 bins úteis.
  static Float32List computePowerSpectrum(Float32List real, Float32List imag) {
    initTables();

    // Reordenação por inversão de bits (Bit-reversal permutation)
    for (int i = 0; i < fftSize; i++) {
      final j = bitReversalTable[i];
      if (j > i) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;

        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
    }

    // Cooley-Tukey Radix-2 Decimation-In-Time (DIT)
    for (int len = 2; len <= fftSize; len <<= 1) {
      final halfLen = len >> 1;
      final step = fftSize ~/ len;

      for (int i = 0; i < fftSize; i += len) {
        for (int j = 0; j < halfLen; j++) {
          final tableIdx = j * step;
          final c = cosTable[tableIdx];
          final s = sinTable[tableIdx];

          final uReal = real[i + j];
          final uImag = imag[i + j];

          final vReal = real[i + j + halfLen] * c - imag[i + j + halfLen] * s;
          final vImag = real[i + j + halfLen] * s + imag[i + j + halfLen] * c;

          real[i + j] = uReal + vReal;
          imag[i + j] = uImag + vImag;

          real[i + j + halfLen] = uReal - vReal;
          imag[i + j + halfLen] = uImag - vImag;
        }
      }
    }

    // Converte números complexos em potência/magnitude espectral:
    // (re^2 + im^2) / (1 << 17)
    final output = Float32List(1025);
    const double divisor = 131072.0; // 1 << 17
    for (int k = 0; k <= 1024; k++) {
      final r = real[k];
      final im = imag[k];
      final power = (r * r + im * im) / divisor;
      output[k] = power < 0.0000000001 ? 0.0000000001 : power;
    }

    return output;
  }
}
