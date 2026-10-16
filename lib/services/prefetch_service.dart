import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track_entry.dart';
import '../models/track_info.dart';
import 'lyrics_provider_service.dart';
import 'lrclib_service.dart';
import 'musicbrainz_tracklist_provider.dart';
import 'track_predictor.dart';
import 'tracklist_matcher.dart';
import 'tracklist_provider.dart';
import 'vinyl_cache_service.dart';
import 'wikipedia_tracklist_service.dart';

/// Modelo de faixa com letra e metadados mantida no cache de memória do prefetch.
class PrefetchedTrack {
  final String title;
  final String? artist;
  final String? lrc;
  final double? durationSeconds;
  final String? source;

  /// De qual fonte de letras veio ('lrclib', 'netease'...): sem ela, o painel não reconhece a letra como da
  /// fonte ativa e a letra da próxima faixa só aparecia depois da confirmação pelo microfone.
  final String? lyricsSource;
  final DateTime at;

  const PrefetchedTrack({
    required this.title,
    this.artist,
    this.lrc,
    this.durationSeconds,
    this.source,
    this.lyricsSource,
    required this.at,
  });
}

/// Serviço responsável pelo pré-carregamento orientado ao preditor determinístico e letras.
class PrefetchService {
  final LyricsProviderService _lyricsService;
  final VinylCacheService _cacheService;
  final TracklistProvider _provider;
  final TrackPredictor _predictor;

  /// Minutagem do LP pela Wikipedia (completa as durações do disco detectado).
  final WikipediaTracklistService? _wikipedia;

  /// Cache em memória das faixas e letras pré-carregadas. Chave canônica: 'artista|titulo'.
  final Map<String, PrefetchedTrack> _prefetchedTracks = {};

  /// Fontes alternativas de tracklists carregadas durante a sessão.
  final List<PredictionSource> _sessionAlternativeSources = [];

  /// Último resultado de predição gerado.
  PredictionResult? _lastPrediction;

  /// Retorna o último resultado de predição.
  PredictionResult? get lastPrediction => _lastPrediction;

  /// Tracklist oficial do disco em reprodução na sessão atual.
  List<TrackEntry> _currentDiscTracklist = [];

  /// Retorna cópia imutável da tracklist do disco atual.
  List<TrackEntry> get currentDiscTracklist => List.unmodifiable(_currentDiscTracklist);

  /// Token de geração para abortar prefetch se a faixa mudar no meio.
  int _generation = 0;

  PrefetchService({
    LyricsProviderService? lyricsService,
    LrcLibService? lrcLibService,
    required VinylCacheService cacheService,
    TracklistProvider? tracklistProvider,
    TrackPredictor? trackPredictor,
    WikipediaTracklistService? wikipedia,
    http.Client? client,
  })  : _lyricsService = lyricsService ?? LyricsProviderService(lrcLibService: lrcLibService),
        _cacheService = cacheService,
        _provider = tracklistProvider ?? MusicBrainzTracklistProvider(client: client),
        _predictor = trackPredictor ?? TrackPredictor(),
        _wikipedia = wikipedia;

