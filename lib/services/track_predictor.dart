import '../models/track_entry.dart';
import 'tracklist_matcher.dart';

/// Tipo/Papel da predição na lista de candidatos.
enum PredictionKind {
  /// Próxima faixa provável e prioritária.
  next,

  /// Faixa alternativa de outro lançamento/coletânea.
  alternative,

  /// Faixa subsequente à próxima (N+2) no mesmo lado.
  afterNext,

  /// Primeira faixa do próximo lado (após virar o disco físico).
  afterFlip,
}

/// Fonte de catálogo/tracklist avaliada pelo preditor.
class PredictionSource {
  final String albumTitle;
  final String? releaseId;
  final List<TrackEntry> entries;
  final String sideSource; // 'catalog' | 'estimated' | 'none'
  final bool isPreferred; // Álbum preferencial do usuário
  final bool isChosen; // Release já persistido no cache local
  final bool isVinyl;

  const PredictionSource({
    required this.albumTitle,
    this.releaseId,
    required this.entries,
    this.sideSource = 'none',
    this.isPreferred = false,
    this.isChosen = false,
    this.isVinyl = false,
  });
}

/// Candidato a próxima faixa gerado pelo preditor.
class PredictionCandidate {
  final TrackEntry entry;
  final PredictionKind kind;
  final String albumTitle;
  final int score;

  const PredictionCandidate({
    required this.entry,
    required this.kind,
    required this.albumTitle,
    required this.score,
  });

  String get title => entry.title;

  @override
  String toString() =>
      'PredictionCandidate(kind: $kind, title: "${entry.title}", album: "$albumTitle", score: $score)';
}

/// Resultado consolidado da predição de faixa.
class PredictionResult {
  final TrackEntry? current;
  final List<PredictionCandidate> candidates; // Ordem de prioridade (máx. 3)
  final bool endOfSide;
  final bool endOfSideEstimated;
  final String? sideLabel; // "A", "B"...

  const PredictionResult({
    this.current,
    this.candidates = const [],
    this.endOfSide = false,
    this.endOfSideEstimated = false,
    this.sideLabel,
  });

  /// Retorna o candidato principal a ser exibido na interface ("A seguir: ...").
  PredictionCandidate? get primaryCandidate {
    for (final c in candidates) {
      if (c.kind == PredictionKind.next) return c;
    }
    return null;
  }

  /// Conveniência para próxima faixa sequencial.
  PredictionCandidate? get next => primaryCandidate;

  /// Candidato alternativo (ex: outro release/edição).
  PredictionCandidate? get alternative {
    for (final c in candidates) {
      if (c.kind == PredictionKind.alternative) return c;
    }
    return null;
  }

  /// Candidato subsequente (caso a agulha tenha pulado uma faixa).
  PredictionCandidate? get afterNext {
    for (final c in candidates) {
      if (c.kind == PredictionKind.afterNext) return c;
    }
    return null;
  }

  /// Candidato do lado B / outro lado.
  PredictionCandidate? get afterFlip {
    for (final c in candidates) {
      if (c.kind == PredictionKind.afterFlip) return c;
    }
    return null;
  }
}

