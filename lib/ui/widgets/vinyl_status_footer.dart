import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/sync_state.dart';
import '../../models/track_info.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';

/// Rodapé analógico de status exibindo velocidade mecânica, RPM e telemetria de calibração.
class VinylStatusFooter extends StatefulWidget {
  final VinylTelemetry telemetry;
  final TrackInfo? track;
  final Function(double)? onPitchAdjust;
  final Function(double)? onNudge;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;
  final VoidCallback? onListenAgain;

  const VinylStatusFooter({
    super.key,
    required this.telemetry,
    this.track,
    this.onPitchAdjust,
    this.onNudge,
    this.onPlayPause,
    this.onStop,
    this.onListenAgain,
  });

  @override
  State<VinylStatusFooter> createState() => _VinylStatusFooterState();
}

class _VinylStatusFooterState extends State<VinylStatusFooter>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _showFineTuning = false;
  double _manualSliderValue = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // ~33 RPM
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant VinylStatusFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se estiver pausado ou sem música, para a rotação
    if (widget.telemetry.isPaused || widget.track == null) {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    } else {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
      final speed = widget.telemetry.speedFactor;
      if (speed > 0.1) {
        final newDuration = Duration(milliseconds: (1800 / speed).round());
        if (_rotationController.duration != newDuration) {
          _rotationController.duration = newDuration;
        }
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.telemetry;
    final track = widget.track;

    final pitchDisplay = telemetry.pitchPercent;
    final pitchSign = pitchDisplay >= 0 ? '+' : '';
    final pitchText = '$pitchSign${pitchDisplay.toStringAsFixed(1)}%';

    // Painel de nogueira com friso entalhado no topo (sombra + luz) e veio da madeira
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF241810), AppTheme.surface],
        ),
        border: Border(
          top: BorderSide(color: AppTheme.carveLight, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.carveShadow,
            blurRadius: 0,
            spreadRadius: 1.5,
            offset: Offset(0, -1.5),
          ),
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: const WoodGrainPainter(intensity: 0.45, seed: 21),
        child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Linha 1: Indicador de Privacidade do Microfone
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMicPrivacyIndicator(telemetry.isMicActive),
                          const SizedBox(width: 6),
                          Flexible(
                            child: _buildMicDeviceBadge(telemetry.activeMicrophoneName),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (telemetry.status == CalibrationStatus.paused)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'PAUSED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    if (telemetry.status == CalibrationStatus.waitingEndOfSide)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.neonCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.neonCyan.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          telemetry.sideEndLabel != null
                              ? '🔄 ${telemetry.sideEndLabel!.toUpperCase()} — FLIP THE RECORD'
                              : '🔄 END OF SIDE — FLIP THE RECORD',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonCyan,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (telemetry.status == CalibrationStatus.listeningNextTrack)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.neonPurple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.neonPurple.withOpacity(0.4)),
                        ),
                        child: const Text(
                          '🎵 NEXT TRACK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonPurple,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (telemetry.status == CalibrationStatus.confirmingPrediction)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: const Text(
                          '⟳ confirming...',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: Colors.white38,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Linha 2: Barra de telemetria principal + Controles
              Row(
                children: [
                  // Ícone de disco de vinil giratório
                  _buildSpinningVinyl(),
                  const SizedBox(width: 12),

                  // Status e telemetria da vitrola (sem nome da música e sem nome da banda)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          telemetry.statusMessage,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (telemetry.countdownSeconds > 0)
                          Text(
                            'Calibrating in ${telemetry.countdownSeconds}s',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.neonCyan,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text(
                            telemetry.isMicActive
                                ? 'Compensating turntable speed'
                                : (telemetry.status == CalibrationStatus.calibrated
                                    ? 'Speed calibrated'
                                    : 'Waiting for turntable audio'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textInactive,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Barra de Ações Rápidas (Play/Pause, Stop)
                  if (track != null || telemetry.status != CalibrationStatus.idle) ...[
                    // Botão Play / Pause
                    IconButton(
                      icon: Icon(
                        telemetry.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: AppTheme.neonCyan,
                        size: 26,
                      ),
                      tooltip: telemetry.isPaused ? 'Continuar' : 'Pausar',
                      onPressed: widget.onPlayPause,
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Botão Parar / Desconectar
                    IconButton(
                      icon: const Icon(
                        Icons.stop_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                      tooltip: 'Stop listening',
                      onPressed: widget.onStop,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Badge de taxa de rotação do vinil (toque para abrir ajuste fino)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showFineTuning = !_showFineTuning;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildRotationBadge(pitchText),
                  ),
                ],
              ),

              // Controle deslizante de Pitch manual (+/- 5%) e Ajuste de Sincronismo
              if (_showFineTuning) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Text(
                        '-5%',
                        style: TextStyle(fontSize: 10, color: AppTheme.textInactive),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppTheme.neonPurple,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: AppTheme.neonCyan,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            trackHeight: 2,
                          ),
                          child: Slider(
                            value: _manualSliderValue,
                            min: -0.05,
                            max: 0.05,
                            divisions: 20,
                            onChanged: (val) {
                              setState(() {
                                _manualSliderValue = val;
                              });
                              widget.onPitchAdjust?.call(val);
                            },
                          ),
                        ),
                      ),
                      const Text(
                        '+5%',
                        style: TextStyle(fontSize: 10, color: AppTheme.textInactive),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Adjust timing:',
                        style: TextStyle(fontSize: 11, color: AppTheme.textInactive),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => widget.onNudge?.call(-1.0),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.carveLight),
                          ),
                          child: const Text('-1.0s', style: TextStyle(fontSize: 11, color: AppTheme.neonCyan)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => widget.onNudge?.call(-0.5),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.carveLight),
                          ),
                          child: const Text('-0.5s', style: TextStyle(fontSize: 11, color: AppTheme.neonCyan)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => widget.onNudge?.call(0.5),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.carveLight),
                          ),
                          child: const Text('+0.5s', style: TextStyle(fontSize: 11, color: AppTheme.neonPink)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => widget.onNudge?.call(1.0),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.carveLight),
                          ),
                          child: const Text('+1.0s', style: TextStyle(fontSize: 11, color: AppTheme.neonPink)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildMicPrivacyIndicator(bool isMicActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMicActive ? Colors.redAccent.withOpacity(0.15) : Colors.greenAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMicActive ? Colors.redAccent : Colors.greenAccent.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMicActive ? Colors.redAccent : Colors.greenAccent,
              boxShadow: [
                BoxShadow(
                  color: (isMicActive ? Colors.redAccent : Colors.greenAccent).withOpacity(0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isMicActive ? 'MICROPHONE LISTENING' : 'MICROPHONE OFF',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isMicActive ? Colors.redAccent : Colors.greenAccent,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicDeviceBadge(String micName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white24,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.mic_none,
            size: 11,
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              micName,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinningVinyl() {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * math.pi,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: AppTheme.neonPurple.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonPurple.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ranhuras do vinil
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x33FFFFFF), width: 1),
                  ),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x22FFFFFF), width: 1),
                  ),
                ),
                // Selo central
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.neonCyan,
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRotationBadge(String pitchText) {
    final speed = widget.telemetry.speedFactor;
    final isCalibrated = widget.telemetry.status == CalibrationStatus.calibrated;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCalibrated ? AppTheme.surfaceLight : Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCalibrated ? AppTheme.neonCyan : Colors.white12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${speed.toStringAsFixed(3)}x',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                pitchText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pitchText.startsWith('+') ? AppTheme.neonCyan : AppTheme.neonPink,
                ),
              ),
            ],
          ),
          Text(
            '${widget.telemetry.estimatedRpm33.toStringAsFixed(1)} RPM',
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textInactive,
            ),
          ),
        ],
      ),
    );
  }
}