  /// Executa o ciclo completo de predição e pré-carregamento de letras para a faixa atual.
  Future<PredictionResult> prefetchFor(
    TrackInfo current, {
    String? lockedAlbumName,
    List<String> confirmedTitles = const [],
    void Function(PredictionResult)? onPrediction,
    void Function(PredictionCandidate)? onLyricsReady,
  }) async {
    final myGen = ++_generation;
    try {
      debugPrint('[PrefetchService] 🔄 prefetchFor "${current.title}" de "${current.artist}" (gen: $myGen, travado: ${lockedAlbumName ?? "não"})');

      // 1. Montar PredictionSources a partir do cache e alternativas de sessão
      final sources = <PredictionSource>[];

      final cachedDiscs = _cacheService.getAllDiscs();
      for (final disc in cachedDiscs) {
        if (disc.tracklist.isEmpty) continue;
        final idx = TracklistMatcher.findIndex(disc.tracklist, current.title);
        if (idx != -1) {
          final isLocked = (lockedAlbumName != null &&
              TracklistMatcher.normalize(disc.album) == TracklistMatcher.normalize(lockedAlbumName));
          final isPref = isLocked ||
              _cacheService.getPreferredAlbum(current.title, current.artist) == disc.album;
          sources.add(PredictionSource(
            albumTitle: disc.album,
            releaseId: disc.releaseId,
            entries: disc.tracklist,
            sideSource: disc.sideSource,
            isPreferred: isPref,
            isChosen: true,
            isVinyl: (disc.releaseFormat ?? '').toLowerCase().contains('vinyl'),
          ));
        }
      }

      // Adicionar alternativas de sessão já carregadas
      for (final alt in _sessionAlternativeSources) {
        if (!sources.any((s) => s.albumTitle == alt.albumTitle)) {
          final idx = TracklistMatcher.findIndex(alt.entries, current.title);
          if (idx != -1) {
            sources.add(alt);
          }
        }
      }

      // 2. Se nenhuma fonte contém a faixa, consultar provedor de catálogo na rede
      if (sources.isEmpty) {
        debugPrint('[PrefetchService] 🌐 Consultando catálogo oficial na rede para: "${current.title}"');
        final candidates = await _provider.searchReleases(
          title: current.title,
          artist: current.artist,
          album: current.album,
        );
        if (_generation != myGen) return const PredictionResult();

        ReleaseCandidate? winner;
        List<TrackEntry>? winnerEntries;
        int highestScore = -1;

        // Prensagens em vinil (LP/EP) primeiro; outros formatos só se não houver nenhuma
        final vinyl = vinylLpOrEpOnly(candidates);
        final pool = vinyl.isNotEmpty ? vinyl : candidates;

        for (int i = 0; i < min(3, pool.length); i++) {
          final cand = pool[i];
          final entries = await _provider.loadTracklist(cand);
          if (_generation != myGen) return const PredictionResult();

          final matchIdx = TracklistMatcher.findIndex(entries, current.title);
          if (matchIdx != -1) {
            int score = 20;
            final fmt = (cand.format ?? '').toLowerCase();
            if (fmt.contains('vinyl') || fmt.contains('lp')) score += 25;
            // Edição deluxe (remixes, backing tracks...) perde para o LP original: os lados ficam errados nela
            score -= originalEditionPenalty(entries);

            final predSource = PredictionSource(
              albumTitle: cand.albumTitle,
              releaseId: cand.releaseId,
              entries: entries,
              sideSource: 'none',
              isVinyl: fmt.contains('vinyl') || fmt.contains('lp'),
            );

            if (score > highestScore) {
              highestScore = score;
              winner = cand;
              winnerEntries = entries;
            } else {
              _sessionAlternativeSources.add(predSource);
            }
            sources.add(predSource);
          }
        }

        if (winner != null && winnerEntries != null && winnerEntries.isNotEmpty) {
          // Minutagem do LP: a Wikipedia completa as durações que faltam (e substitui as de discos que não são vinil)
          final wikipedia = _wikipedia;
          if (wikipedia != null && !winner.isCompilation) {
            final filled = await wikipedia.fillDurations(
              winnerEntries,
              artist: current.artist,
              album: winner.albumTitle,
              override: !winner.isVinyl,
            );
            if (_generation != myGen) return const PredictionResult();
            if (!identical(filled, winnerEntries)) {
              final releaseId = winner.releaseId;
              final i = sources.indexWhere((s) => s.releaseId == releaseId);
              if (i != -1) {
                final old = sources[i];
                sources[i] = PredictionSource(
                  albumTitle: old.albumTitle,
                  releaseId: old.releaseId,
                  entries: filled,
                  sideSource: old.sideSource,
                  isVinyl: old.isVinyl,
                );
              }
              winnerEntries = filled;
            }
          }
          await _cacheService.saveTracklist(
            album: current.album ?? winner.albumTitle,
            artist: current.artist,
            entries: winnerEntries,
            releaseId: winner.releaseId,
            releaseFormat: winner.format,
            source: winner.providerId,
          );
        }
      }

      if (_generation != myGen) return const PredictionResult();

      // 3. Executar o preditor determinístico
      final prediction = _predictor.predict(
        currentTitle: current.title,
        sources: sources,
        confirmedTitles: confirmedTitles,
      );
      _lastPrediction = prediction;

      if (prediction.current != null) {
        for (final s in sources) {
          if (s.entries.any((e) => e.title == prediction.current!.title)) {
            _currentDiscTracklist = s.entries;
            break;
          }
        }
      }

      onPrediction?.call(prediction);

      // 4. Pré-carregar letras em ordem de prioridade (máximo 3 por troca de faixa)
      final candidatesToFetch = prediction.candidates.take(3).toList();
      for (final cand in candidatesToFetch) {
        if (_generation != myGen) break;
        final trackTitle = cand.entry.title;
        // Coletâneas e trilhas de novela: cada faixa tem o seu artista
        final artist = cand.entry.artist ?? current.artist;
        final key = TracklistMatcher.key(artist, trackTitle);

        // 4a. Já em memória?
        if (_prefetchedTracks.containsKey(key) && _prefetchedTracks[key]?.lrc != null) {
          onLyricsReady?.call(cand);
          continue;
        }

        // 4b. Já no cache em disco?
        final diskLrc = _cacheService.findCachedLyrics(trackTitle, artist);
        if (diskLrc != null && diskLrc.isNotEmpty) {
          _prefetchedTracks[key] = PrefetchedTrack(
            title: trackTitle,
            artist: artist,
            lrc: diskLrc,
            source: 'cache',
            lyricsSource: _cacheService.getLyricsSource(trackTitle, artist),
            at: DateTime.now(),
          );
          onLyricsReady?.call(cand);
          continue;
        }

        // 4c. Cache negativo recente (< 7 dias)?
        if (_cacheService.isLyricsMissingRecent(trackTitle, artist)) {
          debugPrint('[PrefetchService] ⏭️ Cache negativo ativo para "$trackTitle" (pula busca)');
          continue;
        }

        // 4d. Buscar na cascata
        final lrcDetails = await _lyricsService.fetchLyricsDetails(
          trackName: trackTitle,
          artistName: artist,
          // O nome da coletânea atrapalha a busca da letra da gravação original
          albumName: cand.entry.artist != null ? null : cand.albumTitle,
        );
        if (_generation != myGen) break;

        if (lrcDetails != null &&
            lrcDetails.syncedLyrics != null &&
            lrcDetails.syncedLyrics!.isNotEmpty) {
          _prefetchedTracks[key] = PrefetchedTrack(
            title: trackTitle,
            artist: artist,
            lrc: lrcDetails.syncedLyrics,
            durationSeconds: lrcDetails.durationSeconds,
            source: 'network',
            lyricsSource: lrcDetails.source,
            at: DateTime.now(),
          );

          final pTrack = TrackInfo(
            title: trackTitle,
            artist: artist,
            album: cand.albumTitle,
            durationMs: lrcDetails.durationSeconds != null
                ? (lrcDetails.durationSeconds! * 1000).toInt()
                : null,
            offsetSeconds: 0.0,
          );
          await _cacheService.cacheTrack(pTrack, lrcDetails.syncedLyrics);
          onLyricsReady?.call(cand);
          debugPrint('[PrefetchService] ⚡ Letra pronta via cascata: "$trackTitle" (${cand.kind})');
        } else {
          await _cacheService.markLyricsMissing(trackTitle, artist);
          debugPrint('[PrefetchService] ⚠️ Sem letra para "$trackTitle", marcado cache negativo');
        }
      }

      return prediction;
    } catch (e) {
      debugPrint('[PrefetchService] Erro em prefetchFor: $e');
      return const PredictionResult();
    }
  }

