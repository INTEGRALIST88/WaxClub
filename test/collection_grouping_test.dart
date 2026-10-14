import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/services/collection_grouping.dart';
import 'package:waxclub/services/collection_service.dart';

CollectionItem _disc(String album, String artist, [String? year]) =>
    CollectionItem(album: album, artist: artist, year: year, addedAt: DateTime(2026));

void main() {
  final items = [
    _disc('Revolver', 'The Beatles', '1966'),
    _disc('Abbey Road', 'The Beatles', '1969'),
    _disc('A Divina Comédia ou Ando Meio Desligado', 'Os Mutantes', '1970'),
    _disc('Água de Beber', 'Astrud Gilberto', '1965'),
    _disc('AM', 'Arctic Monkeys', '2013'),
    _disc('Favourite Worst Nightmare', 'Arctic Monkeys', '2007'),
    _disc('1999', 'Prince', '1982'),
  ];

  test('ordem de loja de discos: sem artigo, sem acento; números em #', () {
    expect(CollectionGrouper.letterFor('The Beatles'), 'B');
    expect(CollectionGrouper.letterFor('Os Mutantes'), 'M');
    expect(CollectionGrouper.letterFor('Água de Beber'), 'A');
    expect(CollectionGrouper.letterFor('1999'), '#');
    expect(CollectionGrouper.letterFor('A'), 'A', reason: 'nome que é só o artigo fica como está');
  });

  test('por artista: divisor com o nome do artista (A→Z) e os discos dele do mais antigo ao mais novo', () {
    final rows = CollectionGrouper.build(items, CollectionGrouping.artist);
    final headers = rows.where((r) => r.isHeader).map((r) => r.header).toList();
    expect(headers, ['Arctic Monkeys', 'Astrud Gilberto', 'The Beatles', 'Os Mutantes', 'Prince']);
    final arctic = rows.skip(1).take(2).map((r) => r.item!.album).toList();
    expect(arctic, ['Favourite Worst Nightmare', 'AM'], reason: '2007 antes de 2013');
    final beatles = rows.indexWhere((r) => r.header == 'The Beatles');
    expect(rows[beatles + 1].item!.album, 'Revolver');
    expect(rows[beatles].letter, 'B');
  });

  test('por disco: lista corrida com divisores pela letra inicial; # no fim', () {
    final rows = CollectionGrouper.build(items, CollectionGrouping.album);
    final headers = rows.where((r) => r.isHeader).map((r) => r.header).toList();
    expect(headers, ['A', 'D', 'F', 'R', '#']);
    final aDiscs = rows.skip(1).takeWhile((r) => !r.isHeader).map((r) => r.item!.album).toList();
    expect(aDiscs, ['Abbey Road', 'Água de Beber', 'AM']);
    expect(rows.where((r) => !r.isHeader).map((r) => r.itemIndex).toList(), [0, 1, 2, 3, 4, 5, 6],
        reason: 'ordem dos discos para o brilho em sequência');
  });
}
