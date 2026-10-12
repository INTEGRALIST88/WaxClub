import 'package:flutter/foundation.dart';
import '../models/track_entry.dart';
import 'discogs/discogs_auth_service.dart';
import 'discogs/discogs_tracklist_provider.dart';
import 'musicbrainz_tracklist_provider.dart';
import 'tracklist_matcher.dart';
import 'tracklist_provider.dart';

/// Resultado de uma busca de discos para a tela "Mudar disco".
class AlbumCatalogResult {
  final List<ReleaseCandidate> albums;

  /// Base que respondeu: 'discogs' ou 'musicbrainz'.
  final String source;

  /// Aviso para o usuário (ex.: Discogs fora do ar, mostrando a base reserva).
  final String? notice;

  const AlbumCatalogResult({required this.albums, required this.source, this.notice});
}

/// Catálogo de discos para a escolha manual: Discogs como base principal (com a conta do usuário)
/// e MusicBrainz como reserva, usada quando o Discogs não está conectado, falha ou não acha nada.
class AlbumCatalogService {
  final DiscogsAuthService auth;
  final DiscogsTracklistProvider _discogs;
  final MusicBrainzTracklistProvider _musicBrainz;

  AlbumCatalogService({
    required this.auth,
    DiscogsTracklistProvider? discogs,
    MusicBrainzTracklistProvider? musicBrainz,
  })  : _discogs = discogs ?? DiscogsTracklistProvider(auth: auth),
        _musicBrainz = musicBrainz ?? MusicBrainzTracklistProvider();

  /// Todos os discos em que a música aparece, com o disco atual no topo.
  Future<AlbumCatalogResult> albumsForTrack({
    required String title,
    required String artist,
    String? currentAlbum,
  }) {
    return _withFallback(
      discogs: () => _discogs.searchReleases(title: title, artist: artist, album: currentAlbum),
      musicBrainz: () async =>
          groupReleaseEditions(await _musicBrainz.searchReleases(title: title, artist: artist, album: currentAlbum)),
      sort: (list) => sortForTrack(list, artist: artist, currentAlbum: currentAlbum),
    );
  }

  /// Busca livre digitada pelo usuário (artista, disco...).
  Future<AlbumCatalogResult> search(String query, {String? artist, String? currentAlbum}) {
    return _withFallback(
      discogs: () => _discogs.searchReleasesByText(query),
      musicBrainz: () async => groupReleaseEditions(await _musicBrainz.searchReleasesByText(query)),
      sort: (list) => sortForTrack(list, artist: artist, currentAlbum: currentAlbum),
    );
  }

  Future<AlbumCatalogResult> _withFallback({
    required Future<List<ReleaseCandidate>> Function() discogs,
    required Future<List<ReleaseCandidate>> Function() musicBrainz,
    required List<ReleaseCandidate> Function(List<ReleaseCandidate>) sort,
  }) async {
    String? notice;
    if (auth.isEnabled) {
      try {
        final found = await discogs();
        if (found.isNotEmpty) return AlbumCatalogResult(albums: sort(found), source: 'discogs');
        notice = 'Discogs found no records; showing MusicBrainz results.';
      } catch (e) {
        debugPrint('[AlbumCatalog] Discogs falhou: $e');
        notice = 'Discogs is unavailable right now; showing MusicBrainz results.';
      }
    }
    final found = await musicBrainz();
    return AlbumCatalogResult(albums: sort(found), source: 'musicbrainz', notice: notice);
  }

  /// Lista de faixas do disco escolhido, na base de onde ele veio.
  Future<List<TrackEntry>> loadTracklist(ReleaseCandidate candidate) {
    return candidate.providerId == 'discogs'
        ? _discogs.loadTracklist(candidate)
        : _musicBrainz.loadTracklist(candidate);
  }

  /// Ordem da lista: disco atual, discos de estúdio do artista (vinil primeiro), depois singles/EPs,
  /// ao vivo e coletâneas; dentro de cada grupo, do mais antigo (edição original) ao mais novo.
  static List<ReleaseCandidate> sortForTrack(
    List<ReleaseCandidate> list, {
    String? artist,
    String? currentAlbum,
  }) {
    int rank(ReleaseCandidate c) {
      if (currentAlbum != null && TracklistMatcher.similarity(c.albumTitle, currentAlbum) >= 0.9) return 0;
      final byArtist = artist == null || c.artistName == null || TracklistMatcher.isSameArtist(c.artistName!, artist);
      if (c.isCompilation || !byArtist) return 4;
      if (c.isLive) return 3;
      if (c.primaryType == 'Album') return c.isVinyl ? 1 : 2;
      return 3;
    }

    int year(ReleaseCandidate c) => int.tryParse(c.year ?? '') ?? 9999;

    final sorted = List<ReleaseCandidate>.from(list);
    sorted.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : year(a).compareTo(year(b));
    });
    return sorted;
  }

  void dispose() {
    _discogs.dispose();
    _musicBrainz.dispose();
  }
}
