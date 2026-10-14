import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../engine/waxclub_engine.dart';
import '../../models/sync_state.dart';
import '../../models/track_info.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import 'flip_side_button.dart';

/// Painel de controle do celular durante a transmissão para a TV (tela travada em retrato).
///
/// Música, banda, disco e "a seguir" já aparecem na barra de cima; aqui, sem rolagem:
///  1. TV conectada (faixa fina com "Desconectar");
///  2. barra de minutagem;
///  3. **Time sync** em destaque: 5 colunas — duas linhas antes, a cantada no centro e duas depois —, tocáveis;
///     tocar na linha cantada acerta celular e TV (sem letra, as colunas deslocam o tempo: −2 s … +2 s) (no Modo Manual, é a calibração; a região pulsa prateada ao
///     começar a transmissão e enquanto o começo da faixa for incerto);
///  4. rotação medida e ajuste fino da rotação;
///  5. ação principal no rodapé: Ouvir/Ressincronizar ou "Vire o disco"; no Modo Manual, ▶/parar e
///     "tocar o lado B" depois de virar (o Modo Manual nunca usa o reconhecimento do Shazam).
/// Em telas baixas (ex.: 360×740) entra em modo compacto, com as mesmas funções.
class VinylControlCockpit extends StatefulWidget {
  final WaxClubEngine engine;
  final VoidCallback onOpenCastDialog;
  final VoidCallback onDisconnectCast;

  /// ▶ do Modo Manual (parar, tocar o lado seguinte depois de virar ou escolher onde a agulha começa).
  final VoidCallback? onManualPressed;

  const VinylControlCockpit({
    super.key,
    required this.engine,
    required this.onOpenCastDialog,
    required this.onDisconnectCast,
    this.onManualPressed,
  });

  @override
  State<VinylControlCockpit> createState() => _VinylControlCockpitState();
}

class _VinylControlCockpitState extends State<VinylControlCockpit> with TickerProviderStateMixin {
  late final AnimationController _discSpin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  /// Brilho prateado da sincronia da letra (Modo Manual).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  DateTime? _pulseUntil;
  Timer? _pulseTimer;
  bool _wasManual = false;

  double _manualPitch = 0.0;

