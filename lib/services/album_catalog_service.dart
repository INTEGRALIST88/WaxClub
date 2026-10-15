import '../l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import '../models/track_entry.dart';
import 'discogs/discogs_auth_service.dart';
import 'discogs/discogs_tracklist_provider.dart';
import 'musicbrainz_tracklist_provider.dart';
import 'record_scan_parser.dart';
import 'tracklist_matcher.dart';
import 'tracklist_provider.dart';
import 'wikipedia_tracklist_service.dart';

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
/// Só aparecem discos de vinil LP ou EP: CD, digital, fita e singles ficam de fora.
class AlbumCatalogService {
  final DiscogsAuthService auth;
  final DiscogsTracklistProvider _discogs;
  final MusicBrainzTracklistProvider _musicBrainz;

  /// Minutagem do LP pela Wikipedia (completa as durações que faltam no disco escolhido).
  final WikipediaTracklistService? _wikipedia;

  AlbumCatalogService({
    required this.auth,
    DiscogsTracklistProvider? discogs,
    MusicBrainzTracklistProvider? musicBrainz,
    WikipediaTracklistService? wikipedia,
  })  : _discogs = discogs ?? DiscogsTracklistProvider(auth: auth),
        _musicBrainz = musicBrainz ?? MusicBrainzTracklistProvider(),
        _wikipedia = wikipedia;

  /// Todos os discos em que a música aparece, com o disco atual no topo.
  Future<AlbumCatalogResult> albumsForTrack({
    required String title,
    required String artist,
    String? currentAlbum,
  }) {
    // Sem anotações de edição entre parênteses ("(studio Chat + New remix)", "(Remastered)")
    final track = catalogSearchName(title);
    final album = currentAlbum == null ? null : catalogSearchName(currentAlbum);
    return _withFallback(
      discogs: () => _discogs.searchReleases(title: track, artist: artist, album: album),
      musicBrainz: () async =>
          groupReleaseEditions(vinylLpOrEpOnly(
              await _musicBrainz.searchReleases(title: track, artist: artist, album: album))),
      sort: (list) => sortForTrack(list, artist: artist, currentAlbum: album),
    );
  }

  /// Busca livre digitada pelo usuário (artista, disco...).
  Future<AlbumCatalogResult> search(String query, {String? artist, String? currentAlbum}) {
    // Link do Discogs colado ("discogs.com/release/35436508-..."): vai direto à prensagem
    final releaseId = DiscogsTracklistProvider.releaseIdFrom(query);
    if (releaseId != null) return byDiscogsRelease(releaseId);
    final text = catalogSearchName(query);
    final album = currentAlbum == null ? null : catalogSearchName(currentAlbum);
    return _withFallback(
      discogs: () => _discogs.searchReleasesByText(text),
      musicBrainz: () async => groupReleaseEditions(vinylLpOrEpOnly(await _musicBrainz.searchReleasesByText(text))),
      sort: (list) => sortForTrack(list, artist: artist, currentAlbum: album),
    );
  }

  /// Prensagens de vinil com este código de barras (câmera), sem agrupar edições.
  /// Código exato: prefere vinil, mas não descarta a prensagem achada (ex.: formato incompleto no cadastro).
  Future<AlbumCatalogResult> byBarcode(String barcode) {
    return _withFallback(
      discogs: () => _discogs.searchByBarcode(barcode),
      musicBrainz: () async => _vinylFirst(await _musicBrainz.searchByBarcode(barcode)),
      sort: _byYear,
      filter: _vinylFirst,
    );
  }

  /// Prensagens com este número de catálogo, sem agrupar edições. Aceita também um código de barras
  /// ou o link do Discogs digitados no mesmo campo.
  Future<AlbumCatalogResult> byCatalogNumber(String catno) {
    final releaseId = DiscogsTracklistProvider.releaseIdFrom(catno);
    if (releaseId != null) return byDiscogsRelease(releaseId);
    final digits = catno.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^\d{12,13}$').hasMatch(digits) && RecordScanParser.isValidBarcode(digits)) return byBarcode(digits);
    return _withFallback(
      discogs: () => _discogs.searchByCatalogNumber(catno),
      musicBrainz: () async => _vinylFirst(await _musicBrainz.searchByCatalogNumber(catno)),
      sort: _byYear,
      filter: _vinylFirst,
    );
  }