  /// Retorna o objeto pré-carregado em memória, se disponível.
  PrefetchedTrack? getPrefetched(String title, [String? artist]) {
    if (artist != null) {
      final key = TracklistMatcher.key(artist, title);
      return _prefetchedTracks[key];
    }
    for (final track in _prefetchedTracks.values) {
      if (TracklistMatcher.isSameTitle(track.title, title)) {
        return track;
      }
    }
    return null;
  }

  /// Verifica se já possui letras em memória para uma faixa.
  bool hasLyricsFor(String title, [String? artist]) {
    final pref = getPrefetched(title, artist);
    return pref != null && pref.lrc != null && pref.lrc!.isNotEmpty;
  }

  /// Retorna o título da próxima faixa prevista.
  String? getPredictedNextTitle(String currentTitle, String currentArtist) {
    return _lastPrediction?.primaryCandidate?.entry.title;
  }

  /// Chamado na troca de faixa: mantém a tracklist do disco e limpa letras excedentes.
  void onTrackChanged() {
    if (_prefetchedTracks.length > 8) {
      _prefetchedTracks.clear();
    }
  }

  /// Limpa a sessão por completo (ao parar reprodução ou descartar engine).
  void clearSession() {
    _generation++;
    _prefetchedTracks.clear();
    _currentDiscTracklist = [];
    _sessionAlternativeSources.clear();
    _lastPrediction = null;
    debugPrint('[PrefetchService] 🗑️ Sessão do prefetch limpa.');
  }

