import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ícone ⓘ das curiosidades de um disco (My Collection). Ao abrir a tela, brilha prateado um disco
/// após o outro: o brilho do disco [index] começa [stepMs] depois do anterior, pela animação [shine].
class CuriosityBadge extends StatelessWidget {
  final Animation<double> shine;
  final Duration shineTotal;
  final int index;
  final VoidCallback onTap;
  final String tooltip;

  static const int stepMs = 220;
  static const int glowMs = 700;

  const CuriosityBadge({
    super.key,
    required this.shine,
    required this.shineTotal,
    required this.index,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: AnimatedBuilder(
          animation: shine,
          builder: (context, _) {
            final elapsed = shine.value * shineTotal.inMilliseconds;
            final t = ((elapsed - index * stepMs) / glowMs).clamp(0.0, 1.0);
            final glow = math.sin(math.pi * t); // 0 → 1 → 0
            const silverDark = Color(0xFF8E959E);
            const silverLight = Color(0xFFF4F6F8);
            return Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(const Color(0xFF3A3F45), silverLight, glow)!,
                    Color.lerp(const Color(0xFF24282C), silverDark, glow)!,
                  ],
                ),
                border: Border.all(color: Color.lerp(silverDark, Colors.white, glow)!, width: 1.6),
                boxShadow: [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.65 * glow), blurRadius: 14 * glow, spreadRadius: 1.5 * glow),
                ],
              ),
              child: Text(
                'i', // l10n-ignore
                style: TextStyle(
                  fontFamily: 'serif', // l10n-ignore
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  height: 1.0,
                  color: Color.lerp(const Color(0xFFD5DAE0), const Color(0xFF2B2F34), glow),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
