import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import '../../app_info.dart';
import '../../engine/waxclub_engine.dart';
import '../../models/sync_state.dart';
import '../../models/track_entry.dart';
import '../../services/album_catalog_service.dart';
import '../../services/wikipedia_tracklist_service.dart';
import '../../services/discogs/discogs_auth_service.dart';
import '../../services/tracklist_matcher.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import '../widgets/lyrics_list_view.dart';
import '../widgets/vinyl_control_cockpit.dart';
import '../widgets/vinyl_status_footer.dart';
import '../widgets/cast_thinking_wheel_dialog.dart';
import '../widgets/flip_side_button.dart';
import '../widgets/album_picker_sheet.dart';
import '../widgets/home_greeting.dart';
import '../../services/collection_service.dart';
import '../../services/user_profile_store.dart';
import 'collection_screen.dart';
import 'record_scan_screen.dart';
import 'plugin_jukebox_screen.dart';
import '../widgets/curiosities_view.dart';
import '../../services/curiosities_service.dart';
import '../widgets/chrome_play_button.dart';
import '../widgets/manual_start_sheet.dart';
import '../widgets/wood_tile_button.dart';
import '../../services/plugins/plugin_catalog.dart';
import '../../services/discogs/discogs_collection_service.dart';
import '../../services/account/account_service.dart';
import 'help_screen.dart';

/// Tela principal do aplicativo WaxClub.
class HomeScreen extends StatefulWidget {
  /// Motor injetado nos testes (no app, a tela cria o seu).
  final WaxClubEngine? engine;

  /// Conta WaxClub (criada no início do app, antes do login); nos testes a tela cria a sua.
  final AccountService? account;

  const HomeScreen({super.key, this.engine, this.account});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final WaxClubEngine _engine;
  late final AnimationController _pulseController;
  Timer? _haloReminderTimer;
  Timer? _initialPulseTimer;
  bool _isHaloPulsing = false;

  /// Conta Discogs do usuário e catálogo de discos da tela "Mudar disco" (criados no primeiro uso).
  late final DiscogsAuthService _discogsAuth = DiscogsAuthService();
  late final AlbumCatalogService _albumCatalog = AlbumCatalogService(
    auth: _discogsAuth,
    wikipedia: WikipediaTracklistService(),
  );
  bool _albumCatalogCreated = false;

  /// Chaves dos botões de madeira, para os nomes da apresentação na abertura.
  final GlobalKey _cameraKey = GlobalKey();
  final GlobalKey _manualKey = GlobalKey();
  final GlobalKey _collectionKey = GlobalKey();
  final GlobalKey _pluginsKey = GlobalKey();
  final GlobalKey _helpKey = GlobalKey();

  /// Plugins instalados e ligados (jukebox).
  final PluginStore _plugins = PluginStore();

  /// Coleção do usuário no Discogs (adicionar discos reconhecidos pela câmera).
  late final DiscogsCollectionService _discogsCollection = DiscogsCollectionService(auth: _discogsAuth);

  /// Nome do usuário (saudação) e coleção local com o histórico de audições.
  final UserProfileStore _profile = UserProfileStore();
  final CollectionService _collection = CollectionService();

  /// Conta WaxClub (api.waxclub.com.br): sincroniza a coleção e as audições.
  late final AccountService _account = widget.account ?? AccountService();
  final int _greetingSeed = DateTime.now().millisecondsSinceEpoch;
  String? _lastPlayKey;

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? WaxClubEngine();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _engine.castService.addListener(_onCastServiceStateChanged);
    _engine.addListener(_recordPlayIfNew);
    _profile.addListener(_onProfileChanged);
    _profile.load();
    _collection.load();
    _account.attachCollection(_collection);
    _account.load();
    _engine.castService.runInitialBackgroundDiscovery();

