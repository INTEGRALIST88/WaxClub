import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/album_catalog_service.dart';
import 'package:waxclub/services/discogs/discogs_auth_service.dart';
import 'package:waxclub/services/discogs/discogs_tracklist_provider.dart';
import 'package:waxclub/services/record_scan_parser.dart';

/// Bloc Party — Silent Alarm (2025, 20th Anniversary, 2×LP branco): https://www.discogs.com/release/35436508
const _silentAlarm = {
  'id': 35436508,
  'title': 'Silent Alarm',
  'year': 2025,
  'country': 'Europe',
  'master_id': 11458,
  'artists': [
    {'name': 'Bloc Party', 'anv': ''}
  ],
  'labels': [
    {'name': '[PIAS]', 'catno': 'PIASC0999DLP'}
  ],
  'formats': [
    {
      'name': 'Vinyl',
      'qty': '2',
      'descriptions': ['LP', 'Album', 'Limited Edition', 'Reissue', 'Stereo'],
      'text': 'White, 20th Anniversary Edition'
    }
  ],
  'identifiers': [
    {'type': 'Matrix / Runout', 'value': 'BP40527-01 A1 ST PIASC0999DLP'},
    {'type': 'Barcode', 'value': '5400863170370'},
  ],
  'images': [
    {'uri': 'https://i.discogs.com/silent-alarm.jpg'}
  ],
  'tracklist': [
    {'position': 'A1', 'title': 'Like Eating Glass', 'duration': '4:20'},
    {'position': 'A2', 'title': 'Helicopter', 'duration': '3:40'},
  ],
};

Map<String, dynamic> _searchResult() => {
      'results': [
        {
          'id': 35436508,
          'title': 'Bloc Party - Silent Alarm',
          'format': ['Vinyl', 'LP', 'Album', 'Limited Edition', 'Reissue', 'Stereo'],
          'year': '2025',
          'label': ['[PIAS]'],
          'catno': 'PIASC0999DLP',
          'barcode': ['5400863170370'],
        }
      ]
    };

Future<DiscogsAuthService> _connected() async {
  final store = MemoryDiscogsCredentialStore()
    ..values['discogs_credentials'] = jsonEncode({'personalToken': 'tok', 'username': 'tester'})
    ..values['discogs_enabled'] = 'true';
  final auth = DiscogsAuthService(store: store);
  await auth.load();
  return auth;
}

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

