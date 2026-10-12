import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/track_entry.dart';
import 'side_estimator.dart';
import 'tracklist_matcher.dart';

/// Disco de trilha sonora de novela embutido no app (capa, emissora, ano e faixas com artista e duração).
class SoundtrackDisc {
  final String album;
  final String network;
  final int? year;
  final String? coverUrl;
  final String? sourceUrl;
  final List<TrackEntry> tracks;

  const SoundtrackDisc({
    required this.album,
    required this.network,
    this.year,
    this.coverUrl,
    this.sourceUrl,
    required this.tracks,
  });

  /// LPs até 1993 (época do vinil no Brasil); depois, CDs de um lado só.
  bool get isVinylEra => year == null || year! <= 1993;

  /// Rótulo do artista do disco (cada faixa guarda o seu próprio artista).
  static const String albumArtist = 'Trilha sonora';

  factory SoundtrackDisc.fromJson(Map<String, dynamic> json) {
    final year = (json['year'] as num?)?.toInt();
    final raw = <TrackEntry>[];
    var position = 1;
    for (final t in (json['tracks'] as List<dynamic>? ?? const [])) {
      if (t is! Map<String, dynamic>) continue;
      final title = (t['title'] as String?)?.trim();
      if (title == null || title.isEmpty) continue;
      raw.add(TrackEntry(
        position: position,
        title: title,
        number: '${position++}',
        side: t['side'] as String?,
        lengthMs: (t['lengthMs'] as num?)?.toInt(),
        artist: (t['artist'] as String?)?.trim(),
      ));
    }
    final vinyl = year == null || year <= 1993;
    return SoundtrackDisc(
      album: (json['album'] as String).trim(),
      network: json['network'] as String? ?? '',
      year: year,
      coverUrl: json['cover'] as String?,
      sourceUrl: json['url'] as String?,
      tracks: vinyl ? estimateVinylSides(raw) : [for (final e in raw) e.side == null ? e.copyWith(side: 'A') : e],
    );
  }

  /// Lados A/B de um LP sem lados informados: divide pela metade da duração total (faixas sem duração
  /// entram com a duração média). Sem durações suficientes, divide pela metade das faixas.
  static List<TrackEntry> estimateVinylSides(List<TrackEntry> entries) {
    if (entries.length < 2 || entries.where((e) => e.side != null).length / entries.length >= 0.8) return entries;
    final known = entries.where((e) => (e.lengthMs ?? 0) > 0).toList();
    if (known.length / entries.length >= 0.6) {
      final avg = known.fold<int>(0, (s, e) => s + e.lengthMs!) ~/ known.length;
      final filled = [for (final e in entries) (e.lengthMs ?? 0) > 0 ? e : e.copyWith(lengthMs: avg)];
      final estimated = SideEstimator.resolveSides(filled).entries;
      // Devolve as durações originais (a média só serviu para achar a divisão)
      return [for (int i = 0; i < entries.length; i++) entries[i].copyWith(side: estimated[i].side)];
    }
    final half = (entries.length / 2).ceil();
    return [for (int i = 0; i < entries.length; i++) entries[i].copyWith(side: i < half ? 'A' : 'B')];
  }
}

/// Catálogo de trilhas sonoras de novelas brasileiras (fonte: Teledramaturgia / Observatório da TV),
/// embutido no app em `assets/catalog/trilhas_novelas.json`.
class SoundtrackCatalog {
  static const String assetPath = 'assets/catalog/trilhas_novelas.json';

  final List<SoundtrackDisc> discs;
  final Map<String, List<(SoundtrackDisc, TrackEntry)>> _byTitle = {};

  SoundtrackCatalog(this.discs) {
    for (final d in discs) {
      for (final t in d.tracks) {
        _byTitle.putIfAbsent(TracklistMatcher.normalize(t.title), () => []).add((d, t));
      }
    }
  }

  static final SoundtrackCatalog empty = SoundtrackCatalog(const []);

  factory SoundtrackCatalog.fromJson(Map<String, dynamic> json) => SoundtrackCatalog([
        for (final d in (json['discs'] as List<dynamic>? ?? const []))
          if (d is Map<String, dynamic>) SoundtrackDisc.fromJson(d),
      ]);

  /// Carrega o catálogo embutido (fora da thread de interface). Sem o arquivo, devolve vazio.
  static Future<SoundtrackCatalog> loadBundled() async {
    try {
      // load (sem o cache do loadString, que deixa escapar a falha quando o arquivo não existe)
      final data = await rootBundle.load(assetPath);
      final raw = utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      return await compute(_parse, raw);
    } catch (e) {
      debugPrint('[SoundtrackCatalog] Catálogo de trilhas indisponível: $e');
      return empty;
    }
  }

  static SoundtrackCatalog _parse(String raw) =>
      SoundtrackCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  /// Trilhas que contêm a música (mesmo título e mesmo artista), da mais antiga para a mais nova.
  List<SoundtrackDisc> discsWith(String title, String artist) {
    final norm = TracklistMatcher.normalize(title);
    final candidates = <(SoundtrackDisc, TrackEntry)>[
      ...?_byTitle[norm],
    ];
    if (candidates.isEmpty) {
      // Títulos com variações ("Azul da Cor do Mar (ao vivo)") — busca mais tolerante
      for (final entry in _byTitle.entries) {
        if (TracklistMatcher.isSameTitle(entry.key, norm)) candidates.addAll(entry.value);
      }
    }
    final found = <SoundtrackDisc>[];
    for (final (disc, track) in candidates) {
      final trackArtist = track.artist;
      if (trackArtist == null || !_sameArtist(trackArtist, artist)) continue;
      if (!found.contains(disc)) found.add(disc);
    }
    found.sort((a, b) => (a.year ?? 9999).compareTo(b.year ?? 9999));
    return found;
  }

  /// Trilha a assumir como disco padrão para a música (a mais antiga em que ela aparece).
  SoundtrackDisc? findFor(String title, String artist) {
    final list = discsWith(title, artist);
    return list.isEmpty ? null : list.first;
  }

  static bool _sameArtist(String catalogArtist, String heardArtist) {
    if (TracklistMatcher.isSameArtist(catalogArtist, heardArtist)) return true;
    // "Gal Costa e Caetano Veloso", "Johnny Glovez featuring Polina": basta o artista principal coincidir
    final parts = catalogArtist.split(RegExp(r'\s+(?:e|&|feat\.?|featuring|com|part\.?|x)\s+|,|/', caseSensitive: false));
    return parts.any((p) => p.trim().isNotEmpty && TracklistMatcher.isSameArtist(p.trim(), heardArtist));
  }
}
