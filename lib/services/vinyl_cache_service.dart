import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track_entry.dart';
import '../models/track_info.dart';
import 'side_estimator.dart';
import 'tracklist_matcher.dart';

/// Modelo que representa uma faixa (música) armazenada em cache.
class CachedTrack {
  final String title;
  final String artist;
  final String? album;
  final String? lrcContent;
  final int? durationMs;
  final double? shazamOffset;
  final String? coverUrl;

  /// Álbum preferencial do usuário para esta faixa.
  /// Definido automaticamente após 2+ faixas consecutivas confirmarem o mesmo disco.
  final String? preferredAlbum;

  /// Origem do álbum preferencial: 'user' (escolhido em "Mudar disco") ou 'sequence' (3 faixas seguidas
  /// confirmadas na ordem do disco). Registros antigos, sem origem, contam como 'sequence'.
  final String? preferredAlbumSource;

  /// Data em que a busca de letras foi realizada sem sucesso (cache negativo por 7 dias).
  final DateTime? lyricsMissingSince;

  /// Deslocamento manual da letra em milissegundos ajustado via nudge (padrão 0).
  final int lyricOffsetMs;

  /// Fonte de onde a letra foi obtida ('lrclib' | 'netease' | 'megalobiz').
  final String? lyricsSource;

  CachedTrack({
    required this.title,
    required this.artist,
    this.album,
    this.lrcContent,
    this.durationMs,
    this.shazamOffset,
    this.coverUrl,
    this.preferredAlbum,
    this.preferredAlbumSource,
    this.lyricsMissingSince,
    this.lyricOffsetMs = 0,
    this.lyricsSource,
  });

  CachedTrack copyWith({
    String? title,
    String? artist,
    String? album,
    String? lrcContent,
    int? durationMs,
    double? shazamOffset,
    String? coverUrl,
    String? preferredAlbum,
    String? preferredAlbumSource,
    DateTime? lyricsMissingSince,
    int? lyricOffsetMs,
    String? lyricsSource,
  }) {
    return CachedTrack(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      lrcContent: lrcContent ?? this.lrcContent,
      durationMs: durationMs ?? this.durationMs,
      shazamOffset: shazamOffset ?? this.shazamOffset,
      coverUrl: coverUrl ?? this.coverUrl,
      preferredAlbum: preferredAlbum ?? this.preferredAlbum,
      preferredAlbumSource: preferredAlbumSource ?? this.preferredAlbumSource,
      lyricsMissingSince: lyricsMissingSince ?? this.lyricsMissingSince,
      lyricOffsetMs: lyricOffsetMs ?? this.lyricOffsetMs,
      lyricsSource: lyricsSource ?? this.lyricsSource,
    );
  }

  factory CachedTrack.fromJson(Map<String, dynamic> json) {
    return CachedTrack(
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String?,
      lrcContent: json['lrcContent'] as String?,
      durationMs: json['durationMs'] as int?,
      shazamOffset: (json['shazamOffset'] as num?)?.toDouble(),
      coverUrl: json['coverUrl'] as String?,
      preferredAlbum: json['preferredAlbum'] as String?,
      preferredAlbumSource: json['preferredAlbumSource'] as String?,
      lyricsMissingSince: json['lyricsMissingSince'] != null
          ? DateTime.tryParse(json['lyricsMissingSince'] as String)
          : null,
      lyricOffsetMs: (json['lyricOffsetMs'] as num?)?.toInt() ?? 0,
      lyricsSource: json['lyricsSource'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'lrcContent': lrcContent,
      'durationMs': durationMs,
      'shazamOffset': shazamOffset,
      'coverUrl': coverUrl,
      'preferredAlbum': preferredAlbum,
      if (preferredAlbumSource != null) 'preferredAlbumSource': preferredAlbumSource,
      if (lyricsMissingSince != null)
        'lyricsMissingSince': lyricsMissingSince!.toIso8601String(),
      if (lyricOffsetMs != 0) 'lyricOffsetMs': lyricOffsetMs,
      if (lyricsSource != null) 'lyricsSource': lyricsSource,
    };
  }
}

/// Modelo que representa um disco de vinil armazenado em cache.
class CachedDisc {
  final String album;
  final String artist;
  final List<CachedTrack> tracks;
  final List<TrackEntry> tracklist;
  final String? coverUrl;
  final double? averagePitch;
  final DateTime? lastPlayedAt;
  final String? releaseId;
  final String? releaseFormat;
  final String? tracklistSource;
  final String sideSource; // 'catalog' | 'estimated' | 'none'

