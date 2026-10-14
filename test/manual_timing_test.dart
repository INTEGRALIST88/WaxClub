import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/engine/manual_timing.dart';

void main() {
  final t0 = DateTime(2026, 10, 14, 20);
  DateTime at(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

  group('sulco entre faixas pelo microfone (janelas de 100 ms, relativo à música)', () {
    List<double> level(double db, double seconds) => List.filled((seconds * 10).round(), db);

    test('queda de 2 s em relação à música seguida da volta do som = fim de uma faixa e começo da seguinte', () {
      final d = ManualBoundaryDetector();
      // 6 s de música (−20 dB), 2 s de sulco com chiado do disco (−40 dB, longe de silêncio absoluto), música de novo
      expect(d.feedWindows(at(0), level(-20, 6)), isNull);
      expect(d.feedWindows(at(6), level(-40, 2)), isNull);
      expect(d.inGap, isTrue);
      final b = d.feedWindows(at(8), level(-21, 1));
      expect(b, isNotNull);
      expect(b!.silenceStart, at(6));
      expect(b.onset, at(8));
      expect(b.gapSeconds, closeTo(2.0, 0.01));
    });

    test('trecho baixo curto dentro da música não é troca de faixa', () {
      final d = ManualBoundaryDetector();
      d.feedWindows(at(0), level(-20, 6));
      expect(d.feedWindows(at(6), [...level(-40, 0.2), ...level(-20, 1)]), isNull);
    });

    test('queda pequena (música mais baixa) não conta; silêncio longo demais também não', () {
      final d = ManualBoundaryDetector();
      d.feedWindows(at(0), level(-20, 6));
      expect(d.feedWindows(at(6), [...level(-28, 2), ...level(-20, 1)]), isNull, reason: 'só 8 dB abaixo');
      final e = ManualBoundaryDetector();
      e.feedWindows(at(0), level(-20, 6));
      expect(e.feedWindows(at(6), [...level(-45, 6), ...level(-20, 1)]), isNull, reason: 'fim do lado / agulha levantada');
    });
  });

  group('depois do ▶: silêncio antes da música ou música já tocando', () {
    List<double> level(double db, double seconds) => List.filled((seconds * 10).round(), db);
    // música: volume que varia (−18 a −28 dB a cada 100 ms)
    List<double> music(double seconds) => [for (var i = 0; i < (seconds * 10).round(); i++) i.isEven ? -18.0 : -28.0];

    test('agulha no sulco de entrada (chiado) e depois a música: começa no primeiro som', () {
      final d = ManualOnsetDetector();
      expect(d.feedWindows(at(0), level(-50, 1)), isNull, reason: 'chiado do disco acima de −55 dB não é música');
      final o = d.feedWindows(at(1), [...level(-50, 0.5), ...music(0.5)]);
      expect(o, isNotNull);
      expect(o!.alreadyPlaying, isFalse);
      expect(o.at, at(1.5));
    });

    test('chiado constante por muito tempo: continua esperando', () {
      final d = ManualOnsetDetector();
      for (var s = 0; s < 6; s++) {
        expect(d.feedWindows(at(s.toDouble()), level(-50, 1)), isNull);
      }
    });

    test('a música já tocava quando o usuário tocou no ▶: começa agora, incerta', () {
      final d = ManualOnsetDetector();
      expect(d.feedWindows(at(0), music(1)), isNull, reason: 'ainda cedo para decidir');
      expect(d.feedWindows(at(1), music(1)), isNull);
      final o = d.feedWindows(at(2), music(1));
      expect(o, isNotNull);
      expect(o!.alreadyPlaying, isTrue);
      expect(o.at, at(0));
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
