import 'collection_service.dart';
import 'tracklist_matcher.dart';

/// Como a lista de My Collection é organizada.
enum CollectionGrouping {
  /// Lista simples na ordem escolhida no menu (tocados, adicionados...).
  none,

  /// Divisor com o nome de cada artista/banda (A→Z) e os discos dele embaixo, em ordem alfabética.
  artist,

  /// Discos de A a Z, com divisores pela letra inicial.
  album,
}

/// Uma linha da lista agrupada: divisor ([header]) ou disco ([item]); [letter] = letra do abecedário.
class CollectionRow {
  final String? header;
  final CollectionItem? item;
  final String letter;

  /// Ordem do disco na lista (para a sequência do brilho do ⓘ).
  final int itemIndex;

  const CollectionRow.header(this.header, this.letter)
      : item = null,
        itemIndex = -1;
  const CollectionRow.item(this.item, this.letter, this.itemIndex) : header = null;

  bool get isHeader => header != null;
}

/// Ordem "de loja de discos": sem acentos, sem maiúsculas e sem o artigo do começo
/// ("The Beatles" → B, "Os Mutantes" → M, "Água de Beber" → A).
class CollectionGrouper {
  CollectionGrouper._();

  static const List<String> alphabet = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#',
  ];

  static final RegExp _article = RegExp(r'^(the|a|an|os|as|o|los|las|el|la|le|les|die|der|das|il|lo|gli)\s+(?=\S)');

  static String sortKey(String name) {
    var k = TracklistMatcher.normalize(name);
    if (k.isEmpty) k = name.toLowerCase().trim();
    final stripped = k.replaceFirst(_article, '');
    return stripped.isEmpty ? k : stripped;
  }

  static String letterFor(String name) {
    final k = sortKey(name);
    if (k.isEmpty) return '#';
    final c = k[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(c) ? c : '#';
  }

  static int _letterRank(String letter) => letter == '#' ? 99 : letter.codeUnitAt(0);

  static int _compareKeys(String a, String b) {
    final la = letterFor(a), lb = letterFor(b);
    final r = _letterRank(la).compareTo(_letterRank(lb));
    return r != 0 ? r : sortKey(a).compareTo(sortKey(b));
  }

  static int _year(CollectionItem i) => int.tryParse((i.year ?? '').replaceAll(RegExp(r'\D'), '').padRight(4, '9').substring(0, 4)) ?? 9999;

  static List<CollectionRow> build(List<CollectionItem> items, CollectionGrouping grouping) {
    final rows = <CollectionRow>[];
    var n = 0;
    switch (grouping) {
      case CollectionGrouping.none:
        for (final i in items) {
          rows.add(CollectionRow.item(i, letterFor(i.album), n++));
        }
      case CollectionGrouping.artist:
        // Artistas agrupados sem diferenciar maiúsculas/acentos; o nome mostrado é o do 1º disco
        final byArtist = <String, List<CollectionItem>>{};
        final display = <String, String>{};
        for (final i in items) {
          final key = TracklistMatcher.normalize(i.artist).isEmpty ? i.artist.toLowerCase() : TracklistMatcher.normalize(i.artist);
          byArtist.putIfAbsent(key, () => []).add(i);
          display.putIfAbsent(key, () => i.artist);
        }
        final artists = byArtist.keys.toList()..sort((a, b) => _compareKeys(display[a]!, display[b]!));
        for (final a in artists) {
          final name = display[a]!;
          final letter = letterFor(name);
          rows.add(CollectionRow.header(name, letter));
          // Discos do artista em ordem alfabética (mesmo título: o mais antigo primeiro)
          final albums = byArtist[a]!
            ..sort((x, y) {
              final r = _compareKeys(x.album, y.album);
              return r != 0 ? r : _year(x).compareTo(_year(y));
            });
          for (final i in albums) {
            rows.add(CollectionRow.item(i, letter, n++));
          }
        }
      case CollectionGrouping.album:
        final sorted = List<CollectionItem>.from(items)..sort((x, y) => _compareKeys(x.album, y.album));
        String? current;
        for (final i in sorted) {
          final letter = letterFor(i.album);
          if (letter != current) {
            rows.add(CollectionRow.header(letter, letter));
            current = letter;
          }
          rows.add(CollectionRow.item(i, letter, n++));
        }
    }
    return rows;
  }
}
