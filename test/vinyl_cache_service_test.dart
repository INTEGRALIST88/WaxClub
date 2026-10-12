import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waxclub/models/track_entry.dart';
import 'package:waxclub/models/track_info.dart';
import 'package:waxclub/services/tracklist_matcher.dart';
import 'package:waxclub/services/vinyl_cache_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vinyl_cache_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('VinylCacheService Tests (T0.2)', () {
    test('Regressão D1: cacheTrack na F3 seguido por saveTracklist preserva ordem oficial 1..5', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();

      // Reconheceu primeiro a faixa 3 (título 'Song 3')
      const f3 = TrackInfo(
        title: 'Song 3',
        artist: 'Band A',
        album: 'Album 1',
        offsetSeconds: 12.0,
      );
      await cache.cacheTrack(f3, '[00:10.00] Letra da 3');

      // Agora o prefetch salva a tracklist oficial na ordem correta
      final entries = [
        const TrackEntry(position: 1, title: 'Song 1', number: 'A1'),
        const TrackEntry(position: 2, title: 'Song 2', number: 'A2'),
        const TrackEntry(position: 3, title: 'Song 3', number: 'A3'),
        const TrackEntry(position: 4, title: 'Song 4', number: 'A4'),
        const TrackEntry(position: 5, title: 'Song 5', number: 'A5'),
      ];

      await cache.saveTracklist(
        album: 'Album 1',
        artist: 'Band A',
        entries: entries,
        source: 'musicbrainz',
        sideSource: 'catalog',
      );

      final tracklist = cache.getTracklist('Album 1', 'Band A');
      expect(tracklist.length, equals(5));
      expect(tracklist[0].title, equals('Song 1'));
      expect(tracklist[2].title, equals('Song 3'));
      expect(tracklist[3].title, equals('Song 4'));

      // Verificar que a próxima de Song 3 é Song 4 (índice 2 + 1)
      final idx = TracklistMatcher.findIndex(tracklist, 'Song 3');
      expect(idx, equals(2));
      expect(tracklist[idx + 1].title, equals('Song 4'));
    });

    test('cacheTrack repetido preserva preferredAlbum e LRC existente quando o novo é nulo', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();

      const t1 = TrackInfo(
        title: 'Musica X',
        artist: 'Artista Y',
        album: 'Disco Z',
        offsetSeconds: 5.0,
      );
      await cache.cacheTrack(t1, '[00:05.00] Letra valida');
      await cache.setPreferredAlbum('Musica X', 'Artista Y', 'Disco Especial');

      // Segunda chamada com LRC nulo
      const t2 = TrackInfo(
        title: 'Musica X',
        artist: 'Artista Y',
        album: 'Disco Z',
        offsetSeconds: 8.0,
      );
      await cache.cacheTrack(t2, null);

      expect(cache.findCachedLyrics('Musica X', 'Artista Y'), equals('[00:05.00] Letra valida'));
      expect(cache.getPreferredAlbum('Musica X', 'Artista Y'), equals('Disco Especial'));
    });

    test('saveTracklist substitui a tracklist anterior sem duplicar ou misturar faixas', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();

      final initial = [
        const TrackEntry(position: 1, title: 'Old 1'),
        const TrackEntry(position: 2, title: 'Old 2'),
      ];
      await cache.saveTracklist(
        album: 'LP Teste',
        artist: 'Artista',
        entries: initial,
        source: 'musicbrainz',
        sideSource: 'none',
      );

      final updated = [
        const TrackEntry(position: 1, title: 'New A'),
        const TrackEntry(position: 2, title: 'New B'),
        const TrackEntry(position: 3, title: 'New C'),
      ];
      await cache.saveTracklist(
        album: 'LP Teste',
        artist: 'Artista',
        entries: updated,
        source: 'musicbrainz',
        sideSource: 'none',
      );

      final result = cache.getTracklist('LP Teste', 'Artista');
      expect(result.length, equals(3));
      expect(result.map((e) => e.title), containsAllInOrder(['New A', 'New B', 'New C']));
    });

    test('recuperação atômica: arquivo corrompido recupera do .bak', () async {
      final cache1 = VinylCacheService(storageDirectory: tempDir);
      await cache1.init();

      await cache1.saveTracklist(
        album: 'LP Seguro',
        artist: 'Banda',
        entries: [const TrackEntry(position: 1, title: 'Hit')],
        source: 'musicbrainz',
        sideSource: 'none',
      );

      final file = File('${tempDir.path}/vinyl_collection.json');
      final bak = File('${tempDir.path}/vinyl_collection.json.bak');

      // Garantir que .bak existe gerando uma segunda escrita
      await cache1.saveTracklist(
        album: 'LP Seguro',
        artist: 'Banda',
        entries: [
          const TrackEntry(position: 1, title: 'Hit'),
          const TrackEntry(position: 2, title: 'Hit 2'),
        ],
        source: 'musicbrainz',
        sideSource: 'none',
      );
      expect(await bak.exists(), isTrue);

      // Corromper arquivo principal
      await file.writeAsString('{ invalid json !!!', flush: true);

      // Novo serviço deve carregar e recuperar do backup
      final cache2 = VinylCacheService(storageDirectory: tempDir);
      await cache2.init();

      final tracklist = cache2.getTracklist('LP Seguro', 'Banda');
      expect(tracklist.isNotEmpty, isTrue);
    });

    test('duas gravações concorrentes não corrompem o arquivo', () async {
      final cache = VinylCacheService(storageDirectory: tempDir);
      await cache.init();

      // Dispara 10 gravações simultâneas
      final futures = <Future<void>>[];
      for (int i = 0; i < 10; i++) {
        futures.add(cache.saveTracklist(
          album: 'Album $i',
          artist: 'Artist $i',
          entries: [TrackEntry(position: 1, title: 'Track $i')],
          source: 'test',
          sideSource: 'none',
        ));
      }
      await Future.wait(futures);

      // Reinicializa serviço lendo do disco
      final reloadedCache = VinylCacheService(storageDirectory: tempDir);
      await reloadedCache.init();
      expect(reloadedCache.getAllDiscs().length, equals(10));
    });
  });
}
