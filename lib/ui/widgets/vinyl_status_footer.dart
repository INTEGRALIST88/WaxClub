import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/sync_state.dart';
import '../../models/track_info.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import 'wood_mic_button.dart';

/// Rodapé analógico de status exibindo velocidade mecânica, RPM e telemetria de calibração.
class VinylStatusFooter extends StatefulWidget {
  final VinylTelemetry telemetry;
  final TrackInfo? track;
  final Function(double)? onPitchAdjust;
  final Function(double)? onNudge;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;
  final VoidCallback? onListenAgain;

  /// Botão de ouvir (microfone cromado) no centro da barra.
  final bool isListening;
  final VoidCallback? onMicPressed;
  final double micSize;

  const VinylStatusFooter({
    super.key,
    required this.telemetry,
    this.track,
    this.onPitchAdjust,
    this.onNudge,
    this.onPlayPause,
    this.onStop,
    this.onListenAgain,
    this.isListening = false,
    this.onMicPressed,
    this.micSize = 60,
  });

  @override
  State<VinylStatusFooter> createState() => _VinylStatusFooterState();
}

class _VinylStatusFooterState extends State<VinylStatusFooter> {
  bool _showFineTuning = false;
  double _manualSliderValue = 0.0;

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
          colors: [Color(0xFF3A2618), Color(0xFF2E1E13)],
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
              // Linha fina acima: "Calibrating in Xs" ou a etapa especial, só quando houver
              if (_hasStatusInfo(telemetry))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Center(child: _buildStatusInfo(telemetry)),
                ),

              // Linha principal: [estado do microfone, play/pause, parar] · microfone cromado · [rotação]
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMicIcon(telemetry.isMicActive),
                        if (track != null || telemetry.status != CalibrationStatus.idle) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              telemetry.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                              color: AppTheme.cream,
                              size: 24,
                            ),
                            tooltip: telemetry.isPaused ? l10n.resume : l10n.pause,
                            onPressed: widget.onPlayPause,
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.surfaceLight,
                              padding: const EdgeInsets.all(5),
                              minimumSize: const Size(34, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 22),
                            tooltip: l10n.stopListening,
                            onPressed: widget.onStop,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.redAccent.withValues(alpha: 0.12),
                              padding: const EdgeInsets.all(5),
                              minimumSize: const Size(34, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ],
                    ),
                    ),
                  ),
                  if (widget.onMicPressed != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: WoodMicButton(
                        isListening: widget.isListening,
                        onPressed: widget.onMicPressed!,
                        size: widget.micSize,
                      ),
                    ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      // Badge de rotação do vinil (toque para abrir o ajuste fino)
                      child: InkWell(
                        onTap: () => setState(() => _showFineTuning = !_showFineTuning),
                        borderRadius: BorderRadius.circular(12),
                        child: _buildRotationBadge(pitchText),
                      ),
                    ),
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
                            activeTrackColor: AppTheme.orange,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: AppTheme.cream,
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
                      Text(
                        l10n.adjustTiming,
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
                          child: const Text('-1.0s', style: TextStyle(fontSize: 11, color: AppTheme.cream)),
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
                          child: const Text('-0.5s', style: TextStyle(fontSize: 11, color: AppTheme.cream)),
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
                          child: const Text('+0.5s', style: TextStyle(fontSize: 11, color: AppTheme.rust)),
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
                          child: const Text('+1.0s', style: TextStyle(fontSize: 11, color: AppTheme.rust)),
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

  /// Microfone inteiro (ouvindo) ou cortado (desligado).
  Widget _buildMicIcon(bool isMicActive) {
    return Tooltip(
      message: isMicActive ? l10n.microphoneListening : l10n.microphoneOff,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isMicActive ? AppTheme.orange.withValues(alpha: 0.18) : AppTheme.surfaceLight,
          border: Border.all(color: isMicActive ? AppTheme.orange : AppTheme.carveLight, width: 1.2),
        ),
        child: Icon(
          isMicActive ? Icons.mic : Icons.mic_off,
          size: 20,
          color: isMicActive ? AppTheme.orange : Colors.white38,
        ),
      ),
    );
  }

  bool _hasStatusInfo(VinylTelemetry t) =>
      t.countdownSeconds > 0 ||
      t.status == CalibrationStatus.paused ||
      t.status == CalibrationStatus.waitingEndOfSide ||
      t.status == CalibrationStatus.listeningNextTrack ||
      t.status == CalibrationStatus.confirmingPrediction;

  /// Só a contagem da calibração ("Calibrating in Xs"); sem ela, a etapa especial em andamento
  /// (pausado, fim do lado, próxima faixa, confirmando), quando houver.
  Widget _buildStatusInfo(VinylTelemetry telemetry) {
    if (telemetry.countdownSeconds > 0) {
      return Text(
        l10n.calibratingIn(telemetry.countdownSeconds),
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.cream),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    String? label;
    Color color = AppTheme.cream;
    switch (telemetry.status) {
      case CalibrationStatus.paused:
        label = l10n.statusPaused;
        color = Colors.amber;
      case CalibrationStatus.waitingEndOfSide:
        label = telemetry.sideEndLabel != null
            ? l10n.sideEndFlip(telemetry.sideEndLabel!.toUpperCase())
            : l10n.endOfSideFlip;
      case CalibrationStatus.listeningNextTrack:
        label = l10n.statusNextTrack;
        color = AppTheme.orange;
      case CalibrationStatus.confirmingPrediction:
        label = l10n.statusConfirming;
        color = Colors.white38;
      default:
        label = null;
    }
    if (label == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
          color: isCalibrated ? AppTheme.cream : Colors.white12,
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
                  color: pitchText.startsWith('+') ? AppTheme.cream : AppTheme.rust,
                ),
              ),
            ],
          ),
          Text(
            l10n.rpmValue(widget.telemetry.estimatedRpm33.toStringAsFixed(1)),
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
