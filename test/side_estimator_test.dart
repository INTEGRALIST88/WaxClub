import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/side_estimator.dart';

void main() {
  group('SideEstimator Tests (T1.1)', () {
    test('Catálogo com >= 80% de lados mantém sideSource catalog', () {
      final entries = [
        const TrackEntry(position: 1, title: 'F1', side: 'A'),
        const TrackEntry(position: 2, title: 'F2', side: 'A'),
        const TrackEntry(position: 3, title: 'F3', side: 'A'),
        const TrackEntry(position: 4, title: 'F4', side: 'B'),
        const TrackEntry(position: 5, title: 'F5', side: 'B'),
      ];

      final res = SideEstimator.resolveSides(entries);
      expect(res.sideSource, equals('catalog'));
      expect(res.entries[0].side, equals('A'));
      expect(res.entries[3].side, equals('B'));
    });

    test('LP de 10 faixas sem lados mas com durações estima A e B na metade do tempo', () {
      // 10 faixas de 3 minutos cada (180.000 ms)
      final entries = List.generate(
        10,
        (i) => TrackEntry(
          position: i + 1,
          title: 'Track ${i + 1}',
          lengthMs: 180000,
        ),
      );

      final res = SideEstimator.resolveSides(entries);
      expect(res.sideSource, equals('estimated'));
      // As primeiras 5 faixas (índices 0..4) no Lado A, as 5 seguintes (5..9) no Lado B
      for (int i = 0; i < 5; i++) {
        expect(res.entries[i].side, equals('A'));
      }
      for (int i = 5; i < 10; i++) {
        expect(res.entries[i].side, equals('B'));
      }
    });

    test('Lados desiguais em número de faixas (3 faixas longas no Lado A, 5 curtas no B)', () {
      // Lado A: 3 faixas de 7 min cada (420.000 ms) = 21 min (1.260.000 ms)
      // Lado B: 5 faixas de 4 min cada (240.000 ms) = 20 min (1.200.000 ms)
      // Total: 2.460.000 ms, metade = 1.230.000 ms
      final entries = [
        const TrackEntry(position: 1, title: 'Long 1', lengthMs: 420000),
        const TrackEntry(position: 2, title: 'Long 2', lengthMs: 420000),
        const TrackEntry(position: 3, title: 'Long 3', lengthMs: 420000), // acum: 1.260.000 (diff 30.000)
        const TrackEntry(position: 4, title: 'Short 1', lengthMs: 240000),
        const TrackEntry(position: 5, title: 'Short 2', lengthMs: 240000),
        const TrackEntry(position: 6, title: 'Short 3', lengthMs: 240000),
        const TrackEntry(position: 7, title: 'Short 4', lengthMs: 240000),
        const TrackEntry(position: 8, title: 'Short 5', lengthMs: 240000),
      ];

      final res = SideEstimator.resolveSides(entries);
      expect(res.sideSource, equals('estimated'));
      expect(res.entries[0].side, equals('A'));
      expect(res.entries[1].side, equals('A'));
      expect(res.entries[2].side, equals('A'));
      expect(res.entries[3].side, equals('B'));
      expect(res.entries[7].side, equals('B'));
    });

    test('Durações ausentes resultam em sideSource none', () {
      final entries = [
        const TrackEntry(position: 1, title: 'F1', lengthMs: 180000),
        const TrackEntry(position: 2, title: 'F2', lengthMs: null), // falta duração
        const TrackEntry(position: 3, title: 'F3', lengthMs: 200000),
      ];

      final res = SideEstimator.resolveSides(entries);
      expect(res.sideSource, equals('none'));
      expect(res.entries[0].side, isNull);
    });

    test('Lista vazia ou com 1 faixa resulta em sideSource none', () {
      final resEmpty = SideEstimator.resolveSides([]);
      expect(resEmpty.sideSource, equals('none'));

      final resOne = SideEstimator.resolveSides([
        const TrackEntry(position: 1, title: 'Solo', lengthMs: 180000),
      ]);
      expect(resOne.sideSource, equals('none'));
    });
  });
}
