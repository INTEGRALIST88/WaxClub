import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ícone ⓘ de madeira das curiosidades de um disco (My Collection). Ao abrir a tela, brilha prateado
/// um disco após o outro: o brilho do disco [index] começa [stepMs] depois do anterior, pela animação
/// [shine] (um reflexo prateado passa por cima da madeira e o contorno acende).
class CuriosityBadge extends StatelessWidget {
  final Animation<double> shine;
  final Duration shineTotal;
  final int index;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  static const int stepMs = 220;
  static const int glowMs = 700;

  const CuriosityBadge({
    super.key,
    required this.shine,
    required this.shineTotal,
    required this.index,
    required this.onTap,
    required this.tooltip,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: size * 0.75,
        child: AnimatedBuilder(
          animation: shine,
          builder: (context, child) {
            final elapsed = shine.value * shineTotal.inMilliseconds;
            final t = ((elapsed - index * stepMs) / glowMs).clamp(0.0, 1.0);
            final glow = math.sin(math.pi * t); // 0 → 1 → 0
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFFE8ECF0).withValues(alpha: 0.75 * glow), blurRadius: 16 * glow, spreadRadius: 2 * glow),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  // reflexo prateado que atravessa o ícone em diagonal
                  if (glow > 0)
                    IgnorePointer(
                      child: ClipOval(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1.6 + 3.2 * t, -1),
                              end: Alignment(-0.6 + 3.2 * t, 1),
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                const Color(0xFFF4F6F8).withValues(alpha: 0.75 * glow),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          child: Image.asset('assets/images/btn_info.png', width: size, height: size, filterQuality: FilterQuality.medium),
        ),
      ),
    );
  }
}
