import 'dart:math';
import '../models/track_entry.dart';

/// Utilitário puro de normalização, correspondência e desambiguação de faixas e artistas.
class TracklistMatcher {
  static const Map<String, String> _diacriticsMap = {
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'Á': 'a', 'À': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a', 'Å': 'a', 'Ā': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
    'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e', 'Ē': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
    'Í': 'i', 'Ì': 'i', 'Î': 'i', 'Ï': 'i', 'Ī': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'Ó': 'o', 'Ò': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o', 'Ø': 'o', 'Ō': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
    'Ú': 'u', 'Ù': 'u', 'Û': 'u', 'Ü': 'u', 'Ū': 'u',
    'ý': 'y', 'ÿ': 'y', 'Ý': 'y',
    'ç': 'c', 'Ç': 'c',
    'ñ': 'n', 'Ñ': 'n',
    'œ': 'oe', 'Œ': 'oe',
    'æ': 'ae', 'Æ': 'ae',
    'ß': 'ss',
  };

  static const String _qualifiersPattern =
      r'(remaster|remasteriz|live|ao vivo|mono|stereo|estéreo|version|versão|edit|mix|bonus|bônus|deluxe|demo|single|feat|ft\.|with)';

  static final RegExp _qualifiersInBrackets = RegExp(
    r'\s*[\(\[][^\)\]]*?' + _qualifiersPattern + r'[^\)\]]*?[\)\]]',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _dashQualifiers = RegExp(
    r'\s+-\s+.*?' + _qualifiersPattern + r'.*?$',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _punctuationRegex = RegExp(
    r'[^\p{L}\p{N}\s]',
    unicode: true,
  );

  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  /// Normaliza um título ou nome de artista:
  /// 1. Converte para minúsculas;
  /// 2. Remove acentos/diacríticos;
  /// 3. Remove qualificadores de versão (remaster, live, etc.) mantendo termos narrativos (ex: Reprise, Intro);
  /// 4. Remove sufixos após ' - ' com qualificadores de versão;
  /// 5. Remove pontuação via regex Unicode;
  /// 6. Colapsa espaços em branco e aplica trim.
  static String normalize(String raw) {
    if (raw.isEmpty) return '';

    String text = raw.toLowerCase();

    // 1. Remover diacríticos
    final sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      sb.write(_diacriticsMap[char] ?? char);
    }
    text = sb.toString();

    // 2. Remover qualificadores entre parênteses/colchetes
    text = text.replaceAll(_qualifiersInBrackets, '');

    // 3. Remover sufixos após hífen
    text = text.replaceAll(_dashQualifiers, '');

    // 4. Remover pontuação preservando letras e números de qualquer alfabeto
    text = text.replaceAll(_punctuationRegex, ' ');

    // 5. Colapsar espaços
    return text.replaceAll(_whitespaceRegex, ' ').trim();
  }

  /// Calcula a distância de Levenshtein entre duas sequências.
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[s2.length];
  }

