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
import '../../services/brain/account_brain_remote.dart';
import '../../services/brain/brain_service.dart';
import '../../services/brain/brain_ai.dart';
import '../../services/ai_translator.dart';
import '../../services/imagine/imagined_music.dart';
import '../../services/imagine/account_imagine_search.dart';
import '../../services/lrc_parser.dart';
import 'waxbrain_screen.dart';
import '../../services/user_profile_store.dart';
import 'collection_screen.dart';
import 'record_scan_screen.dart';
import 'plugin_jukebox_screen.dart';
import '../widgets/curiosities_view.dart';
import '../../services/curiosities_service.dart';
import '../widgets/chrome_play_button.dart';
import '../widgets/manual_start_sheet.dart';
import '../widgets/wood_tile_button.dart';
import '../widgets/wood_menu.dart';
import '../widgets/immersive_quotes.dart';
import '../widgets/retro_text.dart';
import '../../services/plugins/plugin_catalog.dart';
import '../../services/plugins/plugin_links.dart';
import '../widgets/plugin_panel_strip.dart';
import '../../services/plugins/plugin_manifest.dart';
import '../../services/lyrics_provider_service.dart';
import '../../services/local_lyrics_library.dart';
import '../../services/cloud/cloud_folder.dart';
import '../../services/cloud/dropbox_folder.dart';
import '../../services/cloud/google_drive_folder.dart';
import '../../services/cloud/onedrive_folder.dart';
import '../../services/discogs/discogs_collection_service.dart';
import '../../services/account/account_service.dart';
import 'account_screen.dart';
import '../../services/language_detector.dart';
import 'play_record_screen.dart';
import 'record_found_flow.dart';
import '../../services/tracklist_provider.dart';
import 'discogs_login_screen.dart';
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
  final GlobalKey _userKey = GlobalKey();
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

  /// WaxBrain: chaves de IA do usuário (BYOK), no cofre do celular e, criptografadas, na conta.
  final BrainService _brain = BrainService();
  final GlobalKey _brainKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  bool _brainAttached = false;

  /// Plugin A2: tradutor de IA (letras e curiosidades) com os chips do WaxBrain.
  late final BrainAi _brainAi = BrainAi(brain: _brain);
  late final AiTranslator _translator = AiTranslator(ai: _brainAi);
  String? _lyricsTranslationKey;

  /// Plugin A3 Imagined Music: roteiro visual da música atual (fotos do Unsplash escolhidas pela letra).
  late final ImaginedMusic _imagine = ImaginedMusic(ai: _brainAi, searcher: AccountImagineSearch(_account));
  Storyboard? _storyboard;
  String? _storyboardKey;
  String? _storyboardSentKey;
  final Set<String> _imaginePhotosUsed = {};

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
    _engine.addListener(_maybeTranslateLyrics);
    _engine.addListener(_maybeImagine);
    _imagine.addListener(_onImagineNotify);
    _imagine.load();
    _translator.addListener(_onTranslatorNotify);
    _translator.load();
    _profile.addListener(_onProfileChanged);
    _profile.load();
    _collection.load();
    _account.attachCollection(_collection);
    _account.addListener(_onAccountForBrain);
    _account.load();
    _brain.load().then((_) => _brain.recheckStale());
    // Plugin C1 (Connections): conta Discogs; o estado fica no próprio serviço do Discogs
    _plugins.bindConnection(PluginCatalog.discogsId, _discogsConnection);
    // Fontes de letras: cada site é um plugin (Lyrics sources); a busca consulta só os ligados
    LyricsProviderService.sourceEnabled = _plugins.isLyricsEngineOn;
    LyricsProviderService.sourceOrder = _plugins.lyricsEngineOrder; // ordem do painel = ordem da busca
    // Plugin S5: letras do próprio usuário
    LyricsProviderService.myLyrics = _myLyrics;
    _myLyrics.load();
    // Pastas das letras na nuvem: atualizam ao abrir o app (sem avisar; falha fica para a próxima)
    for (final c in _clouds) {
      c.load().then((_) async {
        if (!c.configured || !c.isConnected) return;
        try {
          await c.syncInto(_myLyrics);
        } catch (e) {
          debugPrint('[${c.serviceName}] Sincronização ao abrir falhou: $e');
        }
      });
    }
    // Plugin pedido pelo site ("Install" no navegador do celular): instala assim que os plugins carregam
    PluginLinks.instance.pending.addListener(_onPluginLink);
    _plugins.addListener(_onPluginsChanged);
    PluginLinks.instance.start();
    _discogsAuth.load().then((_) => _plugins.load()).then((_) => _onPluginLink()).then((_) => _autoImportDiscogs());
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
    _engine.removeListener(_maybeTranslateLyrics);
    _engine.removeListener(_maybeImagine);
    _imagine.removeListener(_onImagineNotify);
    _imagine.dispose();
    _translator.removeListener(_onTranslatorNotify);
    _translateRetry?.cancel();
    _translator.dispose();
    _profile.removeListener(_onProfileChanged);
    _profile.dispose();
    PluginLinks.instance.pending.removeListener(_onPluginLink);
    _plugins.removeListener(_onPluginsChanged);
    LyricsProviderService.sourceEnabled = (_) => true;
    LyricsProviderService.sourceOrder = () => const ['local', 'lrclib', 'netease', 'megalobiz', 'kugou', 'qqmusic']; // l10n-ignore
    LyricsProviderService.myLyrics = null;
    _myLyrics.dispose();
    for (final c in _clouds) {
      c.dispose();
    }
    _plugins.dispose();
    _account.detachCollection(_collection);
    _account.removeListener(_onAccountForBrain);
    _brain.dispose();
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

  /// Plugin C1: conta Discogs (estado no próprio serviço do Discogs).
  late final PluginConnection _discogsConnection = PluginConnection(
    listenable: _discogsAuth,
    isEnabled: () => _discogsAuth.wantsEnabled,
    setEnabled: _discogsAuth.setEnabled,
    isConnected: () => _discogsAuth.isLoggedIn,
    accountName: () => _discogsAuth.username,
    connect: _connectDiscogs,
    disconnect: _discogsAuth.logout,
    importCollection: () => _importDiscogsCollection(),
  );

  Future<int?>? _discogsImport;

  /// Traz a coleção do Discogs para My Collection (só os discos novos). Roda sozinho ao conectar e ao abrir o
  /// app (no máximo a cada 12 h); [quiet] = sem aviso quando nada entrou.
  Future<int?> _importDiscogsCollection({bool quiet = false}) => _discogsImport ??= () async {
        try {
          await _collection.load();
          final items = await _discogsCollection.fetchCollection();
          final added = items == null ? null : await _collection.importFromDiscogs(items);
          if (mounted && (!quiet || (added ?? 0) > 0)) {
            final text = added == null
                ? l10n.discogsImportFailed
                : (added == 0 ? l10n.discogsImportNothingNew : l10n.discogsImported(added));
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
          }
          return added;
        } finally {
          _discogsImport = null;
        }
      }();

  /// Ao abrir o app: com o Discogs conectado, traz os discos novos da coleção de lá (no máximo a cada 12 h).
  Future<void> _autoImportDiscogs() async {
    await _collection.load();
    if (!_discogsAuth.isEnabled) return;
    final last = _collection.discogsImportedAt;
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 12)) return;
    await _importDiscogsCollection(quiet: true);
  }

  /// Login do Discogs pelo plugin C1; ao conectar, o plugin fica ligado.
  Future<bool> _connectDiscogs() async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiscogsLoginScreen(auth: _discogsAuth)),
    );
    if (connected == true) {
      await _discogsAuth.setEnabled(true);
      _importDiscogsCollection(); // conectou: traz a coleção de lá
    }
    return connected == true;
  }

  void _openCollection() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CollectionScreen(
        collection: _collection,
        tracklistFor: (album, artist) => _engine.cacheService.getTracklist(album, artist),
        account: _account,
        discogs: _discogsConnection,
        onAddRecord: _openRecordScan,
        onPlayItem: _playCollectionItem,
        curiositiesFor: _curiositiesOn ? _curiositiesForItem : null,
      ),
    ));
  }

  /// Logo (sem nada tocando): escolher um disco da coleção ou do Discogs para tocar.
  Future<void> _openPlayRecord() async {
    _albumCatalogCreated = true;
    final choice = await Navigator.of(context).push<PlayRecordChoice>(MaterialPageRoute(
      builder: (_) => PlayRecordScreen(
        collection: _collection,
        catalog: _albumCatalog,
        tracklistFor: (album, artist) => _engine.cacheService.getTracklist(album, artist),
      ),
    ));
    if (choice == null || !mounted) return;
    if (choice.addToCollection) {
      await addReleaseToCollection(
        context,
        collection: _collection,
        discogsCollection: _discogsCollection,
        release: choice.release,
      );
      if (!mounted) return;
    }
    await _startRecord(choice.release, choice.tracks);
  }

  /// "Play" no detalhe de um disco da coleção.
  Future<void> _playCollectionItem(CollectionItem item) async {
    _albumCatalogCreated = true;
    final tracks = await tracksForCollectionItem(
      item,
      tracklistFor: (album, artist) => _engine.cacheService.getTracklist(album, artist),
      catalog: _albumCatalog,
    );
    if (!mounted) return;
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(l10n.playRecordNoTracks, style: const TextStyle(color: Colors.white)),
      ));
      return;
    }
    await _startRecord(releaseFromCollectionItem(item), tracks);
  }

  /// Deixa o disco pronto (faixas travadas; Modo Manual se ele não estiver no catálogo de reconhecimento),
  /// volta à tela principal e mostra a sequência: a escuta só começa quando o usuário quiser.
  Future<void> _startRecord(ReleaseCandidate release, List<TrackEntry> tracks) async {
    Navigator.of(context).popUntil((r) => r.isFirst);
    final missing = await prepareRecordForPlay(context, engine: _engine, release: release, tracklist: tracks);
    if (!mounted) return;
    // Pediu para tocar este disco: fora do reconhecimento, só o Modo Manual acompanha
    if (missing) await switchToManualForMissingRecord(context, _engine);
    if (!mounted) return;
    await _showReadyToPlay();
  }

  /// Botão de usuário: dados do cadastro, sair e apagar a conta.
  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AccountScreen(account: _account)));
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
        content: Text(
          on ? (_engine.isManualPlaying ? l10n.manualContinueHint : l10n.manualOnHint) : l10n.manualOffHint,
          style: const TextStyle(color: Colors.white),
        ),
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
  late final CuriositiesService _curiositiesService = CuriositiesService(remote: AccountCuriositiesRemote(_account));
  RecordCuriosities? _curiosities;
  String? _curiositiesKey;

  /// Curiosidades do disco e da faixa no lugar da letra, quando não há letra e o plugin
  /// "Record curiosities" (D1) está no prato. Busca na primeira vez (fica guardado no aparelho).
  String? _curiositiesSentKey;

  bool get _curiositiesOn =>
      _plugins.catalog.any((p) => p.id == PluginCatalog.curiositiesId && _plugins.isActive(p));

  /// O plugin ativo é **só o primeiro** ligado do painel, da esquerda para a direita, que não está vermelho
  /// (não encontrou nada para esta música, ou trouxe letra quebrada). É ele que aparece na tela e que fica
  /// iluminado. Os vermelhos à esquerda dele vão para [failed].
  ({String? shown, Set<String> failed}) _panelState() {
    if (_engine.currentTrack == null) return (shown: null, failed: const <String>{});
    final c = _curiosities;
    return PluginPanelStrip.pickFront(
      _plugins,
      lyricsAttempts: _engine.lyricsAttempts,
      curiositiesFound: c == null ? null : !c.isEmpty,
    );
  }

  /// Última fonte pedida para a música atual (evita buscar de novo a cada quadro).
  String? _lyricsRequestKey;

  /// O ativo é uma fonte de letras, mas a letra na tela veio de outra: busca a letra na ordem do painel
  /// (a primeira fonte que tiver vira a ativa; as que não tiverem ficam vermelhas).
  void _syncLyricsWithPanel(String? shownId) {
    final track = _engine.currentTrack;
    final p = shownId == null ? null : _plugins.byId(shownId);
    if (track == null || p == null || p.category != PluginCategory.sources) return;
    if (_engine.lyricsSource == p.engine && _engine.lyrics.isNotEmpty) return;
    final key = '${track.title}|${track.artist}|${_plugins.lyricsEngineOrder().join(',')}'; // l10n-ignore
    if (key == _lyricsRequestKey) return;
    _lyricsRequestKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_engine.reloadLyricsForCurrentTrack());
    });
  }

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
        return _curiositiesService.forTrack(
          artist: track.artist,
          album: album,
          track: track.title,
          discogsNotes: notes,
          lang: _artistLanguage(album, artist, lyrics: _engine.lyrics.map((l) => l.text).join(' ')),
        );
      }()
          .then((c) => _translatedCuriosities(c, artist: artist, album: album))
          .then((c) {
        if (mounted && _curiositiesKey == key) {
          setState(() => _curiosities = c);
          _curiositiesSentKey = null; // a TV recebe a versão traduzida
        }
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

  /// Idioma em que o artista canta (disco, faixas e, tocando, a letra), guardado por disco.
  final Map<String, String> _languageByRecord = {};
  String _artistLanguage(String album, String artist, {String lyrics = ''}) {
    final key = '$artist|$album'; // l10n-ignore
    final known = _languageByRecord[key];
    if (known != null && lyrics.isEmpty) return known;
    final titles = _engine.cacheService.getTracklist(album, artist).map((t) => t.title).join(' ');
    final lang = LanguageDetector.detect('$album $titles $lyrics');
    // Com a letra a detecção é melhor; sem ela, guarda a primeira resposta
    if (lyrics.isNotEmpty || known == null) _languageByRecord[key] = lang;
    return _languageByRecord[key]!;
  }

  /// Curiosidades de um disco da coleção (popup do ⓘ), no idioma do artista.
  Future<List<Curiosity>> _curiositiesForItem(CollectionItem item) async {
    _albumCatalogCreated = true;
    final notes = item.discogsReleaseId == null ? null : await _albumCatalog.discogsNotes(item.discogsReleaseId!);
    final facts = await _curiositiesService.albumFacts(
      artist: item.artist,
      album: item.album,
      lang: _artistLanguage(item.album, item.artist),
      discogsNotes: notes,
      discogsReleaseId: item.discogsReleaseId,
    );
    return (await _translatedCuriosities(RecordCuriosities(album: facts), artist: item.artist, album: item.album)).album;
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

  /// Informações da música com o celular em pé, no alto da barra ao lado da capa: música (destaque),
  /// banda, disco e a próxima faixa (ou o fim do lado). Tocar abre a lista de faixas do disco.
  Widget _portraitTrackInfo() {
    final track = _engine.currentTrack!;
    final album = (_engine.lockedAlbumName?.isNotEmpty ?? false) ? _engine.lockedAlbumName! : (track.album ?? '');
    final sideEnd = _engine.telemetry.sideEndLabel;
    final next = _engine.telemetry.predictedNextTrackTitle;
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RetroText(track.title, fontSize: 26, depth: 3),
        if (track.artist.trim().isNotEmpty) RetroText(track.artist, fontSize: 21, depth: 2),
        if (album.trim().isNotEmpty)
          Row(
            children: [
              if (_engine.isAlbumLocked) ...[
                const Icon(Icons.album, size: 12, color: AppTheme.cream),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        if (sideEnd != null || next != null)
          Text(
            sideEnd ?? '${l10n.upNextTitle(next!)}${_engine.telemetry.nextLyricsReady ? " ⚡" : ""}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: sideEnd != null ? Colors.amber : AppTheme.orange,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
    // Se as quatro linhas não couberem na altura da barra, o bloco encolhe um pouco (sem estourar); na
    // largura, cada linha corta com reticências.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showAlbumTracklistModal,
      child: LayoutBuilder(
        builder: (context, c) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(width: c.maxWidth, child: lines),
        ),
      ),
    );
  }

  /// Botões de madeira da linha de baixo da barra, da esquerda para a direita: usuário, Identify,
  /// Manual (chave liga/desliga), WaxBrain, My Collection, Plugins e Help.
  Widget _woodButtons(double size) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WoodTileButton(asset: 'assets/images/btn_user.png', label: l10n.profile, onPressed: _openProfile, size: size, key: _userKey),
          WoodTileButton(asset: 'assets/images/btn_camera.png', label: l10n.camera, onPressed: _openRecordScan, size: size, key: _cameraKey),
          WoodTileButton(
            asset: _engine.isManualMode ? 'assets/images/btn_manual_on.png' : 'assets/images/btn_manual_off.png',
            label: l10n.manual,
            onPressed: _toggleManualMode,
            size: size,
            key: _manualKey,
          ),
          WoodTileButton(asset: 'assets/images/btn_brain.png', label: l10n.waxBrain, onPressed: _openBrain, size: size, key: _brainKey),
          WoodTileButton(asset: 'assets/images/btn_collection.png', label: l10n.myCollection, onPressed: _openCollection, size: size, key: _collectionKey),
          WoodTileButton(asset: 'assets/images/btn_plugins.png', label: l10n.plugins, onPressed: _openPlugins, size: size, key: _pluginsKey),
          WoodTileButton(asset: 'assets/images/btn_help.png', label: l10n.help, onPressed: _openHelp, size: size, key: _helpKey),
        ],
      );

  /// Botão ☰ (celular em pé): abre o menu de madeira com os botões um abaixo do outro, com o nome na frente.
  Widget _menuButton() => WoodTileButton(
        key: _menuKey,
        asset: 'assets/images/btn_menu.png',
        label: l10n.menu,
        onPressed: _openWoodMenu,
        size: 36,
      );

  void _openWoodMenu() {
    final manualOn = _engine.isManualMode;
    showWoodMenu(context, anchor: _menuKey, items: [
      WoodMenuItem(asset: 'assets/images/btn_user.png', label: l10n.profile, onTap: _openProfile),
      WoodMenuItem(asset: 'assets/images/btn_camera.png', label: l10n.camera, onTap: _openRecordScan),
      WoodMenuItem(
        asset: manualOn ? 'assets/images/btn_manual_on.png' : 'assets/images/btn_manual_off.png',
        label: l10n.manual,
        onTap: _toggleManualMode,
        badge: manualOn ? l10n.jukeboxOn : l10n.jukeboxOff,
        badgeOn: manualOn,
      ),
      WoodMenuItem(asset: 'assets/images/btn_brain.png', label: l10n.waxBrain, onTap: _openBrain),
      WoodMenuItem(asset: 'assets/images/btn_collection.png', label: l10n.myCollection, onTap: _openCollection),
      WoodMenuItem(asset: 'assets/images/btn_plugins.png', label: l10n.plugins, onTap: _openPlugins),
      WoodMenuItem(asset: 'assets/images/btn_help.png', label: l10n.help, onTap: _openHelp),
    ]);
  }

  /// Conta conectada: o WaxBrain passa a guardar uma cópia criptografada das chaves na conta (e traz as
  /// que já estavam lá); conta desconectada: segue só no celular.
  void _onAccountForBrain() {
    if (_account.isSignedIn && !_brainAttached) {
      _brainAttached = true;
      _brain.attachRemote(AccountBrainRemote(_account));
    } else if (!_account.isSignedIn && _brainAttached) {
      _brainAttached = false;
      _brain.detachRemote();
    }
  }

  void _openBrain() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WaxBrainScreen(brain: _brain)));
  }

  /// Jukebox de plugins (idiomas, exibição, fontes de letras, IA, conexões).
  void _openPlugins() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PluginJukeboxScreen(
        store: _plugins,
        installer: _pluginInstaller,
        myLyrics: _myLyrics,
        clouds: _clouds,
        translator: _translator,
        imagine: _imagine,
        brain: _brain,
        openBrain: _openBrain,
      ),
    ));
  }

  late final PluginInstaller _pluginInstaller = PluginInstaller(store: _plugins);

  /// Fontes de letras ligadas, na ordem do painel, da última vez (para saber se mudou).
  String? _sourcesSignature;

  /// Ligou, desligou, reordenou ou ejetou uma fonte de letras no painel: a letra da faixa que está
  /// tocando é buscada de novo na nova ordem (efeito na hora, no celular e na TV).
  void _onPluginsChanged() {
    if (!_plugins.isLoaded) return;
    final sig = _plugins.lyricsEngineOrder().join(',');
    final before = _sourcesSignature;
    _sourcesSignature = sig;
    if (before != null && before != sig) _lyricsRequestKey = null; // a ordem mudou: o build confere de novo
    final translatorOn = _translatorOn;
    if (translatorOn != _translatorWasOn) {
      _translatorWasOn = translatorOn;
      _onTranslatorChanged();
    }
    final imagineOn = _imagineOn;
    if (imagineOn != _imagineWasOn) {
      _imagineWasOn = imagineOn;
      _onImagineChanged();
    }
  }

  bool _imagineWasOn = false;
  ImagineMode? _imagineModeSeen;

  /// Aviso do A3: só a troca de modo refaz o envio à TV. Começar/terminar um roteiro (ou falhar) só redesenha
  /// o aviso — refazer aqui pedia o roteiro de novo a cada falha, num laço sem fim.
  void _onImagineNotify() {
    if (!mounted) return;
    if (_imagineModeSeen != _imagine.mode) {
      _imagineModeSeen = _imagine.mode;
      _onImagineChanged();
    } else {
      setState(() {});
    }
  }

  /// Modo imersivo no celular: só a imagem (sem a letra), com uma frase da letra de vez em quando.
  bool get _immersiveOnPhone =>
      _imagineOn && _imagine.mode == ImagineMode.immersive && _currentShot != null;

  /// Aviso do A3 enquanto monta a música ou quando ela ficou sem imagens (nulo: nada a avisar).
  Widget? _imagineStatus() {
    if (!_imagineOn || _engine.currentTrack == null || _storyboard?.hasPhotos == true) return null;
    final String text;
    VoidCallback? onTap;
    if (_imagine.working) {
      text = l10n.imagineWorking;
    } else {
      switch (_imagine.lastError) {
        case 'no_chip': // l10n-ignore
          text = l10n.imagineNeedsChip;
          onTap = _openBrain;
        case 'all_failed': // l10n-ignore
          text = l10n.imagineChipFailed;
          onTap = _openBrain;
        case 'bad_reply': // l10n-ignore
          text = l10n.imagineBadReply;
        case 'search_failed' || 'no_photos': // l10n-ignore
          text = l10n.imagineNoPhotos;
        default:
          return null;
      }
    }
    return _aiPill(text, working: _imagine.working, onTap: onTap);
  }

  /// Aviso pequeno dos plugins de IA (A2/A3) no alto da letra.
  Widget _aiPill(String text, {required bool working, VoidCallback? onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PluginCategory.ai.color.withValues(alpha: 0.6)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (working)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: AppTheme.cream))
            else
              Icon(Icons.auto_awesome, size: 14, color: PluginCategory.ai.color),
            const SizedBox(width: 8),
            Flexible(child: Text(text, style: const TextStyle(color: AppTheme.cream, fontSize: 12))),
          ]),
        ),
      );

  /// O Imagined Music (A3) está no prato.
  bool get _imagineOn => _plugins.catalog.any((p) => p.id == PluginCatalog.imaginedId && _plugins.isActive(p));

  /// Ligou/desligou o A3 ou trocou o modo: refaz (o roteiro já feito vem do aparelho) e reenvia à TV.
  void _onImagineChanged() {
    if (!mounted) return;
    _storyboardKey = null;
    _storyboardSentKey = null;
    _maybeImagine();
    setState(() {});
  }

  /// Plugin A3: monta (ou pega do aparelho) o roteiro visual da música atual e o envia à TV.
  void _maybeImagine() {
    final cast = _engine.castService;
    final track = _engine.currentTrack;
    if (!_imagineOn || track == null) {
      if (_storyboard != null || _storyboardSentKey != null) {
        _storyboard = null;
        _storyboardKey = null;
        _storyboardSentKey = null;
        cast.sendImagine(mode: _imagine.mode.name, scenes: const []);
        if (mounted) setState(() {});
      }
      return;
    }
    final lines = [for (final l in _engine.lyrics) l.text];
    final key = ImaginedMusic.keyFor(track.title, track.artist, lines);
    if (key != _storyboardKey) {
      _storyboardKey = key;
      _storyboard = null;
      _storyboardSentKey = null;
      final cached = _imagine.cached(track.title, track.artist, lines);
      if (cached != null) {
        _storyboard = cached;
      } else {
        _imagine
            .storyboard(
              title: track.title,
              artist: track.artist,
              album: _engine.lockedAlbumName ?? track.album,
              lines: lines,
              durationSeconds: _engine.telemetry.trackDurationSeconds,
            )
            .then((sb) {
          if (!mounted || _storyboardKey != key) return;
          setState(() => _storyboard = sb);
          _sendStoryboard(key);
          _prefetchNextStoryboard();
        });
        return;
      }
    }
    _sendStoryboard(key);
  }

  /// Envia o roteiro à TV (uma vez por música e por conexão) e avisa o Unsplash das fotos usadas.
  void _sendStoryboard(String key) {
    final sb = _storyboard;
    final cast = _engine.castService;
    if (sb == null) return;
    for (final s in sb.scenes) {
      final p = s.photo;
      if (p != null && _imaginePhotosUsed.add(p.id)) {
        AccountImagineSearch(_account).used(p).catchError((_) {});
      }
    }
    if (!cast.isConnected) {
      _storyboardSentKey = null;
      return;
    }
    final sentKey = '$key|${_imagine.mode.name}|${cast.connectedClientCount}'; // l10n-ignore
    if (_storyboardSentKey == sentKey) return;
    _storyboardSentKey = sentKey;
    final lyrics = _engine.lyrics;
    int msOf(int line, double? at) =>
        at != null ? (at * 1000).round() : (line >= 0 && line < lyrics.length ? lyrics[line].timestamp.inMilliseconds : 0);
    const motions = ['zoom_in', 'pan_left', 'zoom_out', 'pan_right']; // l10n-ignore
    final shots = _imagineShots(sb);
    cast.sendImagine(
      mode: _imagine.mode.name,
      title: _engine.currentTrack?.title,
      // Uma entrada por tomada (~13 s cada): a TV troca a imagem em cada uma
      scenes: [
        for (var i = 0; i < shots.length; i++)
          {
            'ms': shots[i].ms, // l10n-ignore
            'url': shots[i].photo.sized(), // l10n-ignore
            'author': shots[i].photo.author, // l10n-ignore
            'credit': shots[i].photo.credit, // l10n-ignore
            if (shots[i].photo.color != null) 'color': shots[i].photo.color, // l10n-ignore
            'palette': shots[i].scene.palette, // l10n-ignore
            // movimento alternado entre as tomadas da mesma cena (zoom, pan...), começando pelo da cena
            'motion': i > 0 && identical(shots[i - 1].scene, shots[i].scene) // l10n-ignore
                ? motions[(motions.indexOf(shots[i].scene.motion) + i) % motions.length]
                : shots[i].scene.motion,
            'transition': i > 0 && identical(shots[i - 1].scene, shots[i].scene) ? 'dissolve' : shots[i].scene.transition, // l10n-ignore
            'intensity': shots[i].scene.intensity, // l10n-ignore
          },
      ],
      // Frase com início e fim da linha cantada: a TV mostra só enquanto ela é cantada
      quotes: [
        for (final q in sb.quotes)
          {
            'ms': msOf(q.line, null), // l10n-ignore
            if (q.line + 1 < lyrics.length) 'endMs': msOf(q.line + 1, null), // l10n-ignore
            'text': q.text, // l10n-ignore
          },
      ],
    );
  }

  /// Prepara o roteiro da próxima música do disco (só uma adiantada: o Unsplash limita as buscas por hora).
  Future<void> _prefetchNextStoryboard() async {
    final current = _engine.currentTrack;
    final tracks = _engine.lockedTracklist;
    if (!_imagineOn || current == null || tracks.isEmpty) return;
    final at = TracklistMatcher.findIndex(tracks, current.title);
    if (at < 0 || at + 1 >= tracks.length) return;
    final next = tracks[at + 1];
    final artist = next.artist ?? _engine.lockedAlbumArtist ?? current.artist;
    final lrc = _engine.cacheService.findCachedLyrics(next.title, artist);
    if (lrc == null || lrc.trim().isEmpty) return;
    final lines = [for (final l in LrcParser.parse(lrc)) l.text];
    if (_imagine.cached(next.title, artist, lines) != null) return;
    await _imagine.storyboard(title: next.title, artist: artist, album: _engine.lockedAlbumName, lines: lines);
  }

  /// Tomadas do roteiro (~13 s cada, várias fotos por cena), com o início de cada cena pela letra.
  List<ImagineShot> _imagineShots(Storyboard sb) {
    final lyrics = _engine.lyrics;
    final duration = _engine.telemetry.trackDurationSeconds;
    return sb.shots(
      (s) => s.atSeconds != null
          ? (s.atSeconds! * 1000).round()
          : (s.line >= 0 && s.line < lyrics.length ? lyrics[s.line].timestamp.inMilliseconds : 0),
      endMs: duration != null && duration > 0 ? (duration * 1000).round() : null,
    );
  }

  /// Tomada atual (a última que já começou), para o fundo do celular.
  ImagineShot? get _currentShot {
    final sb = _storyboard;
    if (sb == null) return null;
    final pos = (_engine.telemetry.currentPositionSeconds * 1000).round();
    ImagineShot? current;
    for (final s in _imagineShots(sb)) {
      if (s.ms <= pos + 500 || current == null) current = s;
    }
    return current;
  }

  /// Fundo do celular com a foto da cena atual (escurecida para a letra) e o crédito ao fotógrafo.
  Widget _imagineBackdrop() {
    final photo = _imagineOn ? _currentShot?.photo : null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 1600),
      child: photo == null
          ? const SizedBox.expand(key: ValueKey('no-imagine')) // l10n-ignore
          : Stack(key: ValueKey(photo.id), fit: StackFit.expand, children: [
              Image.network(photo.sized(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
              Container(color: Colors.black.withValues(alpha: _immersiveOnPhone ? 0.12 : 0.62)),
            ]),
    );
  }

  /// Crédito ao fotógrafo do Unsplash (exigência da API), com link para o perfil dele.
  Widget? _imagineCredit() {
    final photo = _imagineOn ? _currentShot?.photo : null;
    if (photo == null) return null;
    return GestureDetector(
      onTap: photo.authorUrl == null ? null : () => PluginLinks.instance.openUrl(photo.authorUrl!),
      child: Text(photo.isArt ? photo.credit : l10n.imaginePhotoCredit(photo.author),
          style: const TextStyle(color: Colors.white60, fontSize: 10.5, decoration: TextDecoration.underline)),
    );
  }

  bool _translatorWasOn = false;

  /// O tradutor (A2) está no prato e já tem idioma escolhido.
  bool get _translatorOn =>
      _translator.language != null &&
      _plugins.catalog.any((p) => p.id == PluginCatalog.translatorId && _plugins.isActive(p));

  String? _translatorLangSeen;
  Timer? _translateRetry;
  int _translateRetries = 0;

  /// Aviso do tradutor: só a troca de idioma refaz as traduções. Começar/terminar/falhar só redesenha o aviso
  /// (refazer aqui pedia a tradução de novo a cada falha, num laço que queimava o limite do chip grátis).
  void _onTranslatorNotify() {
    if (!mounted) return;
    final lang = _translator.language?.code;
    if (lang != _translatorLangSeen) {
      _translatorLangSeen = lang;
      _onTranslatorChanged();
    } else {
      setState(() {});
    }
  }

  /// Aviso do tradutor (A2) enquanto traduz a letra desta música ou por que ela ficou sem tradução.
  Widget? _translatorStatus() {
    if (!_translatorOn || _engine.currentTrack == null || _engine.lyrics.isEmpty) return null;
    if (_engine.lyrics.any((l) => l.translation != null)) return null;
    final String text;
    VoidCallback? onTap;
    if (_translator.working) {
      text = l10n.translatorWorking;
    } else {
      switch (_translator.lastError) {
        case 'no_chip': // l10n-ignore
          text = l10n.translatorNeedsChip;
          onTap = _openBrain;
        case 'all_failed': // l10n-ignore
          text = l10n.translatorChipFailed;
          onTap = _openBrain;
        case 'bad_reply': // l10n-ignore
          text = l10n.translatorBadReply;
        default:
          return null;
      }
    }
    return _aiPill(text, working: _translator.working, onTap: onTap);
  }

  /// Ligou/desligou o tradutor ou trocou o idioma: a letra e as curiosidades são refeitas.
  void _onTranslatorChanged() {
    if (!mounted) return;
    _lyricsTranslationKey = null;
    _curiositiesKey = null; // busca de novo (do aparelho) e traduz, ou volta ao inglês
    _maybeTranslateLyrics();
    setState(() {});
  }

  /// Plugin A2: traduz a letra da música atual linha por linha (uma vez por música; depois vem do
  /// aparelho) e põe cada tradução embaixo da linha, no celular e na TV.
  void _maybeTranslateLyrics() {
    final track = _engine.currentTrack;
    final lyrics = _engine.lyrics;
    if (track == null || lyrics.isEmpty) return;
    final lines = [for (final l in lyrics) l.text];
    final hasTranslation = lyrics.any((l) => l.translation != null);
    if (!_translatorOn) {
      if (hasTranslation) _engine.applyLyricTranslations(track.title, lines, null);
      _lyricsTranslationKey = null;
      return;
    }
    final key = '${_translator.language!.code}|${track.title}|${Object.hashAll(lines)}'; // l10n-ignore
    if (hasTranslation || _lyricsTranslationKey == key) {
      if (hasTranslation) _prefetchRecordTranslations(); // a próxima letra pode ter chegado agora
      return;
    }
    _lyricsTranslationKey = key;
    final cached = _translator.cached('lyrics', lines); // l10n-ignore
    if (cached != null) {
      _engine.applyLyricTranslations(track.title, lines, cached);
      return;
    }
    _translator.translateLyrics(lines, title: track.title, artist: track.artist).then((tr) {
      if (tr != null && mounted && _lyricsTranslationKey == key) {
        _translateRetries = 0;
        _engine.applyLyricTranslations(track.title, lines, tr);
      } else if (tr == null && mounted && _lyricsTranslationKey == key && _translateRetries < 2) {
        // Falhou (limite por minuto do chip grátis, resposta fora do formato): tenta de novo daqui a pouco
        _translateRetries++;
        _translateRetry?.cancel();
        _translateRetry = Timer(const Duration(seconds: 45), () {
          if (!mounted || _lyricsTranslationKey != key) return;
          _lyricsTranslationKey = null;
          _maybeTranslateLyrics();
        });
      }
      _prefetchRecordTranslations();
    });
  }

  /// Músicas já traduzidas adiantado (idioma|artista|música), para não pedir de novo.
  final Set<String> _prefetchedTranslations = {};
  bool _prefetchingTranslations = false;

  /// Enquanto uma música toca, traduz as próximas do disco cuja letra já está no aparelho (a próxima faixa é
  /// sempre buscada adiantado), uma de cada vez para não estourar o limite do chip grátis. Assim a tradução
  /// aparece na hora em que cada música começa.
  Future<void> _prefetchRecordTranslations() async {
    if (_prefetchingTranslations || !_translatorOn) return;
    final current = _engine.currentTrack;
    final tracks = _engine.lockedTracklist;
    if (current == null || tracks.isEmpty) return;
    final at = TracklistMatcher.findIndex(tracks, current.title);
    _prefetchingTranslations = true;
    try {
      for (final e in tracks.skip(at < 0 ? 0 : at + 1)) {
        if (!mounted || !_translatorOn) return;
        final artist = e.artist ?? _engine.lockedAlbumArtist ?? current.artist;
        final key = '${_translator.language!.code}|$artist|${e.title}'; // l10n-ignore
        if (_prefetchedTranslations.contains(key)) continue;
        final lrc = _engine.cacheService.findCachedLyrics(e.title, artist);
        if (lrc == null || lrc.trim().isEmpty) continue; // letra ainda não buscada: fica para quando vier
        final lines = [for (final l in LrcParser.parse(lrc)) l.text];
        if (lines.isEmpty) continue;
        _prefetchedTranslations.add(key);
        if (_translator.cached('lyrics', lines) != null) continue; // l10n-ignore
        await _translator.translateLyrics(lines, title: e.title, artist: artist);
        if (_translator.lastError == 'no_chip' || _translator.lastError == 'all_failed') return; // l10n-ignore
      }
    } finally {
      _prefetchingTranslations = false;
    }
  }

  /// Plugin A2: curiosidades e notícias traduzidas, marcadas como tradução de IA (sem o tradutor, iguais).
  Future<RecordCuriosities> _translatedCuriosities(RecordCuriosities c, {required String artist, required String album}) async {
    if (!_translatorOn || c.isEmpty) return c;
    final all = [...c.album, ...c.news, ...c.track];
    final tr = await _translator.translateTexts([for (final x in all) x.text], context: '"$album" by $artist'); // l10n-ignore (vai para a IA, não para a tela)
    if (tr == null) return c;
    var i = 0;
    Curiosity t(Curiosity x) => Curiosity(tr[i++], '${x.source} · ${l10n.aiTranslatedTag}', url: x.url, date: x.date);
    final album0 = [for (final x in c.album) t(x)];
    final news = [for (final x in c.news) t(x)];
    final track = [for (final x in c.track) t(x)];
    return RecordCuriosities(album: album0, news: news, track: track);
  }
  final LocalLyricsLibrary _myLyrics = LocalLyricsLibrary();
  final List<CloudLyricsFolder> _clouds = [DropboxFolder(), OneDriveFolder(), GoogleDriveFolder()];

  /// Link "Install" do site: com a conta pronta (esta tela só existe depois do login), instala na hora.
  void _onPluginLink() {
    if (!mounted || !_plugins.isLoaded || PluginLinks.instance.pending.value == null) return;
    final id = PluginLinks.instance.take();
    if (id != null) unawaited(_installPluginFromLink(id));
  }

  Future<void> _installPluginFromLink(String id) async {
    final known = _plugins.byId(id);
    final name = known == null ? id : '${known.code} · ${known.name}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(l10n.pluginInstalling(name), style: const TextStyle(color: Colors.white)),
      ));
    final result = await _pluginInstaller.install(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final ok = result == PluginInstallResult.installed;
    final message = switch (result) {
      PluginInstallResult.installed => l10n.pluginInstalledMsg(name),
      PluginInstallResult.alreadyInstalled => l10n.pluginAlreadyInstalled(name),
      PluginInstallResult.builtIn => l10n.pluginBuiltInMsg(name),
      PluginInstallResult.needsUpdate => l10n.pluginNeedsUpdate,
      PluginInstallResult.notFound => l10n.pluginNotFound,
      PluginInstallResult.invalid => l10n.pluginInvalid,
      PluginInstallResult.network => l10n.pluginNetworkError,
    };
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        icon: Icon(ok ? Icons.check_circle : Icons.extension, color: ok ? AppTheme.orange : AppTheme.cream, size: 36),
        title: Text(ok ? l10n.pluginInstalledTitle : l10n.plugins, style: const TextStyle(color: AppTheme.cream)),
        content: Text(message, style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openPlugins();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.orange, foregroundColor: Colors.white),
            child: Text(l10n.pluginOpenJukebox),
          ),
        ],
      ),
    );
  }

  /// Evita que toques repetidos no botão da coleção disparem duas operações seguidas.
  bool _collectionBusy = false;

  /// Adiciona (ou retira) da coleção o disco que está tocando. Para adicionar, abre a mesma tela de
  /// dados do disco (nota, estado da capa e do vinil, observações) do fluxo da câmera.
  Future<void> _toggleCurrentInCollection() async {
    if (_collectionBusy) return;
    final track = _engine.currentTrack;
    if (track == null) return;
    final album =
        (_engine.lockedAlbumName?.isNotEmpty ?? false) ? _engine.lockedAlbumName! : (track.album ?? track.title);
    final artist = _engine.lockedAlbumArtist ?? track.artist;
    final messenger = ScaffoldMessenger.of(context);
    _collectionBusy = true;
    try {
      if (_collection.contains(album, artist)) {
        await _collection.remove(album, artist);
        messenger.showSnackBar(SnackBar(
          backgroundColor: AppTheme.surfaceLight,
          content: Text(l10n.removedFromCollection(album), style: const TextStyle(color: Colors.white)),
        ));
        return;
      }
      // Edição do disco travado, quando conhecida (Discogs/MusicBrainz), para a coleção e o Discogs
      final disc = _engine.cacheService.findCachedDisc(album, artist);
      final source = disc?.tracklistSource;
      final releaseId = disc?.releaseId ?? '';
      final knownRelease = releaseId.isNotEmpty && (source == 'discogs' || source == 'musicbrainz'); // l10n-ignore
      final tracks = _engine.lockedTracklist;
      await addReleaseToCollection(
        context,
        collection: _collection,
        discogsCollection: _discogsCollection,
        release: ReleaseCandidate(
          providerId: knownRelease ? source! : 'local', // l10n-ignore
          releaseId: knownRelease ? releaseId : '',
          albumTitle: album,
          artistName: artist,
          format: disc?.releaseFormat,
          coverUrl: _engine.lockedAlbumCoverUrl ?? track.coverUrl,
          trackCount: tracks.isEmpty ? null : tracks.length,
        ),
      );
    } finally {
      _collectionBusy = false;
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
      // O disco já está preparado (tracklist e disco padrão); a escuta só começa quando o usuário
      // colocar a agulha e tocar no microfone (ou no ▶ do Modo Manual)
      Navigator.of(context).popUntil((r) => r.isFirst);
      await _showReadyToPlay();
    }
  }

  /// "Ready to play": a sequência em poucas palavras, depois de "Let's listen?".
  Future<void> _showReadyToPlay() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: RetroText(l10n.readyTitle, fontSize: 26, depth: 2),
          content: Text(
            _engine.isManualMode ? l10n.readyStepsManual : l10n.readyStepsAuto,
            style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 15),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.readyGotIt))],
        ),
      );

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
      animation: Listenable.merge([_engine, _plugins]),
      builder: (context, _) {
        final telemetry = _engine.telemetry;
        final isListening = telemetry.isUserListening || telemetry.status == CalibrationStatus.listeningSample1;
        final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
        // Microfone cromado no centro da barra inferior
        final micSize = isLandscape ? 50.0 : 48.0;
        final awaitingFlip = _engine.isAwaitingSideFlip && !telemetry.isMicActive;
        // Etapa atual (ouvindo, não identificada...) mostrada na saudação, já que o rodapé ficou enxuto
        final statusLine = (telemetry.status == CalibrationStatus.idle || telemetry.statusMessage.isEmpty)
            ? null
            : telemetry.statusMessage;

        // Tela estreita (celular em pé): sem o texto ao lado do logo, só os botões
        final compactBar = MediaQuery.sizeOf(context).width < 600;
        // Em pé, com música tocando: capa maior no canto e as informações da música ao lado dela
        final trackOnTop = compactBar && _engine.currentTrack != null;
        final logoSize = trackOnTop ? 66.0 : (compactBar ? 46.0 : 50.0);
        _ensureCuriosities(); // também durante a transmissão (a TV mostra as curiosidades)
        final panel = _panelState();
        _syncLyricsWithPanel(panel.shown);
        // O que aparece é só o ativo: curiosidades no lugar da letra (celular e TV) quando o D1 é o ativo;
        // letra só quando ela é da fonte ativa (enquanto a da fonte ativa não chega, nada)
        final curiositiesFirst = panel.shown == PluginCatalog.curiositiesId;
        final shownPlugin = panel.shown == null ? null : _plugins.byId(panel.shown!);
        final lyricsMatchPanel = shownPlugin != null &&
            shownPlugin.category == PluginCategory.sources &&
            _engine.lyricsSource == shownPlugin.engine;
        _engine.curiositiesFirst = curiositiesFirst || !lyricsMatchPanel;
        if (_engine.manualSuggested) _offerManualMode();
        const tileSize = 40.0;
        // Em pé (e no cockpit): linha com os plugins que mudam a tela, para ligar/desligar e ordenar
        final panelHeight = compactBar ? PluginPanelStrip.heightFor(_plugins) : 0.0;

        return Stack(
          children: [
            Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                toolbarHeight: trackOnTop ? 92 : 74,
                flexibleSpace: const _WoodTopPanel(),
                // Em pé: embaixo, só o painel de plugins (os botões de madeira ficam no menu ☰ e a música no
                // alto, ao lado da capa). Deitado: botões na linha de cima.
                bottom: !compactBar || panelHeight == 0
                    ? null
                    : PreferredSize(
                        preferredSize: Size.fromHeight(panelHeight),
                        child: SizedBox(
                          height: panelHeight,
                          child: PluginPanelStrip(store: _plugins, shownId: panel.shown, failedIds: panel.failed),
                        ),
                      ),
                // Em pé: botão ☰ (alinhado ao topo da capa) e a capa um pouco à direita. Logo (ou capa do disco)
                // no canto esquerdo; o texto ao lado só aparece com o celular deitado
                leadingWidth: logoSize + 22 + (compactBar ? _menuButtonWidth : 0),
                leading: Padding(
                  padding: EdgeInsets.only(left: compactBar ? 6 : 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (compactBar)
                        SizedBox(
                          height: logoSize,
                          child: Align(
                            alignment: Alignment.topCenter,
                            // o botão tem 4 px de folga em volta: sobe 4 para o topo bater com o da capa
                            child: Transform.translate(offset: const Offset(0, -4), child: _menuButton()),
                          ),
                        ),
                      if (compactBar) const SizedBox(width: 4),
                      Center(
                    child: GestureDetector(
                      onTap: _engine.currentTrack == null ? _openPlayRecord : _showAlbumTracklistModal,
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
                    ],
                  ),
                ),
                titleSpacing: 12,
                title: compactBar
                    ? (trackOnTop ? _portraitTrackInfo() : null)
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
                                    RetroText(_engine.currentTrack!.title, fontSize: 22, depth: 2),
                                    // Linha 2: Nome do Disco (com ícone de disco neon se travado)
                                    Row(
                                      children: [
                                        if (_engine.isAlbumLocked) ...[
                                          const Icon(Icons.album, size: 13, color: AppTheme.cream),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: RetroText(
                                            (_engine.lockedAlbumName != null && _engine.lockedAlbumName!.isNotEmpty)
                                                ? _engine.lockedAlbumName!
                                                : ((_engine.currentTrack?.album != null &&
                                                        _engine.currentTrack!.album!.isNotEmpty)
                                                    ? _engine.currentTrack!.album!
                                                    : (_engine.currentTrack?.artist ?? l10n.unknownAlbum)),
                                            fontSize: 16,
                                            depth: 2,
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
                                        RetroText(kAppName, fontSize: compactBar ? 22 : 26, depth: 2),
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
                  if (!compactBar) _woodButtons(tileSize),
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
                        onManualPressed: _onManualPressed,
                      ),
                    )
                  : Stack(
                      children: [
                        // Fundo em madeira escura com veio (entorno da letra)
                        const Positioned.fill(child: WoodBackground()),
                        // Plugin A3: foto da cena atual atrás da letra
                        Positioned.fill(child: IgnorePointer(child: _imagineBackdrop())),

                        // Lista vertical de letras sincronizadas (some no modo imersivo do A3: só a imagem)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _immersiveOnPhone ? 0 : 1,
                            duration: const Duration(milliseconds: 900),
                            child: IgnorePointer(
                              ignoring: _immersiveOnPhone,
                              child: LyricsListView(
                            lyrics: lyricsMatchPanel ? _engine.lyrics : const [],
                            activeIndex: _engine.activeLineIndex,
                            onSeek: (seconds) => _engine.syncToLine(seconds),
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
                          ),
                        ),
                        // Plugin A3 imersivo: uma frase da letra aparece e esmaece de vez em quando
                        if (_immersiveOnPhone && (_storyboard?.quotes.isNotEmpty ?? false))
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ImmersiveQuotes(
                                quotes: _storyboard!.quotes,
                                activeLine: () => _engine.activeLineIndex,
                              ),
                            ),
                          ),
                        // Plugin A3: crédito ao fotógrafo do Unsplash (com link para o perfil)
                        if (_imagineCredit() case final credit?) Positioned(left: 12, bottom: 10, child: credit),
                        // Plugin A3: "Imagining this song…" ou por que ficou sem imagens
                        if (_imagineStatus() ?? _translatorStatus() case final status?)
                          Positioned(left: 16, right: 16, top: 8, child: Center(child: status)),

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
                      showLyricSync: _engine.isManualMode && _engine.isManualPlaying,
                      lyricBiasSeconds: _engine.lyricBiasSeconds,
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
              child: IntroLabelsLayer(specs: MediaQuery.sizeOf(context).width < 600
                  ? [IntroLabelSpec(anchor: _menuKey, text: l10n.menu, delay: Duration.zero)]
                  : [
                // Um botão por vez, da esquerda para a direita, alternando acima/abaixo
                IntroLabelSpec(anchor: _userKey, text: l10n.profile, delay: Duration.zero),
                IntroLabelSpec(anchor: _cameraKey, text: l10n.camera, delay: const Duration(milliseconds: 1200), above: true),
                IntroLabelSpec(anchor: _manualKey, text: l10n.manual, delay: const Duration(milliseconds: 2400)),
                IntroLabelSpec(
                    anchor: _collectionKey, text: l10n.myCollection, delay: const Duration(milliseconds: 3600), above: true),
                IntroLabelSpec(anchor: _pluginsKey, text: l10n.plugins, delay: const Duration(milliseconds: 4800)),
                IntroLabelSpec(anchor: _helpKey, text: l10n.help, delay: const Duration(milliseconds: 6000), above: true),
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
/// Largura do botão ☰ na barra (36 + 4 de folga de cada lado + 4 até a capa).
const double _menuButtonWidth = 48;

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