  CachedDisc({
    required this.album,
    required this.artist,
    required this.tracks,
    this.tracklist = const [],
    this.coverUrl,
    this.averagePitch,
    this.lastPlayedAt,
    this.releaseId,
    this.releaseFormat,
    this.tracklistSource,
    this.sideSource = 'none',
  });

  CachedDisc copyWith({
    String? album,
    String? artist,
    List<CachedTrack>? tracks,
    List<TrackEntry>? tracklist,
    String? coverUrl,
    double? averagePitch,
    DateTime? lastPlayedAt,
    String? releaseId,
    String? releaseFormat,
    String? tracklistSource,
    String? sideSource,
  }) {
    return CachedDisc(
      album: album ?? this.album,
      artist: artist ?? this.artist,
      tracks: tracks ?? this.tracks,
      tracklist: tracklist ?? this.tracklist,
      coverUrl: coverUrl ?? this.coverUrl,
      averagePitch: averagePitch ?? this.averagePitch,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      releaseId: releaseId ?? this.releaseId,
      releaseFormat: releaseFormat ?? this.releaseFormat,
      tracklistSource: tracklistSource ?? this.tracklistSource,
      sideSource: sideSource ?? this.sideSource,
    );
  }

  factory CachedDisc.fromJson(Map<String, dynamic> json) {
    var tracksJson = json['tracks'] as List? ?? [];
    List<CachedTrack> tracks = tracksJson.map((t) => CachedTrack.fromJson(t)).toList();

    var tracklistJson = json['tracklist'] as List? ?? [];
    List<TrackEntry> tracklist =
        tracklistJson.map((t) => TrackEntry.fromJson(t as Map<String, dynamic>)).toList();

    return CachedDisc(
      album: json['album'] as String,
      artist: json['artist'] as String,
      tracks: tracks,
      tracklist: tracklist,
      coverUrl: json['coverUrl'] as String?,
      averagePitch: (json['averagePitch'] as num?)?.toDouble(),
      lastPlayedAt: json['lastPlayedAt'] != null ? DateTime.parse(json['lastPlayedAt'] as String) : null,
      releaseId: json['releaseId'] as String?,
      releaseFormat: json['releaseFormat'] as String?,
      tracklistSource: json['tracklistSource'] as String?,
      sideSource: json['sideSource'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'album': album,
      'artist': artist,
      'tracks': tracks.map((t) => t.toJson()).toList(),
      'tracklist': tracklist.map((t) => t.toJson()).toList(),
      'coverUrl': coverUrl,
      'averagePitch': averagePitch,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      if (releaseId != null) 'releaseId': releaseId,
      if (releaseFormat != null) 'releaseFormat': releaseFormat,
      if (tracklistSource != null) 'tracklistSource': tracklistSource,
      'sideSource': sideSource,
    };
  }
}

/// Estado calibrado do toca-discos persistido entre sessões.
class CachedTurntableState {
  /// Incerteza assumida para registros antigos (antes da v1.1.10), que não guardavam o desvio-padrão.
  /// Moderada de propósito: valores travados em 1.000x pela zona morta antiga são corrigidos rapidamente.
  static const double legacyStdDev = 0.005;

  final double lastStableSpeedFactor;
  final DateTime updatedAt;

  /// Desvio-padrão da estimativa de rotação (ex.: 0.002 = ±0.2%).
  final double stdDev;

  CachedTurntableState({
    required this.lastStableSpeedFactor,
    required this.updatedAt,
    this.stdDev = legacyStdDev,
  });

