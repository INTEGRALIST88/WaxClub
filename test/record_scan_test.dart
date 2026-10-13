import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/album_catalog_service.dart';
import 'package:waxclub/services/collection_service.dart';
import 'package:waxclub/services/discogs/discogs_auth_service.dart';
import 'package:waxclub/services/discogs/discogs_tracklist_provider.dart';
import 'package:waxclub/services/musicbrainz_tracklist_provider.dart';
import 'package:waxclub/services/record_scan_parser.dart';
import 'package:waxclub/services/tracklist_provider.dart';
import 'package:waxclub/ui/screens/record_found_flow.dart';

void main() {
  group('código de barras', () {
    test('aceita EAN-13 e UPC-A com dígito verificador certo', () {
      expect(RecordScanParser.isValidBarcode('4006381333931'), isTrue);
      expect(RecordScanParser.isValidBarcode('036000291452'), isTrue);
      expect(RecordScanParser.isValidBarcode('0 36000 29145 2'), isTrue, reason: 'espaços impressos sob as barras');
    });

    test('recusa dígito verificador errado e tamanhos que não são de disco', () {
      expect(RecordScanParser.isValidBarcode('4006381333932'), isFalse);
      expect(RecordScanParser.isValidBarcode('12345'), isFalse);
    });
  });

  group('número de catálogo lido da foto', () {
    test('acha os números de catálogo e ignora ano, duração e rotação', () {
      const text = 'STEREO\nPINK FLOYD\nSHVL 804\n33 RPM\n1973\n6349 123\nSIDE A 3:45\n4006381333931';
      final found = RecordScanParser.catalogNumberCandidates(text);
      expect(found, containsAll(['SHVL 804', '6349 123']));
      expect(found, isNot(contains('1973')));
      expect(found.any((c) => c.contains('3:45') || c.contains('345')), isFalse);
      expect(found, isNot(contains('4006381333931')), reason: 'é o código de barras');
    });

    test('formatos com hífen e letras', () {
      expect(RecordScanParser.catalogNumberCandidates('MOFI 1-034\nLPGW-4'), containsAll(['MOFI 1-034', 'LPGW-4']));
    });
  });

  test('Discogs: busca por código de barras lê gravadora, nº de catálogo e código', () async {
    final auth = DiscogsAuthService(store: MemoryDiscogsCredentialStore());
    final results = DiscogsTracklistProvider.parseSearchResults({
      'results': [
        {
          'id': 123,
          'title': 'Pink Floyd - The Dark Side Of The Moon',
          'format': ['Vinyl', 'LP', 'Album'],
          'year': '1973',
          'country': 'UK',
          'label': ['Harvest', 'EMI'],
          'catno': 'SHVL 804',
          'barcode': ['5099902987613'],
        }
      ]
    });
    expect(results.single.label, 'Harvest');
    expect(results.single.catalogNumber, 'SHVL 804');
    expect(results.single.barcode, '5099902987613');
    expect(results.single.isVinylLpOrEp, isTrue);
    auth.dispose();
  });

  test('sem Discogs conectado, a busca por código de barras usa o MusicBrainz e só mostra vinil', () async {
    String? query;
    final client = MockClient((req) async {
      query = req.url.queryParameters['query'];
      return http.Response.bytes(utf8.encode(jsonEncode({
        'releases': [
          {
            'id': 'mb-lp',
            'title': 'Clube da Esquina',
            'date': '1972',
            'country': 'BR',
            'barcode': '7891234567895',
            'artist-credit': [
              {'name': 'Milton Nascimento & Lô Borges'}
            ],
            'media': [
              {'format': '12" Vinyl'}
            ],
            'release-group': {'id': 'g1', 'primary-type': 'Album'},
            'label-info': [
              {'catalog-number': 'SMOFB 3721', 'label': {'name': 'EMI-Odeon'}}
            ],
          },
          {
            'id': 'mb-cd',
            'title': 'Clube da Esquina',
            'date': '1995',
            'media': [
              {'format': 'CD'}
            ],
            'release-group': {'id': 'g1', 'primary-type': 'Album'},
          },
        ]
      })), 200);
    });
    final auth = DiscogsAuthService(store: MemoryDiscogsCredentialStore());
    final catalog = AlbumCatalogService(auth: auth, musicBrainz: MusicBrainzTracklistProvider(client: client));
    final r = await catalog.byBarcode('7891234567895');
    expect(query, 'barcode:7891234567895');
    expect(r.source, 'musicbrainz');
    expect(r.albums.map((a) => a.releaseId), ['mb-lp']);
    expect(r.albums.single.catalogNumber, 'SMOFB 3721');
    expect(r.albums.single.label, 'EMI-Odeon');
    expect(RecordSummary.detailsOf(r.albums.single), '1972 · BR · EMI-Odeon · SMOFB 3721');
  });

  test('item da coleção guarda gravadora, nº de catálogo, código de barras e estado', () {
    final item = CollectionItem(
      album: 'Clube da Esquina',
      artist: 'Milton Nascimento',
      addedAt: DateTime(2026, 10, 13),
      musicBrainzReleaseId: 'mb-lp',
      label: 'EMI-Odeon',
      catalogNumber: 'SMOFB 3721',
      barcode: '7891234567895',
      rating: 5,
      mediaCondition: 'Very Good Plus (VG+)',
    );
    final back = CollectionItem.fromJson(jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>);
    expect(back.label, 'EMI-Odeon');
    expect(back.catalogNumber, 'SMOFB 3721');
    expect(back.barcode, '7891234567895');
    expect(back.musicBrainzReleaseId, 'mb-lp');
    expect(back.rating, 5);
    expect(back.mediaCondition, 'Very Good Plus (VG+)');
  });

  testWidgets('cadastro: nota, estado e observações vão para o item da coleção', (tester) async {
    const release = ReleaseCandidate(
      providerId: 'discogs',
      releaseId: '123',
      albumTitle: 'The Dark Side Of The Moon',
      artistName: 'Pink Floyd',
      year: '1973',
      label: 'Harvest',
      catalogNumber: 'SHVL 804',
      format: 'Vinyl, LP, Album',
    );
    Object? popped;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Object>(
                MaterialPageRoute(builder: (_) => const CollectionEntryScreen(release: release, offerDiscogs: true)),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SHVL 804'), findsOneWidget, reason: 'dados da prensagem no resumo');
    await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3)); // 4 estrelas
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Primeira prensagem');
    await tester.scrollUntilVisible(find.text('Save'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final result = popped as CollectionEntryResult;
    expect(result.item.rating, 4);
    expect(result.item.notes, 'Primeira prensagem');
    expect(result.item.discogsReleaseId, '123');
    expect(result.item.catalogNumber, 'SHVL 804');
    expect(result.alsoDiscogs, isTrue, reason: 'marcado por padrão quando o Discogs está conectado');
  });
}
