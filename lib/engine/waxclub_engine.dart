import '../l10n/l10n.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/lyric_line.dart';
import '../models/sync_state.dart';
import '../models/track_entry.dart';
import '../models/track_info.dart';
import '../services/audio_record_service.dart';
import '../services/lrc_parser.dart';
import '../services/lrclib_service.dart';
import '../services/lyrics_provider_service.dart';
import '../services/session_log_service.dart';
import '../services/shazam_service.dart';
import '../services/tracklist_matcher.dart';
import '../services/track_predictor.dart';
import '../services/vinyl_cache_service.dart';
import '../services/prefetch_service.dart';
import '../services/wikipedia_tracklist_service.dart';
import '../services/mic_busy_service.dart';
import '../services/audio_level_analyzer.dart';
import '../services/cast_sync_service.dart';
import '../services/soundtrack_catalog.dart';
import 'prediction_tuning.dart';
import 'speed_estimator.dart';

/// Motor central de sincronização de letras e compensação de rotação de discos de vinil.
///
/// Módulo 1 — Smart Listening Scheduler com Modo Preditivo:
///   1ª checagem: identifica a música + timestamp inicial
///   2ª checagem em 15s: calibra RPM / speed factor
///   3ª checagem no meio da música (calculado via duração oficial de estúdio): re-validação com feedback visual
///   Modo Preditivo de Transição:
///     - Ao terminar a faixa atual, exibe IMEDIATAMENTE a próxima faixa do álbum (sem tela em branco)
///     - Em background, confirma silenciosamente com o microfone via Shazam (dupla captura)
///     - Se confirmada: grava o álbum como preferencial permanente do usuário
///     - Se inesperada: corrige a letra imediatamente e retifica o álbum
///     - Se ambas capturas falharem: desliga o microfone e entra em repouso
///
/// Módulo 2 — Cache local (VinylCacheService):
///   Persiste discos, capas retificadas, faixas, .lrc, pitch médio e álbum preferencial em JSON local.
///
/// Módulo 3 — Prefetch inteligente & Desambiguação de Álbum (PrefetchService):
///   Pré-baixa letras e ao identificar 2 faixas consecutivas, desambigua e retifica
///   a capa oficial do álbum físico de vinil via Cover Art Archive / MusicBrainz.
///
/// Módulo 4 — Transmissão sem fio / Cast (CastSyncService):
///   Permite que o smartphone envie em tempo real a letra e o sincronismo para uma TV na rede local.
class WaxClubEngine extends ChangeNotifier {
  final AudioRecordService _recordService;
  final ShazamService _shazamService;
  final LyricsProviderService _lyricsService;
  final VinylCacheService _cacheService;
  final SessionLogService _logService;
  late final PrefetchService _prefetchService;
  final CastSyncService _castService;

  /// Detecta outro app ocupando o microfone (o Android silencia a captura do WaxClub).
  final MicBusyService _micBusyService;
  MicStatus? _lastMicStatus;
  double? _lastPeakDb;

  /// A última captura foi bloqueada por outro app usando o microfone.
  bool get micBlockedByOtherApp => _lastMicStatus?.blocksCapture(_lastPeakDb) ?? false;

  CastSyncService get castService => _castService;
  LrcLibService get lrcLibService => _lyricsService.lrcLibService;
  SessionLogService get logService => _logService;
  VinylCacheService get cacheService => _cacheService;
  PrefetchService get prefetchService => _prefetchService;

  WaxClubEngine({
    AudioRecordService? recordService,
    ShazamService? shazamService,
    LyricsProviderService? lyricsService,
    LrcLibService? lrcLibService,
    VinylCacheService? cacheService,
    SessionLogService? logService,
    CastSyncService? castService,
    PrefetchService? prefetchService,
    SoundtrackCatalog? soundtrackCatalog,
    MicBusyService? micBusyService,
  })  : _recordService = recordService ?? AudioRecordService(),
        _shazamService = shazamService ?? ShazamService(),
        _lyricsService = lyricsService ?? LyricsProviderService(lrcLibService: lrcLibService),
        _cacheService = cacheService ?? VinylCacheService(),
        _logService = logService ?? SessionLogService(),
        _castService = castService ?? CastSyncService(),
        _micBusyService = micBusyService ?? const MicBusyService() {
    _prefetchService = prefetchService ?? PrefetchService(
      lyricsService: _lyricsService,
      cacheService: _cacheService,
      wikipedia: WikipediaTracklistService(),
    );
    _castService.onClientScreenConfirmed = (deviceName) {
      debugPrint('[WaxClubEngine] 📺 Tela cliente confirmada: $deviceName. Enviando dados imediatos com compensação de delay...');
      if (_currentTrack != null) {
        _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
        _sendCastSyncWithTvLookahead();
      }
      notifyListeners();
    };
    _initCache();
    if (soundtrackCatalog != null) {
      _soundtracks = soundtrackCatalog;
    } else {
      SoundtrackCatalog.loadBundled().then((catalog) {
        if (_isDisposed) return;
        _soundtracks = catalog;
        debugPrint('[WaxClubEngine] 📼 Trilhas de novela carregadas: ${catalog.discs.length} discos.');
      });
    }
  }

  /// Trilhas sonoras de novelas embutidas no app (disco padrão das músicas que aparecem nelas).
  SoundtrackCatalog _soundtracks = SoundtrackCatalog.empty;
  SoundtrackCatalog get soundtrackCatalog => _soundtracks;

  /// Origem do disco travado: 'user' (Mudar disco), 'soundtrack' (trilha de novela) ou `null` (automático).
  String? _lockedAlbumSource;
  String? get lockedAlbumSource => _lockedAlbumSource;

  /// Trilha de novela a assumir para a música, se nenhum disco preferido (do usuário ou confirmado pela
  /// sequência tocada) foi definido para ela.
  SoundtrackDisc? _soundtrackFor(TrackInfo track) {
    if (_cacheService.getPreferredAlbum(track.title, track.artist) != null) return null;
    return _soundtracks.findFor(track.title, track.artist);
  }

  /// Grava a trilha no cache de discos (tracklist, capa, formato) e a trava como disco atual.
  Future<void> _lockSoundtrack(SoundtrackDisc disc) async {
    final cached = _cacheService.findCachedDisc(disc.album, SoundtrackDisc.albumArtist);
    // Regrava sempre a partir do catálogo embutido (versões novas trazem minutagens do selo corrigidas)
    if (cached == null || cached.tracklist.isEmpty || cached.tracklistSource == 'teledramaturgia') {
      await _cacheService.saveTracklist(
        album: disc.album,
        artist: SoundtrackDisc.albumArtist,
        entries: disc.tracks,
        releaseId: disc.sourceUrl,
        releaseFormat: disc.isVinylEra ? 'Vinyl LP' : 'CD',
        source: 'teledramaturgia',
        sideSource: disc.isVinylEra ? 'estimated' : 'catalog',
      );
      if (disc.coverUrl != null) {
        await _cacheService.updateDiscCover(disc.album, SoundtrackDisc.albumArtist, disc.coverUrl!);
      }
    }
    _unlockAlbum(reason: 'Trilha de novela "${disc.album}"');
    _lockAlbum(
      albumName: disc.album,
      coverUrl: disc.coverUrl,
      artist: SoundtrackDisc.albumArtist,
      tracklist: disc.tracks,
    );
    _lockedAlbumSource = 'soundtrack';
    _logService.log('soundtrack_locked', {'album': disc.album, 'year': disc.year, 'network': disc.network});
  }

