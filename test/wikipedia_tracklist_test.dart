import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/wikipedia_tracklist_service.dart';

const _wikitext = '''
{{Infobox album
| name = Abbey Road
| artist = [[The Beatles]]
}}
==Track listing==
{{Track listing
| headline = Side one
| title1 = [[Come Together]]
| writer1 = Lennon–McCartney
| length1 = 4:20
| title2 = [[Something (Beatles song)|Something]]<ref>nota</ref>
| length2 = 3:03
}}
{{Track listing
| headline = Side two
| title1 = "Here Comes the Sun"
| length1 = 3:05
| title2 = The End {{small|(medley)}}
| length2 = 2:05
}}
''';

TrackEntry _e(int p, String t, [int? ms]) => TrackEntry(position: p, title: t, lengthMs: ms);

void main() {
  test('lê os modelos {{Track listing}} com links, referências e aspas', () {
    final list = WikipediaTracklistService.parseWikitext(_wikitext);
    expect(list.map((e) => e.title), ['Come Together', 'Something', 'Here Comes the Sun', 'The End']);
    expect(list.map((e) => e.lengthMs), [260000, 183000, 185000, 125000]);
  });

  test('sem modelo, lê lista numerada "# Título – 3:45"', () {
    final list = WikipediaTracklistService.parseWikitext('# "Aquarela do Brasil" – 4:10\n# Garota de Ipanema - 5:22\n');
    expect(list.map((e) => e.title), ['Aquarela do Brasil', 'Garota de Ipanema']);
    expect(list.map((e) => e.lengthMs), [250000, 322000]);
  });

  test('completa só as durações que faltam quando o disco é vinil', () {
    final wiki = WikipediaTracklistService.parseWikitext(_wikitext);
    final merged = WikipediaTracklistService.mergeDurations(
      [_e(1, 'Come Together', 259000), _e(2, 'Something')],
      wiki,
    );
    expect(merged.map((e) => e.lengthMs), [259000, 183000], reason: 'a duração do disco (Discogs/MusicBrainz) tem prioridade');
  });

  test('disco que não é vinil: a minutagem do LP substitui, se o artigo casar com metade das faixas', () {
    final wiki = WikipediaTracklistService.parseWikitext(_wikitext);
    final merged = WikipediaTracklistService.mergeDurations(
      [_e(1, 'Come Together', 255000), _e(2, 'Something', 180000)],
      wiki,
      override: true,
    );
    expect(merged.map((e) => e.lengthMs), [260000, 183000]);

    final wrongArticle = WikipediaTracklistService.mergeDurations(
      [_e(1, 'Come Together', 255000), _e(2, 'Outra', 1000), _e(3, 'Mais Outra', 1000)],
      wiki,
      override: true,
    );
    expect(wrongArticle.first.lengthMs, 255000, reason: 'artigo casa com menos da metade: não substitui');
  });

  test('busca o artigo do álbum, confere o artista e completa as durações', () async {
    final client = MockClient((req) async {
      final q = req.url.queryParameters;
      if (q['list'] == 'search') {
        return http.Response(jsonEncode({
          'query': {
            'search': [
              {'title': 'Abbey Road Studios'},
              {'title': 'Abbey Road'},
            ]
          }
        }), 200);
      }
      if (q['action'] == 'parse') {
        return http.Response.bytes(utf8.encode(jsonEncode({
          'parse': {'wikitext': _wikitext}
        })), 200);
      }
      return http.Response('', 404);
    });
    final service = WikipediaTracklistService(client: client);
    final filled = await service.fillDurations(
      [_e(1, 'Come Together'), _e(2, 'Something')],
      artist: 'The Beatles (2)',
      album: 'Abbey Road',
    );
    expect(filled.map((e) => e.lengthMs), [260000, 183000]);
  });

  test('sem rede ou sem artigo devolve as faixas como estão', () async {
    final service = WikipediaTracklistService(client: MockClient((_) async => throw Exception('offline')));
    final entries = [_e(1, 'Come Together')];
    expect(await service.fillDurations(entries, artist: 'X', album: 'Y'), same(entries));
  });
}