  factory CachedTurntableState.fromJson(Map<String, dynamic> json) {
    return CachedTurntableState(
      lastStableSpeedFactor: (json['lastStableSpeedFactor'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      stdDev: (json['stdDev'] as num?)?.toDouble() ?? legacyStdDev,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastStableSpeedFactor': lastStableSpeedFactor,
      'updatedAt': updatedAt.toIso8601String(),
      'stdDev': stdDev,
    };
  }
}

/// Modelo que representa a coleção completa de discos de vinil.
class VinylCollection {
  final int schemaVersion;
  final List<CachedDisc> discs;
  final CachedTurntableState? turntable;

  VinylCollection({
    this.schemaVersion = 2,
    required this.discs,
    this.turntable,
  });

  factory VinylCollection.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    var discsJson = json['discs'] as List? ?? [];
    List<CachedDisc> discs = discsJson.map((d) => CachedDisc.fromJson(d)).toList();
    final turntableJson = json['turntable'] as Map<String, dynamic>?;
    final turntable = turntableJson != null ? CachedTurntableState.fromJson(turntableJson) : null;

    return VinylCollection(
      schemaVersion: version,
      discs: discs,
      turntable: turntable,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'discs': discs.map((d) => d.toJson()).toList(),
      if (turntable != null) 'turntable': turntable!.toJson(),
    };
  }
}

/// Serviço responsável por persistir e recuperar a coleção de vinis e suas informações.
class VinylCacheService {
  static const String _fileName = 'vinyl_collection.json';
  final Directory? _storageDirectory;
  VinylCollection _collection = VinylCollection(schemaVersion: 2, discs: []);

  Future<void>? _saveQueue;

  VinylCacheService({Directory? storageDirectory}) : _storageDirectory = storageDirectory;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Retorna o estado persistido de velocidade calibrada da vitrola.
  CachedTurntableState? get turntableState => _collection.turntable;

  /// Salva a velocidade estimada do toca-discos e a sua incerteza (desvio-padrão) no cache.
  Future<void> saveTurntableSpeed(double speedFactor, {double stdDev = 0.002}) async {
    _collection = VinylCollection(
      schemaVersion: _collection.schemaVersion,
      discs: _collection.discs,
      turntable: CachedTurntableState(
        lastStableSpeedFactor: speedFactor,
        updatedAt: DateTime.now(),
        stdDev: stdDev,
      ),
    );
    await _enqueueSave();
  }

  /// Retorna o deslocamento de letra salvo em milissegundos para a faixa.
  int getLyricOffsetMs(String title, String artist) {
    final track = findCachedTrack(title, artist);
    return track?.lyricOffsetMs ?? 0;
  }

  /// Salva o deslocamento manual de letra (nudge) para uma faixa específica.
  Future<void> saveLyricOffset(String title, String artist, int offsetMs) async {
    for (final disc in _collection.discs) {
      for (int i = 0; i < disc.tracks.length; i++) {
        final t = disc.tracks[i];
        if (TracklistMatcher.isSameTrack(t.title, t.artist, title, artist)) {
          disc.tracks[i] = t.copyWith(lyricOffsetMs: offsetMs);
          await _enqueueSave();
          return;
        }
      }
    }
    // Se a faixa ainda não existe em nenhum disco, cria um registro básico para persistir
    await cacheTrack(TrackInfo(title: title, artist: artist, offsetSeconds: 0.0), null);
    for (final disc in _collection.discs) {
      for (int i = 0; i < disc.tracks.length; i++) {
        final t = disc.tracks[i];
        if (TracklistMatcher.isSameTrack(t.title, t.artist, title, artist)) {
          disc.tracks[i] = t.copyWith(lyricOffsetMs: offsetMs);
          await _enqueueSave();
          return;
        }
      }
    }
  }

  /// Retorna a fonte de letras preferencial salva para a faixa.
  String? getLyricsSource(String title, String artist) {
    final track = findCachedTrack(title, artist);
    return track?.lyricsSource;
  }

  /// Salva a fonte de onde a letra foi obtida com sucesso.
  Future<void> saveLyricsSource(String title, String artist, String source) async {
    for (final disc in _collection.discs) {
      for (int i = 0; i < disc.tracks.length; i++) {
        final t = disc.tracks[i];
        if (TracklistMatcher.isSameTrack(t.title, t.artist, title, artist)) {
          disc.tracks[i] = t.copyWith(lyricsSource: source);
          await _enqueueSave();
          return;
        }
      }
    }
    // Se a faixa ainda não existe em nenhum disco, cria um registro básico para persistir
    await cacheTrack(TrackInfo(title: title, artist: artist, offsetSeconds: 0.0), null);
    for (final disc in _collection.discs) {
      for (int i = 0; i < disc.tracks.length; i++) {
        final t = disc.tracks[i];
        if (TracklistMatcher.isSameTrack(t.title, t.artist, title, artist)) {
          disc.tracks[i] = t.copyWith(lyricsSource: source);
          await _enqueueSave();
          return;
        }
      }
    }
  }

