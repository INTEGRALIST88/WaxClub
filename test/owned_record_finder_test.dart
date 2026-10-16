import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/collection_service.dart';
import 'package:waxclub/services/owned_record_finder.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late CollectionService col;
  late VinylCacheService cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('waxclub_owned_');
    col = CollectionService(directory: dir);
    await col.load();
    cache = VinylCacheService(storageDirectory: dir);
    await cache.init();
  });
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  const forSale = [
    TrackEntry(position: 1, title: 'No Reply', number: 'A1', side: 'A'),
    TrackEntry(position: 2, title: "I'm a Loser", number: 'A2', side: 'A'),
  ];

  test('música de um disco da coleção (lista de faixas no aparelho): usa esse disco, com a capa do usuário', () async {
    await col.add(CollectionItem(album: 'Beatles For Sale', artist: 'The Beatles', coverUrl: 'https://my/cover.jpg', addedAt: DateTime(2026)));
    await cache.saveTracklist(album: 'Beatles For Sale', artist: 'The Beatles', entries: forSale, source: 'discogs');
    final finder = OwnedRecordFinder(collection: col, cache: cache);
    final owned = await finder.find('No Reply', 'Beatles', album: 'Beatles For Sale (Deluxe Edition)');
    expect(owned?.album, 'Beatles For Sale', reason: '"Beatles" = "The Beatles"; o disco da coleção vence a edição deluxe');
    expect(owned?.coverUrl, 'https://my/cover.jpg');
    expect(owned?.tracklist.length, 2);
  });

  test('sem lista no aparelho: busca a prensagem do Discogs do disco da coleção (e guarda)', () async {
    await col.add(CollectionItem(album: 'Beatles For Sale', artist: 'The Beatles', discogsReleaseId: '123', addedAt: DateTime(2026)));
    final asked = <String>[];
    final finder = OwnedRecordFinder(collection: col, cache: cache, fetchTracklist: (id) async {
      asked.add(id);
      return forSale;
    });
    expect((await finder.find("I'm a Loser", 'The Beatles'))?.album, 'Beatles For Sale');
    expect(asked, ['123']);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(cache.getTracklist('Beatles For Sale', 'The Beatles'), isNotEmpty, reason: 'fica guardada para a próxima vez');
  });

  test('música que não está em nenhum disco da coleção: nada (vale o disco do reconhecimento)', () async {
    await col.add(CollectionItem(album: 'Beatles For Sale', artist: 'The Beatles', addedAt: DateTime(2026)));
    await cache.saveTracklist(album: 'Beatles For Sale', artist: 'The Beatles', entries: forSale, source: 'discogs');
    final finder = OwnedRecordFinder(collection: col, cache: cache);
    expect(await finder.find('Help!', 'The Beatles', album: 'Help!'), isNull);
    expect(await finder.find('No Reply', 'Other Band'), isNull, reason: 'outro artista');
  });

  test('disco da coleção sem lista de faixas, mas com o mesmo nome do sugerido: vale', () async {
    await col.add(CollectionItem(album: 'Spooky', artist: 'Lush', coverUrl: 'https://my/spooky.jpg', addedAt: DateTime(2026)));
    final finder = OwnedRecordFinder(collection: col, cache: cache);
    expect((await finder.find('Stray', 'Lush', album: 'Spooky'))?.coverUrl, 'https://my/spooky.jpg');
  });
}
