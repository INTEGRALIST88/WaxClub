import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:waxclub/services/collection_service.dart';
import 'package:waxclub/services/discogs/discogs_auth_service.dart';
import 'package:waxclub/services/discogs/discogs_collection_service.dart';

Map<String, dynamic> _release(int id, String title, List<Map<String, dynamic>> artists, {int rating = 0, List<Map<String, dynamic>> notes = const []}) => {
      'id': id,
      'rating': rating,
      'date_added': '2024-03-01T10:00:00-08:00',
      'notes': notes,
      'basic_information': {
        'id': id,
        'title': title,
        'year': 1965,
        'cover_image': 'https://i.discogs.com/$id.jpg',
        'formats': [
          {'name': 'Vinyl', 'qty': '1', 'descriptions': ['LP', 'Album']}
        ],
        'labels': [
          {'name': 'Parlophone (2)', 'catno': 'PMC 1240'}
        ],
        'artists': artists,
      },
    };

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('waxclub_discogs_import_'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  Future<DiscogsAuthService> auth(http.Client client) async {
    final store = MemoryDiscogsCredentialStore()
      ..values['discogs_credentials'] = jsonEncode(const DiscogsCredentials(personalToken: 'token-x', username: 'collector').toJson())
      ..values['discogs_enabled'] = 'true';
    final a = DiscogsAuthService(store: store, client: client);
    await a.load();
    return a;
  }

  test('lê a coleção inteira (todas as páginas) e converte cada disco', () async {
    final pages = <int>[];
    final client = MockClient((req) async {
      expect(req.method, 'GET', reason: 'importar só lê o Discogs');
      expect(req.url.path, '/users/collector/collection/folders/0/releases');
      final page = int.parse(req.url.queryParameters['page']!);
      pages.add(page);
      final releases = page == 1
          ? [
              _release(1, 'Beatles For Sale', [
                {'name': 'The Beatles', 'anv': '', 'join': ''}
              ], rating: 5, notes: [
                {'field_id': 1, 'value': 'Very Good Plus (VG+)'},
                {'field_id': 2, 'value': 'Good (G)'},
              ]),
            ]
          : [
              _release(2, 'Bridge Over Troubled Water', [
                {'name': 'Simon', 'anv': '', 'join': '&'},
                {'name': 'Garfunkel (2)', 'anv': '', 'join': ''},
              ]),
            ];
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'pagination': {'page': page, 'pages': 2, 'items': 2},
            'releases': releases,
          })),
          200);
    });
    final svc = DiscogsCollectionService(auth: await auth(client), client: client);
    final items = (await svc.fetchCollection())!;
    expect(pages, [1, 2]);
    expect(items.map((i) => i.album), ['Beatles For Sale', 'Bridge Over Troubled Water']);
    final first = items.first;
    expect(first.artist, 'The Beatles');
    expect(first.discogsReleaseId, '1');
    expect(first.year, '1965');
    expect(first.format, 'Vinyl, LP, Album');
    expect(first.label, 'Parlophone');
    expect(first.catalogNumber, 'PMC 1240');
    expect(first.rating, 5);
    expect(first.mediaCondition, 'Very Good Plus (VG+)');
    expect(first.sleeveCondition, 'Good (G)');
    expect(items.last.artist, 'Simon & Garfunkel');
  });

  test('sem conta: não lê nada', () async {
    final client = MockClient((_) async => fail('não deveria chamar o Discogs'));
    final a = DiscogsAuthService(store: MemoryDiscogsCredentialStore(), client: client);
    await a.load();
    expect(await DiscogsCollectionService(auth: a, client: client).fetchCollection(), isNull);
  });

  test('importar: entra só o que é novo, sem repetir prensagem e sem trazer de volta o que foi tirado', () async {
    final col = CollectionService(directory: dir);
    await col.load();
    final now = DateTime(2024);
    await col.add(CollectionItem(album: 'Already Here', artist: 'Band', addedAt: now, discogsReleaseId: '10'));
    await col.add(CollectionItem(album: 'Removed', artist: 'Band', addedAt: now));
    await col.remove('Removed', 'Band');
    final added = await col.importFromDiscogs([
      CollectionItem(album: 'Already Here', artist: 'Band', addedAt: now, discogsReleaseId: '10'),
      CollectionItem(album: 'Same Pressing Other Name', artist: 'Band', addedAt: now, discogsReleaseId: '10'),
      CollectionItem(album: 'Removed', artist: 'Band', addedAt: now, discogsReleaseId: '11'),
      CollectionItem(album: 'New One', artist: 'Band', addedAt: now, discogsReleaseId: '12'),
    ]);
    expect(added, 1);
    expect(col.contains('New One', 'Band'), isTrue);
    expect(col.contains('Removed', 'Band'), isFalse);
    expect(col.discogsImportedAt, isNotNull);
    final again = CollectionService(directory: dir);
    await again.load();
    expect(again.discogsImportedAt, isNotNull, reason: 'a data da importação fica guardada');
  });
}
