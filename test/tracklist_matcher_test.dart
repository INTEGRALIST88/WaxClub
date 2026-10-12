import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/tracklist_matcher.dart';

void main() {
  group('TracklistMatcher Tests (T0.1)', () {
    test('normalização e diacríticos', () {
      expect(TracklistMatcher.normalize('Coração'), equals('coracao'));
      expect(TracklistMatcher.normalize('Ação'), equals('acao'));
      expect(TracklistMatcher.normalize('ao'), equals('ao'));
      expect(TracklistMatcher.isSameTitle('Coração', 'coracao'), isTrue);
      expect(TracklistMatcher.isSameTitle('Ação', 'ao'), isFalse);
    });

    test('remoção de qualificadores e sufixos de remaster/live', () {
      expect(
        TracklistMatcher.normalize('Bohemian Rhapsody - Remastered 2011'),
        equals('bohemian rhapsody'),
      );
      expect(
        TracklistMatcher.isSameTitle(
          'Bohemian Rhapsody - Remastered 2011',
          'Bohemian Rhapsody',
        ),
        isTrue,
      );
      expect(
        TracklistMatcher.normalize('Tempo Perdido (Ao Vivo)'),
        equals('tempo perdido'),
      );
    });

    test('preservação de qualificadores narrativos (Reprise, Part 2)', () {
      expect(
        TracklistMatcher.normalize('Intro (Reprise)'),
        equals('intro reprise'),
      );
      expect(
        TracklistMatcher.isSameTitle('Intro', 'Intro (Reprise)'),
        isFalse,
      );
      expect(
        TracklistMatcher.isSameTitle('Love', 'Love Me Do'),
        isFalse,
      );
    });

    test('títulos curtos (<5 chars) exigem igualdade exata', () {
      expect(TracklistMatcher.isSameTitle('In', 'In'), isTrue);
      expect(TracklistMatcher.isSameTitle('In', 'Inn'), isFalse);
      expect(TracklistMatcher.isSameTitle('Go', 'Go!'), isTrue);
      expect(TracklistMatcher.isSameTitle('Go', 'Gone'), isFalse);
    });

    test('findIndex com faixas repetidas e expectedIndex', () {
      final entries = [
        const TrackEntry(position: 1, title: 'Intro'),
        const TrackEntry(position: 2, title: 'Song A'),
        const TrackEntry(position: 3, title: 'Interlude'),
        const TrackEntry(position: 4, title: 'Song B'),
        const TrackEntry(position: 5, title: 'Interlude'),
        const TrackEntry(position: 6, title: 'Outro'),
      ];

      // Sem dica de expectedIndex pega o primeiro
      expect(TracklistMatcher.findIndex(entries, 'Interlude'), equals(2));
      // Com dica próxima ao segundo pega a posição 4 (índice 4)
      expect(TracklistMatcher.findIndex(entries, 'Interlude', expectedIndex: 4), equals(4));
    });

    test('isSameArtist com "The Beatles" e participações (feat)', () {
      expect(TracklistMatcher.isSameArtist('The Beatles', 'Beatles'), isTrue);
      expect(TracklistMatcher.isSameArtist('Queen feat. David Bowie', 'Queen'), isTrue);
      expect(TracklistMatcher.isSameArtist('Legião Urbana', 'Legiao Urbana'), isTrue);
    });

    test('isSequentialMatch valida ordem sequencial e rejeita ordem invertida', () {
      final entries = [
        const TrackEntry(position: 1, title: 'Faixa 1'),
        const TrackEntry(position: 2, title: 'Faixa 2'),
        const TrackEntry(position: 3, title: 'Faixa 3'),
        const TrackEntry(position: 4, title: 'Faixa 4'),
      ];

      // Ordem direta de 3 músicas
      expect(
        TracklistMatcher.isSequentialMatch(entries, ['Faixa 1', 'Faixa 2', 'Faixa 3']),
        isTrue,
      );

      // Ordem invertida (Faixa 2 antes da Faixa 1)
      expect(
        TracklistMatcher.isSequentialMatch(entries, ['Faixa 2', 'Faixa 1', 'Faixa 3']),
        isFalse,
      );

      // Faixa inexistente
      expect(
        TracklistMatcher.isSequentialMatch(entries, ['Faixa 1', 'Faixa Fantasma', 'Faixa 3']),
        isFalse,
      );

      // Salto aceitável (Faixa 1 -> Faixa 3 com gap 2)
      expect(
        TracklistMatcher.isSequentialMatch(entries, ['Faixa 1', 'Faixa 3'], maxGap: 2),
        isTrue,
      );

      // Salto excessivo (Faixa 1 -> Faixa 4 com maxGap 2)
      expect(
        TracklistMatcher.isSequentialMatch(entries, ['Faixa 1', 'Faixa 4'], maxGap: 2),
        isFalse,
      );
    });

    test('chave de cache canônica', () {
      expect(
        TracklistMatcher.key('The Beatles', 'Love Me Do (Remastered)'),
        equals('the beatles|love me do'),
      );
    });
  });
}
