import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/curiosities_service.dart';
import 'package:waxclub/services/plugins/plugin_catalog.dart';
import 'package:waxclub/ui/widgets/curiosities_view.dart';

const _rumours = 'Rumours is the eleventh studio album by British-American rock band Fleetwood Mac, released on 4 February 1977 by Warner Bros. Records. '
    'It was recorded in California in 1976 while the band members were going through breakups. '
    'The band was happy. '
    'The album spent 31 weeks at number one on the Billboard 200 and has sold over 40 million copies worldwide. '
    'It won the Grammy Award for Album of the Year in 1978.\n\n== Background ==\nSome text about something that is not very informative at all here.';

const _dreams = 'Dreams is a song by Fleetwood Mac, written by Stevie Nicks and released as a single in 1977. '
    'It became the band\'s only number one hit in the United States. It is short.';

void main() {
  test('escolhe frases curtas e informativas, na ordem do texto, começando pela definição', () {
    final facts = CuriositiesService.pickFacts(_rumours, max: 3);
    expect(facts.length, 3);
    expect(facts.first, startsWith('Rumours is the eleventh studio album'));
    expect(facts.any((f) => f.contains('40 million')), isTrue);
    expect(facts.any((f) => f.contains('The band was happy')), isFalse, reason: 'curta demais e sem informação');
    expect(facts.any((f) => f.contains('Background')), isFalse, reason: 'títulos de seção saem');
  });

  test('busca o artigo do disco e da faixa na Wikipedia e guarda no aparelho', () async {
    final dir = await Directory.systemTemp.createTemp('waxclub_curio_');
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      final q = req.url.queryParameters;
      if (q['list'] == 'search') {
        final isSong = q['srsearch']!.contains('song');
        return http.Response.bytes(utf8.encode(jsonEncode({
          'query': {
            'search': [
              isSong
                  ? {'title': 'Dreams (Fleetwood Mac song)', 'snippet': 'song by <b>Fleetwood Mac</b>'}
                  : {'title': 'Rumours (album)', 'snippet': 'album by Fleetwood Mac'}
            ]
          }
        })), 200);
      }
      final isSong = q['titles']!.contains('song');
      return http.Response.bytes(utf8.encode(jsonEncode({
        'query': {
          'pages': [
            {'extract': isSong ? _dreams : _rumours}
          ]
        }
      })), 200);
    });
    final service = CuriositiesService(client: client, directory: dir);
    final c = await service.forTrack(artist: 'Fleetwood Mac', album: 'Rumours', track: 'Dreams');
    expect(c.album, isNotEmpty);
    expect(c.album.first.source, 'Wikipedia');
    expect(c.album.first.url, contains('Rumours'));
    expect(c.track.first.text, contains('Stevie Nicks'));

    // segunda vez: vem do aparelho, sem rede
    final again = CuriositiesService(client: MockClient((_) async => throw Exception('offline')), directory: dir);
    final c2 = await again.forTrack(artist: 'Fleetwood Mac', album: 'Rumours', track: 'Dreams');
    expect(c2.album.length, c.album.length);
    expect(calls, 4);
    await dir.delete(recursive: true);
  });

  test('distribui as curiosidades ao longo da faixa; as do disco só no começo do lado', () {
    const c = RecordCuriosities(
      album: [Curiosity('Fato do disco 1', 'Wikipedia'), Curiosity('Fato do disco 2', 'Wikipedia')],
      track: [Curiosity('Fato da faixa', 'Wikipedia')],
    );
    final first = CuriositiesView.schedule(c, duration: 240, sideStart: true);
    expect(first.map((s) => s.aboutRecord), [true, true, false]);
    expect(first.first.start, 3.0);
    expect(first.last.start + first.last.length, lessThanOrEqualTo(240));

    final middle = CuriositiesView.schedule(c, duration: 240);
    expect(middle.map((s) => s.curiosity.text), ['Fato da faixa'], reason: 'no meio do lado, só as da faixa');

    final at = CuriositiesView.visibleAt(first, 4.0, duration: 240);
    expect(at!.$1.curiosity.text, 'Fato do disco 1');
    expect(CuriositiesView.visibleAt(first, 1.0, duration: 240), isNull, reason: 'espera antes da primeira');
  });

  test('embutido novo (Record curiosities) entra ligado, mas respeita se o usuário desligar', () async {
    final dir = await Directory.systemTemp.createTemp('waxclub_plugins_');
    // arquivo da 1.3.12 (sem seenBuiltIns): só English e Synced lyrics
    await File('${dir.path}${Platform.pathSeparator}waxclub_plugins.json')
        .writeAsString(jsonEncode({'version': 1, 'installed': [], 'active': ['lang.en', 'display.lyrics']}));
    final store = PluginStore(directory: dir);
    await store.load();
    final d2 = store.byCode('D2')!;
    expect(store.isActive(d2), isTrue, reason: 'novo embutido entra ligado');
    expect(store.canToggle(d2), isTrue);
    await store.toggle(d2); // usuário desliga

    final reopened = PluginStore(directory: dir);
    await reopened.load();
    expect(reopened.isActive(reopened.byCode('D2')!), isFalse, reason: 'a escolha do usuário é respeitada');
    expect(reopened.isActive(reopened.byCode('D1')!), isTrue);
    await dir.delete(recursive: true);
  });
}