  /// Inicializa o serviço carregando a coleção do disco.
  Future<void> init() async {
    if (_isInitialized) return;
    await _load();
    _isInitialized = true;
  }

  /// Retorna o conteúdo da letra (.lrc) em cache, se disponível, para a música especificada.
  String? findCachedLyrics(String title, String artist) {
    for (var disc in _collection.discs) {
      for (var track in disc.tracks) {
        if (TracklistMatcher.isSameTrack(track.title, track.artist, title, artist)) {
          return track.lrcContent;
        }
      }
    }
    return null;
  }

  /// Retorna a faixa em cache, se disponível, para a música especificada.
  CachedTrack? findCachedTrack(String title, String artist) {
    for (var disc in _collection.discs) {
      for (var track in disc.tracks) {
        if (TracklistMatcher.isSameTrack(track.title, track.artist, title, artist)) {
          return track;
        }
      }
    }
    return null;
  }

  /// Verifica se a busca de letras para esta música falhou recentemente (< 7 dias).
  bool isLyricsMissingRecent(String title, String artist) {
    for (final disc in _collection.discs) {
      for (final track in disc.tracks) {
        if (TracklistMatcher.isSameTrack(track.title, track.artist, title, artist)) {
          if (track.lyricsMissingSince != null) {
            final diff = DateTime.now().difference(track.lyricsMissingSince!);
            if (diff.inDays < 7) return true;
          }
        }
      }
    }
    return false;
  }

  /// Registra falha de busca de letras para ativar cache negativo de 7 dias.
  Future<void> markLyricsMissing(String title, String artist) async {
    for (final disc in _collection.discs) {
      for (int i = 0; i < disc.tracks.length; i++) {
        final t = disc.tracks[i];
        if (TracklistMatcher.isSameTrack(t.title, t.artist, title, artist)) {
          disc.tracks[i] = t.copyWith(lyricsMissingSince: DateTime.now());
          await _enqueueSave();
          return;
        }
      }
    }
  }

  /// Retorna o disco em cache, se disponível, dado o álbum e artista.
  CachedDisc? findCachedDisc(String album, String artist) {
    final normAlbum = TracklistMatcher.normalize(album);
    if (normAlbum.isEmpty || normAlbum == 'unknown album') return null;

    for (var disc in _collection.discs) {
      if (TracklistMatcher.normalize(disc.album) == normAlbum &&
          TracklistMatcher.isSameArtist(disc.artist, artist)) {
        return disc;
      }
    }
    return null;
  }

  /// Localiza um disco cuja tracklist oficial contém a faixa especificada.
  /// Ignora discos identificados como 'Unknown Album'.
  CachedDisc? findDiscWithTrack(String title, String artist) {
    for (var disc in _collection.discs) {
      if (TracklistMatcher.normalize(disc.album) == 'unknown album') continue;
      if (!TracklistMatcher.isSameArtist(disc.artist, artist)) continue;

      if (TracklistMatcher.findIndex(disc.tracklist, title) != -1) {
        return disc;
      }
    }
    return null;
  }

  /// Retorna a tracklist oficial (ordem sequencial de catálogo) do álbum especificado.
  /// Se o disco não possuir tracklist oficial cadastrada, retorna lista vazia.
  List<TrackEntry> getTracklist(String album, String artist) {
    var disc = findCachedDisc(album, artist);
    if (disc != null) {
      return disc.tracklist;
    }
    return [];
  }

  /// Salva ou substitui integralmente a tracklist de um disco de forma isolada.
  Future<void> saveTracklist({
    required String album,
    required String artist,
    required List<TrackEntry> entries,
    String? releaseId,
    String? releaseFormat,
    required String source,
    String? sideSource,
  }) async {
    final sideRes = SideEstimator.resolveSides(entries);
    final effectiveEntries = sideRes.entries;
    final effectiveSideSource = (sideSource != null && sideSource.isNotEmpty && sideSource != 'none')
        ? sideSource
        : sideRes.sideSource;

    var disc = findCachedDisc(album, artist);
    if (disc == null) {
      disc = CachedDisc(
        album: album,
        artist: artist,
        tracks: [],
        tracklist: effectiveEntries,
        releaseId: releaseId,
        releaseFormat: releaseFormat,
        tracklistSource: source,
        sideSource: effectiveSideSource,
      );
      _collection.discs.add(disc);
    } else {
      final updated = disc.copyWith(
        tracklist: effectiveEntries,
        releaseId: releaseId ?? disc.releaseId,
        releaseFormat: releaseFormat ?? disc.releaseFormat,
        tracklistSource: source,
        sideSource: effectiveSideSource,
      );
      final index = _collection.discs.indexOf(disc);
      _collection.discs[index] = updated;
    }

    await _enqueueSave();
    debugPrint(
      '[VinylCacheService] 💾 Tracklist oficial de "$album" (${effectiveEntries.length} faixas, fonte: $source, lados: $effectiveSideSource) persistida.',
    );
  }

