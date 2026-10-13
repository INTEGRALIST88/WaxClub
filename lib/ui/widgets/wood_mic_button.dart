import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botão de ouvir: o microfone de madeira (arte do usuário). Ouvindo, ganha um anel laranja
/// pulsante e o selo de parar; parado, uma sombra suave de peça entalhada.
class WoodMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;
  final double size;

  const WoodMicButton({super.key, required this.isListening, required this.onPressed, this.size = 84});

  @override
  State<WoodMicButton> createState() => _WoodMicButtonState();
}

class _WoodMicButtonState extends State<WoodMicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.isListening) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(WoodMicButton old) {
    super.didUpdateWidget(old);
    if (widget.isListening && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!widget.isListening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      button: true,
      label: widget.isListening ? 'Stop listening (microphone off)' : 'Listen to the room',
      child: Tooltip(
        message: widget.isListening ? 'Stop listening (microphone off)' : 'Listen to the room',
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final glow = widget.isListening ? 10.0 + _pulse.value * 16.0 : 0.0;
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.22),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 14, offset: const Offset(0, 6)),
                    if (widget.isListening)
                      BoxShadow(color: AppTheme.orange.withValues(alpha: 0.75), blurRadius: glow, spreadRadius: 2 + _pulse.value * 3),
                  ],
                ),
                child: child,
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/mic_button.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(color: AppTheme.wood, borderRadius: BorderRadius.circular(size * 0.22)),
                      child: Icon(Icons.mic, color: AppTheme.cream, size: size * 0.5),
                    ),
                  ),
                ),
                if (widget.isListening)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: size * 0.32,
                      height: size * 0.32,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 2),
                      ),
                      child: Icon(Icons.stop_rounded, color: Colors.white, size: size * 0.22),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
