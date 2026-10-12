import '../models/track_entry.dart';

/// Resultado da resolução de lados físicos do disco (A / B).
class SideEstimationResult {
  final List<TrackEntry> entries;
  final String sideSource; // 'catalog' | 'estimated' | 'none'

  const SideEstimationResult({
    required this.entries,
    required this.sideSource,
  });
}

/// Estimador e validador de lados físicos de discos de vinil.
class SideEstimator {
  /// Analisa e atribui lados 'A' e 'B' para a tracklist oficial.
  ///
  /// - Se >= 80% das entradas já possuem [side] definido pelo catálogo (ex: 'A1', 'B2'),
  ///   preserva os dados e retorna com `sideSource = 'catalog'`.
  /// - Se < 80% possuem [side], mas TODAS as faixas possuem [lengthMs] (> 0),
  ///   localiza a fronteira cujo tempo acumulado mais se aproxima de metade da duração
  ///   total do álbum. Atribui 'A' às faixas anteriores/iguais à fronteira e 'B' às
  ///   restantes, com `sideSource = 'estimated'`.
  /// - Caso contrário, retorna a lista sem modificação com `sideSource = 'none'`.
  static SideEstimationResult resolveSides(List<TrackEntry> entries) {
    if (entries.isEmpty) {
      return const SideEstimationResult(entries: [], sideSource: 'none');
    }

    final totalEntries = entries.length;
    final entriesWithSide = entries.where((e) => e.side != null && e.side!.isNotEmpty).length;

    // Caso 1: Catálogo já tem >= 80% com lado identificado
    if (entriesWithSide / totalEntries >= 0.8) {
      return SideEstimationResult(entries: entries, sideSource: 'catalog');
    }

    // Caso 2: Verificar se todas as faixas possuem duração válida
    final allHaveLength = entries.every((e) => e.lengthMs != null && e.lengthMs! > 0);
    if (allHaveLength && totalEntries >= 2) {
      final totalDuration = entries.fold<int>(0, (sum, e) => sum + (e.lengthMs ?? 0));
      final halfDuration = totalDuration / 2.0;

      int bestSplitIndex = 0; // índice da última faixa do Lado A
      double minDiff = double.infinity;
      int accumulated = 0;

      // Lado A deve ter >= 1 faixa e Lado B deve ter >= 1 faixa
      for (int i = 0; i < totalEntries - 1; i++) {
        accumulated += entries[i].lengthMs!;
        final diff = (accumulated - halfDuration).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestSplitIndex = i;
        }
      }

      final estimatedList = <TrackEntry>[];
      for (int i = 0; i < totalEntries; i++) {
        final assignedSide = i <= bestSplitIndex ? 'A' : 'B';
        estimatedList.add(entries[i].copyWith(side: assignedSide));
      }

      return SideEstimationResult(
        entries: estimatedList,
        sideSource: 'estimated',
      );
    }

    // Caso 3: Sem dados suficientes para estimativa confiável
    return SideEstimationResult(entries: entries, sideSource: 'none');
  }
}
