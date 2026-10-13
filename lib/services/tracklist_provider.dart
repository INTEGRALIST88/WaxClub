import '../models/track_entry.dart';

/// Representa um candidato a álbum/lançamento identificado no catálogo.
class ReleaseCandidate {
  final String providerId; // 'musicbrainz', 'itunes', etc.
  final String releaseId;
  final String albumTitle;
  final String? format; // '12" Vinyl', 'CD', 'Digital Media'
  final String? status; // 'Official', 'Promotional'
  final String? primaryType; // 'Album', 'Single', 'EP'
  final List<String> secondaryTypes; // 'Compilation', 'Live', 'Soundtrack'

  // Detalhes para a escolha manual do disco ("Mudar disco")
  final String? artistName; // artista creditado no disco ("Various" em coletâneas)
  final String? year;
  final String? country;
  final String? coverUrl;
  final int? trackCount;

  /// Agrupa edições do mesmo disco (release-group do MusicBrainz, master do Discogs).
  final String? groupId;

  /// Quantas edições do mesmo disco foram agrupadas neste candidato.
  final int editions;

  const ReleaseCandidate({
    required this.providerId,
    required this.releaseId,
    required this.albumTitle,
    this.format,
    this.status,
    this.primaryType,
    this.secondaryTypes = const [],
    this.artistName,
    this.year,
    this.country,
    this.coverUrl,
    this.trackCount,
    this.groupId,
    this.editions = 1,
  });

  bool get isVinyl {
    final f = (format ?? '').toLowerCase();
    return f.contains('vinyl') || f.contains('lp') || f.contains('12"') || f.contains('10"') || f.contains('7"');
  }

  /// Disco de vinil LP ou EP (fora CD, digital, fita e compactos de single).
  bool get isVinylLpOrEp {
    if (!isVinyl) return false;
    final tokens = (format ?? '').toLowerCase().split(',').map((t) => t.trim()).toList();
    final type = (primaryType ?? '').toLowerCase();
    if (tokens.contains('lp') || tokens.contains('ep') || type == 'album' || type == 'ep') return true;
    if (type == 'single' || tokens.any((t) => t.contains('single'))) return false;
    return true;
  }

  bool get isCompilation => secondaryTypes.any((t) => t.toLowerCase() == 'compilation');
  bool get isLive => secondaryTypes.any((t) => t.toLowerCase() == 'live');

  ReleaseCandidate copyWith({int? editions}) => ReleaseCandidate(
        providerId: providerId,
        releaseId: releaseId,
        albumTitle: albumTitle,
        format: format,
        status: status,
        primaryType: primaryType,
        secondaryTypes: secondaryTypes,
        artistName: artistName,
        year: year,
        country: country,
        coverUrl: coverUrl,
        trackCount: trackCount,
        groupId: groupId,
        editions: editions ?? this.editions,
      );
}

/// Interface abstrata para provedores de catálogo e tracklists.
abstract class TracklistProvider {
  /// Pesquisa releases candidatos a partir da faixa, artista e opcionalmente álbum.
  Future<List<ReleaseCandidate>> searchReleases({
    required String title,
    required String artist,
    String? album,
  });

  /// Carrega a lista completa de faixas ordenadas ([TrackEntry]) para um release específico.
  Future<List<TrackEntry>> loadTracklist(ReleaseCandidate candidate);

  /// Libera recursos.
  void dispose();
}

/// Só os discos de vinil LP ou EP (a escolha de disco não mostra CD, digital nem singles).
List<ReleaseCandidate> vinylLpOrEpOnly(List<ReleaseCandidate> list) => [for (final c in list) if (c.isVinylLpOrEp) c];

/// Junta as várias prensagens/edições do mesmo disco num único item (preferindo a de vinil).
List<ReleaseCandidate> groupReleaseEditions(List<ReleaseCandidate> list) {
  final groups = <String, List<ReleaseCandidate>>{};
  for (final c in list) {
    final key = '${c.providerId}:${c.groupId ?? 'r${c.releaseId}'}';
    final g = groups.putIfAbsent(key, () => []);
    if (!g.any((x) => x.releaseId == c.releaseId)) g.add(c);
  }
  return [
    for (final g in groups.values) (g.firstWhere((c) => c.isVinyl, orElse: () => g.first)).copyWith(editions: g.length),
  ];
}
