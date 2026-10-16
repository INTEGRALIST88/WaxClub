import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/track_entry.dart';
import 'artist_names.dart';
import 'collection_grouping.dart';
import 'collection_service.dart';
import 'tracklist_matcher.dart';
import 'vinyl_cache_service.dart';

/// Disco da coleção do usuário que tem a música reconhecida.
class OwnedRecord {
  final String album;
  final String artist;
  final String? coverUrl;
  final List<TrackEntry> tracklist;
  const OwnedRecord({required this.album, required this.artist, this.coverUrl, this.tracklist = const []});
}

/// "A coleção primeiro": quando uma música é reconhecida, procura em My Collection um disco do mesmo artista
/// que tenha essa faixa — pela lista de faixas guardada no aparelho ou, se faltar, pela prensagem no Discogs.
/// Achando, o app usa a capa, a lista de faixas e a letra desse disco; só sem ele usa o disco sugerido pelo
/// reconhecimento.
class OwnedRecordFinder {
  final CollectionService collection;
  final VinylCacheService cache;

  /// Lista de faixas de uma prensagem do Discogs (nulo: sem busca na rede).
  final Future<List<TrackEntry>> Function(String releaseId)? fetchTracklist;

  /// Máximo de discos do artista buscados na rede por reconhecimento (os outros esperam a próxima vez).
  static const int maxFetches = 4;

  OwnedRecordFinder({required this.collection, required this.cache, this.fetchTracklist});

  static String _artistKey(String artist) => CollectionGrouper.sortKey(artist);

  /// Mesmo artista (sem diferenciar maiúsculas, acentos e o artigo: "The Beatles" = "Beatles"), inclusive pelos
  /// outros nomes conhecidos ("Suede" = "The London Suede").
  static bool sameArtist(String a, String b) {
    final ka = _artistKey(a);
    final kb = _artistKey(b);
    if (ka.isEmpty || kb.isEmpty) return false;
    if (ka == kb) return true;
    return ArtistNames.variants(a).any((v) => _artistKey(v) == kb) || ArtistNames.variants(b).any((v) => _artistKey(v) == ka);
  }

  Future<OwnedRecord?> find(String title, String artist, {String? album}) async {
    await collection.load();
    final mine = [for (final i in collection.items()) if (sameArtist(i.artist, artist)) i];
    if (mine.isEmpty) return null;

    OwnedRecord? byTracklist(CollectionItem i, List<TrackEntry> tracks) =>
        tracks.isNotEmpty && TracklistMatcher.findIndex(tracks, title) >= 0
            ? OwnedRecord(album: i.album, artist: i.artist, coverUrl: i.coverUrl, tracklist: tracks)
            : null;

    final hits = <OwnedRecord>[];
    final unknown = <CollectionItem>[];
    for (final i in mine) {
      final tracks = cache.getTracklist(i.album, i.artist);
      final hit = byTracklist(i, tracks);
      if (hit != null) {
        hits.add(hit);
      } else if (tracks.isEmpty) {
        unknown.add(i);
      }
    }
    // Discos sem lista de faixas no aparelho: busca a prensagem no Discogs (e guarda para as próximas vezes)
    final fetch = fetchTracklist;
    if (hits.isEmpty && fetch != null) {
      var n = 0;
      for (final i in unknown) {
        final id = i.discogsReleaseId;
        if (id == null || id.isEmpty || n >= maxFetches) continue;
        n++;
        try {
          final tracks = await fetch(id).timeout(const Duration(seconds: 6));
          if (tracks.isEmpty) continue;
          unawaited(cache.saveTracklist(album: i.album, artist: i.artist, entries: tracks, releaseId: id, source: 'discogs'));
          final hit = byTracklist(i, tracks);
          if (hit != null) {
            hits.add(hit);
            break;
          }
        } catch (e) {
          debugPrint('[OwnedRecord] Lista de faixas de "${i.album}" indisponível: $e');
        }
      }
    }
    if (hits.isEmpty) {
      // Sem lista de faixas: vale o disco da coleção com o mesmo nome do sugerido pelo reconhecimento
      final key = album == null ? '' : TracklistMatcher.normalize(album);
      for (final i in mine) {
        if (key.isNotEmpty && TracklistMatcher.normalize(i.album) == key) {
          return OwnedRecord(album: i.album, artist: i.artist, coverUrl: i.coverUrl, tracklist: cache.getTracklist(i.album, i.artist));
        }
      }
      return null;
    }
    // Mais de um disco com a faixa (ex.: o LP e uma coletânea): o de mesmo nome do sugerido, senão o primeiro
    final key = album == null ? '' : TracklistMatcher.normalize(album);
    return hits.firstWhere((h) => key.isNotEmpty && TracklistMatcher.normalize(h.album) == key, orElse: () => hits.first);
  }
}