  /// Armazena em cache (ou atualiza) uma faixa e o seu respectivo disco,
  /// preservando campos existentes como preferredAlbum, lrcContent anterior e coverUrl.
  Future<void> cacheTrack(TrackInfo track, String? lrcContent) async {
    final albumName = track.album ?? 'Unknown Album';
    final artistName = track.artist;

    var disc = findCachedDisc(albumName, artistName);

    CachedTrack? existingTrack;
    if (disc != null) {
      final idx = disc.tracks.indexWhere(
        (t) => TracklistMatcher.isSameTitle(t.title, track.title),
      );
      if (idx >= 0) {
        existingTrack = disc.tracks[idx];
      }
    }

    // Preservar valores antigos se o novo vier nulo ou vazio
    final effectiveLrc = (lrcContent != null && lrcContent.isNotEmpty)
        ? lrcContent
        : (track.lrcContent != null && track.lrcContent!.isNotEmpty)
            ? track.lrcContent
            : existingTrack?.lrcContent;

    final effectiveCover = track.coverUrl ?? existingTrack?.coverUrl;
    final effectiveDuration = track.durationMs ?? existingTrack?.durationMs;
    final effectivePrefAlbum = existingTrack?.preferredAlbum;

    final newTrack = CachedTrack(
      title: track.title,
      artist: track.artist,
      album: track.album,
      lrcContent: effectiveLrc,
      durationMs: effectiveDuration,
      shazamOffset: track.offsetSeconds,
      coverUrl: effectiveCover,
      preferredAlbum: effectivePrefAlbum,
    );

    if (disc == null) {
      disc = CachedDisc(
        album: albumName,
        artist: artistName,
        tracks: [newTrack],
        coverUrl: effectiveCover,
        lastPlayedAt: DateTime.now(),
      );
      _collection.discs.add(disc);
    } else {
      int trackIndex = disc.tracks.indexWhere(
        (t) => TracklistMatcher.isSameTitle(t.title, track.title),
      );
      if (trackIndex >= 0) {
        disc.tracks[trackIndex] = newTrack;
      } else {
        disc.tracks.add(newTrack);
      }
    }

    // A mesma faixa pode existir em outros discos (ex.: "Unknown Album" de uma sessão anterior). Uma letra
    // sincronizada nova substitui as cópias vazias ou em texto simples, que de outro modo seriam encontradas
    // primeiro nas buscas e manteriam a letra antiga.
    if (effectiveLrc != null && _hasLrcTimestamps(effectiveLrc)) {
      for (final other in _collection.discs) {
        for (int i = 0; i < other.tracks.length; i++) {
          final t = other.tracks[i];
          if (identical(t, newTrack)) continue;
          if (!TracklistMatcher.isSameTrack(t.title, t.artist, track.title, track.artist)) continue;
          if (t.lrcContent == null || !_hasLrcTimestamps(t.lrcContent!)) {
            other.tracks[i] = t.copyWith(lrcContent: effectiveLrc);
          }
        }
      }
    }

    await _enqueueSave();
  }

  static final RegExp _lrcTimestamp = RegExp(r'\[\d{1,3}:\d{2}');
  static bool _hasLrcTimestamps(String content) => _lrcTimestamp.hasMatch(content);

  /// Armazena em cache (ou atualiza) um disco inteiro.
  Future<void> cacheDisc(CachedDisc disc) async {
    int index = _collection.discs.indexWhere((d) =>
        TracklistMatcher.normalize(d.album) == TracklistMatcher.normalize(disc.album) &&
        TracklistMatcher.isSameArtist(d.artist, disc.artist));

    if (index >= 0) {
      _collection.discs[index] = disc;
    } else {
      _collection.discs.add(disc);
    }

    await _enqueueSave();
  }

