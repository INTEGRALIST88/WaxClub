import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'tracklist_matcher.dart';

/// Disco da coleção do usuário (espelho local da tabela `colecao`, que irá para a conta WaxClub).
class CollectionItem {
  final String album;
  final String artist;
  final String? coverUrl;
  final String? year;
  final String? format;
  final String? discogsReleaseId; // necessário para sincronizar com o Discogs
  final String? musicBrainzReleaseId;
  final String? label;
  final String? catalogNumber;
  final String? barcode;
  final DateTime addedAt;
  final int? rating; // 1 a 5
  final String? mediaCondition; // ex.: "Very Good Plus (VG+)"
  final String? sleeveCondition;
  final String? notes;

  /// Última alteração (para a sincronização com a conta WaxClub); discos antigos usam [addedAt].
  final DateTime? updatedAt;

  const CollectionItem({
    required this.album,
    required this.artist,
    this.coverUrl,
    this.year,
    this.format,
    this.discogsReleaseId,
    this.musicBrainzReleaseId,
    this.label,
    this.catalogNumber,
    this.barcode,
    required this.addedAt,
    this.rating,
    this.mediaCondition,
    this.sleeveCondition,
    this.notes,
    this.updatedAt,
  });

  String get key => CollectionService.keyFor(album, artist);
  DateTime get changedAt => updatedAt ?? addedAt;

  CollectionItem withUpdatedAt(DateTime at) => CollectionItem.fromJson({...toJson(), 'updatedAt': at.toIso8601String()});

  Map<String, dynamic> toJson() => {
        'album': album,
        'artist': artist,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (year != null) 'year': year,
        if (format != null) 'format': format,
        if (discogsReleaseId != null) 'discogsReleaseId': discogsReleaseId,
        if (musicBrainzReleaseId != null) 'musicBrainzReleaseId': musicBrainzReleaseId,
        if (label != null) 'label': label,
        if (catalogNumber != null) 'catalogNumber': catalogNumber,
        if (barcode != null) 'barcode': barcode,
        'addedAt': addedAt.toIso8601String(),
        if (rating != null) 'rating': rating,
        if (mediaCondition != null) 'mediaCondition': mediaCondition,
        if (sleeveCondition != null) 'sleeveCondition': sleeveCondition,
        if (notes != null) 'notes': notes,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory CollectionItem.fromJson(Map<String, dynamic> j) => CollectionItem(
        album: j['album'] as String,
        artist: j['artist'] as String,
        coverUrl: j['coverUrl'] as String?,
        year: j['year'] as String?,
        format: j['format'] as String?,
        discogsReleaseId: j['discogsReleaseId'] as String?,
        musicBrainzReleaseId: j['musicBrainzReleaseId'] as String?,
        label: j['label'] as String?,
        catalogNumber: j['catalogNumber'] as String?,
        barcode: j['barcode'] as String?,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.now(),
        rating: (j['rating'] as num?)?.toInt(),
        mediaCondition: j['mediaCondition'] as String?,
        sleeveCondition: j['sleeveCondition'] as String?,
        notes: j['notes'] as String?,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      );
}

/// Uma faixa ouvida (espelho local da tabela `audicoes`).
class PlayEvent {
  final String album;
  final String artist;
  final String track;
  final String? trackArtist;
  final DateTime at;

  const PlayEvent({required this.album, required this.artist, required this.track, this.trackArtist, required this.at});

  String get key => CollectionService.keyFor(album, artist);

  Map<String, dynamic> toJson() => {
        'album': album,
        'artist': artist,
        'track': track,
        if (trackArtist != null) 'trackArtist': trackArtist,
        'at': at.toIso8601String(),
      };

