import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/services/album_catalog_service.dart';
import 'package:waxclub/services/collection_service.dart';
import 'package:waxclub/services/discogs/discogs_auth_service.dart';
import 'package:waxclub/ui/screens/play_record_screen.dart';

void main() {
  testWidgets('Play a record: coleção inteira sem busca, filtro por artista/disco, faixas e "Play"', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('waxclub_play_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final collection = CollectionService(directory: dir);
    await tester.runAsync(() async {
      await collection.load();
      await collection.add(CollectionItem(album: 'Abbey Road', artist: 'The Beatles', addedAt: DateTime(2026)));
      await collection.add(CollectionItem(album: 'Kind of Blue', artist: 'Miles Davis', addedAt: DateTime(2026)));
    });
    final catalog = AlbumCatalogService(auth: DiscogsAuthService(store: MemoryDiscogsCredentialStore()));
    const tracks = [TrackEntry(position: 1, title: 'So What', number: 'A1', side: 'A', lengthMs: 562000)];

    PlayRecordChoice? choice;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              choice = await Navigator.of(context).push<PlayRecordChoice>(MaterialPageRoute(
                builder: (_) => PlayRecordScreen(
                  collection: collection,
                  catalog: catalog,
                  tracklistFor: (album, artist) => album == 'Kind of Blue' ? tracks : const [],
                ),
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Sem busca: a coleção inteira
    expect(find.text('Abbey Road'), findsOneWidget);
    expect(find.text('Kind of Blue'), findsOneWidget);

    // Filtro por artista
    await tester.enterText(find.byType(TextField), 'miles');
    await tester.pump();
    expect(find.text('Abbey Road'), findsNothing);
    expect(find.text('Kind of Blue'), findsOneWidget);
    expect(find.text('Search Discogs'), findsOneWidget, reason: 'com texto, oferece a busca no Discogs');

    // Abre o disco: faixas e "Play" (já é da coleção)
    await tester.tap(find.text('Kind of Blue'));
    await tester.pumpAndSettle();
    expect(find.text('So What'), findsOneWidget);
    expect(find.text('9:22'), findsOneWidget);
    expect(find.text('Play and add to collection'), findsNothing);
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(choice, isNotNull);
    expect(choice!.release.albumTitle, 'Kind of Blue');
    expect(choice!.addToCollection, isFalse);
    expect(choice!.tracks.single.title, 'So What');
    catalog.dispose();
  });
}