void main() {
  group('formas do código de barras e do nº de catálogo', () {
    test('código de barras: só dígitos, como impresso e UPC/EAN', () {
      expect(DiscogsTracklistProvider.barcodeVariants('5400863170370'),
          ['5400863170370', '5 400863 170370']);
      expect(DiscogsTracklistProvider.barcodeVariants('036000291452'),
          containsAll(['036000291452', '0036000291452', '0 36000 29145 2']));
    });

    test('nº de catálogo: como lido, sem separadores e com espaço entre letras e números', () {
      final v = DiscogsTracklistProvider.catalogNumberVariants('PIASC0999DLP');
      expect(v.first, 'PIASC0999DLP');
      expect(v, contains('PIASC 0999 DLP'));
      expect(DiscogsTracklistProvider.catalogNumberVariants('shvl-804'), containsAll(['SHVL-804', 'SHVL804', 'SHVL 804']));
    });

    test('link do Discogs ou código [r...] viram o número da prensagem', () {
      expect(DiscogsTracklistProvider.releaseIdFrom('https://www.discogs.com/release/35436508-Bloc-Party-Silent-Alarm'),
          '35436508');
      expect(DiscogsTracklistProvider.releaseIdFrom('https://www.discogs.com/pt_BR/release/35436508'), '35436508');
      expect(DiscogsTracklistProvider.releaseIdFrom('[r35436508]'), '35436508');
      expect(DiscogsTracklistProvider.releaseIdFrom('Bloc Party Silent Alarm'), isNull);
    });
  });

  test('foto da contracapa: acha o código de barras escrito junto do nº de catálogo', () {
    const text = '®&©2025 Bloc Party under exclusive licence\nPIASC0999DLP / 5400863170370.\nwww.pias.com';
    expect(RecordScanParser.barcodesIn(text), ['5400863170370']);
    expect(RecordScanParser.barcodesIn('5 400863 170370'), ['5400863170370']);
    expect(RecordScanParser.catalogNumberCandidates(text), contains('PIASC0999DLP'));
  });

  test('prensagem completa (/releases/{id}) vira candidato com gravadora, catálogo, código e capa', () {
    final c = DiscogsTracklistProvider.parseRelease(_silentAlarm)!;
    expect(c.albumTitle, 'Silent Alarm');
    expect(c.artistName, 'Bloc Party');
    expect(c.year, '2025');
    expect(c.label, '[PIAS]');
    expect(c.catalogNumber, 'PIASC0999DLP');
    expect(c.barcode, '5400863170370');
    expect(c.coverUrl, 'https://i.discogs.com/silent-alarm.jpg');
    expect(c.isVinylLpOrEp, isTrue);
    expect(c.trackCount, 2);
  });

  test('código de barras sem resultado no campo exato: tenta como impresso e depois o texto livre', () async {
    final asked = <Map<String, String>>[];
    final client = MockClient((req) async {
      asked.add(req.url.queryParameters);
      return _json(req.url.queryParameters['q'] == '5400863170370' ? _searchResult() : {'results': []});
    });
    final auth = await _connected();
    final catalog = AlbumCatalogService(auth: auth, discogs: DiscogsTracklistProvider(auth: auth, client: client));
    final r = await catalog.byBarcode('5400863170370');
    expect(asked.map((q) => q['barcode'] ?? 'q:${q['q']}'), ['5400863170370', '5 400863 170370', 'q:5400863170370']);
    expect(r.source, 'discogs');
    expect(r.albums.single.releaseId, '35436508');
  });

  test('nº de catálogo: tenta as formas com vinil, depois sem o filtro de formato', () async {
    final asked = <String>[];
    final client = MockClient((req) async {
      final q = req.url.queryParameters;
      asked.add('${q['catno']}|${q['format'] ?? '-'}');
      return _json(q['format'] == null && q['catno'] == 'PIASC0999DLP' ? _searchResult() : {'results': []});
    });
    final auth = await _connected();
    final catalog = AlbumCatalogService(auth: auth, discogs: DiscogsTracklistProvider(auth: auth, client: client));
    final r = await catalog.byCatalogNumber('PIASC0999DLP');
    expect(asked.first, 'PIASC0999DLP|Vinyl');
    expect(asked.last, 'PIASC0999DLP|-');
    expect(r.albums.single.catalogNumber, 'PIASC0999DLP');
  });

  test('código de barras digitado no campo do nº de catálogo é buscado como código de barras', () async {
    final asked = <String?>[];
    final client = MockClient((req) async {
      asked.add(req.url.queryParameters['barcode']);
      return _json(_searchResult());
    });
    final auth = await _connected();
    final catalog = AlbumCatalogService(auth: auth, discogs: DiscogsTracklistProvider(auth: auth, client: client));
    final r = await catalog.byCatalogNumber('5400863170370');
    expect(asked, ['5400863170370']);
    expect(r.albums.single.releaseId, '35436508');
  });

  test('link do Discogs colado vai direto à prensagem, mesmo sem a conta conectada', () async {
    final paths = <String>[];
    final client = MockClient((req) async {
      paths.add(req.url.path);
      return _json(_silentAlarm);
    });
    final auth = DiscogsAuthService(store: MemoryDiscogsCredentialStore());
    final catalog = AlbumCatalogService(auth: auth, discogs: DiscogsTracklistProvider(auth: auth, client: client));
    final r = await catalog.search('https://www.discogs.com/release/35436508-Bloc-Party-Silent-Alarm');
    expect(paths, ['/releases/35436508']);
    expect(r.source, 'discogs');
    expect(r.albums.single.albumTitle, 'Silent Alarm');
    final tracks = await DiscogsTracklistProvider(auth: auth, client: client).loadTracklist(r.albums.single);
    expect(tracks.map((t) => t.number), ['A1', 'A2'], reason: 'faixas também sem a conta conectada');
  });
}