  factory PlayEvent.fromJson(Map<String, dynamic> j) => PlayEvent(
        album: j['album'] as String,
        artist: j['artist'] as String,
        track: j['track'] as String,
        trackArtist: j['trackArtist'] as String?,
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Quantas vezes um disco foi ouvido e quando (vale também para discos fora da coleção).
class DiscStats {
  final int playCount;
  final DateTime? firstPlayedAt;
  final DateTime? lastPlayedAt;
  const DiscStats({this.playCount = 0, this.firstPlayedAt, this.lastPlayedAt});

  Map<String, dynamic> toJson() => {
        'playCount': playCount,
        if (firstPlayedAt != null) 'first': firstPlayedAt!.toIso8601String(),
        if (lastPlayedAt != null) 'last': lastPlayedAt!.toIso8601String(),
      };

  factory DiscStats.fromJson(Map<String, dynamic> j) => DiscStats(
        playCount: (j['playCount'] as num?)?.toInt() ?? 0,
        firstPlayedAt: DateTime.tryParse(j['first'] as String? ?? ''),
        lastPlayedAt: DateTime.tryParse(j['last'] as String? ?? ''),
      );
}

enum CollectionSort { recentlyPlayed, mostPlayed, recentlyAdded, alphabetical }

/// Coleção do usuário e histórico de audições, guardados no aparelho. Quando a conta WaxClub existir,
/// é esta base que sincroniza com o servidor (Hostinger) e com o Discogs.
///
/// Regra de contagem (decisão do usuário): qualquer faixa ouvida conta o disco, uma vez por sessão;
/// uma nova sessão daquele disco começa após [sessionGap] sem ouvi-lo.
class CollectionService extends ChangeNotifier {
  static const String _fileName = 'waxclub_collection.json';
  static const Duration sessionGap = Duration(hours: 2);
  static const int maxPlayEvents = 5000;

  final Directory? _directory;
  CollectionService({Directory? directory}) : _directory = directory;

  final Map<String, CollectionItem> _items = {};
  final Map<String, DiscStats> _stats = {};
  final List<PlayEvent> _plays = [];

  /// Discos tirados da coleção e quando (a remoção também vai para a conta WaxClub).
  final Map<String, DateTime> _removed = {};
  bool _loaded = false;
  bool get isLoaded => _loaded;

  static String keyFor(String album, String artist) =>
      '${TracklistMatcher.normalize(album)}|${TracklistMatcher.normalize(artist)}';

  int get count => _items.length;
  bool contains(String album, String artist) => _items.containsKey(keyFor(album, artist));
  CollectionItem? itemFor(String album, String artist) => _items[keyFor(album, artist)];
  DiscStats statsFor(String album, String artist) => _stats[keyFor(album, artist)] ?? const DiscStats();

  /// Histórico de audições de um disco, do mais recente ao mais antigo.
  List<PlayEvent> historyFor(String album, String artist) {
    final key = keyFor(album, artist);
    return _plays.where((p) => p.key == key).toList().reversed.toList();
  }

  List<CollectionItem> items({CollectionSort sort = CollectionSort.recentlyPlayed}) {
    final list = _items.values.toList();
    int byDate(DateTime? a, DateTime? b) => (b ?? DateTime(1900)).compareTo(a ?? DateTime(1900));
    switch (sort) {
      case CollectionSort.recentlyPlayed:
        list.sort((a, b) => byDate(_stats[a.key]?.lastPlayedAt ?? a.addedAt, _stats[b.key]?.lastPlayedAt ?? b.addedAt));
      case CollectionSort.mostPlayed:
        list.sort((a, b) => (_stats[b.key]?.playCount ?? 0).compareTo(_stats[a.key]?.playCount ?? 0));
      case CollectionSort.recentlyAdded:
        list.sort((a, b) => byDate(a.addedAt, b.addedAt));
      case CollectionSort.alphabetical:
        list.sort((a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()));
    }
    return list;
  }

  Future<File?> _file() async {
    try {
      final dir = _directory ?? await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$_fileName');
    } catch (_) {
      return null; // sem armazenamento (ex.: testes): coleção só em memória
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file();
      if (f != null && await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        for (final i in (j['items'] as List<dynamic>? ?? const [])) {
          final item = CollectionItem.fromJson(i as Map<String, dynamic>);
          _items[item.key] = item;
        }
        (j['stats'] as Map<String, dynamic>? ?? const {})
            .forEach((k, v) => _stats[k] = DiscStats.fromJson(v as Map<String, dynamic>));
        for (final p in (j['plays'] as List<dynamic>? ?? const [])) {
          _plays.add(PlayEvent.fromJson(p as Map<String, dynamic>));
        }
        (j['removed'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
          final at = DateTime.tryParse(v as String? ?? '');
          if (at != null) _removed[k] = at;
        });
      }
    } catch (e) {
      debugPrint('[CollectionService] Coleção local ilegível: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      if (f == null) return;
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        'version': 1,
        'items': _items.values.map((i) => i.toJson()).toList(),
        'stats': _stats.map((k, v) => MapEntry(k, v.toJson())),
        'plays': _plays.map((p) => p.toJson()).toList(),
        'removed': _removed.map((k, v) => MapEntry(k, v.toIso8601String())),
      }));
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('[CollectionService] Falha ao salvar a coleção: $e');
    }
  }

