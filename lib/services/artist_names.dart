import 'tracklist_matcher.dart';

/// Outros nomes de um artista para a busca de letras. O mesmo artista aparece com nomes diferentes conforme o
/// país ou a fonte — "Suede" é "The London Suede" nos EUA, "The Charlatans" é "The Charlatans UK", "Bob
/// Marley & The Wailers" vira só "Bob Marley" — e aí o site de letras não acha a música. Só são tentados quando
/// o nome reconhecido não trouxe letra nenhuma.
class ArtistNames {
  ArtistNames._();

  /// Nomes regionais/alternativos conhecidos (nos dois sentidos), já normalizados.
  static const Map<String, List<String>> _aliases = {
    'the london suede': ['Suede'],
    'london suede': ['Suede'],
    'suede': ['The London Suede'],
    'the charlatans uk': ['The Charlatans'],
    'charlatans uk': ['The Charlatans'],
    'the charlatans': ['The Charlatans UK'],
    'the beat': ['The English Beat'],
    'the english beat': ['The Beat'],
    'english beat': ['The Beat'],
    'yazoo': ['Yaz'],
    'yaz': ['Yazoo'],
    'the verve': ['Verve'],
    'verve': ['The Verve'],
    'the jam': ['Jam'],
    'bush': ['Bush (UK)'],
    'the church': ['The Church (AU)'],
    'blink 182': ['blink-182'],
    'sigur ros': ['Sigur Rós'],
  };

  static final RegExp _feat = RegExp(r'\s+(feat\.?|ft\.?|featuring|with|x)\s+.+$', caseSensitive: false);
  static final RegExp _band = RegExp(r'\s+(&|and|e|y)\s+(the|his|her|os|as)\s+.+$', caseSensitive: false);

  /// Nomes alternativos de [artist], do mais provável ao menos (sem repetir o próprio nome). Vazio se não houver.
  static List<String> variants(String artist) {
    final original = artist.trim();
    if (original.isEmpty) return const [];
    final out = <String>[];
    void add(String v) {
      final t = v.trim();
      if (t.isEmpty) return;
      final n = TracklistMatcher.normalize(t);
      if (n == TracklistMatcher.normalize(original)) return;
      if (out.any((o) => TracklistMatcher.normalize(o) == n)) return;
      out.add(t);
    }

    final norm = TracklistMatcher.normalize(original);
    for (final a in _aliases[norm] ?? const <String>[]) {
      add(a);
    }
    // Participações: "Artista feat. Fulano" → "Artista"
    final noFeat = original.replaceFirst(_feat, '');
    add(noFeat);
    // "Bob Marley & The Wailers" → "Bob Marley" (só quando sobra um nome de duas palavras ou mais, para não
    // transformar "Echo & The Bunnymen" em "Echo")
    final noBand = noFeat.replaceFirst(_band, '');
    if (noBand != noFeat && noBand.trim().split(RegExp(r'\s+')).length >= 2) add(noBand);
    // Com e sem o artigo
    final lower = noFeat.toLowerCase();
    if (lower.startsWith('the ')) {
      add(noFeat.substring(4));
    } else if (!lower.contains(' ') || lower.split(' ').length <= 3) {
      if (out.isEmpty) add('The $noFeat');
    }
    for (final a in _aliases[TracklistMatcher.normalize(noFeat)] ?? const <String>[]) {
      add(a);
    }
    return out.take(3).toList();
  }
}
