import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/artist_names.dart';
import 'package:waxclub/services/lrclib_service.dart';

void main() {
  test('outros nomes do artista: regionais, sem participação, sem a banda, com/sem "The"', () {
    expect(ArtistNames.variants('The London Suede'), contains('Suede'));
    expect(ArtistNames.variants('Suede'), contains('The London Suede'));
    expect(ArtistNames.variants('The Charlatans UK'), contains('The Charlatans'));
    expect(ArtistNames.variants('Bob Marley & The Wailers'), contains('Bob Marley'));
    expect(ArtistNames.variants('Echo & The Bunnymen'), isNot(contains('Echo')), reason: 'não vira só "Echo"');
    expect(ArtistNames.variants('Daft Punk feat. Pharrell Williams'), contains('Daft Punk'));
    expect(ArtistNames.variants('The Verve'), contains('Verve'));
    expect(ArtistNames.variants('Radiohead').length, lessThanOrEqualTo(3));
  });

  test('LRCLIB: música guardada com outro nome do artista é achada pela busca só do título (mesma duração)', () async {
    final asked = <Uri>[];
    final client = MockClient((req) async {
      asked.add(req.url);
      if (req.url.path.endsWith('/get')) return http.Response('{}', 404);
      if (req.url.queryParameters.containsKey('artist_name')) return http.Response('[]', 200);
      return http.Response.bytes(
          utf8.encode(jsonEncode([
            {'trackName': 'Animal Nitrate', 'artistName': 'Suede', 'duration': 206.0, 'syncedLyrics': '[00:10.00] la la\n[03:20.00] end'},
            {'trackName': 'Animal Nitrate', 'artistName': 'Suede', 'duration': 330.0, 'syncedLyrics': '[00:10.00] live\n[05:20.00] end'},
          ])),
          200);
    });
    final r = await LrcLibService(client: client)
        .fetchLyricsDetails(trackName: 'Animal Nitrate', artistName: 'The London Suede', durationSeconds: 207);
    expect(r?.syncedLyrics, contains('la la'), reason: 'a versão de estúdio (duração parecida), não a ao vivo');
    expect(asked.any((u) => u.path.endsWith('/search') && !u.queryParameters.containsKey('artist_name')), isTrue);
  });
}
