import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/manual_timing.dart';

void main() {
  final t0 = DateTime(2026, 10, 14, 20);
  DateTime at(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

  group('sulco entre faixas pelo microfone', () {
    test('silêncio de 1 a 3 s seguido de som = fim de uma faixa e começo da seguinte', () {
      final d = ManualBoundaryDetector();
      expect(d.feed(start: at(0), silent: false), isNull);
      expect(d.feed(start: at(0.5), silent: true), isNull);
      expect(d.inGap, isTrue);
      expect(d.feed(start: at(1.0), silent: true), isNull);
      final b = d.feed(start: at(2.5), silent: false, soundOnset: at(2.7));
      expect(b, isNotNull);
      expect(b!.silenceStart, at(0.5));
      expect(b.onset, at(2.7), reason: 'o começo da faixa seguinte é o primeiro som');
      expect(b.gapSeconds, closeTo(2.2, 0.01));
      expect(d.inGap, isFalse);
    });

    test('pausa curta da própria música não é troca de faixa', () {
      final d = ManualBoundaryDetector();
      d.feed(start: at(0), silent: true);
      expect(d.feed(start: at(0.2), silent: false), isNull);
    });

    test('silêncio longo demais não é o sulco (fim do lado, agulha levantada)', () {
      final d = ManualBoundaryDetector();
      d.feed(start: at(0), silent: true);
      expect(d.gapTooLong(at(4)), isTrue);
      expect(d.feed(start: at(5), silent: false), isNull);
    });
  });

  group('rotação da vitrola na sessão', () {
    test('o 1º ajuste só acerta o começo; outro mais de 1 minuto depois mede a rotação', () {
      final e = ManualTimingEstimator();
      expect(e.addNudge(10, 0.5), isNull, reason: 'primeiro ajuste: começo');
      expect(e.addNudge(40, 0.5), isNull, reason: 'menos de 1 minuto depois: ainda acertando o começo');
      // 120 s depois do último ajuste a letra atrasou 1 s: a vitrola gira ~0,83% mais rápido
      expect(e.addNudge(160, 1.0), closeTo(1 / 120, 1e-9));
    });

    test('a estimativa por ajustes nunca passa de ±4%', () {
      final e = ManualTimingEstimator();
      e.addNudge(0, 1);
      expect(e.addNudge(61, 30), ManualTimingEstimator.maxCorrection);
    });

    test('faixa medida pelo microfone: média das medidas válidas, descarta as absurdas', () {
      final e = ManualTimingEstimator();
      expect(e.addTrackMeasurement(200, 198), closeTo(200 / 198, 1e-9));
      expect(e.addTrackMeasurement(200, 150), isNull, reason: 'diferença de 33%: medida errada');
      final avg = e.addTrackMeasurement(300, 297);
      expect(avg, closeTo((200 / 198 + 300 / 297) / 2, 1e-9));
      expect(e.addTrackMeasurement(20, 19), isNull, reason: 'faixa curta demais para medir');
    });
  });
}
