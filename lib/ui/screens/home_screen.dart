import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_info.dart';
import '../../engine/waxclub_engine.dart';
import '../../models/sync_state.dart';
import '../../models/track_entry.dart';
import '../../services/album_catalog_service.dart';
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

/// Tela principal do aplicativo WaxClub.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final WaxClubEngine _engine;
  late final AnimationController _pulseController;
  Timer? _haloReminderTimer;
  Timer? _initialPulseTimer;
  bool _isHaloPulsing = false;

  /// Conta Discogs do usuário e catálogo de discos da tela "Mudar disco" (criados no primeiro uso).
  late final DiscogsAuthService _discogsAuth = DiscogsAuthService();
  late final AlbumCatalogService _albumCatalog = AlbumCatalogService(auth: _discogsAuth);
  bool _albumCatalogCreated = false;

  @override
  void initState() {
    super.initState();
    _engine = WaxClubEngine();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _engine.castService.addListener(_onCastServiceStateChanged);
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
            ? AppTheme.neonCyan
            : (shouldGlow
                ? AppTheme.neonCyan.withValues(alpha: 0.5 + (glowValue * 0.5))
                : Colors.white38);

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
                        color: AppTheme.neonCyan.withValues(alpha: 0.45 * glowValue),
                        blurRadius: 9.0 * glowValue,
                        spreadRadius: 2.2 * glowValue,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: isConnected
                  ? AppTheme.neonCyan.withValues(alpha: 0.2)
                  : (shouldGlow
                      ? AppTheme.neonCyan.withValues(alpha: 0.15 * glowValue)
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan),
                        )
                      : Icon(
                          isConnected ? Icons.cast_connected : Icons.cast,
                          color: (isConnected || shouldGlow) ? AppTheme.neonCyan : Colors.white,
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
                      const Icon(Icons.cast_connected, color: AppTheme.neonCyan, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Casting to TV',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                            ),
                            Text(
                              'Screen: ${_engine.castService.clientDeviceName ?? "Living room TV"}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.neonCyan),
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
                      label: const Text('Disconnect from TV'),
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

  void _showDemoSongsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Demos (Vinyl Mode)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Load tracks with synced lyrics and a simulated 1.018x turntable pitch for instant testing:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textInactive),
                ),
                const SizedBox(height: 16),
                _buildDemoItem(
                  title: 'Bohemian Rhapsody',
                  artist: 'Queen',
                  offset: 15.0,
                ),
                _buildDemoItem(
                  title: 'Dreams',
                  artist: 'Fleetwood Mac',
                  offset: 8.0,
                ),
                _buildDemoItem(
                  title: 'Hotel California',
                  artist: 'Eagles',
                  offset: 20.0,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDemoItem({
    required String title,
    required String artist,
    required double offset,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.music_note, color: AppTheme.neonCyan),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      subtitle: Text(artist, style: const TextStyle(color: AppTheme.textInactive)),
      trailing: const Icon(Icons.play_arrow, color: AppTheme.neonPurple),
      onTap: () {
        Navigator.pop(context);
        _engine.loadManualTrack(
          title: title,
          artist: artist,
          startOffsetSeconds: offset,
        );
      },
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.speed, color: AppTheme.neonCyan),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Vinyl Compensation', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              GestureDetector(
                onLongPress: _exportSessionLogs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.neonCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'v$kAppVersion',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.neonCyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How $kAppName ($kAppTagline) works:\n\n'
                  '1. Capture & fingerprint: identifies the track and its current position using the Shazam algorithm.\n\n'
                  '2. Speed calibration: measures your turntable\'s speed deviation and computes the exact speed factor.\n\n'
                  '3. Mid-song re-sync: checks the lyrics are still in sync while the track plays.\n\n'
                  '4. Continuous mode: at the end of a track, it listens automatically to identify the next song.\n\n'
                  '5. Smart prefetch: while a song plays, it downloads lyrics for the album\'s likely next tracks.\n\n'
                  '6. Local cache: remembers the records and songs you have played to speed up future sessions.\n\n'
                  'Tip: long-press the version badge to export the session logs.',
                  style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido', style: TextStyle(color: AppTheme.neonPurple)),
            ),
          ],
        );
      },
    );
  }

  /// Exporta os últimos eventos de log da sessão para a área de transferência.
  Future<void> _exportSessionLogs() async {
    final logs = await _engine.logService.tail(lines: 200);
    if (!mounted) return;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text('No events logged in this session.', style: TextStyle(color: Colors.white70)),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: logs));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text(
            'Session logs copied to the clipboard!',
            style: TextStyle(color: AppTheme.neonCyan),
          ),
        ),
      );
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
        const SnackBar(
          backgroundColor: AppTheme.surface,
          content: Text('No record identified yet.', style: TextStyle(color: Colors.white70)),
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
            : ((current.album != null && current.album!.isNotEmpty)
                ? current.album!
                : current.title);
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
                                  child: const Icon(Icons.album, color: AppTheme.neonCyan),
                                ),
                              )
                            : Container(
                                width: 56,
                                height: 56,
                                color: AppTheme.surfaceLight,
                                child: const Icon(Icons.album, color: AppTheme.neonCyan),
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
                                color: AppTheme.neonCyan,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (tracklist.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${tracklist.length} tracks on this record',
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
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Change record'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.neonCyan,
                        side: const BorderSide(color: AppTheme.carveLight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openAlbumPicker();
                      },
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),

                // Lista de faixas ou aviso de indisponibilidade
                Expanded(
                  child: tracklist.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.queue_music, size: 48, color: AppTheme.textInactive),
                                SizedBox(height: 12),
                                Text(
                                  'No tracklist for this album yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textInactive, fontSize: 14),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'The tracklist is fetched automatically from the official catalog (MusicBrainz) while the song plays.',
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

                            final posLabel = entry.number != null && entry.number!.isNotEmpty
                                ? entry.number!
                                : '${entry.position}';

                            return ListTile(
                              dense: true,
                              tileColor: isCurrent
                                  ? AppTheme.neonCyan.withValues(alpha: 0.12)
                                  : (isNext ? AppTheme.neonPurple.withValues(alpha: 0.08) : null),
                              leading: Container(
                                width: 38,
                                alignment: Alignment.center,
                                child: isCurrent
                                    ? const Icon(Icons.graphic_eq, color: AppTheme.neonCyan, size: 22)
                                    : (isNext
                                        ? const Icon(Icons.skip_next_rounded, color: AppTheme.neonPurple, size: 20)
                                        : Text(
                                            posLabel,
                                            style: TextStyle(
                                              color: isCurrent ? AppTheme.neonCyan : AppTheme.textInactive,
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
                                        color: isCurrent
                                            ? AppTheme.neonCyan
                                            : (isNext ? Colors.white : Colors.white70),
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
                                        color: AppTheme.neonCyan.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                                      ),
                                      child: const Text(
                                        'PLAYING',
                                        style: TextStyle(
                                          color: AppTheme.neonCyan,
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
                                        color: AppTheme.neonPurple.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.4)),
                                      ),
                                      child: const Text(
                                        'UP NEXT',
                                        style: TextStyle(
                                          color: AppTheme.neonPurple,
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
                                        if (entry.side != null && entry.side!.isNotEmpty) 'Side ${entry.side}',
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
                                        color: isCurrent ? AppTheme.neonCyan : AppTheme.textInactive,
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
        final isListening = telemetry.isUserListening ||
            telemetry.status == CalibrationStatus.listeningSample1;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            toolbarHeight: 74,
            leadingWidth: 48,
            leading: IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white70),
              tooltip: 'How it works',
              onPressed: _showInfoDialog,
            ),
            title: Row(
              children: [
                GestureDetector(
                  onTap: _showAlbumTracklistModal,
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
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/icon/app_icon.jpg',
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : ClipRRect(
                            key: const ValueKey('default_logo'),
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/icon/app_icon.jpg',
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.album, color: AppTheme.neonCyan, size: 40),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
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
                                const Icon(Icons.album, size: 13, color: AppTheme.neonCyan),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  (_engine.lockedAlbumName != null && _engine.lockedAlbumName!.isNotEmpty)
                                      ? _engine.lockedAlbumName!
                                      : ((_engine.currentTrack?.album != null && _engine.currentTrack!.album!.isNotEmpty)
                                          ? _engine.currentTrack!.album!
                                          : (_engine.currentTrack?.artist ?? 'Unknown Album')),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.neonCyan,
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
                              'Up next: ${_engine.telemetry.predictedNextTrackTitle!}${_engine.telemetry.nextLyricsReady ? " ⚡" : ""}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.neonPurple,
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
                              const Text(
                                kAppName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onLongPress: _exportSessionLogs,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.neonCyan.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text(
                                    'v$kAppVersion',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: AppTheme.neonCyan,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
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
              IconButton(
                icon: const Icon(Icons.playlist_play, color: AppTheme.neonCyan),
                tooltip: 'Demo Songs',
                onPressed: _showDemoSongsSheet,
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
                      ),
                    ),


                    // Botão Flutuante (FAB) de escuta / calibração; no fim do lado vira "Vire o disco" pulsando
                    Positioned(
                      right: 20,
                      bottom: 110,
                      child: (_engine.isAwaitingSideFlip && !telemetry.isMicActive)
                          ? FlipSideButton(onPressed: () => _engine.flipSide())
                          : _buildGlowingListenFab(isListening),
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
                ),
        );
      },
    );
  }

  Widget _buildGlowingListenFab(bool isListening) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowRadius = isListening ? 12.0 + (_pulseController.value * 14.0) : 6.0;
        final fabColor = isListening ? Colors.redAccent : AppTheme.neonPurple;

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: fabColor.withOpacity(0.6),
                blurRadius: glowRadius,
                spreadRadius: isListening ? 2.0 : 0.0,
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _onFabPressed,
            tooltip: isListening ? 'Stop listening (microphone off)' : 'Listen to the room',
            backgroundColor: fabColor,
            child: Icon(
              isListening ? Icons.stop_rounded : Icons.mic,
              color: Colors.white,
              size: 28,
            ),
          ),
        );
      },
    );
  }
}
