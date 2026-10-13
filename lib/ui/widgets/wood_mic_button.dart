import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botão de ouvir: só o microfone cromado (da arte do usuário), no centro da barra inferior.
/// Ouvindo, ganha um halo laranja pulsante atrás e o selo vermelho de parar.
class WoodMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onPressed;
  final double size;

  const WoodMicButton({super.key, required this.isListening, required this.onPressed, this.size = 60});

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
    final label = widget.isListening ? 'Stop listening (microphone off)' : 'Listen to the room';
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Halo: laranja pulsante ouvindo; sombra suave parado
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Container(
                    width: size * 0.78,
                    height: size * 0.78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isListening
                          ? AppTheme.orange.withValues(alpha: 0.22 + _pulse.value * 0.18)
                          : Colors.black.withValues(alpha: 0.18),
                      boxShadow: [
                        if (widget.isListening)
                          BoxShadow(
                            color: AppTheme.orange.withValues(alpha: 0.7),
                            blurRadius: 10 + _pulse.value * 14,
                            spreadRadius: 1 + _pulse.value * 3,
                          ),
                      ],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/mic_chrome.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.mic, color: AppTheme.cream, size: size * 0.6),
                ),
                if (widget.isListening)
                  Positioned(
                    right: 0,
                    top: 0,
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
