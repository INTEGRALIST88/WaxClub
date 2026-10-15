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

  // Identificação da prensagem (reconhecimento pela câmera)
  final String? label;
  final String? catalogNumber;
  final String? barcode;

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
    this.label,
    this.catalogNumber,
    this.barcode,
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
        label: label,
        catalogNumber: catalogNumber,
        barcode: barcode,
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

/// Nome limpo para buscar em catálogo: tira o que vem entre parênteses/colchetes e sufixos de edição.
/// Ex.: "Baby's in Black (studio Chat + New remix)" → "Baby's in Black";
/// "Beatles For Sale (Remastered)" → "Beatles For Sale"; "Help! - 2009 Remaster" → "Help!".
String catalogSearchName(String text) {
  var s = text.replaceAll(RegExp(r'\s*[\(\[][^\)\]]*[\)\]]'), '');
  s = s.replaceAll(
    RegExp(r'\s+[-–]\s+.*\b(remaster(ed)?|remix|mix|version|edition|mono|stereo|live|deluxe|anniversary)\b.*$',
        caseSensitive: false),
    '',
  );
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? text.trim() : s;
}

/// Faixa típica de edição especial/deluxe: remix, backing track, vocal isolado, demo, take, ensaio...
final RegExp _bonusVersionPattern = RegExp(
  r'[\(\[\-–].*\b(remix|mix|backing track|naked vocal|isolated|demo|take \d+|outtake|alternate|rehearsal|'
  r'session|studio chat|test pressing|instrumental|karaoke)\b',
  caseSensitive: false,
);

/// Quantas faixas da lista são versões de edição especial (o LP original não tem nenhuma).
int bonusVersionCount(List<TrackEntry> entries) =>
    entries.where((e) => _bonusVersionPattern.hasMatch(e.title)).length;

/// Pontuação de uma tracklist como "o LP original": cada faixa bônus e cada faixa além de 20 tira pontos.
/// Ex.: "Beatles for Sale" de 14 faixas vence a caixa de 34 com remixes e backing tracks.
int originalEditionPenalty(List<TrackEntry> entries) =>
    bonusVersionCount(entries) * 3 + (entries.length > 20 ? entries.length - 20 : 0);

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