  /// Retorna todos os discos em cache.
  List<CachedDisc> getAllDiscs() {
    return _collection.discs;
  }

  /// Retorna o álbum preferencial do usuário para uma dada música.
  String? getPreferredAlbum(String title, String artist) {
    for (final disc in _collection.discs) {
      for (final track in disc.tracks) {
        if (TracklistMatcher.isSameTrack(track.title, track.artist, title, artist) &&
            track.preferredAlbum != null) {
          return track.preferredAlbum;
        }
      }
    }
    return null;
  }

  /// Origem do álbum preferencial da música: 'user', 'sequence' ou `null` sem preferência.
  String? getPreferredAlbumSource(String title, String artist) {
    for (final disc in _collection.discs) {
      for (final track in disc.tracks) {
        if (TracklistMatcher.isSameTrack(track.title, track.artist, title, artist) &&
            track.preferredAlbum != null) {
          return track.preferredAlbumSource ?? 'sequence';
        }
      }
    }
    return null;
  }

  void _applyPreferredAlbumInMemory(String title, String artist, String albumName, String source) {
    for (final disc in _collection.discs) {
      for (int i = 0; i < disc.tracks.length; i++) {
        final t = disc.tracks[i];
        if (TracklistMatcher.isSameTrack(t.title, t.artist, title, artist)) {
          // A escolha do usuário não é sobrescrita pela confirmação automática por sequência
          if (source != 'user' && t.preferredAlbumSource == 'user' && t.preferredAlbum != albumName) return;
          disc.tracks[i] = t.copyWith(preferredAlbum: albumName, preferredAlbumSource: source);
          return;
        }
      }
    }

    final existingData = findCachedTrack(title, artist);

    var disc = findCachedDisc(albumName, artist);
    if (disc != null) {
      disc.tracks.add(CachedTrack(
        title: title,
        artist: artist,
        album: albumName,
        preferredAlbum: albumName,
        preferredAlbumSource: source,
        lrcContent: existingData?.lrcContent,
        coverUrl: existingData?.coverUrl,
        durationMs: existingData?.durationMs,
        shazamOffset: existingData?.shazamOffset,
        lyricOffsetMs: existingData?.lyricOffsetMs ?? 0,
        lyricsSource: existingData?.lyricsSource,
      ));
    } else {
      disc = CachedDisc(
        album: albumName,
        artist: artist,
        tracks: [
          CachedTrack(
            title: title,
            artist: artist,
            album: albumName,
            preferredAlbum: albumName,
            preferredAlbumSource: source,
            lrcContent: existingData?.lrcContent,
            coverUrl: existingData?.coverUrl,
            durationMs: existingData?.durationMs,
            shazamOffset: existingData?.shazamOffset,
            lyricOffsetMs: existingData?.lyricOffsetMs ?? 0,
            lyricsSource: existingData?.lyricsSource,
          ),
        ],
        coverUrl: existingData?.coverUrl,
        lastPlayedAt: DateTime.now(),
      );
      _collection.discs.add(disc);
    }
  }

  /// Define o álbum preferencial para uma faixa.
  Future<void> setPreferredAlbum(String title, String artist, String albumName, {String source = 'sequence'}) async {
    _applyPreferredAlbumInMemory(title, artist, albumName, source);
    await _enqueueSave();
    debugPrint('[VinylCacheService] ✅ Álbum preferencial gravado: "$albumName" para "$title"');
  }

  /// Define o álbum preferencial para uma lista de faixas em lote com persistência única (T0.5).
  Future<void> setPreferredAlbumBatch(List<TrackInfo> tracks, String albumName, {String source = 'sequence'}) async {
    if (tracks.isEmpty) return;
    for (final t in tracks) {
      _applyPreferredAlbumInMemory(t.title, t.artist, albumName, source);
    }
    await _enqueueSave();
    debugPrint('[VinylCacheService] ✅ Álbum preferencial gravado em lote (${tracks.length} faixas): "$albumName"');
  }