    // Lembrete periódico a cada 1 minuto (60 segundos)
    _haloReminderTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_engine.castService.hasDiscoveredDevices && !_engine.castService.isCastActive) {
        _triggerHaloPulse(cycles: 1);
      }
    });
  }

  bool _portraitLocked = false;

  /// Durante a transmissão o celular vira painel de controle: tela travada em retrato.
  /// Sem transmissão, o app volta a girar livremente.
  void _applyOrientationForCast() {
    final casting = _engine.castService.isCastActive;
    if (casting == _portraitLocked) return;
    _portraitLocked = casting;
    SystemChrome.setPreferredOrientations(
      casting ? const [DeviceOrientation.portraitUp] : DeviceOrientation.values,
    );
  }

  void _onCastServiceStateChanged() {
    _applyOrientationForCast();
    if (_engine.castService.hasDiscoveredDevices && !_engine.castService.isCastActive && !_isHaloPulsing) {
      _triggerHaloPulse(cycles: 3);
    }
  }

  void _triggerHaloPulse({int cycles = 3}) {
    if (_isHaloPulsing || !mounted) return;
    setState(() => _isHaloPulsing = true);
    _pulseController.repeat(reverse: true);

    _initialPulseTimer?.cancel();
    _initialPulseTimer = Timer(Duration(milliseconds: 1400 * cycles), () {
      if (mounted) {
        _pulseController.stop();
        _pulseController.reset();
        setState(() => _isHaloPulsing = false);
      }
    });
  }

  @override
  void dispose() {
    _haloReminderTimer?.cancel();
    _initialPulseTimer?.cancel();
    _engine.castService.removeListener(_onCastServiceStateChanged);
    _engine.removeListener(_recordPlayIfNew);
    _profile.removeListener(_onProfileChanged);
    _profile.dispose();
    _account.detachCollection(_collection);
    if (widget.account == null) _account.dispose();
    _collection.dispose();
    if (_portraitLocked) SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _pulseController.dispose();
    if (_albumCatalogCreated) _albumCatalog.dispose();
    _engine.dispose();
    super.dispose();
  }

  void _onFabPressed() {
    if (_engine.telemetry.isUserListening) {
      // Se o usuário iniciou a escuta expressamente, toque para interromper imediatamente
      _engine.stop();
    } else {
      // Inicia a captura e identificação real (preempta background se necessário)
      _engine.startListening();
    }
  }

  /// Constrói o botão oficial de Transmissão (Cast / Chromecast) no canto superior esquerdo.
  /// Estado 1 (Não conectado, sem TVs detectadas): Icons.cast com borda discreta
  /// Estado 2 (Não conectado, TV detectada): Animação de Halo/Brilho pulsante em ciano neon circular
  /// Estado 3 (Conectado): Icons.cast_connected preenchido em ciano neon
  Widget _buildCastButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_engine.castService, _pulseController]),
      builder: (context, _) {
        final isConnected = _engine.castService.isCastActive;
        final isConnecting = _engine.castService.isConnecting;
        final shouldGlow = _isHaloPulsing && !isConnected;

        // Pulsação suave de brilho circular ao redor do botão
        final glowValue = shouldGlow ? _pulseController.value : 0.0;
        final borderColor = isConnected
            ? AppTheme.cream
            : (shouldGlow ? AppTheme.cream.withValues(alpha: 0.5 + (glowValue * 0.5)) : Colors.white38);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: shouldGlow
                  ? [
                      BoxShadow(
                        color: AppTheme.cream.withValues(alpha: 0.45 * glowValue),
                        blurRadius: 9.0 * glowValue,
                        spreadRadius: 2.2 * glowValue,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: isConnected
                  ? AppTheme.cream.withValues(alpha: 0.2)
                  : (shouldGlow
                      ? AppTheme.cream.withValues(alpha: 0.15 * glowValue)
                      : Colors.white.withValues(alpha: 0.12)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: borderColor,
                  width: shouldGlow ? (1.3 + (glowValue * 0.8)) : 1.2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _showCastDialog,
                child: Center(
                  child: isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cream),
                        )
                      : Icon(
                          isConnected ? Icons.cast_connected : Icons.cast,
                          color: (isConnected || shouldGlow) ? AppTheme.cream : Colors.white,
                          size: 21,
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCastDialog() {
    if (_engine.castService.isCastActive) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cast_connected, color: AppTheme.cream, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.castingToTv,
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                            ),
                            Text(
                              l10n.castScreenName(_engine.castService.clientDeviceName ?? l10n.defaultTvName),
                              style: const TextStyle(fontSize: 12, color: AppTheme.cream),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.link_off, color: Colors.white),
                      label: Text(l10n.disconnectFromTv),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        await _engine.disconnectCast();
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      CastThinkingWheelDialog.show(
        context,
        castService: _engine.castService,
        onConnected: () {
          setState(() {});
        },
      );
    }
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  /// Registra cada faixa nova nas audições (qualquer faixa conta o disco, uma vez por sessão).
  void _recordPlayIfNew() {
    final track = _engine.currentTrack;
    if (track == null) return;
    final album = (_engine.lockedAlbumName?.isNotEmpty ?? false) ? _engine.lockedAlbumName! : (track.album ?? '');
    if (album.isEmpty) return;
    final artist = _engine.lockedAlbumArtist ?? track.artist;
    final key = '$album|$artist|${track.title}' /* l10n-ignore */;
    if (key == _lastPlayKey) return;
    _lastPlayKey = key;
    _collection.recordTrackPlay(album: album, artist: artist, track: track.title, trackArtist: track.artist);
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _profile.displayName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l10n.whatShouldWeCallYou, style: const TextStyle(color: AppTheme.cream)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: l10n.yourName, hintStyle: const TextStyle(color: Colors.white38)),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.orange, foregroundColor: Colors.white),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (name != null) await _profile.setDisplayName(name);
  }

  void _openHelp() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HelpScreen(onExportLogs: _exportSessionLogs)));
  }

  void _openCollection() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionScreen(
        collection: _collection,
        tracklistFor: (album, artist) => _engine.cacheService.getTracklist(album, artist),
        account: _account,
      ),
    ));
  }

  /// Liga/desliga a chave MANUAL. A escuta pela minutagem (sem Shazam) chega na próxima versão;
  /// por enquanto a chave guarda a escolha e desliga sozinha quando o disco termina.
  void _toggleManualMode() {
    final on = !_engine.isManualMode;
    _engine.setManualMode(on);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(on ? l10n.manualOnHint : l10n.manualOffHint, style: const TextStyle(color: Colors.white)),
      ));
  }

  /// ▶ cromado do Modo Manual: parar, começar o próximo lado (depois de virar) ou escolher onde a agulha começa.
  Future<void> _onManualPressed() async {
    if (_engine.isManualPlaying) {
      _engine.stopManual();
      return;
    }
    if (_engine.manualPendingIndex != null) {
      await _engine.startManualPending();
      return;
    }
    final tracks = _engine.manualRecordTracklist;
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(l10n.manualNoRecord, style: const TextStyle(color: Colors.white)),
      ));
      await _openRecordScan();
      return;
    }
    final choice = await showManualStartSheet(context, tracks, album: _engine.lockedAlbumName);
    if (choice == null || !mounted) return;
    await _engine.startManualPlayback(trackIndex: choice.trackIndex, useMic: choice.useMic);
  }

  // ---------- Curiosidades (sem letra) ----------
  final CuriositiesService _curiositiesService = CuriositiesService();
  RecordCuriosities? _curiosities;
  String? _curiositiesKey;

  /// Curiosidades do disco e da faixa no lugar da letra, quando não há letra e o plugin
  /// "Record curiosities" (D2) está no prato. Busca na primeira vez (fica guardado no aparelho).
  String? _curiositiesSentKey;

  bool get _curiositiesOn =>
      _plugins.catalog.any((p) => p.id == 'display.curiosities' && _plugins.isActive(p)); // l10n-ignore

  /// 1ª faixa do lado: as curiosidades do disco (e as notícias) entram antes das da faixa.
  bool get _isSideStart {
    final track = _engine.currentTrack;
    if (track == null) return false;
    final list = _engine.lockedTracklist;
    final i = TracklistMatcher.findIndex(list, track.title);
    return i <= 0 || (list[i].side != null && list[i].side != list[i - 1].side);
  }

  /// Busca as curiosidades da faixa atual (uma vez por faixa) e, transmitindo, envia para a TV.
  /// Roda a cada redesenho, com ou sem TV (durante a transmissão o celular mostra o painel).
  void _ensureCuriosities() {
    final track = _engine.currentTrack;
    if (track == null || !_curiositiesOn) return;
    final album = _engine.lockedAlbumName ?? track.album ?? '';
    final artist = _engine.lockedAlbumArtist ?? track.artist;
    final key = '$album|$artist|${track.title}'; // l10n-ignore
    if (key != _curiositiesKey) {
      _curiositiesKey = key;
      _curiosities = null;
      () async {
        final notes = await _discogsNotesFor(album);
        return _curiositiesService.forTrack(artist: track.artist, album: album, track: track.title, discogsNotes: notes);
      }()
          .then((c) {
        if (mounted && _curiositiesKey == key) setState(() => _curiosities = c);
      });
    }
    final c = _curiosities;
    final cast = _engine.castService;
    if (c != null && !c.isEmpty && cast.isConnected && _curiositiesSentKey != '$key|${cast.connectedClientCount}') {
      _curiositiesSentKey = '$key|${cast.connectedClientCount}';
      cast.sendCuriosities(c, sideStart: _isSideStart);
    }
    if (!cast.isConnected) _curiositiesSentKey = null;
  }

  /// O automático não reconhece a música há ~90 s: oferece o Modo Manual (letra pela minutagem).
  void _offerManualMode() {
    _engine.dismissManualSuggestion();
    if (_engine.isManualMode) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        duration: const Duration(seconds: 12),
        content: Text(l10n.manualSuggestion, style: const TextStyle(color: Colors.white)),
        action: SnackBarAction(
          label: l10n.manualSuggestionAction,
          textColor: AppTheme.orange,
          onPressed: () async {
            _engine.stop();
            _engine.setManualMode(true);
            await _onManualPressed();
          },
        ),
      ));
    });
  }

  /// Notas da prensagem no Discogs, quando o disco atual veio do Discogs e a conta está conectada.
  Future<String?> _discogsNotesFor(String album) async {
    if (album.isEmpty) return null;
    final target = TracklistMatcher.normalize(album);
    for (final d in _engine.cacheService.getAllDiscs()) {
      if (d.tracklistSource == 'discogs' && d.releaseId != null && TracklistMatcher.normalize(d.album) == target) { // l10n-ignore
        _albumCatalogCreated = true;
        return _albumCatalog.discogsNotes(d.releaseId!);
      }
    }
    return null;
  }

  Widget? _curiositiesOrNull() {
    if (_engine.currentTrack == null || !_curiositiesOn) return null;
    _ensureCuriosities();
    final c = _curiosities;
    if (c == null || c.isEmpty) return null;
    final sideStart = _isSideStart;
    return CuriositiesView(
      curiosities: c,
      positionSeconds: _engine.telemetry.currentPositionSeconds,
      durationSeconds: _engine.telemetry.trackDurationSeconds,
      sideStart: sideStart,
    );
  }

  /// Faixa de informações da barra superior com o celular em pé: música (destaque), banda · disco e
  /// a próxima faixa (ou o fim do lado). Tocar abre a lista de faixas do disco.
  Widget _portraitTrackInfo() {
    final track = _engine.currentTrack!;
    final album = (_engine.lockedAlbumName?.isNotEmpty ?? false) ? _engine.lockedAlbumName! : (track.album ?? '');
    final artistAlbum = [track.artist, album].where((s) => s.trim().isNotEmpty).join(' · ');
    final sideEnd = _engine.telemetry.sideEndLabel;
    final next = _engine.telemetry.predictedNextTrackTitle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showAlbumTracklistModal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (_engine.isAlbumLocked) ...[
                        const Icon(Icons.album, size: 13, color: AppTheme.cream),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          artistAlbum,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.cream, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (sideEnd != null || next != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sideEnd ??
                          '${l10n.upNextTitle(next!)}${_engine.telemetry.nextLyricsReady ? " ⚡" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sideEnd != null ? Colors.amber : AppTheme.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.queue_music_rounded, color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }

  /// Jukebox de plugins (idiomas, exibição, IA).
  void _openPlugins() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PluginJukeboxScreen(store: _plugins)));
  }

  /// Adiciona (ou retira) da coleção o disco que está tocando.
  Future<void> _toggleCurrentInCollection() async {
    final track = _engine.currentTrack;
    if (track == null) return;
    final album =
        (_engine.lockedAlbumName?.isNotEmpty ?? false) ? _engine.lockedAlbumName! : (track.album ?? track.title);
    final artist = _engine.lockedAlbumArtist ?? track.artist;
    final messenger = ScaffoldMessenger.of(context);
    if (_collection.contains(album, artist)) {
      await _collection.remove(album, artist);
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(l10n.removedFromCollection(album), style: const TextStyle(color: Colors.white)),
      ));
    } else {
      await _collection.add(CollectionItem(
        album: album,
        artist: artist,
        coverUrl: _engine.lockedAlbumCoverUrl ?? track.coverUrl,
        addedAt: DateTime.now(),
      ));
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(l10n.addedToCollection(album), style: const TextStyle(color: Colors.white)),
      ));
    }
  }

  /// Exporta os últimos eventos de log da sessão para a área de transferência.
  Future<void> _exportSessionLogs() async {
    final logs = await _engine.logService.tail(lines: 200);
    if (!mounted) return;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(l10n.noEventsLogged, style: const TextStyle(color: Colors.white70)),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: logs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(
            l10n.logsCopied,
            style: TextStyle(color: AppTheme.cream),
          ),
        ),
      );
    }
  }

  /// Câmera: reconhece o disco (código de barras, nº de catálogo ou digitado), cadastra na coleção
  /// e, se o usuário quiser ouvir, já começa a escuta com o disco travado.
  Future<void> _openRecordScan() async {
    _albumCatalogCreated = true;
    final listen = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RecordScanScreen(
        engine: _engine,
        catalog: _albumCatalog,
        collection: _collection,
        profile: _profile,
        discogsCollection: _discogsCollection,
      ),
    ));
    if (listen == true && mounted && !_engine.telemetry.isUserListening) {
      // Disco fora do catálogo de reconhecimento: o Modo Manual já foi ligado no fluxo
      if (_engine.isManualMode) {
        await _onManualPressed();
      } else {
        _engine.startListening();
      }
    }
  }

  /// Janela "Mudar disco": todos os discos em que a música atual aparece (Discogs/MusicBrainz).
  void _openAlbumPicker() {
    if (_engine.currentTrack == null) return;
    _albumCatalogCreated = true;
    showAlbumPickerSheet(context, engine: _engine, catalog: _albumCatalog);
  }

  /// Exibe modal com a tracklist completa do álbum do disco em reprodução.
  void _showAlbumTracklistModal() {
    final current = _engine.currentTrack;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(l10n.noRecordYet, style: const TextStyle(color: Colors.white70)),
        ),
      );
      return;
    }

    // Obter tracklist: disco travado -> prefetch em memória -> cache por álbum -> cache por faixa
    List<TrackEntry> tracklist = _engine.lockedTracklist;
    if (tracklist.isEmpty) {
      tracklist = _engine.prefetchService.currentDiscTracklist;
    }
    if (tracklist.isEmpty && current.album != null && current.album!.isNotEmpty) {
      tracklist = _engine.cacheService.getTracklist(current.album!, current.artist);
    }
    if (tracklist.isEmpty) {
      final disc = _engine.cacheService.findDiscWithTrack(current.title, current.artist);
      if (disc != null) {
        tracklist = disc.tracklist;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final albumName = (_engine.lockedAlbumName != null && _engine.lockedAlbumName!.isNotEmpty)
            ? _engine.lockedAlbumName!
            : ((current.album != null && current.album!.isNotEmpty) ? current.album! : current.title);
        final artistName = _engine.lockedAlbumArtist ?? current.artist;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Indicador de arrasto
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Cabeçalho com Capa, Álbum e Artista
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: current.coverUrl != null && current.coverUrl!.isNotEmpty
                            ? Image.network(
                                current.coverUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 56,
                                  height: 56,
                                  color: AppTheme.surfaceLight,
                                  child: const Icon(Icons.album, color: AppTheme.cream),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: AppTheme.surfaceLight,
                                child: const Icon(Icons.album, color: AppTheme.cream),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              albumName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artistName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.cream,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tracklist.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  l10n.tracksOnRecord(tracklist.length),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textInactive,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Disco errado (ex.: coletânea)? O usuário escolhe o disco certo, que vira o padrão
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: StatefulBuilder(
                          builder: (context, setSheetState) {
                            final albumKey = (_engine.lockedAlbumName?.isNotEmpty ?? false)
                                ? _engine.lockedAlbumName!
                                : (current.album ?? current.title);
                            final inCollection =
                                _collection.contains(albumKey, _engine.lockedAlbumArtist ?? current.artist);
                            return FilledButton.icon(
                              icon: Icon(inCollection ? Icons.check_circle : Icons.library_add, size: 18),
                              label: Text(inCollection ? l10n.inCollection : l10n.addToCollection),
                              style: FilledButton.styleFrom(
                                backgroundColor: inCollection ? AppTheme.surfaceLight : AppTheme.orange,
                                foregroundColor: inCollection ? AppTheme.cream : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                await _toggleCurrentInCollection();
                                setSheetState(() {});
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: Text(l10n.changeRecord),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.cream,
                            side: const BorderSide(color: AppTheme.carveLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openAlbumPicker();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12),

                // Lista de faixas ou aviso de indisponibilidade
                Expanded(
                  child: tracklist.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.queue_music, size: 48, color: AppTheme.textInactive),
                                SizedBox(height: 12),
                                Text(
                                  l10n.noTracklistYet,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textInactive, fontSize: 14),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  l10n.tracklistFetchedHint,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: tracklist.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, index) {
                            final entry = tracklist[index];
                            final isCurrent = TracklistMatcher.isSameTitle(
                              entry.title,
                              current.title,
                            );
                            final isNext = !isCurrent &&
                                _engine.telemetry.predictedNextTrackTitle != null &&
                                TracklistMatcher.isSameTitle(
                                  entry.title,
                                  _engine.telemetry.predictedNextTrackTitle!,
                                );

                            final durationStr = entry.lengthMs != null
                                ? '${(entry.lengthMs! ~/ 60000)}:${((entry.lengthMs! % 60000) ~/ 1000).toString().padLeft(2, '0')}'
                                : null;

                            final posLabel =
                                entry.number != null && entry.number!.isNotEmpty ? entry.number! : '${entry.position}';

                            return ListTile(
                              dense: true,
                              // Modo Manual: tocar numa faixa pula para ela (começa agora)
                              onTap: _engine.isManualMode
                                  ? () {
                                      final i = TracklistMatcher.findIndex(_engine.manualRecordTracklist, entry.title);
                                      if (i < 0) return;
                                      Navigator.of(context).pop();
                                      _engine.manualJumpTo(i);
                                    }
                                  : null,
                              tileColor: isCurrent
                                  ? AppTheme.cream.withValues(alpha: 0.12)
                                  : (isNext ? AppTheme.orange.withValues(alpha: 0.08) : null),
                              leading: Container(
                                width: 38,
                                alignment: Alignment.center,
                                child: isCurrent
                                    ? const Icon(Icons.graphic_eq, color: AppTheme.cream, size: 22)
                                    : (isNext
                                        ? const Icon(Icons.skip_next_rounded, color: AppTheme.orange, size: 20)
                                        : Text(
                                            posLabel,
                                            style: TextStyle(
                                              color: isCurrent ? AppTheme.cream : AppTheme.textInactive,
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          )),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.title,
                                      style: TextStyle(
                                        color: isCurrent ? AppTheme.cream : (isNext ? Colors.white : Colors.white70),
                                        fontWeight: (isCurrent || isNext) ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.cream.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.cream.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        l10n.playing,
                                        style: TextStyle(
                                          color: AppTheme.cream,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else if (isNext)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.orange.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        l10n.upNextCaps,
                                        style: TextStyle(
                                          color: AppTheme.orange,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // Coletâneas/trilhas: artista de cada faixa, junto com o lado do disco
                              subtitle: (entry.artist != null || (entry.side != null && entry.side!.isNotEmpty))
                                  ? Text(
                                      [
                                        if (entry.artist != null) entry.artist!,
                                        if (entry.side != null && entry.side!.isNotEmpty) l10n.sideLabel(entry.side!),
                                      ].join(' • '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppTheme.textInactive, fontSize: 11),
                                    )
                                  : null,
                              trailing: durationStr != null
                                  ? Text(
                                      durationStr,
                                      style: TextStyle(
                                        color: isCurrent ? AppTheme.cream : AppTheme.textInactive,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _engine,
      builder: (context, _) {
        final telemetry = _engine.telemetry;
        final isListening = telemetry.isUserListening || telemetry.status == CalibrationStatus.listeningSample1;
        final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
        // Microfone cromado no centro da barra inferior
        final micSize = isLandscape ? 50.0 : 62.0;
        final awaitingFlip = _engine.isAwaitingSideFlip && !telemetry.isMicActive;
        // Etapa atual (ouvindo, não identificada...) mostrada na saudação, já que o rodapé ficou enxuto
        final statusLine = (telemetry.status == CalibrationStatus.idle || telemetry.statusMessage.isEmpty)
            ? null
            : telemetry.statusMessage;

        // Tela estreita (celular em pé): sem o texto ao lado do logo, só os botões
        final compactBar = MediaQuery.sizeOf(context).width < 600;
        final logoSize = compactBar ? 46.0 : 50.0;
        _ensureCuriosities(); // também durante a transmissão (a TV mostra as curiosidades)
        if (_engine.manualSuggested) _offerManualMode();
        final tileSize = compactBar ? 34.0 : 40.0;

        return Stack(
          children: [
            Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                toolbarHeight: 74,
                flexibleSpace: const _WoodTopPanel(),
                // Em pé, com música tocando: música, banda · disco e "a seguir" numa faixa abaixo do disco
                bottom: (compactBar && _engine.currentTrack != null)
                    ? PreferredSize(preferredSize: const Size.fromHeight(64), child: _portraitTrackInfo())
                    : null,
                // Logo (ou capa do disco) no canto esquerdo; o texto ao lado só aparece com o celular deitado
                leadingWidth: logoSize + 22,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Center(
                    child: GestureDetector(
                      onTap: _showAlbumTracklistModal,
                      onLongPress: _exportSessionLogs,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                        child: ((_engine.lockedAlbumCoverUrl ?? _engine.currentTrack?.coverUrl) != null &&
                                (_engine.lockedAlbumCoverUrl ?? _engine.currentTrack?.coverUrl)!.isNotEmpty)
                            ? ClipRRect(
                                key: ValueKey(_engine.lockedAlbumCoverUrl ?? _engine.currentTrack!.coverUrl),
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  (_engine.lockedAlbumCoverUrl ?? _engine.currentTrack!.coverUrl)!,
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/icon/app_icon.png',
                                    width: logoSize,
                                    height: logoSize,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : ClipRRect(
                                key: const ValueKey('default_logo'), // l10n-ignore
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/icon/app_icon.png',
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.album, color: AppTheme.cream, size: 40),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                titleSpacing: 12,
                title: compactBar
                    ? null
                    : Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _engine.currentTrack != null ? _showAlbumTracklistModal : null,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_engine.currentTrack != null) ...[
                                    // Linha 1: Nome da Música (+20% em destaque)
                                    Text(
                                      _engine.currentTrack!.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17.5,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    // Linha 2: Nome do Disco (com ícone de disco neon se travado)
                                    Row(
                                      children: [
                                        if (_engine.isAlbumLocked) ...[
                                          const Icon(Icons.album, size: 13, color: AppTheme.cream),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            (_engine.lockedAlbumName != null && _engine.lockedAlbumName!.isNotEmpty)
                                                ? _engine.lockedAlbumName!
                                                : ((_engine.currentTrack?.album != null &&
                                                        _engine.currentTrack!.album!.isNotEmpty)
                                                    ? _engine.currentTrack!.album!
                                                    : (_engine.currentTrack?.artist ?? l10n.unknownAlbum)),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppTheme.cream,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    // Linha 3: "A seguir:" / Fim do lado / Artista
                                    if (_engine.telemetry.sideEndLabel != null)
                                      Text(
                                        _engine.telemetry.sideEndLabel!,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else if (_engine.telemetry.predictedNextTrackTitle != null)
                                      Text(
                                        '${l10n.upNextTitle(_engine.telemetry.predictedNextTrackTitle!)}${_engine.telemetry.nextLyricsReady ? " ⚡" : ""}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppTheme.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    else if (_engine.currentTrack != null)
                                      Text(
                                        _engine.currentTrack!.artist,
                                        style: const TextStyle(
                                          fontSize: 11.0,
                                          color: Colors.white60,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        // O nome tem prioridade: só a versão encolhe quando falta espaço
                                        Text(
                                          kAppName,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: compactBar ? 15 : 17,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Versão: some primeiro quando falta espaço
                                        Flexible(
                                          child: GestureDetector(
                                            onLongPress: _exportSessionLogs,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: AppTheme.cream.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(color: AppTheme.cream.withValues(alpha: 0.3)),
                                              ),
                                              child: const Text(
                                                'v$kAppVersion',
                                                maxLines: 1,
                                                overflow: TextOverflow.clip,
                                                softWrap: false,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  color: AppTheme.cream,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      kAppTagline,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppTheme.textInactive,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                actions: [
                  // Botões de madeira; na abertura do app, o nome de cada um aparece embaixo e some (IntroLabelsLayer)
                  WoodTileButton(
                    asset: 'assets/images/btn_camera.png',
                    label: l10n.camera,
                    onPressed: _openRecordScan,
                    size: tileSize,
                    key: _cameraKey,
                  ),
                  // Chave MANUAL (mesmo botão, imagem do estado ligado/desligado)
                  WoodTileButton(
                    asset: _engine.isManualMode ? 'assets/images/btn_manual_on.png' : 'assets/images/btn_manual_off.png',
                    label: l10n.manual,
                    onPressed: _toggleManualMode,
                    size: tileSize,
                    key: _manualKey,
                  ),
                  WoodTileButton(
                    asset: 'assets/images/btn_collection.png',
                    label: l10n.myCollection,
                    onPressed: _openCollection,
                    size: tileSize,
                    key: _collectionKey,
                  ),
                  WoodTileButton(
                    asset: 'assets/images/btn_plugins.png',
                    label: l10n.plugins,
                    onPressed: _openPlugins,
                    size: tileSize,
                    key: _pluginsKey,
                  ),
                  WoodTileButton(
                    asset: 'assets/images/btn_help.png',
                    label: l10n.help,
                    onPressed: _openHelp,
                    size: tileSize,
                    key: _helpKey,
                  ),
                  _buildCastButton(),
                  const SizedBox(width: 4),
                ],
              ),
              // REGRA ESTRITA: Durante a transmissão para TV, o celular NUNCA exibe as letras;
              // permanece 100% como mesa de controle e cockpit analógico do vinil.
              body: _engine.castService.isCastActive
                  ? SafeArea(
                      child: VinylControlCockpit(
                        engine: _engine,
                        onOpenCastDialog: _showCastDialog,
                        onDisconnectCast: () => _engine.disconnectCast(),
                        onCoverTap: _showAlbumTracklistModal,
                      ),
                    )
                  : Stack(
                      children: [
                        // Fundo em madeira escura com veio (entorno da letra)
                        const Positioned.fill(child: WoodBackground()),

                        // Lista vertical de letras sincronizadas
                        Positioned.fill(
                          child: LyricsListView(
                            lyrics: _engine.lyrics,
                            activeIndex: _engine.activeLineIndex,
                            onSeek: (seconds) => _engine.seekTo(seconds),
                            emptyState: _engine.currentTrack == null
                                ? HomeGreeting(
                                    name: _profile.displayName,
                                    seed: _greetingSeed,
                                    onEditName: _editName,
                                    bottomReserve: awaitingFlip ? 84 : 8,
                                    statusLine: statusLine,
                                  )
                                : _curiositiesOrNull(),
                          ),
                        ),

                        // Botão Flutuante (FAB) de escuta / calibração; no fim do lado vira "Vire o disco" pulsando
                        // Fim do lado: "Flip the record" acima da barra (o microfone fica na barra)
                        if (awaitingFlip)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 14,
                            child: Center(child: FlipSideButton(onPressed: () => _engine.flipSide())),
                          ),
                      ],
                    ),
              bottomNavigationBar: _engine.castService.isCastActive
                  ? null
                  : VinylStatusFooter(
                      telemetry: telemetry,
                      track: _engine.currentTrack,
                      onPitchAdjust: (val) => _engine.setManualPitchAdjustment(val),
                      onNudge: (val) => _engine.nudgeSync(val),
                      onPlayPause: () => _engine.togglePlayPause(),
                      onStop: () => _engine.stop(),
                      onListenAgain: () => _engine.startListening(),
                      isListening: isListening,
                      onMicPressed: _onFabPressed,
                      micSize: micSize,
                      // Modo Manual: o microfone vira o ▶ cromado
                      centerButton: _engine.isManualMode
                          ? ChromePlayButton(
                              size: micSize,
                              state: _engine.isManualPlaying
                                  ? ChromeButtonState.stop
                                  : (_engine.manualPendingIndex != null ? ChromeButtonState.flip : ChromeButtonState.play),
                              tooltip: _engine.isManualPlaying
                                  ? l10n.manualStopTooltip
                                  : (_engine.manualPendingIndex != null ? l10n.manualNextSideTooltip : l10n.manualPlayTooltip),
                              onPressed: _onManualPressed,
                            )
                          : null,
                    ),
            ),
            // Nomes dos botões na abertura (esquerda → direita), por cima de tudo
            Positioned.fill(
              child: IntroLabelsLayer(specs: [
                // Um botão por vez, da esquerda para a direita, alternando acima/abaixo
                IntroLabelSpec(anchor: _cameraKey, text: l10n.camera, delay: Duration.zero, above: true),
                IntroLabelSpec(anchor: _manualKey, text: l10n.manual, delay: const Duration(milliseconds: 1200)),
                IntroLabelSpec(
                    anchor: _collectionKey, text: l10n.myCollection, delay: const Duration(milliseconds: 2400), above: true),
                IntroLabelSpec(anchor: _pluginsKey, text: l10n.plugins, delay: const Duration(milliseconds: 3600)),
                IntroLabelSpec(anchor: _helpKey, text: l10n.help, delay: const Duration(milliseconds: 4800), above: true),
              ]),
            ),
          ],
        );
      },
    );
  }
}

/// Painel de nogueira em destaque atrás da barra superior: o mesmo acabamento do rodapé, um tom
/// mais claro que o fundo, com veio da madeira e friso entalhado (luz + sombra) na borda de baixo.
class _WoodTopPanel extends StatelessWidget {
  const _WoodTopPanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E1E13), Color(0xFF3A2618)],
          ),
          border: Border(bottom: BorderSide(color: AppTheme.carveLight, width: 1.6)),
          boxShadow: [
            BoxShadow(color: AppTheme.carveShadow, blurRadius: 0, spreadRadius: 1.5, offset: Offset(0, 2)),
            BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: CustomPaint(
          size: Size.infinite,
          painter: const WoodGrainPainter(intensity: 0.55, seed: 12),
        ),
      ),
    );
  }
}
