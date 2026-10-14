/// Idioma em que o artista canta ou fala, pelo texto do disco (títulos das faixas, nome do disco e,
/// quando houver, a letra). Código ISO 639-1 ("en", "pt", "es"...); inglês quando não dá para saber.
/// Usado para buscar as curiosidades na Wikipedia daquele idioma.
class LanguageDetector {
  LanguageDetector._();

  /// Palavras muito comuns e curtas de cada idioma (artigos, preposições, pronomes).
  static const Map<String, List<String>> _stopwords = {
    'en': ['the', 'and', 'you', 'love', 'of', 'in', 'my', 'me', 'to', 'it', 'is', 'on', 'your', 'for', 'with', 'baby', 'night', 'heart', 'i', 'don\'t', 'can\'t', 'all'],
    'pt': ['o', 'a', 'os', 'as', 'de', 'do', 'da', 'dos', 'das', 'que', 'não', 'eu', 'você', 'meu', 'minha', 'amor', 'em', 'no', 'na', 'um', 'uma', 'é', 'pra', 'coração', 'samba', 'tu', 'te', 'mais', 'sem', 'com'],
    'es': ['el', 'la', 'los', 'las', 'de', 'que', 'y', 'en', 'no', 'mi', 'tu', 'te', 'yo', 'amor', 'corazón', 'un', 'una', 'es', 'por', 'para', 'con', 'del', 'como', 'más', 'quiero'],
    'fr': ['le', 'la', 'les', 'de', 'des', 'du', 'et', 'je', 'tu', 'un', 'une', 'est', 'pas', 'que', 'qui', 'mon', 'ma', 'mes', 'amour', 'dans', 'pour', 'avec', 'toi', 'moi', 'c\'est'],
    'it': ['il', 'la', 'le', 'di', 'che', 'e', 'non', 'un', 'una', 'per', 'con', 'mi', 'ti', 'io', 'tu', 'amore', 'cuore', 'del', 'della', 'nel', 'sono', 'come', 'più'],
    'de': ['der', 'die', 'das', 'und', 'ich', 'du', 'nicht', 'ein', 'eine', 'ist', 'mit', 'mein', 'dich', 'mich', 'liebe', 'zu', 'auf', 'den', 'dem', 'im', 'wir', 'sie'],
  };

  /// Letras e sinais típicos (pesam a favor do idioma).
  static final Map<String, RegExp> _marks = {
    'pt': RegExp(r'[ãõç]|ção|ções|lh|nh'),
    'es': RegExp(r'[ñ¿¡]|ción'),
    'fr': RegExp(r"[èêëàâîôûœ]|qu'|l'|d'"),
    'it': RegExp(r'[àèìòù]\b|zione|gli'),
    'de': RegExp(r'[äöüß]|sch'),
  };

  static String detect(String text) {
    final t = text.toLowerCase();
    if (t.trim().isEmpty) return 'en';

    // Escritas próprias: decide pela escrita
    int count(RegExp r) => r.allMatches(t).length;
    final letters = count(RegExp(r'\p{L}', unicode: true));
    if (letters == 0) return 'en';
    final scripts = <String, int>{
      'ja': count(RegExp(r'[぀-ヿ]')), // hiragana/katakana
      'ko': count(RegExp(r'[가-힯]')),
      'zh': count(RegExp(r'[一-鿿]')),
      'ru': count(RegExp(r'[Ѐ-ӿ]')),
      'el': count(RegExp(r'[Ͱ-Ͽ]')),
      'ar': count(RegExp(r'[؀-ۿ]')),
      'he': count(RegExp(r'[֐-׿]')),
    };
    if (scripts['ja']! > 0 && (scripts['ja']! + scripts['zh']!) / letters > 0.2) return 'ja';
    for (final e in scripts.entries) {
      if (e.key != 'ja' && e.value / letters > 0.3) return e.key;
    }

    // Línguas latinas: palavras comuns + letras típicas
    final words = RegExp(r"[\p{L}']+", unicode: true).allMatches(t).map((m) => m.group(0)!).toList();
    final scores = <String, double>{};
    for (final lang in _stopwords.keys) {
      final set = _stopwords[lang]!.toSet();
      var s = words.where(set.contains).length.toDouble();
      final mark = _marks[lang];
      if (mark != null) s += mark.allMatches(t).length * 0.7;
      scores[lang] = s;
    }
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    // Pouca evidência: fica no inglês (ex.: títulos curtos com nomes próprios)
    if (best.value < 1.5) return 'en';
    final en = scores['en'] ?? 0;
    if (best.key != 'en' && best.value < en * 1.2) return 'en';
    return best.key;
  }
}
