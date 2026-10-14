import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ícone ⓘ cromado das curiosidades de um disco (My Collection), sem fundo. Ao abrir a tela, um reflexo
/// prateado passa pelo símbolo de um disco após o outro: o brilho do disco [index] começa [stepMs] depois
/// do anterior, pela animação [shine].
///
/// A duração é lida do controlador a cada quadro (não no momento em que o ícone foi montado): a lista
/// pode aparecer antes de a coleção carregar e mudar a duração da animação — antes, os ícones montados
/// cedo ficavam com a duração antiga e o brilho congelava no meio.
class CuriosityBadge extends StatelessWidget {
  final AnimationController shine;
  final int index;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  static const int stepMs = 220;
  static const int glowMs = 700;

  const CuriosityBadge({
    super.key,
    required this.shine,
    required this.index,
    required this.onTap,
    required this.tooltip,
    this.size = 36,
  });

  /// Quanto do brilho deste disco já passou (0 = não começou, 1 = terminou).
  static double progress(AnimationController shine, int index) {
    final total = shine.duration?.inMilliseconds ?? 0;
    if (total <= 0) return 1;
    final elapsed = shine.value * total;
    return ((elapsed - index * stepMs) / glowMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: size * 0.75,
        child: AnimatedBuilder(
          animation: shine,
          builder: (context, _) {
            final t = progress(shine, index);
            final glow = math.sin(math.pi * t); // 0 → 1 → 0
            // Cromo: faixas claras e escuras; o reflexo é uma faixa branca que atravessa o símbolo
            final band = -0.6 + 2.2 * t;
            // Só o símbolo, sem fundo: o brilho é o reflexo que atravessa o cromo
            return SizedBox(
              width: size,
              height: size,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF4F6F8),
                    const Color(0xFF9AA3AD),
                    if (glow > 0) Colors.white else const Color(0xFFDDE2E7),
                    const Color(0xFF6E7781),
                    const Color(0xFFCFD5DB),
                  ],
                  stops: [
                    0.0,
                    0.35,
                    glow > 0 ? band.clamp(0.36, 0.64) : 0.5,
                    0.72,
                    1.0,
                  ],
                ).createShader(rect),
                child: Icon(Icons.info_outline_rounded, size: size, color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}