  /// Desambigua o álbum físico cruzando as faixas confirmadas na sessão em ordem sequencial estrita.
  Future<AlbumResolutionResult?> resolveAlbumCover({
    TrackInfo? firstTrack,
    TrackInfo? secondTrack,
    List<TrackInfo>? sessionTracks,
  }) async {
    final tracks = sessionTracks ?? [
      if (firstTrack != null) firstTrack,
      if (secondTrack != null) secondTrack,
    ];
    if (tracks.isEmpty) return null;

    final titles = tracks.map((t) => t.title).toList();
    final artist = tracks.first.artist;

    try {
      debugPrint('[PrefetchService] 🔍 Desambiguando álbum para ${titles.length} faixas em sequência: ${titles.join(" ➔ ")}');

      final cached = _cacheService.findDiscContainingTracks(titles, artist);
      if (cached != null && cached.coverUrl != null && cached.coverUrl!.isNotEmpty) {
        debugPrint('[PrefetchService] ✅ Álbum identificado no cache com ordem exata: "${cached.album}"');
        return AlbumResolutionResult(
          albumName: cached.album,
          coverUrl: cached.coverUrl,
          tracklist: cached.tracklist,
        );
      }

      final candidates = await _provider.searchReleases(
        title: titles.first,
        artist: artist,
      );

      // Entre os que batem com a ordem tocada, fica o mais próximo do LP original: uma edição deluxe
      // (remixes, backing tracks antes das faixas originais) também "bate", mas traz os lados errados
      ReleaseCandidate? best;
      List<TrackEntry>? bestEntries;
      var bestPenalty = 1 << 30;
      for (int i = 0; i < min(6, candidates.length); i++) {
        final cand = candidates[i];
        final entries = await _provider.loadTracklist(cand);

        final isMatch = TracklistMatcher.isSequentialMatch(entries, titles);
        if (isMatch) {
          final penalty = originalEditionPenalty(entries) - (cand.isVinyl ? 5 : 0);
          if (penalty < bestPenalty) {
            best = cand;
            bestEntries = entries;
            bestPenalty = penalty;
          }
          if (bonusVersionCount(entries) == 0 && entries.length <= 20) break; // já é o LP original
        } else {
          debugPrint('[PrefetchService] ⏭️ Candidato "${cand.albumTitle}" descartado: ordem das faixas não corresponde à sequência tocada.');
        }
      }
      if (best != null && bestEntries != null) {
        final coverUrl = 'https://coverartarchive.org/release/${best.releaseId}/front-250';
        debugPrint('[PrefetchService] 🎯 Álbum retificado com precisão (ordem de ${titles.length} faixas confirmada): "${best.albumTitle}" (capa: $coverUrl)');
        return AlbumResolutionResult(
          albumName: best.albumTitle,
          coverUrl: coverUrl,
          tracklist: bestEntries,
        );
      }
    } catch (e) {
      debugPrint('[PrefetchService] Erro na resolução de álbum: $e');
    }
    return null;
  }

  void dispose() {
    _provider.dispose();
  }
}

/// Resultado da desambiguação de álbum quando múltiplas músicas são identificadas.
class AlbumResolutionResult {
  final String albumName;
  final String? coverUrl;
  final List<TrackEntry> tracklist;

  const AlbumResolutionResult({
    required this.albumName,
    this.coverUrl,
    this.tracklist = const [],
  });
}
