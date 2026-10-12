import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Vinyl Mechanical Rotation Compensation Math Tests', () {
    test('cálculo do speed_factor com base em delta_real e delta_musica', () {
      // Simulação do comportamento do vinil:
      // Amostra 1: t_start, base_offset = 10.0s
      const double baseOffset = 10.0;
      final tStart = DateTime(2026, 10, 1, 12, 0, 0);

      // Amostra 2 após 28.0 segundos de relógio real
      final tSample2 = tStart.add(const Duration(milliseconds: 28000));
      // Toca-discos rodando ligeiramente mais rápido (pitch +1.8% -> 1.018x):
      // A música tocou: 28.0 * 1.018 = 28.504 segundos
      const double novoOffset = baseOffset + 28.504;

      final double deltaReal = (tSample2.difference(tStart)).inMilliseconds / 1000.0;
      const double deltaMusica = novoOffset - baseOffset;
      final double speedFactor = deltaMusica / deltaReal;

      expect(deltaReal, equals(28.0));
      expect(deltaMusica, closeTo(28.504, 0.001));
      expect(speedFactor, closeTo(1.018, 0.0001));

      // Verificação da posição após 60 segundos de reprodução compensada
      const double elapsedAfterCalibration = 60.0;
      final double posicaoAtual = novoOffset + (elapsedAfterCalibration * speedFactor);

      // Posição calculada com precisão analógica
      expect(posicaoAtual, closeTo(38.504 + (60.0 * 1.018), 0.001));
    });

    test('detecção de pulo de agulha (needle skip fallback)', () {
      const double expectedPosition = 120.0; // Posição que o relógio esperava

      // Caso 1: Variação normal contínua (< 3s)
      const double detectedNormal = 121.2;
      final isNeedleSkipNormal = (detectedNormal - expectedPosition).abs() > 3.0;
      expect(isNeedleSkipNormal, isFalse);

      // Caso 2: Agulha pulou para frente (+12s)
      const double detectedJumpForward = 132.5;
      final isNeedleSkipForward = (detectedJumpForward - expectedPosition).abs() > 3.0;
      expect(isNeedleSkipForward, isTrue);

      // Caso 3: Agulha pulou para trás (-8s)
      const double detectedJumpBackward = 112.0;
      final isNeedleSkipBackward = (detectedJumpBackward - expectedPosition).abs() > 3.0;
      expect(isNeedleSkipBackward, isTrue);
    });

    test('cálculo da RPM estimada para discos de 33 1/3 e 45 RPM', () {
      const double speedFactor = 1.018;

      const rpm33 = 33.3333 * speedFactor;
      const rpm45 = 45.0 * speedFactor;

      expect(rpm33, closeTo(33.933, 0.01));
      expect(rpm45, closeTo(45.81, 0.01));
    });

    test('filtro EMA suaviza transição do SpeedFactor e evita saltos bruscos', () {
      double currentSpeed = 1.0;
      const double newSample = 1.025;

      // Aplicação do filtro EMA com peso 0.40 no histórico e 0.60 na amostra
      final smoothed = (currentSpeed * 0.40) + (newSample * 0.60);

      expect(smoothed, equals(1.015));
      expect(smoothed, lessThan(newSample));
      expect(smoothed, greaterThan(currentSpeed));
    });

    test('trava de pitch (isPitchLocked) impede recalculação de velocidade', () {
      double speedFactor = 1.015;
      const double incomingSample = 1.040;

      void applySample(bool isLocked) {
        if (!isLocked) {
          speedFactor = (speedFactor * 0.40) + (incomingSample * 0.60);
        }
      }

      applySample(true);

      // Deve manter exatamente 1.015 quando travado
      expect(speedFactor, equals(1.015));
    });
  });
}
