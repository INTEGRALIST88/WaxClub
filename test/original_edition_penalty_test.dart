import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/tracklist_provider.dart';

List<TrackEntry> _list(List<String> titles) => [
      for (var i = 0; i < titles.length; i++) TrackEntry(position: i + 1, title: titles[i]),
    ];

void main() {
  final lp = _list([
    'No Reply', "I'm a Loser", "Baby's in Black", 'Rock and Roll Music', "I'll Follow the Sun",
    'Mr. Moonlight', 'Kansas City/Hey, Hey, Hey, Hey', 'Eight Days a Week', 'Words of Love',
    "Honey Don't", 'Every Little Thing', "I Don't Want to Spoil the Party", 'What You\'re Doing',
    "Everybody's Trying to Be My Baby",
  ]);
  final deluxe = _list([
    'No Reply (studio Chat + New remix)',
    "I'm a Loser (studio Chat + New remix)",
    'Rock and Roll (Backing Track)',
    "I'll Follow the Sun (No Read Guitar remix)",
    'I Feel Fine (Naked vocal)',
    "She's a Woman (extended intro + take 4)",
    'I Feel Fine (UK Test Pressing)',
    ...lp.map((e) => e.title),
    'Extra 1', 'Extra 2', 'Extra 3', 'Extra 4', 'Extra 5',
  ]);

  test('o LP original não tem faixas de edição especial', () {
    expect(bonusVersionCount(lp), 0);
    expect(originalEditionPenalty(lp), 0);
  });

  test('remixes, backing tracks, vocais isolados, takes e test pressings contam como bônus', () {
    expect(bonusVersionCount(deluxe), 7);
  });

  test('a edição deluxe perde para o LP original', () {
    expect(originalEditionPenalty(deluxe), greaterThan(originalEditionPenalty(lp)));
  });

  test('busca no catálogo ignora anotações de edição entre parênteses', () {
    expect(catalogSearchName("Baby's in Black (studio Chat + New remix)"), "Baby's in Black");
    expect(catalogSearchName('Beatles For Sale (Remastered)'), 'Beatles For Sale');
    expect(catalogSearchName('Help! - 2009 Remaster'), 'Help!');
    expect(catalogSearchName('Abbey Road [Super Deluxe]'), 'Abbey Road');
    expect(catalogSearchName('Ob-La-Di, Ob-La-Da'), 'Ob-La-Di, Ob-La-Da');
    expect(catalogSearchName('(What\'s the Story)'), '(What\'s the Story)'); // só parênteses: mantém
  });

  test('títulos normais com hífen ou barra não são confundidos com bônus', () {
    expect(bonusVersionCount(_list(['Ob-La-Di, Ob-La-Da', 'Kansas City/Hey, Hey, Hey, Hey', 'Mixed Emotions'])), 0);
  });
}