  /// Inicializa o cache de forma assíncrona ao criar o engine e aplica o prior de velocidade persistido.
  Future<void> _initCache() async {
    try {
      await _cacheService.init();
      debugPrint('[WaxClubEngine] ✅ Cache de vinil carregado com sucesso.');

      if (PredictionTuning.kUsePersistedSpeedPrior) {
        final turntable = _cacheService.turntableState;
        if (turntable != null) {
          final diffDays = DateTime.now().difference(turntable.updatedAt).inDays;
          final deltaFrom1 = (turntable.lastStableSpeedFactor - 1.0).abs();
          if (deltaFrom1 <= 0.05 && diffDays <= 30) {
            // A incerteza cresce com o tempo desde a última medição (correia/motor podem mudar)
            final agedStdDev = math.sqrt(
              turntable.stdDev * turntable.stdDev + PredictionTuning.speedDriftVariancePerDay * diffDays,
            );
            _turntable = TurntableSpeedModel(mean: turntable.lastStableSpeedFactor, stdDev: agedStdDev);
            _speedFactor = _turntable.mean;
            _refreshSpeed();
            debugPrint('[WaxClubEngine] 🎛️ Rotação do toca-discos restaurada: ${_speedFactor.toStringAsFixed(4)}x ±${(agedStdDev * 100).toStringAsFixed(2)}% (${turntable.updatedAt})');
            _logService.log('speed_prior_applied', {
              'speedFactor': _speedFactor,
              'stdDev': agedStdDev,
              'updatedAt': turntable.updatedAt.toIso8601String(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[WaxClubEngine] ⚠️ Erro ao carregar cache: $e');
    }

    _telemetry = _telemetry.copyWith(activeMicrophoneName: _recordService.activeDeviceName);
    if (!_isDisposed) notifyListeners();
  }

  /// Conecta o celular a uma TV detectada na rede Wi-Fi e envia imediatamente a faixa atual.
  Future<bool> connectCast(CastDevice device) async {
    final success = await _castService.connectTo(device);
    if (success && _currentTrack != null) {
      _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
      _sendCastSyncWithTvLookahead();
    }
    notifyListeners();
    return success;
  }

  /// Conecta o celular diretamente via endereço IP da TV.
  Future<bool> connectCastByIp(String ip) async {
    final success = await _castService.connectToHost(ip);
    if (success && _currentTrack != null) {
      _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
      _sendCastSyncWithTvLookahead();
    }
    notifyListeners();
    return success;
  }

  /// Envia atualização de sincronismo para a TV com compensação de atraso de transmissão (Lookahead de +400ms).
  void _sendCastSyncWithTvLookahead() {
    if (!_castService.isConnected) return;
    const tvLeadTimeMs = 850; // Antecipação total de 850ms (+400ms além dos 450ms do celular)
    final tvDuration = Duration(
      milliseconds: (((_currentPositionSeconds + _lyricBiasSeconds) * 1000) + tvLeadTimeMs).round(),
    );
    final tvActiveIndex = LrcParser.findActiveIndex(_lyrics, tvDuration);

    _castService.sendSync(
      position: _currentPositionSeconds + _lyricBiasSeconds + 0.40,
      activeLineIndex: tvActiveIndex,
      speedFactor: effectiveSpeedFactor,
      status: _telemetry.status.name,
      statusMessage: _telemetry.statusMessage,
      isPaused: _isPaused || _awaitingNeedle,
      isMicActive: _telemetry.isMicActive,
      nextTitle: _telemetry.sideEndLabel == null ? _telemetry.predictedNextTrackTitle : null,
      awaitingNeedle: _awaitingNeedle,
      speedStdErr: _currentSpeedEstimate?.standardError ?? _turntable.stdDev,
    );
  }

  /// Lado do disco ("A", "B"...) da faixa atual, quando a tracklist é conhecida.
  String? get currentSide => _currentTrack == null ? null : _sideFor(_currentTrack!.title);

  /// Primeira música do próximo lado (prevista), exibida no fim do lado ("Lado B começa com...").
  String? get afterFlipTitle => (_lastPrediction ?? _prefetchService.lastPrediction)?.afterFlip?.entry.title;

  /// Posição da faixa atual na tracklist do disco (1-based) e total de faixas, quando conhecidas.
  (int, int)? get currentTrackNumber {
    final track = _currentTrack;
    if (track == null) return null;
    for (final list in [_lockedTracklist, _prefetchService.currentDiscTracklist]) {
      if (list.isEmpty) continue;
      final idx = TracklistMatcher.findIndex(list, track.title);
      if (idx != -1) return (idx + 1, list.length);
    }
    return null;
  }

  /// Lado do disco ("A", "B"...) da faixa, segundo a tracklist do disco atual.
  String? _sideFor(String title) {
    for (final list in [_lockedTracklist, _prefetchService.currentDiscTracklist]) {
      if (list.isEmpty) continue;
      final idx = TracklistMatcher.findIndex(list, title);
      if (idx != -1) return list[idx].side;
    }
    return null;
  }

  /// Encerra a transmissão para a TV.
  Future<void> disconnectCast() async {
    await _castService.disconnect(stopTvApp: true);
    notifyListeners();
  }

  // Histórico de faixas tocadas na sessão para desambiguação de álbum
  final List<TrackInfo> _sessionHistory = [];
  final List<String> _sessionConfirmedTitles = [];
  int _consecutiveConfirmationsOnAlbum = 0;
  String? _currentAlbumBeingConfirmed;
  PredictionResult? _lastPrediction;
  Timer? _sideFlipProbeTimer;
  DateTime? _waitingEndOfSideEnteredAt;

  // Bloqueio / Trava de Disco da Sessão (Anti-Fragmentação Shazam em Coletâneas)
  String? _lockedAlbumName;
  String? _lockedAlbumCoverUrl;
  String? _lockedAlbumArtist;
  List<TrackEntry> _lockedTracklist = [];

  /// Indica se o álbum e a capa física do disco estão travados para a sessão atual.
  bool get isAlbumLocked => _lockedAlbumName != null && _lockedAlbumName!.isNotEmpty;

  /// Nome do álbum travado para a sessão.
  String? get lockedAlbumName => _lockedAlbumName;

  /// URL da capa do álbum travado para a sessão.
  String? get lockedAlbumCoverUrl => _lockedAlbumCoverUrl;

  /// Artista do álbum travado para a sessão.
  String? get lockedAlbumArtist => _lockedAlbumArtist;

  /// Tracklist oficial completa do disco travado.
  List<TrackEntry> get lockedTracklist => List.unmodifiable(_lockedTracklist);

  /// O lado [side] é o último do disco (maior letra de lado na lista de faixas: B num LP simples,
  /// D num duplo). Sem lados na lista, não dá para saber: `false`.
  static bool isLastSideOfRecord(List<TrackEntry> tracklist, String side) {
    final sides = tracklist.map((e) => e.side?.toUpperCase()).whereType<String>().where((s) => s.isNotEmpty).toSet();
    if (sides.isEmpty) return false;
    final last = sides.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return side.toUpperCase() == last;
  }

  /// Chave MANUAL (Modo Manual: letra pela minutagem, sem Shazam). Começa desligada e volta a
  /// desligada quando o disco termina (fim da última música do último lado).
  bool _manualMode = false;
  bool get isManualMode => _manualMode;

  void setManualMode(bool on) {
    if (_manualMode == on) return;
    _manualMode = on;
    _logService.log('manual_mode', {'on': on});
    if (!on && (isManualPlaying || _manualPendingIndex != null)) _stopManual(l10n.manualModeOffStatus);
    notifyListeners();
  }

  void _resetManualMode(String reason) {
    if (!_manualMode) return;
    _manualMode = false;
    _logService.log('manual_mode', {'on': false, 'reason': reason});
    notifyListeners();
  }

  /// Trava o nome, capa, artista e tracklist do disco para a sessão.
  void _lockAlbum({
    required String albumName,
    String? coverUrl,
    required String artist,
    List<TrackEntry> tracklist = const [],
  }) {
    if (albumName.isEmpty || albumName.toLowerCase() == 'unknown album') return;
    _lockedAlbumName = albumName;
    _lockedAlbumArtist = artist;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      _lockedAlbumCoverUrl = coverUrl;
    }
    if (tracklist.isNotEmpty) {
      _lockedTracklist = List.from(tracklist);
    }
    debugPrint('[WaxClubEngine] 🔒 DISCO TRAVADO: "$_lockedAlbumName" de "$_lockedAlbumArtist" (capa: ${_lockedAlbumCoverUrl != null ? "✓" : "não"}, faixas: ${_lockedTracklist.length})');
    _logService.log('lock_disc', {
      'album': albumName,
      'artist': artist,
      'tracks': _lockedTracklist.length,
    });
  }

  /// Destrava o disco atual quando uma faixa anômala (fora da tracklist) é detectada.
  void _unlockAlbum({String? reason}) {
    if (!isAlbumLocked) return;
    debugPrint('[WaxClubEngine] 🔓 DISCO DESTRAVADO: "$_lockedAlbumName" (motivo: ${reason ?? "desconhecido"})');
    _logService.log('unlock_disc', {
      'album': _lockedAlbumName,
      'reason': reason ?? 'desconhecido',
    });
    _lockedAlbumName = null;
    _lockedAlbumCoverUrl = null;
    _lockedAlbumArtist = null;
    _lockedTracklist = [];
    _lockedAlbumSource = null;
  }

  /// Escolha manual do disco pelo usuário ("Mudar disco"): trava o disco escolhido com a lista de faixas
  /// dele, atualiza capa, lado e próxima música (celular e TV) e o grava como o disco padrão do usuário
  /// para todas as músicas dele, passando por cima da escolha automática nas próximas vezes.
  /// Disco reconhecido pela câmera: grava a lista de faixas e o torna o disco padrão de todas as faixas,
  /// para que o modo automático já o trave ao reconhecer a primeira música. Se uma faixa dele já estiver
  /// tocando, aplica a escolha na hora.
  Future<void> prepareScannedRecord({
    required String albumTitle,
    required String artist,
    required List<TrackEntry> tracklist,
    String? coverUrl,
    String? releaseId,
    String? releaseFormat,
    required String source,
  }) async {
    if (albumTitle.trim().isEmpty || tracklist.isEmpty) return;
    await _cacheService.saveTracklist(
      album: albumTitle,
      artist: artist,
      entries: tracklist,
      releaseId: releaseId,
      releaseFormat: releaseFormat,
      source: source,
      sideSource: tracklist.any((e) => e.side != null) ? 'catalog' : null,
    );
    if (coverUrl != null && coverUrl.isNotEmpty) {
      await _cacheService.updateDiscCover(albumTitle, artist, coverUrl);
    }
    await _cacheService.setPreferredAlbumBatch([
      for (final e in tracklist) TrackInfo(title: e.title, artist: e.artist ?? artist, offsetSeconds: 0.0),
    ], albumTitle, source: 'user');
    if (_isDisposed) return;
    // Disco escolhido pela câmera fica travado: é a lista de faixas do Modo Manual
    _lockAlbum(albumName: albumTitle, coverUrl: coverUrl, artist: artist, tracklist: tracklist);
    _lockedAlbumSource = 'user';
    notifyListeners();
    _logService.log('record_scanned', {'album': albumTitle, 'artist': artist, 'source': source, 'tracks': tracklist.length});
    debugPrint('[WaxClubEngine] 📷 Disco reconhecido pela câmera: "$albumTitle" ($source, ${tracklist.length} faixas).');

    final current = _currentTrack;
    if (current != null && TracklistMatcher.findIndex(tracklist, current.title) != -1) {
      await applyUserAlbumChoice(
        albumTitle: albumTitle,
        tracklist: tracklist,
        coverUrl: coverUrl,
        releaseId: releaseId,
        releaseFormat: releaseFormat,
        source: source,
      );
    }
  }

  Future<void> applyUserAlbumChoice({
    required String albumTitle,
    required List<TrackEntry> tracklist,
    String? coverUrl,
    String? releaseId,
    String? releaseFormat,
    required String source,
  }) async {
    final current = _currentTrack;
    if (current == null || albumTitle.trim().isEmpty) return;
    // Artista da música (o disco travado pode ser uma trilha, creditada a "Trilha sonora")
    final artist = current.artist;

    await _cacheService.saveTracklist(
      album: albumTitle,
      artist: artist,
      entries: tracklist,
      releaseId: releaseId,
      releaseFormat: releaseFormat,
      source: source,
      sideSource: tracklist.any((e) => e.side != null) ? 'catalog' : null,
    );
    if (coverUrl != null && coverUrl.isNotEmpty) {
      await _cacheService.updateDiscCover(albumTitle, artist, coverUrl);
    }
    // Disco padrão do usuário: a música atual e todas as faixas do disco escolhido
    await _cacheService.setPreferredAlbumBatch([
      current,
      for (final e in tracklist)
        if (!TracklistMatcher.isSameTitle(e.title, current.title))
          TrackInfo(title: e.title, artist: e.artist ?? artist, offsetSeconds: 0.0),
    ], albumTitle, source: 'user');
    if (_isDisposed) return;

    _unlockAlbum(reason: 'Disco escolhido pelo usuário: "$albumTitle"');
    _lockAlbum(albumName: albumTitle, coverUrl: coverUrl, artist: artist, tracklist: tracklist);
    _lockedAlbumSource = 'user';
    _lockedAlbumCoverUrl = (coverUrl != null && coverUrl.isNotEmpty) ? coverUrl : current.coverUrl;

    _currentTrack = current.copyWith(
      album: albumTitle,
      coverUrl: _lockedAlbumCoverUrl,
      isAlbumLocked: true,
    );
    _sessionConfirmedTitles
      ..clear()
      ..add(current.title);
    _currentAlbumBeingConfirmed = albumTitle;
    _consecutiveConfirmationsOnAlbum = 3; // escolha do usuário vale como confirmada

    // Duração pela lista de faixas do disco escolhido (quando ela traz a duração)
    final catalogDuration = _catalogDurationFor(current.title);
    if (catalogDuration != null && catalogDuration > _currentPositionSeconds) {
      _trackDurationSeconds = catalogDuration;
      _telemetry = _telemetry.copyWith(trackDurationSeconds: catalogDuration);
    }

    _logService.log('album_chosen_by_user', {
      'album': albumTitle,
      'track': current.title,
      'source': source,
      'tracks': tracklist.length,
    });
    debugPrint('[WaxClubEngine] 💿 Disco escolhido pelo usuário: "$albumTitle" ($source, ${tracklist.length} faixas).');

    // Nova previsão da próxima música a partir da lista de faixas escolhida
    _lastPrediction = null;
    _prefetchService.onTrackChanged();
    _telemetry = _telemetry.copyWith(
      clearPredictedNext: true,
      nextLyricsReady: false,
      diagnosticMessage: 'Record chosen: "$albumTitle"',
    );
    notifyListeners();
    if (_castService.isConnected) {
      _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(current.title));
      _sendCastSyncWithTvLookahead();
    }
    if (_tStart != null && !_isPaused && !isAwaitingSideFlip) {
      _scheduleEndOfTrackListener();
    }
    _startPrefetch(_currentTrack!);
  }
  /// Verifica se uma faixa reconhecida pertence ao disco atualmente travado.
  bool _isTrackInLockedAlbum(TrackInfo track) {
    if (!isAlbumLocked) return false;

    // 1. Se possuir tracklist oficial travada, verifica presença do título
    if (_lockedTracklist.isNotEmpty) {
      final idx = TracklistMatcher.findIndex(_lockedTracklist, track.title);
      if (idx != -1) return true;
    }

    // 2. Se a tracklist ainda não tiver sido carregada, confere por artista
    if (_lockedTracklist.isEmpty && _lockedAlbumArtist != null) {
      if (TracklistMatcher.isSameArtist(track.artist, _lockedAlbumArtist!)) {
        return true;
      }
    }

    return false;
  }

  // Estado da faixa e letras
  TrackInfo? _currentTrack;
  TrackInfo? get currentTrack => _currentTrack;

  List<LyricLine> _lyrics = [];
  List<LyricLine> get lyrics => _lyrics;

  // Variáveis do algoritmo de compensação de velocidade mecânica
  DateTime? _tStart;
  double _baseOffset = 0.0;
  double _speedFactor = 1.0;
  double _manualPitchOffset = 0.0;
  bool _isPitchLocked = false;
  bool get isPitchLocked => _isPitchLocked;

  // Bias manual persistente de rolagem de letras (nudge)
  double _lyricBiasSeconds = 0.0;
  double get lyricBiasSeconds => _lyricBiasSeconds;
  Timer? _nudgeDebounceTimer;

  // ─── ROTAÇÃO ───
  // Modelo da rotação do toca-discos (propriedade do hardware, acumulada entre faixas e sessões)
  TurntableSpeedModel _turntable = TurntableSpeedModel();
  // Regressão tempo-real × posição-da-música com todas as escutas reconhecidas da faixa atual
  final TrackSpeedFit _trackFit = TrackSpeedFit();
  SpeedEstimate? _currentSpeedEstimate;

  /// Indica se a rotação do toca-discos já é conhecida com boa precisão (incerteza <= 0.3%).
  bool get isHardwareSpeedCalibrated => _turntable.isCalibrated;

  /// Estimativa atual da rotação (com incerteza) usada para avançar a letra.
  SpeedEstimate? get currentSpeedEstimate => _currentSpeedEstimate;

  // Detecção de nível de áudio e silêncio (EMA de capturas bem-sucedidas)
  double? _referenceMusicDb;
  double? get referenceMusicDb => _referenceMusicDb;

  /// Recalcula a rotação da faixa atual combinando o modelo do toca-discos com a regressão da faixa.
  void _refreshSpeed() {
    _currentSpeedEstimate = _turntable.combine(_trackFit.estimate());
    if (!_isPitchLocked) {
      _speedFactor = _currentSpeedEstimate!.speed;
    }
    _telemetry = _telemetry.copyWith(
      speedFactor: effectiveSpeedFactor,
      isHardwareSpeedCalibrated: isHardwareSpeedCalibrated,
    );
  }

  /// Incorpora a regressão da faixa encerrada ao modelo do toca-discos e o persiste.
  void _commitTrackSpeed() {
    final estimate = _trackFit.estimate();
    _trackFit.clear();
    if (estimate == null || _isPitchLocked) return;
    _turntable.addTrackEstimate(estimate);
    _cacheService.saveTurntableSpeed(_turntable.mean, stdDev: _turntable.stdDev);
    debugPrint('[WaxClubEngine] 💾 Rotação da faixa $estimate incorporada: toca-discos ${_turntable.mean.toStringAsFixed(4)}x ±${(_turntable.stdDev * 100).toStringAsFixed(2)}%');
    _logService.log('turntable_speed_updated', {
      'trackSpeed': estimate.speed,
      'trackStdErr': estimate.standardError,
      'samples': estimate.samples,
      'span': estimate.spanSeconds,
      'turntableSpeed': _turntable.mean,
      'turntableStdDev': _turntable.stdDev,
    });
  }

  /// Ancora a posição da letra numa escuta reconhecida e registra a observação para a regressão de rotação.
  /// Toda escuta reconhecida realinha a letra ao timestamp informado pelo Shazam.
  void _anchorToRecognition(TrackInfo recognized, DateTime captureStart) {
    if (recognized.offsetSeconds > 0) {
      _trackFit.add(SpeedObservation(
        captureStart.millisecondsSinceEpoch / 1000.0,
        recognized.offsetSeconds,
      ));
    }
    _refreshSpeed();
    final now = DateTime.now();
    final elapsed = now.difference(captureStart).inMilliseconds / 1000.0;
    _baseOffset = recognized.offsetSeconds + elapsed * effectiveSpeedFactor;
    _currentPositionSeconds = _baseOffset;
    _tStart = now;

    // A música ouvida já passou da duração conhecida: essa duração é de outra edição/versão (ex.: LRC de
    // um álbum diferente). Descartá-la evita encerrar a faixa cedo e o ciclo "pula para a próxima / volta".
    // Margem de 3s: posições perto do fim (ou alguns segundos além, por arredondamento) são legítimas.
    final duration = _trackDurationSeconds;
    if (duration != null && _currentPositionSeconds > duration + 3.0) {
      debugPrint('[WaxClubEngine] ⚠️ Posição ouvida (${_currentPositionSeconds.toStringAsFixed(0)}s) além da duração conhecida '
          '(${duration.toStringAsFixed(0)}s) para "${recognized.title}". Duração descartada; o fim será detectado pelo microfone.');
      _logService.log('duration_inconsistent', {
        'track': recognized.title,
        'position': _currentPositionSeconds,
        'duration': duration,
      });
      _trackDurationSeconds = null;
      _telemetry = _telemetry.copyWith(clearTrackDuration: true);
    }
  }

  /// Duração da faixa segundo a tracklist do disco (catálogo), quando conhecida.
  /// É mais confiável que a duração informada pelo provedor de letras, que pode ser de outra edição.
  double? _catalogDurationFor(String title) {
    for (final list in [_lockedTracklist, _prefetchService.currentDiscTracklist]) {
      if (list.isEmpty) continue;
      final idx = TracklistMatcher.findIndex(list, title);
      if (idx != -1) {
        final ms = list[idx].lengthMs;
        if (ms != null && ms > 0) return ms / 1000.0;
      }
    }
    return null;
  }

  /// Letra do lado que terminou ("A", "B"...), usada nas mensagens de virada.
  String? _sideEndLetter;

  /// Rótulo "End of side X" no idioma atual; guarda a letra do lado.
  String _sideEndLabelFor(String? side) {
    _sideEndLetter = (side == null || side.isEmpty) ? null : side;
    return (side == null || side.isEmpty) ? l10n.endOfSide : l10n.endOfSideLabel(side);
  }

  /// Melhor duração disponível: catálogo do disco primeiro, depois a do provedor de letras.
  double? _bestDuration(String title, double? lyricsDuration) {
    final catalog = _catalogDurationFor(title);
    if (catalog != null) return catalog;
    if (lyricsDuration != null && lyricsDuration > 0) return lyricsDuration;
    return null;
  }

  /// Posição estimada da música num instante real, segundo a âncora e a rotação atuais.
  double _positionAt(DateTime instant) {
    if (_tStart == null) return _currentPositionSeconds;
    return _baseOffset + (instant.difference(_tStart!).inMilliseconds / 1000.0) * effectiveSpeedFactor;
  }

  /// Texto curto da rotação atual para mensagens de status (ex.: "1.012x ±0.2%").
  String get _speedLabel {
    final se = _currentSpeedEstimate?.standardError ?? _turntable.stdDev;
    return '${effectiveSpeedFactor.toStringAsFixed(3)}x ±${(se * 100).toStringAsFixed(1)}%';
  }

  void togglePitchLock() {
    _isPitchLocked = !_isPitchLocked;
    if (!_isPitchLocked) _refreshSpeed();
    _telemetry = _telemetry.copyWith(
      isPitchLocked: _isPitchLocked,
      diagnosticMessage: _isPitchLocked
          ? l10n.statusPitchLocked(_speedFactor.toStringAsFixed(3))
          : l10n.statusPitchUnlocked,
    );
    notifyListeners();
    debugPrint('[WaxClubEngine] 🔒 Trava de rotação alterada: $_isPitchLocked');
  }

  double get effectiveSpeedFactor => (_speedFactor + _manualPitchOffset).clamp(0.80, 1.25);

  int _sessionId = 0;

  // Telemetria pública
  VinylTelemetry _telemetry = const VinylTelemetry();
  VinylTelemetry get telemetry => _telemetry;

  int _activeLineIndex = -1;
  int get activeLineIndex => _activeLineIndex;

  double _currentPositionSeconds = 0.0;
  double get currentPositionSeconds => _currentPositionSeconds;

  // Duração oficial da faixa em segundos (catálogo de estúdio)
  double? _trackDurationSeconds;
  double? get trackDurationSeconds => _trackDurationSeconds;

  // Timers e loops
  Timer? _tickerTimer;
  Timer? _syncCheckTimer;
  Timer? _countdownTimer;
  Timer? _endOfTrackTimer;

  /// Quantas checagens de sincronia já ocorreram na faixa atual (define o intervalo da próxima).
  int _syncCheckIndex = 0;

  bool _isDisposed = false;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  /// Modo contínuo: quando true, o engine automaticamente gerencia a próxima faixa.
  bool _continuousMode = true;
  bool get continuousMode => _continuousMode;
  set continuousMode(bool value) {
    _continuousMode = value;
    notifyListeners();
  }

  /// Executa uma rotina em segundo plano de forma protegida contra exceções não tratadas (T0.4).
  /// Garante que o microfone não fique preso como ativo e permite ação de contingência via [onFallback].
  Future<void> _guarded(
    String routineName,
    Future<void> Function() routine, {
    VoidCallback? onFallback,
  }) async {
    try {
      await routine();
    } catch (e, stack) {
      debugPrint('[WaxClubEngine] ⚠️ Exceção tratada em $routineName: $e\n$stack');
      _logService.log('routine_error', {
        'routine': routineName,
        'error': e.toString(),
      });
      if (_telemetry.isMicActive) {
        _telemetry = _telemetry.copyWith(isMicActive: false);
        notifyListeners();
      }
      onFallback?.call();
    }
  }

  /// Inicia o ciclo completo de escuta e calibração de vinil (Smart Listening Scheduler).
  Future<void> startListening({bool useMockIfRecognitionFails = false}) async {
    _clearManualState();
    _resetState();
    _sessionHistory.clear();
    _sessionConfirmedTitles.clear();
    _consecutiveConfirmationsOnAlbum = 0;
    _currentAlbumBeingConfirmed = null;
    _isPaused = false;
    _telemetry = _telemetry.copyWith(isUserListening: true);
    notifyListeners();
    final mySession = ++_sessionId;

    try {
      // ═══════════════════════════════════════════════════════════════
      // ETAPA 1: Captura e Fingerprint inicial (Amostra 1 — identificação)
      // ═══════════════════════════════════════════════════════════════
      _updateStatus(
        CalibrationStatus.listeningSample1,
        l10n.statusListeningMic,
        isMicActive: true,
      );

      // Escuta progressiva: consulta o Shazam já aos 4s (músicas fáceis respondem logo) e, sem recomeçar
      // a gravação, de novo aos 8s e 12s para as que precisam de mais áudio
      final first = await _captureAndIdentify(
        checkpoints: PredictionTuning.fastFirstCheckpoints,
        priority: RecordPriority.user,
        useSilenceGate: false,
      );
      if (_sessionId != mySession || _isDisposed) return;
      var captureTime = first.captureStart;
      TrackInfo? recognized = first.track;

      // Se a primeira escuta falhar, aciona uma segunda escuta (trecho novo, direto pelos marcos longos)
      if (recognized == null && !useMockIfRecognitionFails) {
        final retrySeconds = PredictionTuning.robustCheckpoints.last.inSeconds;
        _updateStatus(
          CalibrationStatus.listeningSample1,
          l10n.statusFaintSignal(retrySeconds),
          isMicActive: true,
        );
        _telemetry = _telemetry.copyWith(
          diagnosticMessage: 'Extended listening (${retrySeconds}s) enabled',
          signalQuality: 0.70,
        );
        notifyListeners();

        final retry = await _captureAndIdentify(
          checkpoints: PredictionTuning.robustCheckpoints,
          priority: RecordPriority.user,
          useSilenceGate: false,
        );
        if (_sessionId != mySession || _isDisposed) return;
        if (retry.track != null) {
          captureTime = retry.captureStart;
          recognized = retry.track;
        }
      }

      _updateStatus(
        CalibrationStatus.recognizingSample1,
        l10n.statusIdentifying,
        isMicActive: false,
      );
      // Mock de contingência se solicitado
      if (recognized == null && useMockIfRecognitionFails) {
        recognized = ShazamService.getMockTrack(
          title: 'Bohemian Rhapsody',
          artist: 'Queen',
          offsetSeconds: 15.0,
        );
      }

      if (recognized == null && micBlockedByOtherApp) {
        _logService.log('mic_blocked', {
          'silenced': _lastMicStatus?.silenced,
          'recordings': _lastMicStatus?.recordings,
          'peakDb': _lastPeakDb,
        });
        _updateStatus(CalibrationStatus.error, l10n.statusMicBusy, isMicActive: false);
        _telemetry = _telemetry.copyWith(diagnosticMessage: 'Microphone silenced by another app', signalQuality: 0.0);
        notifyListeners();
        return;
      }

      if (recognized == null) {
        final reason = _shazamService.lastFailureReason;
        _logService.log('recognition_failed', {
          'reason': reason,
          'peaks': _shazamService.lastPeaksCount,
        });
        final isNetworkIssue = reason != null && reason != 'no_match';
        _updateStatus(
          CalibrationStatus.error,
          isNetworkIssue
              ? l10n.statusRecognitionFailed(reason)
              : l10n.statusSongNotIdentified,
          isMicActive: false,
        );
        _telemetry = _telemetry.copyWith(
          diagnosticMessage: 'No matching audio fingerprint found',
          signalQuality: 0.30,
        );
        notifyListeners();
        return;
      }

      _telemetry = _telemetry.copyWith(
        diagnosticMessage: 'Audio recognition completed',
        signalQuality: 0.98,
      );
      notifyListeners();

      _logService.log('track_recognized', {
        'title': recognized.title,
        'artist': recognized.artist,
        'album': recognized.album,
        'offset': recognized.offsetSeconds,
      });

      // ═══════════════════════════════════════════════════════════════
      // ETAPA 2: Busca de Letras Sincronizadas & Duração Oficial de Estúdio
      // ═══════════════════════════════════════════════════════════════
      _updateStatus(
        CalibrationStatus.fetchingLyrics,
        l10n.statusFetchingLyricsAndTracklist(recognized.title),
        isMicActive: false,
      );

      // Verifica primeiro o álbum preferencial do usuário para esta música
      final userPrefAlbum = _cacheService.getPreferredAlbum(recognized.title, recognized.artist);
      // Trilha de novela: disco padrão quando nenhum disco preferido foi definido para a música
      final soundtrack = userPrefAlbum == null ? _soundtracks.findFor(recognized.title, recognized.artist) : null;
      final searchAlbum = userPrefAlbum ?? recognized.album; // a letra é da gravação original, não da trilha

      _sessionConfirmedTitles.add(recognized.title);
      _currentAlbumBeingConfirmed = searchAlbum;
      _consecutiveConfirmationsOnAlbum = 1;

      final resolved = await _resolveLyricsFor(recognized.copyWith(album: searchAlbum));
      if (_sessionId != mySession || _isDisposed) return;

      String? lrcContent = resolved.lrcContent;
      _trackDurationSeconds = _bestDuration(recognized.title, resolved.durationSeconds) ??
          _estimateTrackDuration(recognized, _lyrics);

      if (lrcContent != null && lrcContent.isNotEmpty) {
        _lyrics = LrcParser.parse(
          lrcContent,
          estimatedDurationSeconds: _trackDurationSeconds,
        );
      } else {
        _lyrics = [];
      }

      _trackDurationSeconds ??= _estimateTrackDuration(recognized, _lyrics);

      final officialAlbum = userPrefAlbum ?? resolved.album ?? recognized.album;
      final cachedCover = recognized.coverUrl ??
          _cacheService.findCachedDisc(officialAlbum ?? '', recognized.artist)?.coverUrl ??
          _cacheService.findCachedTrack(recognized.title, recognized.artist)?.coverUrl;

      // Localiza disco correspondente em cache para obter tracklist e capa existentes
      final cachedDisc = _cacheService.findCachedDisc(officialAlbum ?? '', recognized.artist) ??
          _cacheService.findDiscWithTrack(recognized.title, recognized.artist);

      final initialAlbum = cachedDisc?.album ?? officialAlbum ?? 'Album';
      final initialCover = cachedDisc?.coverUrl ?? cachedCover;
      final initialTracklist = cachedDisc?.tracklist ?? const <TrackEntry>[];

      if (soundtrack != null) {
        debugPrint('[WaxClubEngine] 📼 "${recognized.title}" está na trilha "${soundtrack.album}": disco assumido.');
        await _lockSoundtrack(soundtrack);
        if (_sessionId != mySession || _isDisposed) return;
        // Duração da faixa segundo a trilha (catálogo do disco tem prioridade)
        _trackDurationSeconds = _catalogDurationFor(recognized.title) ?? _trackDurationSeconds;
      } else {
        _lockAlbum(
          albumName: initialAlbum,
          coverUrl: initialCover,
          artist: recognized.artist,
          tracklist: initialTracklist,
        );
        if (userPrefAlbum != null) {
          _lockedAlbumSource = _cacheService.getPreferredAlbumSource(recognized.title, recognized.artist) == 'user'
              ? 'user'
              : null;
        }
      }

      _currentTrack = recognized.copyWith(
        lrcContent: lrcContent,
        album: _lockedAlbumName ?? officialAlbum,
        coverUrl: _lockedAlbumCoverUrl ?? cachedCover,
        durationMs: _trackDurationSeconds != null ? (_trackDurationSeconds! * 1000).round() : recognized.durationMs,
        isAlbumLocked: isAlbumLocked,
      );

      // Carrega deslocamento salvo de letra (nudge) para esta faixa
      final savedOffsetMs = _cacheService.getLyricOffsetMs(_currentTrack!.title, _currentTrack!.artist);
      _lyricBiasSeconds = (savedOffsetMs / 1000.0).clamp(
        -PredictionTuning.maxNudgeBiasSeconds,
        PredictionTuning.maxNudgeBiasSeconds,
      );
      if (_lyricBiasSeconds != 0.0) {
        debugPrint('[WaxClubEngine] 🎚️ Nudge salvo reaplicado para "${_currentTrack!.title}": ${_lyricBiasSeconds.toStringAsFixed(2)}s');
      }

      _sessionHistory.add(_currentTrack!);
      await _cacheService.cacheTrack(_currentTrack!, lrcContent);

      // Âncora: posição do Shazam no início real da captura + tempo decorrido desde então (na rotação atual)
      _anchorToRecognition(recognized, captureTime);

      debugPrint('[WaxClubEngine] ✅ Sincronização calculada: offsetShazam=${recognized.offsetSeconds.toStringAsFixed(2)}s → baseOffset=${_baseOffset.toStringAsFixed(2)}s ($_speedLabel)');
      if (_trackDurationSeconds != null) {
        debugPrint('[WaxClubEngine] 📀 Duração oficial de catálogo: ${_trackDurationSeconds!.toStringAsFixed(1)}s');
      }

      _startPlaybackTicker();
      if (_castService.isConnected && _currentTrack != null) {
        _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
      }

      // Agenda as checagens de sincronia (realinhamento + regressão de rotação) e o fim da faixa
      _syncCheckIndex = 0;
      _scheduleNextSyncCheck();
      _scheduleEndOfTrackListener();

      // Inicia prefetch em segundo plano
      _startPrefetch(_currentTrack!);

    } catch (e) {
      _updateStatus(
        CalibrationStatus.error,
        l10n.statusIdentificationError('$e'),
        isMicActive: false,
      );
    } finally {
      if (_telemetry.isUserListening) {
        _telemetry = _telemetry.copyWith(isUserListening: false);
        notifyListeners();
      }
    }
  }

  /// Resolução de letras em cascata estrita cache-first (D11).
  Future<_ResolvedLyrics> _resolveLyricsFor(TrackInfo track) async {
    // Letra em texto simples (sem timestamps) não encerra a busca: tenta antes a rede por uma versão
    // sincronizada e só usa o texto simples guardado se a rede não trouxer nada melhor.
    _ResolvedLyrics? plainFallback;

    // 1. Prefetch em memória
    final prefetched = _prefetchService.getPrefetched(track.title, track.artist) ??
        _prefetchService.getPrefetched(track.title);
    if (prefetched != null && prefetched.lrc != null && prefetched.lrc!.isNotEmpty &&
        !_hasLrcTimestamps(prefetched.lrc!)) {
      plainFallback = _ResolvedLyrics(
        lrcContent: prefetched.lrc,
        durationSeconds: prefetched.durationSeconds,
        album: track.album,
        source: 'memory',
      );
    } else if (prefetched != null && prefetched.lrc != null && prefetched.lrc!.isNotEmpty) {
      debugPrint('[WaxClubEngine] ⚡ Letra resolvida via memória (prefetch): "${track.title}"');
      return _ResolvedLyrics(
        lrcContent: prefetched.lrc,
        durationSeconds: prefetched.durationSeconds,
        album: track.album,
        source: 'memory',
      );
    }

    // 2. Cache em disco (0 chamadas HTTP)
    final cached = _cacheService.findCachedTrack(track.title, track.artist);
    if (cached != null && cached.lrcContent != null && cached.lrcContent!.isNotEmpty) {
      final dur = cached.durationMs != null && cached.durationMs! > 0 ? (cached.durationMs! / 1000.0) : null;
      final fromCache = _ResolvedLyrics(
        lrcContent: cached.lrcContent,
        durationSeconds: dur,
        album: cached.album ?? track.album,
        source: 'cache',
      );
      if (_hasLrcTimestamps(cached.lrcContent!)) {
        debugPrint('[WaxClubEngine] 💾 Letra resolvida via cache local em disco (0 rede): "${track.title}"');
        return fromCache;
      }
      plainFallback ??= fromCache;
      debugPrint('[WaxClubEngine] 🔁 Cache de "${track.title}" só tem texto simples: buscando versão sincronizada na rede...');
    }

    // 3. Cascata de rede
    debugPrint('[WaxClubEngine] 🌐 Buscando letra na rede para "${track.title}"...');
    final preferredSource = _cacheService.getLyricsSource(track.title, track.artist);
    final details = await _lyricsService.fetchLyricsDetails(
      trackName: track.title,
      artistName: track.artist,
      albumName: track.album,
      durationSeconds: track.durationMs != null ? (track.durationMs! / 1000).round() : null,
      preferredSource: preferredSource,
    );

    final networkLrc = details?.syncedLyrics;
    final networkIsSynced = networkLrc != null && _hasLrcTimestamps(networkLrc);
    if (!networkIsSynced && plainFallback != null) {
      // A rede não trouxe nada melhor que o texto simples já guardado
      return plainFallback;
    }

    if (details?.source != null) {
      await _cacheService.saveLyricsSource(track.title, track.artist, details!.source!);
    }

    return _ResolvedLyrics(
      lrcContent: details?.syncedLyrics,
      durationSeconds: details?.durationSeconds?.toDouble(),
      album: details?.albumName ?? track.album,
      source: 'network',
      lyricsSource: details?.source,
    );
  }

  static final RegExp _lrcTimestampRegex = RegExp(r'\[\d{1,3}:\d{2}');

  /// Indica se o conteúdo é LRC sincronizado (e não texto simples com ritmo estimado).
  static bool _hasLrcTimestamps(String content) => _lrcTimestampRegex.hasMatch(content);

  /// Estima a duração da faixa caso o catálogo não informe
  double? _estimateTrackDuration(TrackInfo track, List<LyricLine> lyrics) {
    if (track.durationMs != null && track.durationMs! > 0) {
      return track.durationMs! / 1000.0;
    }
    if (lyrics.isNotEmpty) {
      final lastTimestamp = lyrics.last.timestamp.inMilliseconds / 1000.0;
      return lastTimestamp + 6.0;
    }
    return null;
  }

  /// Inicia o prefetch inteligente das próximas faixas e exibe a próxima provável.
  void _startPrefetch(TrackInfo currentTrack) {
    final mySession = _sessionId;
    _prefetchService.prefetchFor(
      currentTrack,
      lockedAlbumName: _lockedAlbumName,
      confirmedTitles: _sessionConfirmedTitles,
      onPrediction: (result) {
        if (_sessionId != mySession || _isDisposed) return;
        _lastPrediction = result;
        if (_lockedTracklist.isEmpty && _prefetchService.currentDiscTracklist.isNotEmpty) {
          _lockedTracklist = List.from(_prefetchService.currentDiscTracklist);
          debugPrint('[WaxClubEngine] 📋 Tracklist do disco travado atualizada via prefetch (${_lockedTracklist.length} faixas).');
          // Com a tracklist, o lado do disco (A/B) passa a ser conhecido: atualiza o selo na TV
          if (_castService.isConnected && _currentTrack != null) {
            _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
          }
        }
        _telemetry = _telemetry.copyWith(
          predictedNextTrackTitle: result.next?.title,
          clearPredictedNext: result.next?.title == null,
          nextLyricsReady: _prefetchService.hasLyricsFor(result.next?.title ?? ''),
          sideEndLabel: result.endOfSide ? _sideEndLabelFor(result.sideLabel) : null,
          clearSideEndLabel: !result.endOfSide,
          diagnosticMessage: result.next != null
              ? l10n.statusLikelyNext(result.next!.title)
              : (result.endOfSide ? l10n.statusLastTrackOfSide(result.sideLabel ?? '').trim() : l10n.statusTracklistLoaded),
        );
        notifyListeners();
      },
      onLyricsReady: (cand) {
        if (_sessionId != mySession || _isDisposed) return;
        if (_lastPrediction?.next?.title == cand.entry.title) {
          _telemetry = _telemetry.copyWith(nextLyricsReady: true);
          notifyListeners();
        }
      },
    ).then((result) {
      if (_sessionId != mySession || _isDisposed) return;
      _lastPrediction = result;
      if (_lockedTracklist.isEmpty && _prefetchService.currentDiscTracklist.isNotEmpty) {
        _lockedTracklist = List.from(_prefetchService.currentDiscTracklist);
        debugPrint('[WaxClubEngine] 📋 Tracklist do disco travado atualizada via prefetch (${_lockedTracklist.length} faixas).');
      }
      _telemetry = _telemetry.copyWith(
        predictedNextTrackTitle: result.next?.title,
        clearPredictedNext: result.next?.title == null,
        nextLyricsReady: _prefetchService.hasLyricsFor(result.next?.title ?? ''),
        sideEndLabel: result.endOfSide ? _sideEndLabelFor(result.sideLabel) : null,
        clearSideEndLabel: !result.endOfSide,
      );
      notifyListeners();
      debugPrint('[WaxClubEngine] ✅ Prefetch concluído. Próxima: "${result.next?.title}", endOfSide=${result.endOfSide}');
    }).catchError((e) {
      debugPrint('[WaxClubEngine] ⚠️ Prefetch falhou (não crítico): $e');
    });
  }

  /// Inicia o loop de alta frequência (~16ms / 60fps) para cálculo de posição em tempo real.
  void _startPlaybackTicker() {
    _tickerTimer?.cancel();
    _updateStatus(
      isHardwareSpeedCalibrated ? CalibrationStatus.calibrated : CalibrationStatus.playingUncalibrated,
      l10n.statusInSync(_speedLabel),
    );

    DateTime lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_tStart == null || _isDisposed) return;

      final now = DateTime.now();
      final elapsedRealSeconds = (now.difference(_tStart!).inMilliseconds) / 1000.0;
      _currentPositionSeconds = _baseOffset + (elapsedRealSeconds * effectiveSpeedFactor);

      const leadTimeMs = 450;
      final lookaheadDuration = Duration(
        milliseconds: (((_currentPositionSeconds + _lyricBiasSeconds) * 1000) + leadTimeMs).round(),
      );
      final newIndex = LrcParser.findActiveIndex(_lyrics, lookaheadDuration);

      // Notifica na troca de estrofe ou, no máximo, 2x por segundo (barra de progresso e TV)
      if (newIndex != _activeLineIndex || now.difference(lastNotify).inMilliseconds >= 500) {
        lastNotify = now;
        _activeLineIndex = newIndex;
        _telemetry = _telemetry.copyWith(
          currentPositionSeconds: _currentPositionSeconds,
          activeLineIndex: _activeLineIndex,
          speedFactor: effectiveSpeedFactor,
          trackDurationSeconds: _trackDurationSeconds,
        );
        notifyListeners();

        // Envia atualização de sincronismo para a TV com compensação de delay caso ativa
        _sendCastSyncWithTvLookahead();
      }
    });
  }

  /// Inicia um contador regressivo exibido na telemetria até a próxima checagem.
  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    int remaining = seconds;
    _telemetry = _telemetry.copyWith(countdownSeconds: remaining);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining <= 0 || _isDisposed) {
        timer.cancel();
        return;
      }
      _telemetry = _telemetry.copyWith(countdownSeconds: remaining);
      notifyListeners();
    });
  }

  /// Agenda a próxima checagem de sincronia da faixa atual.
  ///
  /// Cada checagem escuta o microfone, realinha a letra no timestamp reconhecido e acrescenta
  /// uma observação à regressão de rotação. Intervalos crescentes: 20s, +45s e depois a cada 75s,
  /// até perto do fim da faixa (o fim é tratado por [_scheduleEndOfTrackListener]).
  void _scheduleNextSyncCheck({int? delaySeconds}) {
    _syncCheckTimer?.cancel();
    _countdownTimer?.cancel();
    if (isManualPlaying) return; // Modo Manual: sem checagens pelo Shazam
    if (_isDisposed || _isPaused || _currentTrack == null || _tStart == null) return;

    const delays = PredictionTuning.syncCheckDelaysSeconds;
    final delay = delaySeconds ?? delays[math.min(_syncCheckIndex, delays.length - 1)];

    if (_trackDurationSeconds != null && _trackDurationSeconds! > 0) {
      final remaining = (_trackDurationSeconds! - _currentPositionSeconds) / effectiveSpeedFactor;
      if (remaining < delay + PredictionTuning.syncCheckEndMarginSeconds) {
        debugPrint('[WaxClubEngine] ⏭️ Sem checagem de sincronia: faltam ${remaining.toStringAsFixed(0)}s de faixa.');
        return;
      }
    }

    _startCountdown(delay);
    final mySession = _sessionId;
    _syncCheckTimer = Timer(Duration(seconds: delay), () {
      _performSyncCheck(mySession);
    });
  }

  /// Executa uma checagem de sincronia: escuta, realinha a fase e refina a rotação.
  /// Se o microfone reconhecer outra música, transita imediatamente para ela.
  Future<void> _performSyncCheck(int mySession) async {
    await _guarded('_performSyncCheck', () async {
      if (_sessionId != mySession || _isDisposed || _isPaused || _currentTrack == null) return;

      _updateStatus(
        CalibrationStatus.resyncingCheck,
        l10n.statusCheckingSync,
        isMicActive: true,
      );

      final outcome = await _captureAndIdentify(checkpoints: PredictionTuning.syncCheckCheckpoints);
      if (_sessionId != mySession || _isDisposed || _isPaused) return;

      final heard = outcome.track;
      final current = _currentTrack!;

      if (heard != null &&
          !TracklistMatcher.isSameTrack(heard.title, heard.artist, current.title, current.artist)) {
        // A faixa mudou antes do previsto (duração divergente, faixa pulada ou troca de disco)
        debugPrint('[WaxClubEngine] 🔀 Checagem ouviu outra música ("${heard.title}"). Transitando.');
        _logService.log('sync_check_new_track', {'from': current.title, 'to': heard.title});
        await _transitionToNewTrack(heard, outcome.captureStart, mySession);
        return;
      }

      if (heard != null && heard.offsetSeconds > 0) {
        final expectedAtCapture = _positionAt(outcome.captureStart);
        final driftSeconds = heard.offsetSeconds - expectedAtCapture;
        _anchorToRecognition(heard, outcome.captureStart);
        final driftMs = (driftSeconds * 1000).round();
        debugPrint('[WaxClubEngine] 🔄 Checagem #${_syncCheckIndex + 1}: desvio ${driftMs}ms → realinhado. Rotação $_speedLabel');
        _logService.log('sync_check', {
          'track': current.title,
          'driftMs': driftMs,
          'speed': _speedFactor,
          'stdErr': _currentSpeedEstimate?.standardError,
          'samples': _trackFit.length,
        });
        _updateStatus(
          isHardwareSpeedCalibrated ? CalibrationStatus.calibrated : CalibrationStatus.playingUncalibrated,
          l10n.statusSyncRealigned('${driftMs >= 0 ? "+" : ""}$driftMs', _speedLabel),
          isMicActive: false,
        );
        // A rotação pode ter mudado: recalcula o instante do fim da faixa
        _scheduleEndOfTrackListener();
      } else {
        _updateStatus(
          isHardwareSpeedCalibrated ? CalibrationStatus.calibrated : CalibrationStatus.playingUncalibrated,
          l10n.statusInSync(_speedLabel),
          isMicActive: false,
        );
      }

      _syncCheckIndex++;
      _scheduleNextSyncCheck();
    }, onFallback: () {
      _updateStatus(CalibrationStatus.calibrated, l10n.statusInSync(_speedLabel), isMicActive: false);
      _syncCheckIndex++;
      _scheduleNextSyncCheck();
    });
  }

  /// Agenda o reconhecimento imediato da próxima faixa ao terminar a música atual.
  void _scheduleEndOfTrackListener() {
    _endOfTrackTimer?.cancel();
    if (isManualPlaying) {
      _scheduleManualAdvance(); // Modo Manual: a troca de faixa vem da minutagem
      return;
    }

    if (!_continuousMode) {
      debugPrint('[WaxClubEngine] Modo contínuo desativado — sem auto-listen.');
      return;
    }

    if (_trackDurationSeconds == null || _trackDurationSeconds! <= 0) {
      debugPrint('[WaxClubEngine] Duração desconhecida — sem auto-listen programado.');
      return;
    }

    // Calcula tempo exato até o término da música com base na rotação mecânica atual
    final secondsUntilEnd = (_trackDurationSeconds! - _currentPositionSeconds) / effectiveSpeedFactor;

    if (secondsUntilEnd <= 0.5) {
      debugPrint('[WaxClubEngine] Fim da música alcançado — iniciando escuta imediata da próxima faixa.');
      _autoListenNextTrack();
      return;
    }

    debugPrint('[WaxClubEngine] 🕐 Próxima faixa programada em ${secondsUntilEnd.toStringAsFixed(0)}s (imediatamente no fim da música)');

    _endOfTrackTimer = Timer(Duration(milliseconds: (secondsUntilEnd * 1000).round()), () {
      _autoListenNextTrack();
    });
  }

  /// Inicia o modo preditivo de troca de faixa:
  ///   1. Verifica se chegou ao fim do lado físico do disco (D5).
  ///   2. Consulta o tracklist do álbum (cache ou prefetch) e exibe IMEDIATAMENTE a próxima faixa.
  ///   3. Em background, confirma via Shazam (dupla captura).
  ///   4. Se confirmado: grava como álbum preferencial apenas após 2 confirmações consecutivas (D9).
  ///   5. Se errado: corrige a letra e trata pulo de faixa (afterNext) ou release alternativo.
  Future<void> _autoListenNextTrack() async {
    if (_isDisposed || _isPaused || !_continuousMode) return;

    // Faixa encerrada: interrompe as checagens e incorpora a rotação medida ao modelo do toca-discos
    _syncCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _commitTrackSpeed();
    final previousDuration = _trackDurationSeconds;
    _trackDurationSeconds = null;

    final mySession = ++_sessionId;

    // ═══════════════════════════════════════════════════════════════
    // CASO 1: FIM DO LADO DO DISCO (D5)
    // ═══════════════════════════════════════════════════════════════
    final lastPred = _lastPrediction ?? _prefetchService.lastPrediction;
    if (lastPred != null && lastPred.endOfSide) {
      debugPrint('[WaxClubEngine] 🔄 Fim do lado ${lastPred.sideLabel ?? "A"} alcançado. Aguardando virada de disco...');
      _enterWaitingEndOfSide(lastPred.sideLabel);
      return;
    }

    // ═══════════════════════════════════════════════════════════════
    // CASO 2: MODO PREDITIVO (D11 cache-first de letras)
    // ═══════════════════════════════════════════════════════════════
    final TrackInfo? predictedTrack = await _predictNextTrack();

    if (predictedTrack != null && (_sessionId == mySession) && !_isDisposed) {
      debugPrint('[WaxClubEngine] 🔮 Modo Preditivo: exibindo "${predictedTrack.title}" imediatamente.');
      final predicted = await _showPredictedTrack(predictedTrack, mySession);
      if (predicted == null) return;
      // Confirmação em background (não bloqueia a UI)
      _confirmPredictionInBackground(predicted, mySession);
      return;
    }

    // Sem previsão disponível → protocolo padrão de escuta
    if (_sessionId != mySession || _isDisposed) return;
    await _listenAndIdentifyNextTrack(mySession, previousDuration: previousDuration);
  }

  /// Exibe uma faixa prevista na hora (letra do cache/rede, capa e duração) e a envia para a TV.
  /// Com [startTicker] falso, a letra fica parada em 0:00 (ex.: aguardando a agulha após virar o disco).
  /// Retorna a faixa exibida, ou `null` se a sessão mudou enquanto a letra era resolvida.
  Future<TrackInfo?> _showPredictedTrack(TrackInfo predictedTrack, int mySession, {bool startTicker = true}) async {
    final resolved = await _resolveLyricsFor(predictedTrack);
    if (_sessionId != mySession || _isDisposed) return null;

    final lrcContent = resolved.lrcContent;
    _trackDurationSeconds = _bestDuration(predictedTrack.title, resolved.durationSeconds) ?? _trackDurationSeconds;

    if (lrcContent != null && lrcContent.isNotEmpty) {
      _lyrics = LrcParser.parse(
        lrcContent,
        estimatedDurationSeconds: _trackDurationSeconds,
      );
    } else {
      _lyrics = [];
    }

    _trackDurationSeconds ??= _estimateTrackDuration(predictedTrack, _lyrics);
    final effectiveAlbum = isAlbumLocked ? _lockedAlbumName : (resolved.album ?? predictedTrack.album);
    final effectiveCover = isAlbumLocked ? _lockedAlbumCoverUrl : (predictedTrack.coverUrl ??
        _currentTrack?.coverUrl ??
        (_sessionHistory.isNotEmpty ? _sessionHistory.first.coverUrl : null));
    final predicted = predictedTrack.copyWith(
      lrcContent: lrcContent,
      album: effectiveAlbum,
      coverUrl: effectiveCover,
      isAlbumLocked: isAlbumLocked,
    );
    // Salva qualquer debounce de nudge pendente da faixa anterior antes de trocá-la
    _flushPendingNudge();
    _currentTrack = predicted;
    // Carrega deslocamento salvo de letra (nudge) para esta faixa prevista
    final savedOffsetMs = _cacheService.getLyricOffsetMs(predicted.title, predicted.artist);
    _lyricBiasSeconds = (savedOffsetMs / 1000.0).clamp(
      -PredictionTuning.maxNudgeBiasSeconds,
      PredictionTuning.maxNudgeBiasSeconds,
    );
    _baseOffset = 0.0;
    _currentPositionSeconds = 0.0;
    _tStart = startTicker ? DateTime.now() : null;
    _activeLineIndex = -1;

    // Nova faixa: regressão de rotação recomeça; a rotação do toca-discos (modelo) é herdada
    _trackFit.clear();
    _refreshSpeed();

    _logService.log('prediction_shown', {'title': predicted.title, 'awaitingNeedle': !startTicker});

    if (startTicker) {
      _startPlaybackTicker();
      // Status discreto: "confirmando..." sem interromper a exibição
      _updateStatus(
        CalibrationStatus.confirmingPrediction,
        l10n.statusConfirmingNext(predicted.title),
        isMicActive: false,
      );
    } else {
      _tickerTimer?.cancel();
      _tickerTimer = null;
      _telemetry = _telemetry.copyWith(
        currentPositionSeconds: 0.0,
        activeLineIndex: -1,
        trackDurationSeconds: _trackDurationSeconds,
      );
    }

    // A TV acompanha a faixa prevista imediatamente
    if (_castService.isConnected) {
      _castService.sendTrack(predicted, _lyrics, side: _sideFor(predicted.title));
    }
    return predicted;
  }
  /// Tenta prever a próxima faixa a partir do TrackPredictor, álbum preferencial ou cache.
  Future<TrackInfo?> _predictNextTrack() async {
    if (_currentTrack == null) return null;

    final current = _currentTrack!;
    final existingCover = isAlbumLocked
        ? _lockedAlbumCoverUrl
        : (current.coverUrl ??
            _cacheService.findCachedDisc(current.album ?? '', current.artist)?.coverUrl ??
            (_sessionHistory.isNotEmpty ? _sessionHistory.first.coverUrl : null));

    // Prioridade -1: Tracklist oficial do disco travado na sessão
    if (isAlbumLocked && _lockedTracklist.isNotEmpty) {
      final idx = TracklistMatcher.findIndex(_lockedTracklist, current.title);
      if (idx != -1 && idx + 1 < _lockedTracklist.length) {
        final currentEntry = _lockedTracklist[idx];
        final nextEntry = _lockedTracklist[idx + 1];
        // Se houver quebra de lado identificada, não prever como contínua
        if (currentEntry.side != null && nextEntry.side != null && currentEntry.side != nextEntry.side) {
          debugPrint('[WaxClubEngine] 🔮 Quebra de lado no disco travado (${currentEntry.side} -> ${nextEntry.side}). Não prevendo contínua.');
          return null;
        }
        final nextTitle = nextEntry.title;
        final nextArtist = nextEntry.artist ?? _lockedAlbumArtist ?? current.artist;
        final cachedLrc = _cacheService.findCachedLyrics(nextTitle, nextArtist);
        return TrackInfo(
          title: nextTitle,
          artist: nextArtist,
          album: _lockedAlbumName,
          offsetSeconds: 0.0,
          lrcContent: cachedLrc,
          coverUrl: _lockedAlbumCoverUrl ?? existingCover,
          isAlbumLocked: true,
        );
      }
    }

    // Prioridade 0: Predição ativa do TrackPredictor via prefetchService
    final lastPred = _lastPrediction ?? _prefetchService.lastPrediction;
    if (lastPred != null && lastPred.next != null && !lastPred.endOfSide) {
      final cand = lastPred.next!;
      final candCover = isAlbumLocked
          ? _lockedAlbumCoverUrl
          : (existingCover ?? _cacheService.findCachedDisc(cand.albumTitle, current.artist)?.coverUrl);
      return TrackInfo(
        title: cand.entry.title,
        artist: cand.entry.artist ?? current.artist,
        album: isAlbumLocked ? _lockedAlbumName : cand.albumTitle,
        offsetSeconds: 0.0,
        coverUrl: candCover,
        isAlbumLocked: isAlbumLocked,
      );
    }

    // Prioridade 1: Álbum preferencial do usuário (gravado em sessões anteriores)
    final preferredAlbum = _cacheService.getPreferredAlbum(current.title, current.artist);
    final albumToSearch = isAlbumLocked ? _lockedAlbumName : (preferredAlbum ?? current.album);

    if (albumToSearch != null && albumToSearch.isNotEmpty) {
      final tracklist = _cacheService.getTracklist(albumToSearch, current.artist);
      if (tracklist.isNotEmpty) {
        final idx = TracklistMatcher.findIndex(tracklist, current.title);
        if (idx != -1 && idx + 1 < tracklist.length) {
          final nextEntry = tracklist[idx + 1];
          // Se soubermos que há quebra de lado aqui, não predizer como contínua
          if (tracklist[idx].side != null && nextEntry.side != null && tracklist[idx].side != nextEntry.side) {
            return null;
          }
          final nextTitle = nextEntry.title;
          final nextArtist = nextEntry.artist ?? current.artist;
          final cachedLrc = _cacheService.findCachedLyrics(nextTitle, nextArtist);
          final discCover = isAlbumLocked
              ? _lockedAlbumCoverUrl
              : (_cacheService.findCachedDisc(albumToSearch, current.artist)?.coverUrl ?? existingCover);
          return TrackInfo(
            title: nextTitle,
            artist: nextArtist,
            album: albumToSearch,
            offsetSeconds: 0.0,
            lrcContent: cachedLrc,
            coverUrl: discCover,
            isAlbumLocked: isAlbumLocked,
          );
        }
      }
    }

    // Prioridade 2: Prefetch em memória
    final prefetchedTitle = _prefetchService.getPredictedNextTitle(current.title, current.artist);
    if (prefetchedTitle != null) {
      return TrackInfo(
        title: prefetchedTitle,
        artist: current.artist,
        album: albumToSearch,
        offsetSeconds: 0.0,
        coverUrl: existingCover,
        isAlbumLocked: isAlbumLocked,
      );
    }

    return null;
  }

  /// Escuta progressiva: grava continuamente e, em cada marco de [checkpoints], analisa o nível/silêncio
  /// via AudioLevelAnalyzer e consulta o Shazam com todo o áudio acumulado até ali (T2.1 / T2.2).
  /// Para no primeiro reconhecimento — rápido nas músicas fáceis, robusto (até o último marco) nas difíceis.
  /// Sem [checkpoints], faz uma única consulta ao fim de [duration].
  Future<CaptureOutcome> _captureAndIdentify({
    Duration duration = const Duration(milliseconds: 5000),
    List<Duration>? checkpoints,
    RecordPriority priority = RecordPriority.background,
    bool useSilenceGate = true,
  }) async {
    final marks = checkpoints ?? [duration];
    TrackInfo? track;
    AudioLevelReport? lastReport;
    var heardSound = false;
    var queried = false;
    _lastMicStatus = null;
    _lastPeakDb = null;

    final requestedAt = DateTime.now();
    final captureStart = await _recordService.recordProgressive(
      checkpoints: marks,
      priority: priority,
      onCheckpoint: (wav, _) async {
        if (_isDisposed) return true;
        final report = AudioLevelAnalyzer.analyze(wav, referenceMusicDb: _referenceMusicDb);
        lastReport = report;
        // Ainda gravando: pergunta ao Android se outro app está silenciando o microfone
        _lastPeakDb = report.peakDb;
        _lastMicStatus ??= await _micBusyService.check();
        if (useSilenceGate && report.isSilent) {
          debugPrint('[WaxClubEngine] 🔇 Trecho classificado como SILÊNCIO (p90: ${report.p90Db.toStringAsFixed(1)}dB, ref: ${_referenceMusicDb?.toStringAsFixed(1) ?? "none"}dB). Pulando Shazam.');
          return false;
        }
        heardSound = true;
        queried = true;
        track = await _shazamService.recognizeAudio(wav);
        return track != null;
      },
    );
    final actualCaptureStart = captureStart ?? _recordService.lastRecordStartTime ?? requestedAt;
    final report = lastReport;

    if (captureStart == null && track == null) {
      // Gravação cancelada/preemptada: nada foi ouvido de fato
      return CaptureOutcome(captureStart: actualCaptureStart, silent: true, cancelled: true);
    }

    if (!heardSound) {
      if (report != null) {
        _logService.log('capture_silent', {
          'p90Db': report.p90Db,
          'medianDb': report.medianDb,
          'referenceDb': _referenceMusicDb,
        });
      }
      return CaptureOutcome(captureStart: actualCaptureStart, silent: true, report: report);
    }

    final found = track;
    if (found != null && report != null) {
      // Atualiza média móvel do p90 de faixas reconhecidas com sucesso
      final ref = _referenceMusicDb;
      _referenceMusicDb = ref == null ? report.p90Db : (ref * 0.8) + (report.p90Db * 0.2);
    } else if (queried && report != null) {
      _logService.log('capture_unrecognized', {
        'p90Db': report.p90Db,
        'peakDb': report.peakDb,
        'reason': _shazamService.lastFailureReason,
        'peaks': _shazamService.lastPeaksCount,
      });
    }

    return CaptureOutcome(
      track: found,
      captureStart: actualCaptureStart,
      silent: false,
      report: report,
    );
  }
  /// Confirma a previsão em background via Shazam com política persistente de retentativas (T2.2).
  Future<void> _confirmPredictionInBackground(TrackInfo predicted, int mySession) async {
    await _guarded('_confirmPredictionInBackground', () async {
      debugPrint('[WaxClubEngine] 🎤 Iniciando política de confirmação em background para "${predicted.title}"...');
    final startTime = DateTime.now();
    const retryDelays = PredictionTuning.retryDelaysSeconds;

    for (int attempt = 0; attempt < retryDelays.length; attempt++) {
      if (_sessionId != mySession || _isDisposed || _isPaused) return;

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= PredictionTuning.giveUpAfter) break;

      // Atraso antes da tentativa
      if (attempt == 0) {
        await Future.delayed(PredictionTuning.initialConfirmationDelay);
      } else {
        final targetElapsedSec = retryDelays[attempt];
        final currentElapsedSec = DateTime.now().difference(startTime).inSeconds;
        final waitSec = targetElapsedSec - currentElapsedSec;
        if (waitSec > 0) {
          await Future.delayed(Duration(seconds: waitSec));
        }
      }

      if (_sessionId != mySession || _isDisposed || _isPaused) return;

      _telemetry = _telemetry.copyWith(
        isMicActive: true,
        statusMessage: l10n.statusConfirmingAttempt(attempt + 1, retryDelays.length),
      );
      notifyListeners();

      // Escuta progressiva: 4/8/12s na 1ª tentativa (rápida) e 8/12s nas seguintes (robusta)
      final outcome = await _captureAndIdentify(checkpoints: PredictionTuning.identificationCheckpointsFor(attempt));
      if (_sessionId != mySession || _isDisposed) return;

      _telemetry = _telemetry.copyWith(isMicActive: false);

      if (outcome.silent) {
        final currentElapsed = DateTime.now().difference(startTime).inSeconds;
        _telemetry = _telemetry.copyWith(
          diagnosticMessage: 'Silence detected — waiting for audio (${currentElapsed}s)',
          statusMessage: l10n.statusNotConfirmedFor(currentElapsed),
        );
        notifyListeners();
        continue;
      }

      final confirmed = outcome.track;

      if (confirmed != null) {
        final bool isMatch = TracklistMatcher.isSameTrack(
          confirmed.title,
          confirmed.artist,
          predicted.title,
          predicted.artist,
        );

        if (isMatch) {
          debugPrint('[WaxClubEngine] ✅ Previsão CONFIRMADA: "${predicted.title}"');
          _logService.log('prediction_confirmed', {
            'title': predicted.title,
            'ms': DateTime.now().difference(outcome.captureStart).inMilliseconds,
          });

          // Realinha a letra no timestamp confirmado e inicia a regressão de rotação desta faixa
          _anchorToRecognition(confirmed, outcome.captureStart);

          // Atualizar metadados e capa confirmada
          // Se o disco estiver travado, NUNCA usar album ou coverUrl vindos do Shazam!
          final effectiveCover = isAlbumLocked
              ? _lockedAlbumCoverUrl
              : (confirmed.coverUrl ??
                  _currentTrack?.coverUrl ??
                  predicted.coverUrl ??
                  (_sessionHistory.isNotEmpty ? _sessionHistory.first.coverUrl : null));
          final effectiveAlbum = isAlbumLocked
              ? _lockedAlbumName
              : (confirmed.album ?? _currentTrack?.album);
          _currentTrack = _currentTrack?.copyWith(
            coverUrl: effectiveCover,
            durationMs: confirmed.durationMs ?? _currentTrack?.durationMs,
            album: effectiveAlbum,
            isAlbumLocked: isAlbumLocked,
          );

          if (_currentTrack != null) {
            _sessionHistory.add(_currentTrack!);
            _sessionConfirmedTitles.add(_currentTrack!.title);
            await _cacheService.cacheTrack(_currentTrack!, _currentTrack!.lrcContent);
          }

          // Regra de pelo menos 3 faixas em ordem consecutiva para salvar preferredAlbum
          final albumName = _currentTrack?.album;
          if (albumName != null && albumName.isNotEmpty) {
            if (_currentAlbumBeingConfirmed == albumName) {
              _consecutiveConfirmationsOnAlbum++;
            } else {
              _currentAlbumBeingConfirmed = albumName;
              _consecutiveConfirmationsOnAlbum = 1;
            }

            unawaited(_checkAndConfirmPreferredAlbum(albumName, predicted.artist));
          }

          _updateStatus(
            CalibrationStatus.calibrated,
            l10n.statusConfirmed(_currentTrack!.title, _speedLabel),
            isMicActive: false,
          );

          // Metadados confirmados (álbum/capa/duração) seguem para a TV
          if (_castService.isConnected && _currentTrack != null) {
            _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
          }

          _prefetchService.onTrackChanged();
          _startPrefetch(_currentTrack!);
          // Sempre agenda checagens e o fim da faixa (antes, com rotação "calibrada", nada era
          // agendado e o app parava após a 2ª música)
          _syncCheckIndex = 0;
          _scheduleNextSyncCheck();
          _scheduleEndOfTrackListener();
          return;
        }

        // ═══ CENÁRIO 2: Previsão alternativa ou errada ═══
        final lastPred = _lastPrediction ?? _prefetchService.lastPrediction;
        final isAlternative = lastPred?.alternative != null &&
            TracklistMatcher.isSameTrack(
              confirmed.title,
              confirmed.artist,
              lastPred!.alternative!.entry.title,
              confirmed.artist,
            );
        final isAfterNext = lastPred?.afterNext != null &&
            TracklistMatcher.isSameTrack(
              confirmed.title,
              confirmed.artist,
              lastPred!.afterNext!.entry.title,
              confirmed.artist,
            );

        if (isAlternative) {
          debugPrint('[WaxClubEngine] 🔀 Previsão alternativa confirmada ("${lastPred.alternative!.albumTitle}"): "${confirmed.title}"');
          _logService.log('prediction_alternative_confirmed', {
            'predicted': predicted.title,
            'confirmed': confirmed.title,
          });
        } else if (isAfterNext) {
          debugPrint('[WaxClubEngine] ⏩ Pulo de faixa detectado (afterNext): "${confirmed.title}"');
          _logService.log('prediction_after_next_confirmed', {
            'predicted': predicted.title,
            'confirmed': confirmed.title,
          });
        } else {
          debugPrint('[WaxClubEngine] ⚠️ Previsão INCORRETA. Faixa real: "${confirmed.title}" (previsto: "${predicted.title}")');
          _logService.log('prediction_rejected', {
            'predicted': predicted.title,
            'confirmed': confirmed.title,
          });
          _consecutiveConfirmationsOnAlbum = 0;
          _currentAlbumBeingConfirmed = null;
        }

        if (isAlbumLocked && !_isTrackInLockedAlbum(confirmed)) {
          _unlockAlbum(reason: 'Música anômala "${confirmed.title}" fora da tracklist do disco travado "$_lockedAlbumName"');
        }

        await _transitionToNewTrack(confirmed, outcome.captureStart, mySession);
        return;
      } else {
        final currentElapsed = DateTime.now().difference(startTime).inSeconds;
        _telemetry = _telemetry.copyWith(
          diagnosticMessage: 'Not confirmed for ${currentElapsed}s',
          statusMessage: l10n.statusNotConfirmedFor(currentElapsed),
        );
        notifyListeners();
      }
    }

    if (_sessionId != mySession || _isDisposed) return;

    // Desistir apenas após giveUpAfter (ou esgotar tentativas)
    debugPrint('[WaxClubEngine] 🔇 Confirmação persistente esgotada após ${PredictionTuning.giveUpAfter.inSeconds}s. Assumindo fim de reprodução.');
    _logService.log('prediction_gave_up', {
      'predicted': predicted.title,
    });
    _resetState();
    _recordService.cancelRecording();
    _updateStatus(
      CalibrationStatus.idle,
      l10n.statusPlaybackEnded,
      isMicActive: false,
    );
  });
}

  /// Protocolo persistente de captura e identificação quando não há previsão disponível.
  Future<void> _listenAndIdentifyNextTrack(int mySession, {double? previousDuration}) async {
    await _guarded('_listenAndIdentifyNextTrack', () async {
      final startTime = DateTime.now();
    const retryDelays = PredictionTuning.retryDelaysSeconds;

    for (int attempt = 0; attempt < retryDelays.length; attempt++) {
      if (_sessionId != mySession || _isDisposed || _isPaused) return;

      final elapsed = DateTime.now().difference(startTime);
      if (elapsed >= PredictionTuning.giveUpAfter) break;

      if (attempt > 0) {
        final targetElapsedSec = retryDelays[attempt];
        final currentElapsedSec = DateTime.now().difference(startTime).inSeconds;
        final waitSec = targetElapsedSec - currentElapsedSec;
        if (waitSec > 0) {
          await Future.delayed(Duration(seconds: waitSec));
        }
      }

      if (_sessionId != mySession || _isDisposed || _isPaused) return;

      _updateStatus(
        CalibrationStatus.listeningNextTrack,
        l10n.statusListeningNextAttempt(attempt + 1, retryDelays.length),
        isMicActive: true,
      );

      // Escuta progressiva: 4/8/12s na 1ª tentativa (rápida) e 8/12s nas seguintes (robusta)
      final outcome = await _captureAndIdentify(checkpoints: PredictionTuning.identificationCheckpointsFor(attempt));
      if (_sessionId != mySession || _isDisposed) return;

      if (outcome.silent) {
        final curSec = DateTime.now().difference(startTime).inSeconds;
        _updateStatus(
          CalibrationStatus.listeningNextTrack,
          l10n.statusSilenceWaitingNeedle(curSec),
          isMicActive: false,
        );
        continue;
      }

      final nextTrack = outcome.track;
      if (nextTrack != null) {
        if (_currentTrack != null &&
            TracklistMatcher.isSameTrack(nextTrack.title, nextTrack.artist, _currentTrack!.title, _currentTrack!.artist)) {
          // A mesma faixa ainda toca (fim estimado cedo demais): realinha e estende a duração conhecida
          _anchorToRecognition(nextTrack, outcome.captureStart);
          _trackDurationSeconds = math.max(previousDuration ?? 0.0, _currentPositionSeconds + 15.0);
          debugPrint('[WaxClubEngine] ↩️ "${nextTrack.title}" ainda tocando em ${_currentPositionSeconds.toStringAsFixed(0)}s. Duração ajustada para ${_trackDurationSeconds!.toStringAsFixed(0)}s.');
          _startPlaybackTicker();
          _syncCheckIndex = 0;
          _scheduleNextSyncCheck();
          _scheduleEndOfTrackListener();
          return;
        }

        if (isAlbumLocked && !_isTrackInLockedAlbum(nextTrack)) {
          _unlockAlbum(reason: 'Música capturada "${nextTrack.title}" fora da tracklist do disco travado "$_lockedAlbumName"');
        }

        await _transitionToNewTrack(nextTrack, outcome.captureStart, mySession);
        return;
      } else {
        final curSec = DateTime.now().difference(startTime).inSeconds;
        _telemetry = _telemetry.copyWith(
          diagnosticMessage: 'Not identified for ${curSec}s',
        );
        notifyListeners();
      }
    }

    if (_sessionId != mySession || _isDisposed) return;
    _resetState();
    _recordService.cancelRecording();
    _updateStatus(
      CalibrationStatus.idle,
      l10n.statusPlaybackEndedOrStopped,
      isMicActive: false,
    );
  });
}

  /// Executa a transição completa para uma nova faixa.
  Future<void> _transitionToNewTrack(TrackInfo nextTrack, DateTime captureStartTime, int mySession) async {
    debugPrint('[WaxClubEngine] 🎵 Transitando para: "${nextTrack.title}" por "${nextTrack.artist}"');

    // Encerra os agendamentos da faixa anterior e incorpora a rotação medida nela
    _syncCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _endOfTrackTimer?.cancel();
    _commitTrackSpeed();
    _trackDurationSeconds = null;

    // Destravar disco caso a faixa seja uma anomalia em relação ao disco travado
    if (isAlbumLocked && !_isTrackInLockedAlbum(nextTrack)) {
      _unlockAlbum(reason: 'Nova faixa "${nextTrack.title}" não pertence à tracklist de "$_lockedAlbumName"');
    }

    _updateStatus(
      CalibrationStatus.fetchingLyrics,
      l10n.statusFetchingLyrics(nextTrack.title),
      isMicActive: false,
    );

    final resolved = await _resolveLyricsFor(nextTrack);
    if (_sessionId != mySession || _isDisposed) return;

    final lrcContent = resolved.lrcContent;
    _trackDurationSeconds = _bestDuration(nextTrack.title, resolved.durationSeconds);

    if (lrcContent != null && lrcContent.isNotEmpty) {
      _lyrics = LrcParser.parse(
        lrcContent,
        estimatedDurationSeconds: _trackDurationSeconds,
      );
    } else {
      _lyrics = [];
    }

    _trackDurationSeconds ??= _estimateTrackDuration(nextTrack, _lyrics);

    // Se o disco estiver travado, NUNCA usar album ou coverUrl vindos do Shazam!
    final officialAlbum = isAlbumLocked
        ? _lockedAlbumName!
        : (resolved.album ?? nextTrack.album);
    final effectiveCover = isAlbumLocked
        ? _lockedAlbumCoverUrl
        : (nextTrack.coverUrl ??
            _currentTrack?.coverUrl ??
            (_sessionHistory.isNotEmpty ? _sessionHistory.first.coverUrl : null) ??
            _cacheService.findCachedDisc(officialAlbum ?? '', nextTrack.artist)?.coverUrl);
    nextTrack = nextTrack.copyWith(
      lrcContent: lrcContent,
      album: officialAlbum,
      coverUrl: effectiveCover,
      durationMs: _trackDurationSeconds != null ? (_trackDurationSeconds! * 1000).round() : nextTrack.durationMs,
      isAlbumLocked: isAlbumLocked,
    );

    // Se o disco NÃO estava travado: trilha de novela (sem disco preferido) ou disco em cache
    final soundtrack = isAlbumLocked ? null : _soundtrackFor(nextTrack);
    if (soundtrack != null) {
      await _lockSoundtrack(soundtrack);
      if (_sessionId != mySession || _isDisposed) return;
      nextTrack = nextTrack.copyWith(album: _lockedAlbumName, coverUrl: _lockedAlbumCoverUrl, isAlbumLocked: true);
    } else if (!isAlbumLocked) {
      final cachedDisc = _cacheService.findCachedDisc(officialAlbum ?? '', nextTrack.artist) ??
          _cacheService.findDiscWithTrack(nextTrack.title, nextTrack.artist);
      if (cachedDisc != null) {
        _lockAlbum(
          albumName: cachedDisc.album,
          coverUrl: cachedDisc.coverUrl ?? effectiveCover,
          artist: nextTrack.artist,
          tracklist: cachedDisc.tracklist,
        );
        nextTrack = nextTrack.copyWith(
          album: _lockedAlbumName,
          coverUrl: _lockedAlbumCoverUrl ?? effectiveCover,
          isAlbumLocked: true,
        );
      }
    }

    if (_sessionHistory.isNotEmpty && _lockedAlbumSource == null) {
      _prefetchService.resolveAlbumCover(
        firstTrack: _sessionHistory.first,
        secondTrack: nextTrack,
      ).then((resolved) {
        // Descarta resultado tardio se a sessão foi reiniciada/parada ou a faixa já mudou
        if (_sessionId != mySession || _isDisposed) return;
        final playing = _currentTrack;
        if (playing == null ||
            !TracklistMatcher.isSameTrack(playing.title, playing.artist, nextTrack.title, nextTrack.artist)) {
          return;
        }
        if (resolved != null) {
          if (resolved.coverUrl != null || resolved.tracklist.isNotEmpty) {
            _lockAlbum(
              albumName: resolved.albumName,
              coverUrl: resolved.coverUrl ?? _lockedAlbumCoverUrl,
              artist: nextTrack.artist,
              tracklist: resolved.tracklist,
            );
          }
          final newCover = _lockedAlbumCoverUrl ?? resolved.coverUrl;
          final newAlbum = _lockedAlbumName ?? resolved.albumName;
          _currentTrack = _currentTrack?.copyWith(
            album: newAlbum,
            coverUrl: newCover,
            isAlbumLocked: isAlbumLocked,
          );
          if (resolved.coverUrl != null) {
            _cacheService.updateDiscCover(resolved.albumName, nextTrack.artist, resolved.coverUrl!);
          }
          notifyListeners();
        }
      }).catchError((e) => debugPrint('[WaxClubEngine] Retificação de capa falhou (não crítica): $e'));
    }

    // Salva qualquer debounce de nudge pendente da faixa anterior
    _flushPendingNudge();

    _sessionHistory.add(nextTrack);
    _sessionConfirmedTitles.add(nextTrack.title);
    _currentTrack = nextTrack;
    await _cacheService.cacheTrack(nextTrack, lrcContent);

    // Carrega deslocamento salvo de letra (nudge) para a nova faixa
    final savedOffsetMs = _cacheService.getLyricOffsetMs(nextTrack.title, nextTrack.artist);
    _lyricBiasSeconds = (savedOffsetMs / 1000.0).clamp(
      -PredictionTuning.maxNudgeBiasSeconds,
      PredictionTuning.maxNudgeBiasSeconds,
    );
    if (_lyricBiasSeconds != 0.0) {
      debugPrint('[WaxClubEngine] 🎚️ Nudge salvo reaplicado para "${nextTrack.title}": ${_lyricBiasSeconds.toStringAsFixed(2)}s');
    }

    // Regra de pelo menos 3 confirmações em ordem sequencial para salvar preferredAlbum
    final albumName = nextTrack.album;
    if (albumName != null && albumName.isNotEmpty) {
      if (_currentAlbumBeingConfirmed == albumName) {
        _consecutiveConfirmationsOnAlbum++;
      } else {
        _currentAlbumBeingConfirmed = albumName;
        _consecutiveConfirmationsOnAlbum = 1;
      }

      unawaited(_checkAndConfirmPreferredAlbum(albumName, nextTrack.artist));
    }

    _anchorToRecognition(nextTrack, captureStartTime);
    _activeLineIndex = -1;

    debugPrint('[WaxClubEngine] ✅ Nova faixa ativa: baseOffset=${_baseOffset.toStringAsFixed(2)}s, duração=${_trackDurationSeconds?.toStringAsFixed(1)}s, $_speedLabel');

    _startPlaybackTicker();
    if (_castService.isConnected) {
      _castService.sendTrack(nextTrack, _lyrics, side: _sideFor(nextTrack.title));
    }
    _syncCheckIndex = 0;
    _scheduleNextSyncCheck();
    _scheduleEndOfTrackListener();
    _prefetchService.onTrackChanged();
    _startPrefetch(nextTrack);
  }

  /// Valida a ordem sequencial das faixas e só confirma o álbum como preferencial
  /// se pelo menos 3 músicas consecutivas baterem com a ordem oficial da tracklist.
  Future<void> _checkAndConfirmPreferredAlbum(String albumName, String artist) async {
    if (_sessionHistory.length < 3 || _consecutiveConfirmationsOnAlbum < 3) {
      debugPrint(
        '[WaxClubEngine] ℹ️ Álbum "$albumName" em observação (${_sessionHistory.length}/3 faixas, consecutivas: $_consecutiveConfirmationsOnAlbum/3). Aguardando pelo menos 3 faixas para confirmar preferencial.',
      );
      return;
    }

    final sessionTitles = _sessionHistory.map((t) => t.title).toList();

    // 1. Obter tracklist do álbum em cache ou no prefetch
    List<TrackEntry> tracklist = _cacheService.getTracklist(albumName, artist);
    if (tracklist.isEmpty) {
      final disc = _cacheService.findCachedDisc(albumName, artist);
      if (disc != null && disc.tracklist.isNotEmpty) {
        tracklist = disc.tracklist;
      }
    }
    if (tracklist.isEmpty) {
      tracklist = _prefetchService.currentDiscTracklist;
    }

    // 2. Se a tracklist for conhecida, validar a ordem estrita das faixas
    if (tracklist.isNotEmpty) {
      final isOrderCorrect = TracklistMatcher.isSequentialMatch(tracklist, sessionTitles);
      if (!isOrderCorrect) {
        debugPrint(
          '[WaxClubEngine] ⚠️ Ordem das faixas tocadas não coincide com a tracklist de "$albumName". Coletânea/álbum descartado como preferencial.',
        );
        _consecutiveConfirmationsOnAlbum = 0;
        _currentAlbumBeingConfirmed = null;
        return;
      }
    }

    // 3. Ordem verificada e >= 3 faixas consecutivas: confirmar álbum preferencial!
    await _cacheService.setPreferredAlbumBatch(_sessionHistory.toList(), albumName);
    debugPrint(
      '[WaxClubEngine] 🎯 Álbum preferido CONFIRMADO por sequência de ${_sessionHistory.length} faixas com ordem validada: "$albumName"',
    );
  }

  /// Entra no estado de espera ao final do lado físico do disco (D5).
  void _enterWaitingEndOfSide(String? sideLabel) {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _syncCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _endOfTrackTimer?.cancel();

    _waitingEndOfSideEnteredAt = DateTime.now();

    final label = (sideLabel != null && sideLabel.isNotEmpty) ? sideLabel : 'A';
    // Próximo lado: o da 1ª faixa após a virada (previsão), ou a letra seguinte (A → B, C → D)
    final afterFlipSide = (_lastPrediction ?? _prefetchService.lastPrediction)?.afterFlip?.entry.side;
    _nextSideLabel = (afterFlipSide != null && afterFlipSide.isNotEmpty)
        ? afterFlipSide
        : (label.length == 1 ? String.fromCharCode(label.codeUnitAt(0) + 1) : null);
    _sideFlipAnnounced = false;
    _logService.log('side_end_reached', {'side': label, 'nextSide': _nextSideLabel});
    // Fim do último lado (B num LP simples, D num duplo...): acabou o disco, a chave MANUAL desliga
    final record = _lockedTracklist.isNotEmpty ? _lockedTracklist : _prefetchService.currentDiscTracklist;
    if (isLastSideOfRecord(record, label)) _resetManualMode('record_finished');
    _telemetry = _telemetry.copyWith(
      status: CalibrationStatus.waitingEndOfSide,
      statusMessage: l10n.statusEndOfSideFlip(label),
      sideEndLabel: _sideEndLabelFor(label),
      isMicActive: false,
      nextLyricsReady: false,
      predictedNextTrackTitle: null,
      clearPredictedNext: true,
    );
    notifyListeners();

    _sendCastSyncWithTvLookahead();

    _scheduleSideFlipProbe(initial: true);
  }

  /// Agenda sondagem silenciosa da virada de disco.
  void _scheduleSideFlipProbe({bool initial = false}) {
    _sideFlipProbeTimer?.cancel();
    if (_isDisposed || _isPaused) return;

    final delay = initial
        ? PredictionTuning.sideFlipFirstProbe
        : PredictionTuning.sideFlipProbeInterval;

    debugPrint('[WaxClubEngine] ⏳ Agendando sondagem de virada de disco em ${delay.inSeconds}s...');
    _sideFlipProbeTimer = Timer(delay, () async {
      await _executeSideFlipProbe(userTriggered: false);
    });
  }

  /// Indica que o lado do disco terminou e o app aguarda a virada (o botão vira "Vire o disco").
  bool get isAwaitingSideFlip => _waitingEndOfSideEnteredAt != null;

  /// Lado que deve começar após a virada ("B" depois de "A"...), para a animação na TV.
  String? _nextSideLabel;

  /// A TV já recebeu o aviso de virada nesta espera (evita animar duas vezes).
  bool _sideFlipAnnounced = false;

  void _announceSideFlip() {
    if (_sideFlipAnnounced) return;
    _sideFlipAnnounced = true;
    if (_castService.isConnected) {
      _castService.sendSideFlip(nextSide: _nextSideLabel);
    }
  }

  /// Ação do botão "Vire o disco": anima a virada na TV e escuta o novo lado mantendo o disco travado,
  /// a tracklist e a previsão (ao contrário de [startListening], que recomeça a sessão do zero).
  ///
  /// Com a 1ª faixa do novo lado prevista, ela aparece NA HORA, parada em 0:00 ("aguardando a agulha"):
  /// tanto faz o usuário virar o disco antes ou depois de tocar no botão. No primeiro som de música a
  /// letra começa a correr, e cada reconhecimento do Shazam corrige o timestamp (ou troca a faixa).
  Future<void> flipSide() async {
    if (!isAwaitingSideFlip) {
      await startListening();
      return;
    }
    if (_telemetry.status != CalibrationStatus.waitingEndOfSide) return; // já escutando o novo lado
    _announceSideFlip();
    _sideFlipProbeTimer?.cancel();
    _sideFlipProbeTimer = null;

    final predicted = _afterFlipTrack();
    if (predicted == null) {
      // Sem tracklist do novo lado: escuta e identifica (rápida primeiro, robusta depois)
      await _executeSideFlipProbe(userTriggered: true);
      return;
    }

    // Nova sessão: invalida a sondagem em andamento (o resultado dela será ignorado) e libera o microfone
    final mySession = ++_sessionId;
    await _recordService.cancelAndWait();
    if (_sessionId != mySession || _isDisposed) return;

    _waitingEndOfSideEnteredAt = null;
    _telemetry = _telemetry.copyWith(sideEndLabel: null, clearSideEndLabel: true);
    _awaitingNeedle = true;
    debugPrint('[WaxClubEngine] 💿 Virada pelo botão: exibindo "${predicted.title}" em 0:00, aguardando a agulha.');
    _logService.log('side_flip_predicted', {'title': predicted.title, 'side': _nextSideLabel});

    final shown = await _showPredictedTrack(predicted, mySession, startTicker: false);
    if (shown == null) {
      _awaitingNeedle = false;
      return;
    }
    _updateStatus(
      CalibrationStatus.confirmingPrediction,
      l10n.statusWaitingNeedle(shown.title),
      isMicActive: true,
    );
    _sendCastSyncWithTvLookahead();
    unawaited(_awaitNeedleAndConfirm(shown, mySession));
  }

  /// A letra exibida está parada em 0:00 esperando a agulha tocar o novo lado.
  bool _awaitingNeedle = false;
  bool get isAwaitingNeedle => _awaitingNeedle;

  /// 1ª faixa do próximo lado: pela previsão do disco ou, com o disco travado, pela tracklist.
  TrackInfo? _afterFlipTrack() {
    final current = _currentTrack;
    final afterFlip = (_lastPrediction ?? _prefetchService.lastPrediction)?.afterFlip?.entry;
    String? title = afterFlip?.title;
    String? entryArtist = afterFlip?.artist;
    if (title == null && _lockedTracklist.isNotEmpty && _nextSideLabel != null) {
      for (final entry in _lockedTracklist) {
        if (entry.side == _nextSideLabel) {
          title = entry.title;
          entryArtist = entry.artist;
          break;
        }
      }
    }
    // Coletâneas/trilhas: o artista é o da própria faixa
    final artist = entryArtist ?? _lockedAlbumArtist ?? current?.artist;
    if (artist == null) return null;
    if (title == null || title.isEmpty) return null;
    final album = isAlbumLocked
        ? _lockedAlbumName
        : ((_lastPrediction ?? _prefetchService.lastPrediction)?.afterFlip?.albumTitle ?? current?.album);
    return TrackInfo(
      title: title,
      artist: artist,
      album: album,
      offsetSeconds: 0.0,
      lrcContent: _cacheService.findCachedLyrics(title, artist),
      coverUrl: isAlbumLocked ? _lockedAlbumCoverUrl : current?.coverUrl,
      isAlbumLocked: isAlbumLocked,
    );
  }

  /// Faz a letra começar a correr a partir do primeiro som ouvido (a agulha encontrando a música).
  void _startFromNeedle(DateTime onset) {
    if (!_awaitingNeedle) return;
    _awaitingNeedle = false;
    final now = DateTime.now();
    final elapsed = math.max(0.0, now.difference(onset).inMilliseconds / 1000.0);
    _baseOffset = elapsed * effectiveSpeedFactor;
    _currentPositionSeconds = _baseOffset;
    _tStart = now;
    debugPrint('[WaxClubEngine] 🎶 Agulha no novo lado: letra iniciada em ${_baseOffset.toStringAsFixed(1)}s.');
    _logService.log('needle_onset', {'title': _currentTrack?.title, 'position': _baseOffset});
    _startPlaybackTicker();
  }

  /// Após virar o disco com a faixa prevista na tela: escuta até a agulha tocar, inicia a letra no
  /// primeiro som e confirma/corrige pelo Shazam (escuta rápida primeiro, robusta nas seguintes).
  Future<void> _awaitNeedleAndConfirm(TrackInfo predicted, int mySession) async {
    await _guarded('_awaitNeedleAndConfirm', () async {
      final waitStart = DateTime.now();
      DateTime? musicStartedAt;
      var attempt = 0;

      while (true) {
        if (_sessionId != mySession || _isDisposed || _isPaused) return;

        // Música tocando há muito tempo sem reconhecimento: mantém a previsão e segue o fluxo normal
        if (musicStartedAt != null &&
            DateTime.now().difference(musicStartedAt) >= PredictionTuning.giveUpAfter) {
          debugPrint('[WaxClubEngine] ⚠️ Novo lado sem reconhecimento; mantendo a previsão "${predicted.title}".');
          _logService.log('side_flip_unconfirmed', {'title': predicted.title});
          _updateStatus(_telemetry.status, l10n.statusNotConfirmed(predicted.title), isMicActive: false);
          _syncCheckIndex = 0;
          _scheduleNextSyncCheck();
          _scheduleEndOfTrackListener();
          return;
        }
        // Agulha nunca chegou: desiste como na espera da virada
        if (musicStartedAt == null && DateTime.now().difference(waitStart) > PredictionTuning.sideFlipMaxWait) {
          _awaitingNeedle = false;
          _updateStatus(CalibrationStatus.idle, l10n.statusFlipTimeout, isMicActive: false);
          return;
        }

        _telemetry = _telemetry.copyWith(isMicActive: true);
        notifyListeners();
        final listenStart = DateTime.now();
        final outcome = await _captureAndIdentify(
          checkpoints: PredictionTuning.identificationCheckpointsFor(attempt),
        );
        if (_sessionId != mySession || _isDisposed) return;
        _telemetry = _telemetry.copyWith(isMicActive: false);
        // Escuta que voltou na hora (microfone indisponível): não gira o laço sem pausa
        final took = DateTime.now().difference(listenStart);
        if (took < const Duration(milliseconds: 300)) {
          await Future.delayed(const Duration(milliseconds: 300) - took);
          if (_sessionId != mySession || _isDisposed) return;
        }

        if (outcome.cancelled) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        if (outcome.silent) {
          // Ainda sem música: continua parada em 0:00 e escutando (sem gastar consultas ao Shazam)
          if (_awaitingNeedle) {
            _updateStatus(_telemetry.status, l10n.statusWaitingNeedle(predicted.title), isMicActive: false);
            _sendCastSyncWithTvLookahead();
          }
          continue;
        }

        // Houve som: a música começou. A letra corre a partir do instante do primeiro som.
        musicStartedAt ??= outcome.soundOnset ?? outcome.captureStart;
        final heard = outcome.track;

        if (heard == null) {
          _startFromNeedle(musicStartedAt);
          attempt++;
          continue;
        }

        if (!TracklistMatcher.isSameTrack(heard.title, heard.artist, predicted.title, predicted.artist)) {
          debugPrint('[WaxClubEngine] 🔀 Novo lado começou com "${heard.title}" (previsto: "${predicted.title}").');
          _logService.log('side_flip_prediction_rejected', {'predicted': predicted.title, 'heard': heard.title});
          _awaitingNeedle = false;
          if (isAlbumLocked && !_isTrackInLockedAlbum(heard)) {
            _unlockAlbum(reason: 'Música do novo lado "${heard.title}" fora da tracklist do disco travado "$_lockedAlbumName"');
          }
          await _transitionToNewTrack(heard, outcome.captureStart, mySession);
          return;
        }

        // Confirmada: o Shazam fixa o timestamp exato
        _awaitingNeedle = false;
        _anchorToRecognition(heard, outcome.captureStart);
        debugPrint('[WaxClubEngine] ✅ Novo lado confirmado: "${predicted.title}" em ${_currentPositionSeconds.toStringAsFixed(1)}s.');
        _logService.log('side_flip_confirmed', {'title': heard.title, 'artist': heard.artist, 'predicted': true});
        final confirmed = _currentTrack?.copyWith(
          durationMs: heard.durationMs ?? _currentTrack?.durationMs,
          coverUrl: isAlbumLocked ? _lockedAlbumCoverUrl : (heard.coverUrl ?? _currentTrack?.coverUrl),
        );
        if (confirmed != null) {
          _currentTrack = confirmed;
          _sessionHistory.add(confirmed);
          _sessionConfirmedTitles.add(confirmed.title);
          await _cacheService.cacheTrack(confirmed, confirmed.lrcContent);
          if (_sessionId != mySession || _isDisposed) return;
          if (_castService.isConnected) {
            _castService.sendTrack(confirmed, _lyrics, side: _sideFor(confirmed.title));
          }
        }
        _startPlaybackTicker();
        _updateStatus(
          CalibrationStatus.calibrated,
          l10n.statusConfirmed(predicted.title, _speedLabel),
          isMicActive: false,
        );
        _prefetchService.onTrackChanged();
        if (_currentTrack != null) _startPrefetch(_currentTrack!);
        _syncCheckIndex = 0;
        _scheduleNextSyncCheck();
        _scheduleEndOfTrackListener();
        return;
      }
    });
  }

  /// Executa sondagem do microfone ao aguardar virada de disco.
  Future<void> _executeSideFlipProbe({bool userTriggered = false}) async {
    await _guarded('_executeSideFlipProbe', () async {
      if (_isDisposed || _isPaused || _telemetry.status != CalibrationStatus.waitingEndOfSide) return;

    if (_waitingEndOfSideEnteredAt != null) {
      final elapsed = DateTime.now().difference(_waitingEndOfSideEnteredAt!);
      if (elapsed > PredictionTuning.sideFlipMaxWait) {
        debugPrint('[WaxClubEngine] ⏰ Tempo limite de virada atingido (${elapsed.inMinutes}min). Retornando a idle.');
        _sideFlipProbeTimer?.cancel();
        _sideFlipProbeTimer = null;
        _updateStatus(
          CalibrationStatus.idle,
          l10n.statusFlipTimeout,
          isMicActive: false,
        );
        return;
      }
    }

    final mySession = _sessionId;
    debugPrint('[WaxClubEngine] 🎧 Sondagem de virada de disco (userTriggered: $userTriggered)...');

    if (userTriggered) {
      _updateStatus(
        CalibrationStatus.listeningNextTrack,
        l10n.statusListeningNewSide,
        isMicActive: true,
      );
    }

    // Captura com gate de silêncio: agulha no sulco final não gasta chamada ao Shazam
    // Toque do usuário: escuta rápida primeiro (4/8/12s); sondagens automáticas: 8/12s
    final outcome = await _captureAndIdentify(
      checkpoints: userTriggered ? PredictionTuning.fastFirstCheckpoints : PredictionTuning.robustCheckpoints,
      priority: userTriggered ? RecordPriority.user : RecordPriority.background,
    );
    final captureStart = outcome.captureStart;
    final recognized = outcome.track;

    if (_isDisposed || _isPaused || _sessionId != mySession) return;
    // Sondagem interrompida (ex.: toque em "Vire o disco"): quem interrompeu assume a escuta.
    // Antes, a interrupção contava como "não reconhecido" e a sondagem era reagendada em loop.
    if (outcome.cancelled) return;

    if (recognized != null) {
      debugPrint('[WaxClubEngine] 🎉 Novo lado do disco reconhecido: "${recognized.title}" por "${recognized.artist}"');
      _logService.log('side_flip_confirmed', {
        'title': recognized.title,
        'artist': recognized.artist,
      });
      _sideFlipProbeTimer?.cancel();
      _sideFlipProbeTimer = null;
      _waitingEndOfSideEnteredAt = null;

      _telemetry = _telemetry.copyWith(
        sideEndLabel: null,
        clearSideEndLabel: true,
      );

      if (isAlbumLocked && !_isTrackInLockedAlbum(recognized)) {
        _unlockAlbum(reason: 'Música do novo lado "${recognized.title}" fora da tracklist do disco travado "$_lockedAlbumName"');
      }

      // Virada detectada sozinha pelo microfone (sem toque no botão): a TV também anima
      _announceSideFlip();
      await _transitionToNewTrack(recognized, captureStart, mySession);
    } else {
      debugPrint('[WaxClubEngine] 🔇 Sondagem de virada: silêncio ou não reconhecido.');
      if (userTriggered) {
        final side = _sideEndLetter;
        _updateStatus(
          CalibrationStatus.waitingEndOfSide,
          side != null && side.isNotEmpty ? l10n.statusNotIdentifiedSideEnded(side) : l10n.statusNotIdentifiedFlip,
          isMicActive: false,
        );
      }
      _scheduleSideFlipProbe(initial: false);
    }
  });
}

  /// Permite ao usuário adiantar ou atrasar a sincronização da letra em tempo real (+/- 0.5s ou +/- 1.0s).
  ///
  /// NOTA DE ARQUITETURA (T2.4 / D12):
  /// O nudge altera [_lyricBiasSeconds] e NÃO [_baseOffset], deslocando a busca da linha ativa sem
  /// corromper a barra de progresso ou ser apagado pelo realinhamento acústico periódico.
  void nudgeSync(double deltaSeconds) {
    _lyricBiasSeconds = (_lyricBiasSeconds + deltaSeconds).clamp(
      -PredictionTuning.maxNudgeBiasSeconds,
      PredictionTuning.maxNudgeBiasSeconds,
    );
    debugPrint('[WaxClubEngine] 🎚️ Nudge aplicado: delta=${deltaSeconds}s, biasTotal=${_lyricBiasSeconds.toStringAsFixed(2)}s');
    _logService.log('nudge_applied', {
      'delta': deltaSeconds,
      'totalBias': _lyricBiasSeconds,
      'track': _currentTrack?.title,
    });

    const leadTimeMs = 450;
    final lookaheadDuration = Duration(
      milliseconds: (((_currentPositionSeconds + _lyricBiasSeconds) * 1000) + leadTimeMs).round(),
    );
    _activeLineIndex = LrcParser.findActiveIndex(_lyrics, lookaheadDuration);
    _telemetry = _telemetry.copyWith(activeLineIndex: _activeLineIndex);
    notifyListeners();

    _sendCastSyncWithTvLookahead();
    _scheduleNudgeSave();
  }

  void _scheduleNudgeSave() {
    _nudgeDebounceTimer?.cancel();
    _nudgeDebounceTimer = Timer(PredictionTuning.nudgeDebounceDuration, () async {
      if (_currentTrack != null) {
        final ms = (_lyricBiasSeconds * 1000).round();
        await _cacheService.saveLyricOffset(_currentTrack!.title, _currentTrack!.artist, ms);
        debugPrint('[WaxClubEngine] 💾 Nudge persistido no cache: ${ms}ms para "${_currentTrack!.title}"');
      }
    });
  }

  /// Grava imediatamente um nudge ainda em debounce para a faixa atual, antes que ela seja trocada ou a sessão reiniciada.
  void _flushPendingNudge() {
    final timer = _nudgeDebounceTimer;
    _nudgeDebounceTimer = null;
    if (timer == null || !timer.isActive) return;
    timer.cancel();
    final track = _currentTrack;
    if (track != null) {
      final ms = (_lyricBiasSeconds * 1000).round();
      _cacheService.saveLyricOffset(track.title, track.artist, ms);
    }
  }

  /// Permite ao usuário pular para um ponto específico ao clicar numa estrofe (com 300ms de antecipação).
  void seekTo(double seconds) {
    _baseOffset = seconds;
    _tStart = DateTime.now();
    _currentPositionSeconds = seconds;
    const leadTimeMs = 300;
    final lookaheadDuration = Duration(
      milliseconds: (((seconds + _lyricBiasSeconds) * 1000) + leadTimeMs).round(),
    );
    _activeLineIndex = LrcParser.findActiveIndex(_lyrics, lookaheadDuration);
    _scheduleEndOfTrackListener();
    notifyListeners();
  }

  /// Permite ajuste fino manual do pitch slider (+/- 0.05).
  void setManualPitchAdjustment(double delta) {
    _manualPitchOffset = delta;
    _telemetry = _telemetry.copyWith(speedFactor: effectiveSpeedFactor);
    notifyListeners();
  }

  /// Pausa o acompanhamento e o microfone.
  void pause() {
    if (_isPaused) return;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _countdownTimer?.cancel();
    _syncCheckTimer?.cancel();
    _endOfTrackTimer?.cancel();
    _sideFlipProbeTimer?.cancel();
    _sideFlipProbeTimer = null;
    _isPaused = true;
    _updateStatus(
      CalibrationStatus.paused,
      l10n.statusSyncPaused(_formatDuration(_currentPositionSeconds)),
      isMicActive: false,
    );
  }

  /// Retoma o acompanhamento sincronizado.
  void resume() {
    if (!_isPaused || _isDisposed) return;
    _isPaused = false;

    // Pausado aguardando a virada do disco: retoma a espera e as sondagens, sem ticker de letra
    if (_waitingEndOfSideEnteredAt != null) {
      _waitingEndOfSideEnteredAt = DateTime.now();
      final sideLabel = _sideEndLetter ?? 'A';
      _updateStatus(
        CalibrationStatus.waitingEndOfSide,
        l10n.statusEndOfSideFlip(sideLabel),
        isMicActive: false,
      );
      _scheduleSideFlipProbe(initial: true);
      return;
    }

    _baseOffset = _currentPositionSeconds;
    _tStart = DateTime.now();
    // O tempo pausado quebra a relação tempo-real × música: incorpora o que foi medido e recomeça a regressão
    _commitTrackSpeed();
    _startPlaybackTicker();

    if (_currentTrack != null) {
      // Ressincroniza logo pelo microfone (a posição real após a pausa é desconhecida)
      _syncCheckIndex = 0;
      _scheduleNextSyncCheck(delaySeconds: PredictionTuning.resumeResyncDelaySeconds);
    }
    _scheduleEndOfTrackListener();
  }

  /// Alterna entre pausar e retomar a rolagem.
  void togglePlayPause() {
    if (_isPaused) {
      resume();
    } else {
      pause();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MODO MANUAL: letra e trocas de faixa pela minutagem do disco, sem Shazam.
  // O microfone só mede o volume para achar o começo da música (agulha no disco).
  // ═══════════════════════════════════════════════════════════════

  /// Tempo morto entre faixas no vinil (será aprendido com a minutagem medida).
  @visibleForTesting
  static double manualGapSeconds = 2.0;

  List<TrackEntry> _manualTracks = [];
  int _manualIndex = -1;
  int? _manualPendingIndex;
  bool _manualUseMic = true;
  Timer? _manualAdvanceTimer;

  /// Uma faixa do disco está tocando pelo Modo Manual (ou esperando a agulha).
  bool get isManualPlaying => _manualIndex >= 0;

  /// Faixa (índice na lista do disco) que começa ao tocar ▶ depois de virar o disco.
  int? get manualPendingIndex => _manualPendingIndex;

  /// Índice da faixa atual no Modo Manual (-1 se parado).
  int get manualTrackIndex => _manualIndex;

  /// Lista de faixas do disco usada no Modo Manual (o disco travado/escolhido).
  List<TrackEntry> get manualRecordTracklist => List.unmodifiable(
      _lockedTracklist.isNotEmpty ? _lockedTracklist : _prefetchService.currentDiscTracklist);

  /// Começa o disco na faixa [trackIndex]. Com [useMic], a letra fica parada em 0:00 até o microfone
  /// ouvir a música começar; sem microfone, começa na hora. Retorna `false` sem lista de faixas.
  Future<bool> startManualPlayback({required int trackIndex, bool useMic = true}) async {
    final tracks = manualRecordTracklist;
    if (tracks.isEmpty || trackIndex < 0 || trackIndex >= tracks.length) return false;
    _cancelAutomaticFlow();
    if (!_manualMode) {
      _manualMode = true;
      _logService.log('manual_mode', {'on': true, 'reason': 'manual_start'});
    }
    _manualTracks = List.of(tracks);
    _manualUseMic = useMic;
    _manualPendingIndex = null;
    _isPaused = false;
    _telemetry = _telemetry.copyWith(isUserListening: true, clearSideEndLabel: true, sideEndLabel: null);
    final mySession = _sessionId;
    final ok = await _manualShowTrack(trackIndex, mySession);
    if (!ok || _sessionId != mySession || _isDisposed) return false;
    _logService.log('manual_start', {'track': _currentTrack?.title, 'index': trackIndex, 'mic': useMic});
    if (useMic) {
      unawaited(_manualAwaitOnset(mySession));
    } else {
      _manualStartAt(DateTime.now());
    }
    return true;
  }

  /// Toque no ▶ depois de virar o disco: começa a próxima faixa (a 1ª do novo lado).
  Future<bool> startManualPending() async {
    final i = _manualPendingIndex;
    if (i == null) return false;
    return startManualPlayback(trackIndex: i, useMic: _manualUseMic);
  }

  /// Pula para a faixa [trackIndex] começando agora (sem esperar o microfone).
  Future<bool> manualJumpTo(int trackIndex) => startManualPlayback(trackIndex: trackIndex, useMic: false);

  /// Encerra a escuta manual (a chave continua como estiver).
  void stopManual() => _stopManual(l10n.statusMicOffStopped);

  void _cancelAutomaticFlow() {
    _sessionId++;
    _recordService.cancelRecording();
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _syncCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _endOfTrackTimer?.cancel();
    _sideFlipProbeTimer?.cancel();
    _sideFlipProbeTimer = null;
    _waitingEndOfSideEnteredAt = null;
    _awaitingNeedle = false;
    _manualAdvanceTimer?.cancel();
  }

  void _clearManualState() {
    _manualAdvanceTimer?.cancel();
    _manualAdvanceTimer = null;
    _manualIndex = -1;
    _manualPendingIndex = null;
    _manualTracks = [];
  }

  void _stopManual(String message) {
    _sessionId++;
    _recordService.cancelRecording();
    _tickerTimer?.cancel();
    _tickerTimer = null;
    _clearManualState();
    _telemetry = _telemetry.copyWith(isUserListening: false, clearSideEndLabel: true, sideEndLabel: null);
    _updateStatus(CalibrationStatus.idle, message, isMicActive: false);
  }

  /// Mostra a faixa [i] em 0:00 (letra carregada, relógio parado).
  Future<bool> _manualShowTrack(int i, int mySession) async {
    final e = _manualTracks[i];
    final artist = e.artist ?? _lockedAlbumArtist ?? _currentTrack?.artist ?? '';
    final track = TrackInfo(
      title: e.title,
      artist: artist,
      album: _lockedAlbumName,
      durationMs: e.lengthMs,
      coverUrl: _lockedAlbumCoverUrl,
      offsetSeconds: 0.0,
      isAlbumLocked: isAlbumLocked,
    );
    _manualIndex = i;
    final shown = await _showPredictedTrack(track, mySession, startTicker: false);
    if (shown == null) return false;
    // Duração pela minutagem do disco (LP primeiro); a do provedor de letras só se faltar
    final lp = (e.lengthMs ?? 0) > 0 ? e.lengthMs! / 1000.0 : null;
    if (lp != null) _trackDurationSeconds = lp;
    _telemetry = _telemetry.copyWith(trackDurationSeconds: _trackDurationSeconds);
    _updateStatus(
      CalibrationStatus.playingUncalibrated,
      l10n.manualWaitingNeedle(e.number ?? '${i + 1}', e.title),
      isMicActive: _manualUseMic,
    );
    return true;
  }

  /// Escuta só o volume (sem Shazam) até a música começar e inicia a letra no primeiro som.
  Future<void> _manualAwaitOnset(int mySession) async {
    final waitStart = DateTime.now();
    while (_sessionId == mySession && !_isDisposed) {
      if (DateTime.now().difference(waitStart) > PredictionTuning.sideFlipMaxWait) {
        _stopManual(l10n.manualNeedleTimeout);
        return;
      }
      _telemetry = _telemetry.copyWith(isMicActive: true);
      notifyListeners();
      final outcome = await _captureLevelOnly();
      if (_sessionId != mySession || _isDisposed) return;
      if (outcome.cancelled) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
      if (outcome.silent) continue;
      _telemetry = _telemetry.copyWith(isMicActive: false);
      _manualStartAt(outcome.soundOnset ?? outcome.captureStart);
      return;
    }
  }

  /// Captura curta só para medir o volume (nenhuma consulta ao Shazam).
  Future<CaptureOutcome> _captureLevelOnly({Duration chunk = const Duration(milliseconds: 1500)}) async {
    AudioLevelReport? report;
    final requestedAt = DateTime.now();
    final captureStart = await _recordService.recordProgressive(
      checkpoints: [chunk],
      priority: RecordPriority.user,
      onCheckpoint: (wav, _) async {
        report = AudioLevelAnalyzer.analyze(wav, referenceMusicDb: _referenceMusicDb);
        return true;
      },
    );
    final start = captureStart ?? _recordService.lastRecordStartTime ?? requestedAt;
    final r = report;
    if (captureStart == null && r == null) return CaptureOutcome(captureStart: start, silent: true, cancelled: true);
    return CaptureOutcome(captureStart: start, silent: r == null || r.isSilent, report: r);
  }

  /// A música começou em [onset]: a letra corre a partir dali e a troca de faixa é agendada.
  void _manualStartAt(DateTime onset) {
    final now = DateTime.now();
    final elapsed = math.max(0.0, now.difference(onset).inMilliseconds / 1000.0);
    _baseOffset = elapsed * effectiveSpeedFactor;
    _currentPositionSeconds = _baseOffset;
    _tStart = now;
    _startPlaybackTicker();
    final e = _manualTracks[_manualIndex];
    _updateStatus(
      CalibrationStatus.calibrated,
      (_trackDurationSeconds ?? 0) > 0 ? l10n.manualPlaying(e.number ?? '${_manualIndex + 1}', e.title) : l10n.manualNoDuration,
      isMicActive: false,
    );
    if (_castService.isConnected && _currentTrack != null) {
      _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
    }
    _scheduleManualAdvance();
  }

  /// Agenda a próxima faixa para o fim desta (minutagem + tempo morto entre faixas).
  void _scheduleManualAdvance() {
    _manualAdvanceTimer?.cancel();
    final d = _trackDurationSeconds;
    if (!isManualPlaying || _tStart == null || _isPaused || d == null || d <= 0) return;
    final seconds = (d - _currentPositionSeconds) / effectiveSpeedFactor + manualGapSeconds;
    final mySession = _sessionId;
    _manualAdvanceTimer = Timer(Duration(milliseconds: (math.max(0.0, seconds) * 1000).round()), () {
      if (_sessionId == mySession && !_isDisposed) _manualAdvance(mySession);
    });
  }

  /// Fim da faixa: próxima faixa do mesmo lado, fim do lado (virar o disco) ou fim do disco.
  Future<void> _manualAdvance(int mySession) async {
    final i = _manualIndex;
    if (i < 0) return;
    final next = i + 1;
    final side = _manualTracks[i].side;
    final atEnd = next >= _manualTracks.length;
    final nextSide = atEnd ? null : _manualTracks[next].side;
    final sideEnds = !atEnd && side != null && nextSide != null && side.isNotEmpty && nextSide != side;

    if (atEnd || (side != null && isLastSideOfRecord(_manualTracks, side) && sideEnds)) {
      // Acabou a última música do último lado: fim do disco, a chave MANUAL desliga
      _logService.log('manual_record_end', {'last': _manualTracks[i].title});
      _resetManualMode('record_finished');
      _stopManual(l10n.manualRecordEnded);
      return;
    }
    if (sideEnds) {
      _tickerTimer?.cancel();
      _tickerTimer = null;
      _manualPendingIndex = next;
      _manualIndex = -1;
      final label = side;
      _logService.log('manual_side_end', {'side': label, 'next': _manualTracks[next].title});
      _telemetry = _telemetry.copyWith(sideEndLabel: _sideEndLabelFor(label));
      _updateStatus(CalibrationStatus.waitingEndOfSide, l10n.manualFlipAndPlay(label), isMicActive: false);
      return;
    }
    // Mesmo lado: a próxima faixa começa agora (o tempo morto já passou)
    final ok = await _manualShowTrack(next, mySession);
    if (!ok || _sessionId != mySession || _isDisposed) return;
    _manualStartAt(DateTime.now());
  }

  /// Carrega manualmente uma música com letra (.lrc) para demonstração e testes imediatos.
  Future<void> loadManualTrack({
    required String title,
    required String artist,
    required double startOffsetSeconds,
    String? lrcText,
  }) async {
    _resetState();
    _isPaused = false;

    _currentTrack = TrackInfo(
      title: title,
      artist: artist,
      offsetSeconds: startOffsetSeconds,
    );

    _baseOffset = startOffsetSeconds;
    _tStart = DateTime.now();
    _speedFactor = 1.018;

    if (lrcText != null && lrcText.isNotEmpty) {
      _lyrics = LrcParser.parse(lrcText);
    } else {
      final fetched = await _lyricsService.fetchSyncedLyrics(
        trackName: title,
        artistName: artist,
      );
      if (fetched != null) {
        _lyrics = LrcParser.parse(fetched);
      }
    }

    _trackDurationSeconds = _estimateTrackDuration(_currentTrack!, _lyrics);

    _startPlaybackTicker();
    if (_castService.isConnected && _currentTrack != null) {
      _castService.sendTrack(_currentTrack!, _lyrics, side: _sideFor(_currentTrack!.title));
    }
    _updateStatus(
      CalibrationStatus.calibrated,
      l10n.statusSpeedCalibrated(_speedFactor.toStringAsFixed(3)),
      isMicActive: false,
    );
  }

  @visibleForTesting
  Future<void> handleManualTrackTransitionForTesting(TrackInfo track, [DateTime? captureTime]) async {
    await _transitionToNewTrack(track, captureTime ?? DateTime.now(), _sessionId);
  }

  @visibleForTesting
  Future<TrackInfo?> predictNextTrackForTesting() async {
    return _predictNextTrack();
  }

  String _formatDuration(double seconds) {
    final s = seconds.clamp(0.0, 99999.0).round();
    final mins = s ~/ 60;
    final secs = s % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _updateStatus(CalibrationStatus status, String message, {bool isMicActive = false}) {
    _telemetry = _telemetry.copyWith(
      status: status,
      statusMessage: message,
      speedFactor: effectiveSpeedFactor,
      isPaused: _isPaused,
      isMicActive: isMicActive,
      trackDurationSeconds: _trackDurationSeconds,
      clearTrackDuration: _trackDurationSeconds == null,
      activeMicrophoneName: _recordService.activeDeviceName,
    );
    notifyListeners();
  }

  void _resetState() {
    _sideFlipProbeTimer?.cancel();
    _sideFlipProbeTimer = null;
    _waitingEndOfSideEnteredAt = null;
    _tickerTimer?.cancel();
    _syncCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _endOfTrackTimer?.cancel();
    _activeLineIndex = -1;
    _currentPositionSeconds = 0.0;
    // A rotação medida na faixa entra no modelo do toca-discos, que é preservado (propriedade do hardware)
    _commitTrackSpeed();
    _currentSpeedEstimate = null;
    if (!_isPitchLocked) _speedFactor = _turntable.mean;
    _syncCheckIndex = 0;
    _manualPitchOffset = 0.0;
    _isPaused = false;
    _trackDurationSeconds = null;
    _lastPrediction = null;
    _consecutiveConfirmationsOnAlbum = 0;
    _currentAlbumBeingConfirmed = null;
    _unlockAlbum(reason: 'Reinício de estado da sessão');
    _flushPendingNudge();
    _lyricBiasSeconds = 0.0;
    _telemetry = _telemetry.copyWith(
      trackDurationSeconds: null,
      clearTrackDuration: true,
      predictedNextTrackTitle: null,
      clearPredictedNext: true,
      sideEndLabel: null,
      clearSideEndLabel: true,
      nextLyricsReady: false,
      isUserListening: false,
      speedFactor: _speedFactor,
      isHardwareSpeedCalibrated: isHardwareSpeedCalibrated,
    );
  }

  /// Para IMEDIATAMENTE a escuta, cancela gravação do microfone e reseta a sessão.
  void stop() {
    _sessionId++;
    _clearManualState();
    _resetState();
    _recordService.cancelRecording();
    _prefetchService.clearSession();
    _sessionHistory.clear();
    _sessionConfirmedTitles.clear();
    _currentTrack = null;
    _lyrics = [];
    _castService.sendStop();
    _telemetry = _telemetry.copyWith(
      sideEndLabel: null,
      clearSideEndLabel: true,
      nextLyricsReady: false,
      predictedNextTrackTitle: null,
      clearPredictedNext: true,
      trackDurationSeconds: null,
      clearTrackDuration: true,
      isUserListening: false,
    );
    _updateStatus(
      CalibrationStatus.idle,
      l10n.statusMicOffStopped,
      isMicActive: false,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _resetState();
    _recordService.dispose();
    _shazamService.dispose();
    _lyricsService.dispose();
    _cacheService.dispose();
    _prefetchService.dispose();
    _logService.dispose();
    _castService.dispose();
    super.dispose();
  }
}

/// Resultado da captura acústica e análise de nível de áudio / identificação.
class CaptureOutcome {
  final TrackInfo? track;
  final DateTime captureStart;
  final bool silent;
  final AudioLevelReport? report;

  /// Gravação interrompida por outra de maior prioridade (ex.: toque do usuário): não é "não reconhecida".
  final bool cancelled;

  /// Instante real em que o som começou dentro da captura (ex.: a agulha encontrando a música).
  DateTime? get soundOnset {
    final s = report?.soundOnsetSeconds;
    return s == null ? null : captureStart.add(Duration(milliseconds: (s * 1000).round()));
  }

  const CaptureOutcome({
    this.track,
    required this.captureStart,
    this.silent = false,
    this.report,
    this.cancelled = false,
  });
}

/// Informações de letra resolvidas no engine através da cascata de cache/rede.
class _ResolvedLyrics {
  final String? lrcContent;
  final double? durationSeconds;
  final String? album;
  final String source; // 'memory', 'cache', 'network', 'none'
  final String? lyricsSource;

  const _ResolvedLyrics({
    this.lrcContent,
    this.durationSeconds,
    this.album,
    this.source = 'none',
    this.lyricsSource,
  });
}