  Future<void> add(CollectionItem item) async {
    final stamped = item.withUpdatedAt(DateTime.now());
    _items[stamped.key] = stamped;
    _removed.remove(stamped.key);
    notifyListeners();
    await _save();
  }

  Future<void> remove(String album, String artist) async {
    final key = keyFor(album, artist);
    if (_items.remove(key) == null) return;
    _removed[key] = DateTime.now();
    notifyListeners();
    await _save();
  }

  // ---------- sincronização com a conta WaxClub ----------

  /// Discos alterados depois de [since] (todos quando null).
  List<CollectionItem> changedSince(DateTime? since) =>
      _items.values.where((i) => since == null || i.changedAt.isAfter(since)).toList();

  /// Remoções feitas depois de [since] (todas quando null).
  Map<String, DateTime> removedSince(DateTime? since) =>
      Map.fromEntries(_removed.entries.where((e) => since == null || e.value.isAfter(since)));

  /// Audições registradas depois de [since] (todas quando null), em ordem.
  List<PlayEvent> playsAfter(DateTime? since) =>
      _plays.where((p) => since == null || p.at.isAfter(since)).toList();

  /// Aplica o que veio do servidor: vence a alteração mais recente; não muda o horário dos itens.
  Future<void> applyRemote({List<CollectionItem> upserts = const [], Map<String, DateTime> deletions = const {}}) async {
    var changed = false;
    for (final item in upserts) {
      final local = _items[item.key];
      final removedAt = _removed[item.key];
      if (local != null && !item.changedAt.isAfter(local.changedAt)) continue;
      if (removedAt != null && !item.changedAt.isAfter(removedAt)) continue;
      _items[item.key] = item;
      _removed.remove(item.key);
      changed = true;
    }
    deletions.forEach((key, at) {
      final local = _items[key];
      if (local == null || at.isBefore(local.changedAt)) return;
      _items.remove(key);
      _removed[key] = at;
      changed = true;
    });
    if (!changed) return;
    notifyListeners();
    await _save();
  }

  /// Registra uma faixa ouvida. O disco ganha +1 audição se for a primeira faixa dele na sessão.
  /// Retorna `true` quando a contagem do disco aumentou.
  Future<bool> recordTrackPlay({
    required String album,
    required String artist,
    required String track,
    String? trackArtist,
    DateTime? at,
  }) async {
    if (album.trim().isEmpty || track.trim().isEmpty) return false;
    final now = at ?? DateTime.now();
    final key = keyFor(album, artist);
    _plays.add(PlayEvent(album: album, artist: artist, track: track, trackArtist: trackArtist, at: now));
    if (_plays.length > maxPlayEvents) _plays.removeRange(0, _plays.length - maxPlayEvents);

    final old = _stats[key] ?? const DiscStats();
    final newSession = old.lastPlayedAt == null || now.difference(old.lastPlayedAt!) >= sessionGap;
    _stats[key] = DiscStats(
      playCount: old.playCount + (newSession ? 1 : 0),
      firstPlayedAt: old.firstPlayedAt ?? now,
      lastPlayedAt: now,
    );
    notifyListeners();
    await _save();
    return newSession;
  }
}
