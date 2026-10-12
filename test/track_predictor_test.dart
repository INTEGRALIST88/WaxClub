import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/track_predictor.dart';

void main() {
  group('TrackPredictor Tests (T1.2)', () {
    late TrackPredictor predictor;

    setUp(() {
      predictor = TrackPredictor();
    });

    test('Início no meio do lado gera next e afterNext', () {
      final entries = [
        const TrackEntry(position: 1, title: 'Track 1', side: 'A'),
        const TrackEntry(position: 2, title: 'Track 2', side: 'A'),
        const TrackEntry(position: 3, title: 'Track 3', side: 'A'),
        const TrackEntry(position: 4, title: 'Track 4', side: 'A'),
        const TrackEntry(position: 5, title: 'Track 5', side: 'A'),
      ];

      final source = PredictionSource(
        albumTitle: 'Album A',
        entries: entries,
        sideSource: 'catalog',
      );

      final result = predictor.predict(
        currentTitle: 'Track 2',
        sources: [source],
      );

      expect(result.endOfSide, isFalse);
      expect(result.current?.title, equals('Track 2'));
      expect(result.candidates.length, equals(2));
      expect(result.candidates[0].kind, equals(PredictionKind.next));
      expect(result.candidates[0].entry.title, equals('Track 3'));
      expect(result.candidates[1].kind, equals(PredictionKind.afterNext));
      expect(result.candidates[1].entry.title, equals('Track 4'));
    });

    test('Última faixa do Lado A gera endOfSide e candidato afterFlip', () {
      final entries = [
        const TrackEntry(position: 1, title: 'A1', side: 'A'),
        const TrackEntry(position: 2, title: 'A2', side: 'A'),
        const TrackEntry(position: 3, title: 'B1', side: 'B'),
        const TrackEntry(position: 4, title: 'B2', side: 'B'),
      ];

      final source = PredictionSource(
        albumTitle: 'LP Rock',
        entries: entries,
        sideSource: 'catalog',
      );

      final result = predictor.predict(
        currentTitle: 'A2',
        sources: [source],
      );

      expect(result.endOfSide, isTrue);
      expect(result.endOfSideEstimated, isFalse);
      expect(result.sideLabel, equals('A'));
      expect(result.candidates.length, equals(1));
      expect(result.candidates[0].kind, equals(PredictionKind.afterFlip));
      expect(result.candidates[0].entry.title, equals('B1'));
    });

    test('Última faixa do disco gera endOfSide com candidatos vazios', () {
      final entries = [
        const TrackEntry(position: 1, title: 'B1', side: 'B'),
        const TrackEntry(position: 2, title: 'B2 (Final)', side: 'B'),
      ];

      final source = PredictionSource(
        albumTitle: 'LP Rock',
        entries: entries,
        sideSource: 'catalog',
      );

      final result = predictor.predict(
        currentTitle: 'B2 (Final)',
        sources: [source],
      );

      expect(result.endOfSide, isTrue);
      expect(result.candidates, isEmpty);
    });

    test('Fim de lado estimado marca endOfSideEstimated', () {
      final entries = [
        const TrackEntry(position: 1, title: 'Song 1', side: 'A'),
        const TrackEntry(position: 2, title: 'Song 2', side: 'B'),
      ];

      final source = PredictionSource(
        albumTitle: 'LP Estimado',
        entries: entries,
        sideSource: 'estimated',
      );

      final result = predictor.predict(
        currentTitle: 'Song 1',
        sources: [source],
      );

      expect(result.endOfSide, isTrue);
      expect(result.endOfSideEstimated, isTrue);
      expect(result.candidates.first.kind, equals(PredictionKind.afterFlip));
      expect(result.candidates.first.entry.title, equals('Song 2'));
    });

    test('Duas fontes divergentes (estúdio vs coletânea): preferencial vence e gera alternative', () {
      // Estúdio: Bohemian Rhapsody -> You're My Best Friend -> '39
      final studioEntries = [
        const TrackEntry(position: 11, title: 'Bohemian Rhapsody'),
        const TrackEntry(position: 12, title: "You're My Best Friend"),
        const TrackEntry(position: 13, title: "'39"),
      ];
      // Coletânea: Bohemian Rhapsody -> Another One Bites the Dust
      final hitsEntries = [
        const TrackEntry(position: 1, title: 'Bohemian Rhapsody'),
        const TrackEntry(position: 2, title: 'Another One Bites the Dust'),
      ];

      final studioSource = PredictionSource(
        albumTitle: 'A Night at the Opera',
        entries: studioEntries,
        isPreferred: true, // Usuário fixou como preferencial
      );
      final hitsSource = PredictionSource(
        albumTitle: 'Greatest Hits',
        entries: hitsEntries,
      );

      final result = predictor.predict(
        currentTitle: 'Bohemian Rhapsody',
        sources: [studioSource, hitsSource],
      );

      expect(result.endOfSide, isFalse);
      expect(result.candidates.length, greaterThanOrEqualTo(2));
      expect(result.candidates[0].kind, equals(PredictionKind.next));
      expect(result.candidates[0].entry.title, equals("You're My Best Friend"));
      expect(result.candidates[1].kind, equals(PredictionKind.alternative));
      expect(result.candidates[1].entry.title, equals('Another One Bites the Dust'));
    });

    test('Eliminação por adjacência: fonte que não contém faixa anterior é eliminada', () {
      // Fonte 1 (Correta): Track 1 -> Track 2 -> Track 3
      const src1 = PredictionSource(
        albumTitle: 'Disco Real',
        entries: [
          TrackEntry(position: 1, title: 'Song Alpha'),
          TrackEntry(position: 2, title: 'Song Beta'),
          TrackEntry(position: 3, title: 'Song Gamma'),
        ],
      );
      // Fonte 2 (Coletânea com ordem diferente): Song Beta precedida de Song X
      const src2 = PredictionSource(
        albumTitle: 'Outro Disco',
        entries: [
          TrackEntry(position: 1, title: 'Song X'),
          TrackEntry(position: 2, title: 'Song Beta'),
          TrackEntry(position: 3, title: 'Song Delta'),
        ],
      );

      final result = predictor.predict(
        currentTitle: 'Song Beta',
        sources: [src1, src2],
        confirmedTitles: ['Song Alpha', 'Song Beta'],
      );

      // src1 deve vencer porque foi precedida por Song Alpha
      expect(result.candidates[0].kind, equals(PredictionKind.next));
      expect(result.candidates[0].entry.title, equals('Song Gamma'));
      // src2 foi eliminada por adjacência, então não há alternativa Delta
      expect(result.candidates.any((c) => c.entry.title == 'Song Delta'), isFalse);
    });

    test('Faixa repetida usa expectedIndexHint', () {
      final entries = [
        const TrackEntry(position: 1, title: 'Theme (Part 1)'),
        const TrackEntry(position: 2, title: 'Interlude'),
        const TrackEntry(position: 5, title: 'Theme (Part 1)'),
        const TrackEntry(position: 6, title: 'Outro'),
      ];

      final source = PredictionSource(
        albumTitle: 'Concept Album',
        entries: entries,
      );

      final result = predictor.predict(
        currentTitle: 'Theme (Part 1)',
        sources: [source],
        expectedIndexHint: 2, // Espera a segunda ocorrência (índice 2)
      );

      expect(result.candidates[0].entry.title, equals('Outro'));
    });

    test('Fonte sem a faixa é ignorada', () {
      const source = PredictionSource(
        albumTitle: 'Outro Álbum',
        entries: [
          TrackEntry(position: 1, title: 'Musica Totalmente Diferente'),
        ],
      );

      final result = predictor.predict(
        currentTitle: 'Nao Existe Aqui',
        sources: [source],
      );

      expect(result.current, isNull);
      expect(result.candidates, isEmpty);
    });

    test('Determinismo: mesma entrada produz sempre exatamente a mesma saída', () {
      final entries = [
        const TrackEntry(position: 1, title: 'Track 1', side: 'A'),
        const TrackEntry(position: 2, title: 'Track 2', side: 'A'),
        const TrackEntry(position: 3, title: 'Track 3', side: 'A'),
      ];
      final source = PredictionSource(albumTitle: 'Det', entries: entries);

      final r1 = predictor.predict(currentTitle: 'Track 1', sources: [source]);
      final r2 = predictor.predict(currentTitle: 'Track 1', sources: [source]);

      expect(r1.candidates.first.entry.title, equals(r2.candidates.first.entry.title));
      expect(r1.candidates.first.score, equals(r2.candidates.first.score));
    });
  });
}