  /// Localiza um disco no cache que contenha múltiplas faixas especificadas na ordem correta (desambiguação).
  CachedDisc? findDiscContainingTracks(List<String> trackTitles, String artist) {
    if (trackTitles.isEmpty) return null;

    for (var disc in _collection.discs) {
      if (!TracklistMatcher.isSameArtist(disc.artist, artist)) continue;

      // Se o disco possui tracklist oficial cadastrada, valida a ordem sequencial estrita
      if (disc.tracklist.isNotEmpty) {
        if (TracklistMatcher.isSequentialMatch(disc.tracklist, trackTitles)) {
          return disc;
        }
        continue;
      }

      // Fallback para faixas registradas em tracks
      if (disc.tracks.isNotEmpty) {
        final trackEntries = disc.tracks
            .asMap()
            .entries
            .map((e) => TrackEntry(position: e.key + 1, title: e.value.title))
            .toList();
        if (TracklistMatcher.isSequentialMatch(trackEntries, trackTitles)) {
          return disc;
        }
      }
    }
    return null;
  }

  /// Atualiza a capa de um disco existente após retificação, preservando todos os metadados.
  Future<void> updateDiscCover(String album, String artist, String newCoverUrl) async {
    for (var disc in _collection.discs) {
      if (TracklistMatcher.normalize(disc.album) == TracklistMatcher.normalize(album) &&
          TracklistMatcher.isSameArtist(disc.artist, artist)) {
        final updatedDisc = disc.copyWith(
          coverUrl: newCoverUrl,
          tracks: disc.tracks.map((t) => t.copyWith(coverUrl: newCoverUrl)).toList(),
        );
        await cacheDisc(updatedDisc);
        break;
      }
    }
  }

  /// Retorna o diretório base de armazenamento.
  Future<Directory> _getBaseDirectory() async {
    final customDir = _storageDirectory;
    if (customDir != null) return customDir;
    return await getApplicationDocumentsDirectory();
  }

  Future<File> _getFile() async {
    final dir = await _getBaseDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<File> _getTmpFile() async {
    final dir = await _getBaseDirectory();
    return File('${dir.path}/$_fileName.tmp');
  }

  Future<File> _getBakFile() async {
    final dir = await _getBaseDirectory();
    return File('${dir.path}/$_fileName.bak');
  }

  Future<File> _getCorruptFile() async {
    final dir = await _getBaseDirectory();
    return File('${dir.path}/$_fileName.corrupt');
  }

  /// Enfileira gravações para garantir serialização e prevenir concorrência.
  Future<void> _enqueueSave() {
    final next = (_saveQueue ?? Future.value()).then((_) => _atomicSave()).catchError((e) {
      debugPrint('[VinylCacheService] Erro na fila de escrita: $e');
    });
    _saveQueue = next;
    return next;
  }

  /// Gravação atômica: tmp -> bak -> rename.
  Future<void> _atomicSave() async {
    try {
      final file = await _getFile();
      final tmp = await _getTmpFile();
      final bak = await _getBakFile();

      final jsonString = jsonEncode(_collection.toJson());
      await tmp.writeAsString(jsonString, flush: true);

      if (await file.exists()) {
        try {
          await file.copy(bak.path);
        } catch (_) {}
      }

      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('[VinylCacheService] Erro crítico ao salvar cache atômico: $e');
    }
  }

  /// Lê a coleção a partir do arquivo JSON com tolerância a falhas.
  Future<void> _load() async {
    if (_saveQueue != null) {
      await _saveQueue;
    }

    final file = await _getFile();
    final bak = await _getBakFile();
    final corrupt = await _getCorruptFile();

    // 1. Tentar carregar arquivo principal
    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        _collection = VinylCollection.fromJson(jsonMap);
        return;
      } catch (e) {
        debugPrint('[VinylCacheService] ⚠️ Arquivo principal corrompido: $e. Tentando backup...');
      }
    }

    // 2. Tentar carregar backup
    if (await bak.exists()) {
      try {
        final jsonString = await bak.readAsString();
        final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
        _collection = VinylCollection.fromJson(jsonMap);
        debugPrint('[VinylCacheService] ✅ Coleção recuperada do backup (.bak) com sucesso.');
        return;
      } catch (e) {
        debugPrint('[VinylCacheService] ⚠️ Backup (.bak) também corrompido: $e');
      }
    }

    // 3. Se o arquivo principal existe mas falhou junto com o backup, mover para .corrupt
    if (await file.exists()) {
      try {
        await file.rename(corrupt.path);
      } catch (_) {}
    }

    if (_collection.discs.isEmpty) {
      _collection = VinylCollection(schemaVersion: 2, discs: []);
    }
  }

  void dispose() {}
}
