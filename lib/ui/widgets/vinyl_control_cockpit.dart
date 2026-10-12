import 'package:flutter/material.dart';
import '../../engine/waxclub_engine.dart';
import '../../models/sync_state.dart';
import '../../models/track_info.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import 'flip_side_button.dart';

/// Painel de controle do celular durante a transmissão para a TV (tela travada em retrato).
///
/// Organizado em 4 grupos que cabem inteiros na tela, sem rolagem:
///  1. TV conectada (faixa fina com "Desconectar");
///  2. Tocando agora: capa, título, artista, disco, lado, barra de tempo e "A seguir";
///  3. Ajustes: rotação medida, ajuste fino da rotação (pitch + trava) e sincronia da letra (nudge);
///  4. Ação principal no rodapé: Ouvir/Ressincronizar ou "Vire o disco" (pulsando no fim do lado).
/// Em telas baixas (ex.: 360×740) entra em modo compacto, com as mesmas funções.
class VinylControlCockpit extends StatefulWidget {
  final WaxClubEngine engine;
  final VoidCallback onOpenCastDialog;
  final VoidCallback onDisconnectCast;
  final VoidCallback? onCoverTap;

  const VinylControlCockpit({
    super.key,
    required this.engine,
    required this.onOpenCastDialog,
    required this.onDisconnectCast,
    this.onCoverTap,
  });

  @override
  State<VinylControlCockpit> createState() => _VinylControlCockpitState();
}

class _VinylControlCockpitState extends State<VinylControlCockpit> with SingleTickerProviderStateMixin {
  late final AnimationController _discSpin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  double _manualPitch = 0.0;

  static const Color _amber = Color(0xFFFFB300);

  @override
  void didUpdateWidget(covariant VinylControlCockpit oldWidget) {
    super.didUpdateWidget(oldWidget);
    final telemetry = widget.engine.telemetry;
    final spinning = !telemetry.isPaused && widget.engine.currentTrack != null;
    if (spinning && !_discSpin.isAnimating) {
      _discSpin.repeat();
    } else if (!spinning && _discSpin.isAnimating) {
      _discSpin.stop();
    }
    if (telemetry.speedFactor > 0.1) {
      final d = Duration(milliseconds: (1800 / telemetry.speedFactor).round());
      if (_discSpin.duration != d) _discSpin.duration = d;
    }
  }

  @override
  void dispose() {
    _discSpin.dispose();
    super.dispose();
  }

