import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Veio de madeira desenhado proceduralmente (sem imagens): linhas onduladas quase horizontais,
/// com espessura e opacidade variando, como tábuas de madeira escura.
class WoodGrainPainter extends CustomPainter {
  final double intensity;
  final int seed;

  const WoodGrainPainter({this.intensity = 1.0, this.seed = 7});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint()..style = PaintingStyle.stroke;
    double y = -10;
    while (y < size.height + 10) {
      final spacing = 3.0 + rnd.nextDouble() * 7.0;
      y += spacing;
      final amp = 1.0 + rnd.nextDouble() * 4.0;
      final freq = 0.004 + rnd.nextDouble() * 0.01;
      final phase = rnd.nextDouble() * math.pi * 2;
      final light = rnd.nextBool();
      paint
        ..strokeWidth = 0.6 + rnd.nextDouble() * 1.6
        ..color = (light ? AppTheme.woodGrain : AppTheme.carveShadow)
            .withValues(alpha: (0.25 + rnd.nextDouble() * 0.45) * intensity);
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 8) {
        path.lineTo(x, y + math.sin(x * freq + phase) * amp);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WoodGrainPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.seed != seed;
}

/// Fundo de tela em madeira escura com veio e vinheta (entorno da letra).
class WoodBackground extends StatelessWidget {
  final Widget? child;

  const WoodBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A110B), AppTheme.background, Color(0xFF0C0805)],
        ),
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: const WoodGrainPainter(intensity: 0.9),
          child: DecoratedBox(
            // vinheta: escurece as bordas e mantém o centro (onde fica a letra) limpo
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [Color(0x00000000), Color(0x99000000)],
                stops: [0.55, 1.0],
              ),
            ),
            child: child ?? const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Painel de madeira entalhado: borda chanfrada (sombra em cima, luz embaixo) e veio sutil.
/// [raised] inverte o chanfro para botões/elementos em relevo.
class WoodPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool raised;
  final Color? fill;
  final Color? glow;

  const WoodPanel({
    super.key,
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(12),
    this.raised = false,
    this.fill,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    const edge = 1.6;
    final base = fill ?? (raised ? AppTheme.surfaceLight : AppTheme.surface);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: raised
              ? const [AppTheme.carveLight, AppTheme.carveShadow]
              : const [AppTheme.carveShadow, AppTheme.carveLight],
        ),
        boxShadow: [
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.35), blurRadius: 16),
          if (raised) const BoxShadow(color: Color(0xAA000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(edge),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - edge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: raised
                  ? [Color.lerp(base, AppTheme.carveLight, 0.25)!, base]
                  : [Color.lerp(base, AppTheme.carveShadow, 0.35)!, base],
            ),
          ),
          child: CustomPaint(
            painter: WoodGrainPainter(intensity: raised ? 0.35 : 0.5, seed: radius.round()),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