/// Motor determinístico de predição de faixas e término de lado de discos de vinil.
class TrackPredictor {
  /// Executa a predição da próxima música baseando-se nas fontes fornecidas.
  PredictionResult predict({
    required String currentTitle,
    required List<PredictionSource> sources,
    List<String> confirmedTitles = const [],
    int? expectedIndexHint,
  }) {
    if (sources.isEmpty) {
      return const PredictionResult();
    }

    // 1. Localizar índice da faixa atual em cada fonte
    final matchedSources = <_SourceMatch>[];
    for (final src in sources) {
      final idx = TracklistMatcher.findIndex(
        src.entries,
        currentTitle,
        expectedIndex: expectedIndexHint,
      );
      if (idx != -1 && idx < src.entries.length) {
        matchedSources.add(_SourceMatch(
          source: src,
          index: idx,
          currentEntry: src.entries[idx],
        ));
      }
    }

    if (matchedSources.isEmpty) {
      return const PredictionResult();
    }

    // 2. Análise de adjacência e ordem com histórico completo de faixas confirmadas
    final fullHistory = <String>[...confirmedTitles];
    if (fullHistory.isEmpty || !TracklistMatcher.isSameTitle(fullHistory.last, currentTitle)) {
      fullHistory.add(currentTitle);
    }

    if (fullHistory.length >= 2) {
      for (final match in matchedSources) {
        // Verifica se toda a sequência tocada aparece em ordem crescente na fonte
        final isSeq = TracklistMatcher.isSequentialMatch(match.source.entries, fullHistory);
        if (isSeq) {
          match.adjacencyOk = true;
        } else {
          // Checa se há conflito de ordem (faixas aparecem invertidas em relação ao histórico)
          int lastIdx = -1;
          for (final t in fullHistory) {
            final idx = TracklistMatcher.findIndex(match.source.entries, t);
            if (idx != -1) {
              if (lastIdx != -1 && idx < lastIdx) {
                match.hasOrderConflict = true;
                break;
              }
              lastIdx = idx;
            }
          }
        }
      }

      // Se alguma fonte tiver a sequência exata em ordem, descarta fontes com conflito de ordem
      final hasSeqMatches = matchedSources.any((m) => m.adjacencyOk);
      if (hasSeqMatches) {
        final filtered = matchedSources.where((m) => m.adjacencyOk && !m.hasOrderConflict).toList();
        if (filtered.isNotEmpty) {
          matchedSources
            ..clear()
            ..addAll(filtered);
        }
      } else {
        // Se nenhuma teve sequência contígua perfeita, descarta as que têm ordem invertida comprovada
        final nonConflicting = matchedSources.where((m) => !m.hasOrderConflict).toList();
        if (nonConflicting.isNotEmpty && nonConflicting.length < matchedSources.length) {
          matchedSources
            ..clear()
            ..addAll(nonConflicting);
        }
      }
    } else if (confirmedTitles.isNotEmpty) {
      final prev = confirmedTitles.last;
      for (final match in matchedSources) {
        if (match.index > 0) {
          final prevEntry = match.source.entries[match.index - 1];
          if (TracklistMatcher.isSameTitle(prevEntry.title, prev)) {
            match.adjacencyOk = true;
          }
        }
      }
      final hasAdj = matchedSources.any((m) => m.adjacencyOk);
      if (hasAdj) {
        final filtered = matchedSources.where((m) => m.adjacencyOk).toList();
        if (filtered.isNotEmpty) {
          matchedSources
            ..clear()
            ..addAll(filtered);
        }
      }
    }

    // 3. Fim de lado e cálculo de pontuação para cada fonte
    for (final match in matchedSources) {
      final entries = match.source.entries;
      final idx = match.index;
      final current = match.currentEntry;
      final hasNext = (idx + 1 < entries.length);
      final next = hasNext ? entries[idx + 1] : null;

      // Fim de lado: sem próxima faixa OU lados diferentes (se sideSource != none)
      if (match.source.sideSource != 'none') {
        match.isEndOfSide = (!hasNext) ||
            (current.side != null && next?.side != null && current.side != next!.side);
      } else {
        match.isEndOfSide = (!hasNext);
      }

      int score = 0;
      if (match.source.isPreferred) score += 100;
      if (match.adjacencyOk) score += 30;
      if (match.source.isChosen) score += 20;
      if (match.source.isVinyl) score += 5;

      match.baseScore = score;
    }

    // 4. Bonificação por concordância entre fontes para o próximo título
    for (final m1 in matchedSources) {
      int agreementBonus = 0;
      final next1 = (m1.index + 1 < m1.source.entries.length)
          ? m1.source.entries[m1.index + 1]
          : null;

      if (next1 != null) {
        final norm1 = TracklistMatcher.normalize(next1.title);
        for (final m2 in matchedSources) {
          if (identical(m1, m2)) continue;
          final next2 = (m2.index + 1 < m2.source.entries.length)
              ? m2.source.entries[m2.index + 1]
              : null;
          if (next2 != null && TracklistMatcher.normalize(next2.title) == norm1) {
            agreementBonus += 10;
          }
        }
      }
      m1.totalScore = m1.baseScore + agreementBonus;
    }

    // 5. Ordenar fontes por pontuação decrescente
    matchedSources.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final winner = matchedSources.first;

    // 6. Construir resultado da predição
    if (winner.isEndOfSide) {
      final candidates = <PredictionCandidate>[];
      final nextIdx = winner.index + 1;
      if (nextIdx < winner.source.entries.length) {
        // afterFlip: primeira faixa do próximo lado para pré-carregamento de LRC
        candidates.add(PredictionCandidate(
          entry: winner.source.entries[nextIdx],
          kind: PredictionKind.afterFlip,
          albumTitle: winner.source.albumTitle,
          score: winner.totalScore,
        ));
      }

      return PredictionResult(
        current: winner.currentEntry,
        candidates: candidates,
        endOfSide: true,
        endOfSideEstimated: winner.source.sideSource == 'estimated',
        sideLabel: winner.currentEntry.side,
      );
    }

    // Não é fim de lado: gerar até 3 candidatos (next, alternative, afterNext)
    final candidates = <PredictionCandidate>[];

    // Candidato 1: next (melhor grupo)
    final winnerNext = winner.source.entries[winner.index + 1];
    candidates.add(PredictionCandidate(
      entry: winnerNext,
      kind: PredictionKind.next,
      albumTitle: winner.source.albumTitle,
      score: winner.totalScore,
    ));

    // Candidato 2: alternative (segundo grupo divergente, se existir)
    final winnerNorm = TracklistMatcher.normalize(winnerNext.title);
    for (final alt in matchedSources) {
      if (alt.index + 1 < alt.source.entries.length) {
        final altNext = alt.source.entries[alt.index + 1];
        if (TracklistMatcher.normalize(altNext.title) != winnerNorm) {
          candidates.add(PredictionCandidate(
            entry: altNext,
            kind: PredictionKind.alternative,
            albumTitle: alt.source.albumTitle,
            score: alt.totalScore,
          ));
          break; // Apenas a melhor alternativa
        }
      }
    }

    // Candidato 3: afterNext (entries[idx + 2] da fonte vencedora, se existir e no mesmo lado)
    final afterNextIdx = winner.index + 2;
    if (afterNextIdx < winner.source.entries.length) {
      final afterNext = winner.source.entries[afterNextIdx];
      final isSameSide = (winner.source.sideSource == 'none') ||
          (winnerNext.side == null || afterNext.side == null || winnerNext.side == afterNext.side);

      if (isSameSide) {
        candidates.add(PredictionCandidate(
          entry: afterNext,
          kind: PredictionKind.afterNext,
          albumTitle: winner.source.albumTitle,
          score: winner.totalScore,
        ));
      }
    }

    return PredictionResult(
      current: winner.currentEntry,
      candidates: candidates,
      endOfSide: false,
      endOfSideEstimated: false,
      sideLabel: winner.currentEntry.side,
    );
  }
}

class _SourceMatch {
  final PredictionSource source;
  final int index;
  final TrackEntry currentEntry;
  bool adjacencyOk = false;
  bool hasOrderConflict = false;
  bool isEndOfSide = false;
  int baseScore = 0;
  int totalScore = 0;

  _SourceMatch({
    required this.source,
    required this.index,
    required this.currentEntry,
  });
}