  /// A prensagem do link do Discogs colado pelo usuário (não exige a conta conectada).
  Future<AlbumCatalogResult> byDiscogsRelease(String releaseId) async {
    try {
      final release = await _discogs.fetchRelease(releaseId);
      return AlbumCatalogResult(albums: [if (release != null) release], source: 'discogs');
    } catch (e) {
      debugPrint('[AlbumCatalog] Prensagem $releaseId do Discogs indisponível: $e');
      return AlbumCatalogResult(albums: const [], source: 'discogs', notice: l10n.noticeDiscogsUnavailable);
    }
  }

  /// Vinil primeiro; se nenhum resultado for vinil, mantém todos (o código lido é da prensagem em mãos).
  static List<ReleaseCandidate> _vinylFirst(List<ReleaseCandidate> list) {
    final vinyl = [for (final c in list) if (c.isVinyl) c];
    return vinyl.isNotEmpty ? vinyl : list;
  }

  /// Notas da prensagem no Discogs (para as curiosidades); nulo sem a conta conectada ou sem notas.
  Future<String?> discogsNotes(String releaseId) async {
    await auth.load();
    if (!auth.isEnabled) return null;
    try {
      return await _discogs.fetchReleaseNotes(releaseId);
    } catch (e) {
      debugPrint('[AlbumCatalog] Notas do Discogs indisponíveis: $e');
      return null;
    }
  }

  /// Da edição mais antiga (original) para a mais nova.
  static List<ReleaseCandidate> _byYear(List<ReleaseCandidate> list) {
    int year(ReleaseCandidate c) => int.tryParse(c.year ?? '') ?? 9999;
    return List<ReleaseCandidate>.from(list)..sort((a, b) => year(a).compareTo(year(b)));
  }

  Future<AlbumCatalogResult> _withFallback({
    required Future<List<ReleaseCandidate>> Function() discogs,
    required Future<List<ReleaseCandidate>> Function() musicBrainz,
    required List<ReleaseCandidate> Function(List<ReleaseCandidate>) sort,
    List<ReleaseCandidate> Function(List<ReleaseCandidate>) filter = vinylLpOrEpOnly,
  }) async {
    String? notice;
    await auth.load(); // a busca pode começar antes de a conta terminar de carregar
    if (auth.isEnabled) {
      try {
        final found = filter(await discogs());
        if (found.isNotEmpty) return AlbumCatalogResult(albums: sort(found), source: 'discogs');
        notice = l10n.noticeDiscogsNoVinyl;
      } catch (e) {
        debugPrint('[AlbumCatalog] Discogs falhou: $e');
        notice = l10n.noticeDiscogsUnavailable;
      }
    }
    final found = await musicBrainz();
    return AlbumCatalogResult(albums: sort(found), source: 'musicbrainz', notice: notice);
  }

  /// Lista de faixas do disco escolhido, na base de onde ele veio. Durações que faltarem vêm da
  /// Wikipedia (tempos do LP); se o disco não for vinil, a Wikipedia substitui as durações dele.
  Future<List<TrackEntry>> loadTracklist(ReleaseCandidate candidate) async {
    final entries = candidate.providerId == 'discogs'
        ? await _discogs.loadTracklist(candidate)
        : await _musicBrainz.loadTracklist(candidate);
    final artist = candidate.artistName;
    final wikipedia = _wikipedia;
    if (wikipedia == null || candidate.isCompilation || artist == null) return entries;
    return wikipedia.fillDurations(entries, artist: artist, album: candidate.albumTitle, override: !candidate.isVinyl);
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
    _wikipedia?.dispose();
  }
}