  String _fmt(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '0:00';
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _setPitch(double value) {
    final v = value.clamp(-0.05, 0.05).toDouble();
    setState(() => _manualPitch = v);
    widget.engine.setManualPitchAdjustment(v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 640;
      final gap = compact ? 7.0 : 10.0;
      final engine = widget.engine;
      final telemetry = engine.telemetry;
      return Padding(
        padding: EdgeInsets.fromLTRB(14, 4, 14, compact ? 8 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTvStrip(compact),
            SizedBox(height: gap),
            if (!compact) _groupTitle('Tocando agora'),
            _buildNowPlaying(engine.currentTrack, telemetry, compact),
            SizedBox(height: gap),
            if (!compact) _groupTitle('Ajustes'),
            Expanded(child: _buildAdjustments(telemetry, compact)),
            SizedBox(height: gap),
            _buildMainAction(telemetry, compact),
          ],
        ),
      );
    });
  }

  Widget _groupTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 5),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: Colors.white54),
      ),
    );
  }

  // ─── 1. TV CONECTADA ───
  Widget _buildTvStrip(bool compact) {
    final cast = widget.engine.castService;
    final reconnecting = cast.isReconnecting;
    return WoodPanel(
      radius: 14,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 8),
      glow: AppTheme.neonCyan,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reconnecting ? _amber : AppTheme.neonCyan,
              boxShadow: [BoxShadow(color: (reconnecting ? _amber : AppTheme.neonCyan).withValues(alpha: 0.8), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cast.clientDeviceName ?? cast.connectedDevice?.name ?? 'TV',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  reconnecting ? 'Reconectando à TV...' : 'Letra sendo exibida na TV',
                  style: TextStyle(fontSize: 11, color: reconnecting ? _amber : Colors.white54),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: widget.onDisconnectCast,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A80),
              side: const BorderSide(color: Color(0x66FF8A80)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Desconectar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ─── 2. TOCANDO AGORA ───
  Widget _buildNowPlaying(TrackInfo? track, VinylTelemetry telemetry, bool compact) {
    final engine = widget.engine;
    final cover = engine.lockedAlbumCoverUrl ?? track?.coverUrl;
    final album = engine.lockedAlbumName ?? track?.album;
    final side = engine.currentSide;
    final number = engine.currentTrackNumber;
    final coverSize = compact ? 74.0 : 108.0;

    final duration = (track?.durationMs != null && track!.durationMs! > 0)
        ? track.durationMs! / 1000.0
        : (telemetry.trackDurationSeconds ?? 0.0);
    final position = duration > 0
        ? telemetry.currentPositionSeconds.clamp(0.0, duration).toDouble()
        : telemetry.currentPositionSeconds;

    return WoodPanel(
      radius: 18,
      padding: EdgeInsets.all(compact ? 10 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.onCoverTap,
                child: SizedBox(
                  width: coverSize,
                  height: coverSize,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 14, offset: Offset(0, 6))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (cover != null && cover.isNotEmpty)
                                ? Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackCover())
                                : _fallbackCover(),
                          ),
                        ),
                      ),
                      if (side != null && side.isNotEmpty)
                        Positioned(left: 6, bottom: 6, child: _coverBadge('LADO ${side.toUpperCase()}', bold: true)),
                      Positioned(right: 6, top: 6, child: _coverBadge('faixas ▸')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? 'Nenhuma música identificada',
                      style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15),
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track?.artist ?? 'Toque em Ouvir com o disco tocando',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.neonCyan),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (album != null && album.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: album, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                          if (number != null) TextSpan(text: ' · faixa ${number.$1} de ${number.$2}'),
                        ]),
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 10),
          // Barra de tempo (arrastar ajusta a posição da letra)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTheme.neonCyan,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppTheme.neonPurple,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: SizedBox(
              height: 20,
              child: Slider(
                value: duration > 0 ? position : 0.0,
                min: 0.0,
                max: duration > 0 ? duration : 1.0,
                onChanged: duration > 0 ? (v) => widget.engine.seekTo(v) : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(position), style: const TextStyle(fontSize: 11, color: Colors.white54, fontFeatures: [FontFeature.tabularFigures()])),
                Text(duration > 0 ? _fmt(duration) : '--:--', style: const TextStyle(fontSize: 11, color: Colors.white54, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          _buildNext(telemetry, compact),
        ],
      ),
    );
  }

  Widget _coverBadge(String text, {bool bold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(7)),
      child: Text(
        text,
        style: TextStyle(fontSize: bold ? 10.5 : 9.5, fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? Colors.white : Colors.white70),
      ),
    );
  }

  Widget _fallbackCover() {
    return Container(
      color: AppTheme.surfaceLight,
      child: const Center(child: Icon(Icons.album_rounded, size: 42, color: AppTheme.neonCyan)),
    );
  }

  Widget _buildNext(VinylTelemetry telemetry, bool compact) {
    final sideEnd = telemetry.sideEndLabel != null;
    final next = telemetry.predictedNextTrackTitle;
    if (!sideEnd && (next == null || next.isEmpty)) return const SizedBox.shrink();

    final color = sideEnd ? _amber : AppTheme.neonPurple;
    final label = sideEnd ? telemetry.sideEndLabel! : 'A seguir';
    final afterFlip = widget.engine.afterFlipTitle;
    final song = sideEnd
        ? (afterFlip != null ? 'Próximo lado começa com: $afterFlip' : 'Vire o disco para continuar')
        : next!;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(sideEnd ? Icons.flip_camera_android_rounded : Icons.skip_next_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: color)),
                Text(song, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!sideEnd && telemetry.nextLyricsReady)
            const Text('⚡ letra pronta', style: TextStyle(fontSize: 11, color: AppTheme.neonCyan)),
        ],
      ),
    );
  }

  // ─── 3. AJUSTES ───
  Widget _buildAdjustments(VinylTelemetry telemetry, bool compact) {
    final engine = widget.engine;
    final estimate = engine.currentSpeedEstimate;
    final factor = telemetry.speedFactor;
    final pct = (factor - 1.0) * 100.0;
    final stdErr = estimate?.standardError;
    final samples = estimate?.samples ?? 0;
    final rpm = 33.3333 * factor;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rotação medida
        Row(
          children: [
            RotationTransition(
              turns: _discSpin,
              child: Container(
                width: compact ? 38 : 46,
                height: compact ? 38 : 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF131016),
                  border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Center(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.neonCyan),
                    child: const Center(child: CircleAvatar(radius: 3, backgroundColor: Colors.black)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: rpm.toStringAsFixed(2)),
                      const TextSpan(text: ' RPM', style: TextStyle(fontSize: 13, color: AppTheme.neonCyan, letterSpacing: 0)),
                    ]),
                    style: TextStyle(fontSize: compact ? 25 : 29, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                  ),
                  Text(
                    '${factor.toStringAsFixed(3)}× · ${samples > 0 ? 'medida em $samples escutas' : (engine.isHardwareSpeedCalibrated ? 'rotação conhecida' : 'calibrando...')}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _chip('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%', pct.abs() > 0.8 ? _amber : AppTheme.neonCyan),
                if (stdErr != null) ...[
                  const SizedBox(height: 4),
                  _chip('±${(stdErr * 100).toStringAsFixed(1)}%', AppTheme.neonCyan),
                ],
              ],
            ),
          ],
        ),
        _divider(compact),

        // Ajuste fino da rotação
        _subHead('Ajuste fino da rotação', '${_manualPitch >= 0 ? '+' : ''}${(_manualPitch * 100).toStringAsFixed(1)}%'),
        Row(
          children: [
            _stepButton('−0.1', () => _setPitch(_manualPitch - 0.001), compact),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: AppTheme.neonPurple,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: AppTheme.neonCyan,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                // o Slider reserva 48px por padrão; limitado para o painel caber sem rolagem
                child: SizedBox(
                  height: compact ? 28 : 32,
                  child: Slider(
                    value: _manualPitch,
                    min: -0.05,
                    max: 0.05,
                    divisions: 100,
                    onChanged: _setPitch,
                  ),
                ),
              ),
            ),
            _stepButton('+0.1', () => _setPitch(_manualPitch + 0.001), compact),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),
        Row(
          children: [
            Expanded(child: _pillButton(icon: Icons.restart_alt_rounded, label: 'Zerar', onTap: () => _setPitch(0.0), compact: compact)),
            const SizedBox(width: 8),
            Expanded(
              child: _pillButton(
                icon: telemetry.isPitchLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                label: telemetry.isPitchLocked ? 'Rotação travada' : 'Travar rotação',
                active: telemetry.isPitchLocked,
                onTap: engine.togglePitchLock,
                compact: compact,
              ),
            ),
          ],
        ),
        _divider(compact),

        // Sincronia da letra (nudge)
        _subHead('Sincronia da letra', 'se a letra adiantar ou atrasar', dimValue: true),
        Row(
          children: [
            Expanded(child: _nudgeButton('⏪  −0.5s', () => engine.nudgeSync(-0.5), compact)),
            SizedBox(
              width: 76,
              child: Column(
                children: [
                  const Text('ajuste', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  Text(
                    '${engine.lyricBiasSeconds >= 0 ? '+' : ''}${engine.lyricBiasSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(child: _nudgeButton('+0.5s  ⏩', () => engine.nudgeSync(0.5), compact)),
          ],
        ),
      ],
    );

    return WoodPanel(
      radius: 18,
      padding: EdgeInsets.all(compact ? 10 : 12),
      // O conteúdo cabe na tela; a rolagem interna só existe como proteção em telas muito baixas
      child: SingleChildScrollView(physics: const ClampingScrollPhysics(), child: content),
    );
  }

  Widget _divider(bool compact) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 5 : 8),
        child: Container(height: 1, color: AppTheme.carveLight.withValues(alpha: 0.6)),
      );

  Widget _subHead(String title, String value, {bool dimValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white54)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: dimValue ? 11 : 12, fontWeight: dimValue ? FontWeight.w500 : FontWeight.w800, color: dimValue ? Colors.white38 : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _stepButton(String label, VoidCallback onTap, bool compact) {
    return _woodTap(
      onTap: onTap,
      width: 46,
      height: compact ? 28 : 32,
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  Widget _pillButton({required IconData icon, required String label, required VoidCallback onTap, bool active = false, required bool compact}) {
    final color = active ? AppTheme.neonCyan : Colors.white;
    return _woodTap(
      onTap: onTap,
      height: compact ? 28 : 32,
      glow: active ? AppTheme.neonCyan : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _nudgeButton(String label, VoidCallback onTap, bool compact) {
    return _woodTap(
      onTap: onTap,
      height: compact ? 32 : 38,
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  /// Botão em relevo de madeira (chanfro invertido) com toque.
  Widget _woodTap({required VoidCallback onTap, required Widget child, double? width, required double height, Color? glow}) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: WoodPanel(
              raised: true,
              radius: 10,
              padding: EdgeInsets.zero,
              glow: glow,
              child: Center(child: child),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 4. AÇÃO PRINCIPAL ───
  Widget _buildMainAction(VinylTelemetry telemetry, bool compact) {
    final engine = widget.engine;
    final isListening = telemetry.isMicActive;
    final awaitingFlip = engine.isAwaitingSideFlip && !isListening;

    String hint;
    if (awaitingFlip) {
      hint = '${telemetry.sideEndLabel ?? 'Fim do lado'} · toque depois de virar o disco';
    } else if (isListening) {
      hint = 'Ouvindo o disco pelo microfone...';
    } else if (telemetry.countdownSeconds > 0 && engine.currentTrack != null) {
      hint = 'Sincronizado pelo microfone · próxima checagem em ${telemetry.countdownSeconds}s';
    } else {
      hint = telemetry.statusMessage;
    }

    final button = awaitingFlip
        ? FlipSideButton(wide: true, onPressed: () => engine.flipSide())
        : SizedBox(
            height: compact ? 50 : 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isListening ? Colors.redAccent : AppTheme.neonPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 6,
                shadowColor: (isListening ? Colors.redAccent : AppTheme.neonPurple).withValues(alpha: 0.6),
              ),
              onPressed: () => isListening ? engine.stop() : engine.startListening(),
              icon: Icon(isListening ? Icons.stop_rounded : Icons.mic_rounded, size: 24),
              label: Text(
                isListening ? 'OUVINDO... (TOQUE P/ PARAR)' : 'OUVIR / RESSINCRONIZAR',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.8),
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 6),
        Text(
          hint,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}