  /// Razão de similaridade [0.0..1.0] sobre strings normalizadas.
  static double similarity(String a, String b) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA == normB) return 1.0;
    final maxLen = max(normA.length, normB.length);
    if (maxLen == 0) return 1.0;
    final dist = levenshteinDistance(normA, normB);
    return max(0.0, 1.0 - (dist / maxLen));
  }

  /// Compara dois títulos:
  /// - True se normalizados forem iguais;
  /// - Ou se similaridade >= 0.88 E ambos possuírem ao menos 5 caracteres.
  /// Títulos curtos (< 5 caracteres) exigem igualdade exata.
  static bool isSameTitle(String a, String b) {
    final normA = normalize(a);
    final normB = normalize(b);
    if (normA == normB) return true;
    if (normA.length < 5 || normB.length < 5) return false;
    return similarity(normA, normB) >= 0.88;
  }

  /// Compara artistas, desconsiderando artigo "the " no início e suportando "feat/com".
  static bool isSameArtist(String a, String b) {
    var normA = normalize(a);
    var normB = normalize(b);
    if (normA == normB) return true;

    if (normA.startsWith('the ')) normA = normA.substring(4).trim();
    if (normB.startsWith('the ')) normB = normB.substring(4).trim();

    if (normA == normB) return true;
    if (normA.isEmpty || normB.isEmpty) return false;

    // Cobre "Artist feat. X" ou participações
    if (normA.contains(normB) || normB.contains(normA)) return true;

    return similarity(normA, normB) >= 0.85;
  }

  /// Compara se duas faixas representam a mesma gravação (título + artista).
  static bool isSameTrack(String titleA, String artistA, String titleB, String artistB) {
    return isSameTitle(titleA, titleB) && isSameArtist(artistA, artistB);
  }

  /// Localiza o índice da faixa na lista de [TrackEntry].
  /// Procura igualdade normalizada exata primeiro.
  /// Se não encontrar, procura a maior similaridade >= 0.88.
  /// Em caso de empate, escolhe a mais próxima de [expectedIndex].
  static int findIndex(List<TrackEntry> entries, String title, {int? expectedIndex}) {
    if (entries.isEmpty) return -1;
    final normTitle = normalize(title);
    if (normTitle.isEmpty) return -1;

    final exactMatches = <int>[];
    for (int i = 0; i < entries.length; i++) {
      if (normalize(entries[i].title) == normTitle) {
        exactMatches.add(i);
      }
    }

    if (exactMatches.length == 1) return exactMatches.first;
    if (exactMatches.length > 1) {
      if (expectedIndex != null) {
        exactMatches.sort((a, b) => (a - expectedIndex).abs().compareTo((b - expectedIndex).abs()));
      }
      return exactMatches.first;
    }

    // Busca por similaridade
    int bestIndex = -1;
    double bestScore = 0.0;

    for (int i = 0; i < entries.length; i++) {
      final normEntry = normalize(entries[i].title);
      if (normEntry.length < 5 && normTitle.length < 5) continue;

      final score = similarity(normEntry, normTitle);
      if (score >= 0.88) {
        if (score > bestScore) {
          bestScore = score;
          bestIndex = i;
        } else if ((score - bestScore).abs() < 0.001 && expectedIndex != null) {
          if ((i - expectedIndex).abs() < (bestIndex - expectedIndex).abs()) {
            bestIndex = i;
          }
        }
      }
    }

    return bestIndex;
  }

  /// Verifica se uma sequência de faixas tocadas [playedTitles] aparece na ordem
  /// correta (estritamente crescente e consecutiva/adjacente) dentro da [tracklist].
  ///
  /// Retorna `true` se todas as faixas forem encontradas e cada faixa subsequente
  /// aparecer após a anterior na tracklist (idx_next > idx_curr e diferença <= 2 para tolerar pulo de faixa).
  static bool isSequentialMatch(
    List<TrackEntry> tracklist,
    List<String> playedTitles, {
    int maxGap = 2,
  }) {
    if (playedTitles.isEmpty || tracklist.isEmpty) return false;
    if (playedTitles.length == 1) {
      return findIndex(tracklist, playedTitles.first) != -1;
    }

    int lastIdx = -1;
    for (int i = 0; i < playedTitles.length; i++) {
      final currentTitle = playedTitles[i];
      final expected = lastIdx >= 0 ? lastIdx + 1 : null;
      final idx = findIndex(tracklist, currentTitle, expectedIndex: expected);

      if (idx == -1) return false;

      if (lastIdx != -1) {
        // A ordem DEVE ser estritamente crescente
        if (idx <= lastIdx) return false;
        // Não permitir salto excessivo de faixas
        if (maxGap > 0 && (idx - lastIdx) > maxGap) return false;
      }
      lastIdx = idx;
    }
    return true;
  }

  /// Chave canônica para cache em memória: 'artista|titulo'
  static String key(String artist, String title) {
    return '${normalize(artist)}|${normalize(title)}';
  }
}