  static const Color _amber = Color(0xFFFFB300);
  static const Color _silver = Color(0xFFE8ECF0);
  static const Duration _pulseOnStart = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _wasManual = widget.engine.isManualMode;
    if (_wasManual) _pulseFor(_pulseOnStart);
    _syncPulse();
  }

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
    final manual = widget.engine.isManualMode;
    if (manual && !_wasManual) _pulseFor(_pulseOnStart);
    _wasManual = manual;
    _syncPulse();
  }

  void _pulseFor(Duration d) {
    _pulseUntil = DateTime.now().add(d);
    _pulseTimer?.cancel();
    _pulseTimer = Timer(d, () {
      if (mounted) setState(_syncPulse);
    });
  }

  /// Pulsa no Modo Manual: ao começar a transmissão (alguns segundos) e enquanto o começo da faixa
  /// for incerto (a música já tocava no ▶: falta calibrar tocando na linha).
  bool get _shouldPulse {
    final engine = widget.engine;
    if (!engine.isManualMode || engine.lyrics.isEmpty) return false;
    final until = _pulseUntil;
    return engine.manualOnsetUncertain || (until != null && DateTime.now().isBefore(until));
  }

  void _syncPulse() {
    if (_shouldPulse) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating || _pulse.value > 0) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _pulse.dispose();
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
            _buildTimeBar(engine.currentTrack, telemetry, compact),
            SizedBox(height: gap),
            Expanded(child: _buildLyricSync(compact)),
            SizedBox(height: gap),
            _buildSpeed(telemetry, compact),
            SizedBox(height: gap),
            _buildMainAction(telemetry, compact),
          ],
        ),
      );
    });
  }

  // ─── 1. TV CONECTADA ───
  Widget _buildTvStrip(bool compact) {
    final cast = widget.engine.castService;
    final reconnecting = cast.isReconnecting;
    return WoodPanel(
      radius: 14,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 8),
      glow: AppTheme.cream,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reconnecting ? _amber : AppTheme.cream,
              boxShadow: [BoxShadow(color: (reconnecting ? _amber : AppTheme.cream).withValues(alpha: 0.8), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cast.clientDeviceName ?? cast.connectedDevice?.name ?? l10n.tv,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  reconnecting ? l10n.reconnectingToTv : l10n.lyricsOnTv,
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
            child: Text(l10n.disconnect, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ─── 2. MINUTAGEM ───
  Widget _buildTimeBar(TrackInfo? track, VinylTelemetry telemetry, bool compact) {
    final duration = (track?.durationMs != null && track!.durationMs! > 0)
        ? track.durationMs! / 1000.0
        : (telemetry.trackDurationSeconds ?? 0.0);
    final position = duration > 0
        ? telemetry.currentPositionSeconds.clamp(0.0, duration).toDouble()
        : telemetry.currentPositionSeconds;
    const timeStyle = TextStyle(fontSize: 11, color: Colors.white54, fontFeatures: [FontFeature.tabularFigures()]);

    return WoodPanel(
      radius: 14,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 4 : 6),
      child: Row(
        children: [
          Text(_fmt(position), style: timeStyle),
          // Barra de tempo (arrastar ajusta a posição da letra)
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: AppTheme.cream,
                inactiveTrackColor: Colors.white12,
                thumbColor: AppTheme.orange,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: SizedBox(
                height: 24,
                child: Slider(
                  value: duration > 0 ? position : 0.0,
                  min: 0.0,
                  max: duration > 0 ? duration : 1.0,
                  onChanged: duration > 0 ? (v) => widget.engine.seekTo(v) : null,
                ),
              ),
            ),
          ),
          Text(duration > 0 ? _fmt(duration) : '--:--', style: timeStyle), // l10n-ignore
        ],
      ),
    );
  }

  // ─── 3. TIME SYNC (sincronia da letra / do tempo) ───
  Widget _buildLyricSync(bool compact) {
    final engine = widget.engine;
    final hasLyrics = engine.lyrics.isNotEmpty;
    final panel = WoodPanel(
      radius: 18,
      padding: EdgeInsets.fromLTRB(10, compact ? 8 : 10, 10, compact ? 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _subHead(
            l10n.lyricsSync,
            hasLyrics ? l10n.lyricsTapToCalibrate : l10n.timeSyncTapHint,
            accentValue: hasLyrics,
          ),
          Expanded(child: hasLyrics ? _tapLines(compact) : _nudgeFallback(compact)),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: _pulse,
      child: panel,
      builder: (context, child) {
        final v = Curves.easeInOut.transform(_pulse.value);
        if (v <= 0) return child!;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _silver.withValues(alpha: 0.35 + 0.55 * v), width: 1.5),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _silver.withValues(alpha: 0.55 * v), blurRadius: 22 * v, spreadRadius: 1 + 2 * v)],
            ),
            child: child,
          ),
        );
      },
    );
  }

  // 5 colunas: a do centro (a linha que está tocando) é a mais larga
  static const List<int> _colFlex = [3, 4, 6, 4, 3];

  /// Cinco colunas lado a lado: duas linhas antes, a que está sendo cantada no centro e duas depois.
  /// Tocar na coluna da linha cantada acerta celular e TV de uma vez.
  Widget _tapLines(bool compact) {
    final engine = widget.engine;
    final lines = engine.lyrics;
    final active = engine.activeLineIndex.clamp(0, lines.length - 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var k = 0; k < 5; k++)
          () {
            final i = active - 2 + k;
            final ok = i >= 0 && i < lines.length && lines[i].text.trim().isNotEmpty;
            return _syncColumn(
              flex: _colFlex[k],
              distance: (k - 2).abs(),
              compact: compact,
              text: ok ? lines[i].text : '',
              onTap: ok
                  ? () {
                      engine.syncToLine(lines[i].timestamp.inMilliseconds / 1000.0);
                      if (_pulseUntil != null) setState(() => _pulseUntil = null);
                    }
                  : null,
            );
          }(),
      ],
    );
  }

  /// Sem letra (sem o plugin ou faixa instrumental): as mesmas colunas acertam o tempo
  /// (−2 s, −0.5 s, posição atual, +0.5 s, +2 s).
  Widget _nudgeFallback(bool compact) {
    final engine = widget.engine;
    final bias = engine.lyricBiasSeconds;
    const steps = [-2.0, -0.5, 0.0, 0.5, 2.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var k = 0; k < 5; k++)
          k == 2
              ? _syncColumn(
                  flex: _colFlex[k],
                  distance: 0,
                  compact: compact,
                  text: '${_fmt(engine.telemetry.currentPositionSeconds)}\n${bias >= 0 ? '+' : ''}${bias.toStringAsFixed(1)}s', // l10n-ignore
                  onTap: null,
                )
              : _syncColumn(
                  flex: _colFlex[k],
                  distance: 1,
                  compact: compact,
                  text: '${steps[k] > 0 ? '+' : '−'}${steps[k].abs() == 0.5 ? '0.5' : '2'}s', // l10n-ignore
                  onTap: () => engine.nudgeSync(steps[k]),
                ),
      ],
    );
  }

  /// Uma coluna tocável do Time sync; [distance] = 0 no centro (destaque), 1 e 2 para os lados.
  Widget _syncColumn({
    required int flex,
    required int distance,
    required bool compact,
    required String text,
    required VoidCallback? onTap,
  }) {
    final current = distance == 0;
    final fontSize = current ? (compact ? 16.0 : 18.0) : (distance == 1 ? (compact ? 12.5 : 13.5) : (compact ? 11.5 : 12.5));
    final color = current ? AppTheme.cream : (distance == 1 ? Colors.white70 : Colors.white54);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: current ? AppTheme.orange.withValues(alpha: 0.24) : Colors.black.withValues(alpha: text.isEmpty ? 0.08 : 0.2),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: LayoutBuilder(builder: (context, c) {
              // A palavra mais larga cabe inteira na coluna (sem quebrar no meio): reduz a fonte se preciso
              var size = fontSize;
              final room = c.maxWidth - 6;
              var widest = 0.0;
              for (final word in text.split(RegExp(r'\s+'))) {
                if (word.isEmpty) continue;
                final painter = TextPainter(
                  text: TextSpan(
                    text: word,
                    style: DefaultTextStyle.of(context).style.merge(
                          TextStyle(fontSize: size, fontWeight: current ? FontWeight.w800 : FontWeight.w600, height: 1.18),
                        ),
                  ),
                  textDirection: TextDirection.ltr,
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                if (painter.width > widest) widest = painter.width;
                painter.dispose();
              }
              if (widest > room) size = (size * room / widest * 0.96).clamp(7.5, fontSize);
              final lineHeight = size * 1.18;
              final maxLines = ((c.maxHeight - 12) / lineHeight).floor().clamp(1, 20);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Center(
                  child: Text(
                    text,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                      fontSize: size,
                      height: 1.18,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─── 4. ROTAÇÃO ───
  Widget _buildSpeed(VinylTelemetry telemetry, bool compact) {
    final engine = widget.engine;
    final estimate = engine.currentSpeedEstimate;
    final factor = telemetry.speedFactor;
    final pct = (factor - 1.0) * 100.0;
    final stdErr = estimate?.standardError;
    final samples = estimate?.samples ?? 0;
    final rpm = 33.3333 * factor;

    return WoodPanel(
      radius: 18,
      padding: EdgeInsets.all(compact ? 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rotação medida
          Row(
            children: [
              RotationTransition(
                turns: _discSpin,
                child: Container(
                  width: compact ? 34 : 40,
                  height: compact ? 34 : 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF131016),
                    border: Border.all(color: AppTheme.orange.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.cream),
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
                        TextSpan(text: l10n.rpmSuffix, style: const TextStyle(fontSize: 13, color: AppTheme.cream, letterSpacing: 0)),
                      ]),
                      style: TextStyle(fontSize: compact ? 22 : 25, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                    ),
                    Text(
                      '${factor.toStringAsFixed(3)}× · ${samples > 0 ? l10n.measuredOverListens(samples) : (engine.isHardwareSpeedCalibrated ? l10n.knownSpeed : l10n.calibrating)}',
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
                  _chip('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%', pct.abs() > 0.8 ? _amber : AppTheme.cream),
                  if (stdErr != null) ...[
                    const SizedBox(height: 4),
                    _chip('±${(stdErr * 100).toStringAsFixed(1)}%', AppTheme.cream),
                  ],
                ],
              ),
            ],
          ),
          _divider(compact),

          // Ajuste fino da rotação
          _subHead(l10n.fineSpeedAdjustment, '${_manualPitch >= 0 ? '+' : ''}${(_manualPitch * 100).toStringAsFixed(1)}%'),
          Row(
            children: [
              _stepButton('−0.1', () => _setPitch(_manualPitch - 0.001), compact),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: AppTheme.orange,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: AppTheme.cream,
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
              Expanded(child: _pillButton(icon: Icons.restart_alt_rounded, label: l10n.reset, onTap: () => _setPitch(0.0), compact: compact)),
              const SizedBox(width: 8),
              Expanded(
                child: _pillButton(
                  icon: telemetry.isPitchLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  label: telemetry.isPitchLocked ? l10n.speedLocked : l10n.lockSpeed,
                  active: telemetry.isPitchLocked,
                  onTap: engine.togglePitchLock,
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider(bool compact) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 5 : 7),
        child: Container(height: 1, color: AppTheme.carveLight.withValues(alpha: 0.6)),
      );

  Widget _subHead(String title, String value, {bool accentValue = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white54)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: accentValue ? 11.5 : 12,
                fontWeight: FontWeight.w800,
                color: accentValue ? AppTheme.cream : Colors.white,
              ),
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
    final color = active ? AppTheme.cream : Colors.white;
    return _woodTap(
      onTap: onTap,
      height: compact ? 28 : 32,
      glow: active ? AppTheme.cream : null,
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

  // ─── 5. AÇÃO PRINCIPAL ───
  Widget _buildMainAction(VinylTelemetry telemetry, bool compact) {
    final engine = widget.engine;
    if (engine.isManualMode && widget.onManualPressed != null) return _buildManualAction(telemetry, compact);
    final isListening = telemetry.isMicActive;
    final awaitingFlip = engine.isAwaitingSideFlip && !isListening;

    String hint;
    if (awaitingFlip) {
      hint = l10n.tapAfterFlipping(telemetry.sideEndLabel ?? l10n.endOfSide);
    } else if (isListening) {
      hint = l10n.listeningToRecord;
    } else if (telemetry.countdownSeconds > 0 && engine.currentTrack != null) {
      hint = l10n.inSyncNextCheck(telemetry.countdownSeconds);
    } else {
      hint = telemetry.statusMessage;
    }

    final button = awaitingFlip
        ? FlipSideButton(wide: true, onPressed: () => engine.flipSide())
        : _actionButton(
            compact: compact,
            color: isListening ? Colors.redAccent : AppTheme.orange,
            icon: isListening ? Icons.stop_rounded : Icons.mic_rounded,
            label: isListening ? l10n.listeningTapToStop : l10n.listenResync,
            onPressed: () => isListening ? engine.stop() : engine.startListening(),
          );
    return _actionWithHint(button, hint);
  }

  /// Modo Manual: ▶ (escolher a faixa), parar, ou "virou? tocar o lado B" no fim do lado. O microfone
  /// só mede o volume (começo da música e sulco entre faixas); o reconhecimento do Shazam não entra.
  Widget _buildManualAction(VinylTelemetry telemetry, bool compact) {
    final engine = widget.engine;
    final pending = engine.manualPendingIndex;
    final Widget button;
    if (!engine.isManualPlaying && pending != null) {
      final tracks = engine.manualRecordTracklist;
      final side = pending < tracks.length ? (tracks[pending].side ?? '') : '';
      button = FlipSideButton(wide: true, label: l10n.manualPlaySide(side.toUpperCase()), onPressed: widget.onManualPressed!);
    } else if (engine.isManualPlaying) {
      button = _actionButton(
        compact: compact,
        color: AppTheme.surfaceLight,
        icon: Icons.stop_rounded,
        label: l10n.manualStopButton,
        onPressed: widget.onManualPressed!,
      );
    } else {
      button = _actionButton(
        compact: compact,
        color: AppTheme.orange,
        icon: Icons.play_arrow_rounded,
        label: l10n.manualPlayButton,
        onPressed: widget.onManualPressed!,
      );
    }
    return _actionWithHint(button, telemetry.statusMessage, mic: telemetry.isMicActive);
  }

  Widget _actionButton({
    required bool compact,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: compact ? 50 : 56,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 6,
          shadowColor: color.withValues(alpha: 0.6),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      ),
    );
  }

  Widget _actionWithHint(Widget button, String hint, {bool mic = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mic) ...[
              const Icon(Icons.graphic_eq_rounded, size: 13, color: AppTheme.orange),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                hint,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
