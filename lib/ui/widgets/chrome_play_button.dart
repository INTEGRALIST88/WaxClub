import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Estado do botão cromado do Modo Manual.
enum ChromeButtonState {
  /// Pronto para começar: ▶.
  play,

  /// Tocando (ou esperando a agulha): ■ para parar.
  stop,

  /// Lado terminou: ▶ pulsando para começar o próximo lado depois de virar o disco.
  flip,
}

/// Botão cromado do Modo Manual, no lugar do microfone: ▶ para começar, ■ para parar.
class ChromePlayButton extends StatefulWidget {
  final ChromeButtonState state;
  final VoidCallback onPressed;
  final double size;
  final String tooltip;

  const ChromePlayButton({
    super.key,
    required this.state,
    required this.onPressed,
    required this.tooltip,
    this.size = 60,
  });

  @override
  State<ChromePlayButton> createState() => _ChromePlayButtonState();
}

class _ChromePlayButtonState extends State<ChromePlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    animationBehavior: AnimationBehavior.preserve,
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant ChromePlayButton old) {
    super.didUpdateWidget(old);
    _syncPulse();
  }

  void _syncPulse() {
    final active = widget.state != ChromeButtonState.play;
    if (active && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!active && _pulse.isAnimating) {
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
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_pulse.value);
              final glow = widget.state == ChromeButtonState.play ? 0.0 : 0.25 + 0.45 * t;
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    const BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
                    if (glow > 0) BoxShadow(color: AppTheme.orange.withValues(alpha: glow), blurRadius: 18, spreadRadius: 3),
                  ],
                ),
                child: CustomPaint(painter: _ChromePainter(widget.state)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChromePainter extends CustomPainter {
  final ChromeButtonState state;
  _ChromePainter(this.state);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Aro cromado
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F7F7), Color(0xFF8C8C8C), Color(0xFFE2E2E2), Color(0xFF5E5E5E)],
          stops: [0.0, 0.45, 0.7, 1.0],
        ).createShader(rect),
    );
    // Face escovada (anéis concêntricos sutis)
    final inner = r * 0.82;
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [Color(0xFFDADADA), Color(0xFF9E9E9E), Color(0xFFF2F2F2)],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );
    final brushed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var rr = inner * 0.2; rr < inner; rr += inner * 0.07) {
      canvas.drawCircle(c, rr, brushed);
    }
    // Reflexo
    canvas.drawCircle(
      c,
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.7,
          colors: [Colors.white.withValues(alpha: 0.55), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: inner)),
    );

    // Símbolo gravado (escuro, com leve relevo)
    final ink = Paint()..color = const Color(0xFF2B2B2B);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.5);
    Path symbol;
    if (state == ChromeButtonState.stop) {
      final s = inner * 0.62;
      symbol = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: s, height: s), Radius.circular(s * 0.14)));
    } else {
      final h = inner * 0.85;
      final w = h * math.sqrt(3) / 2;
      final left = c.dx - w * 0.38;
      symbol = Path()
        ..moveTo(left, c.dy - h / 2)
        ..lineTo(left + w, c.dy)
        ..lineTo(left, c.dy + h / 2)
        ..close();
    }
    canvas.drawPath(symbol.shift(const Offset(0, 1.2)), light);
    canvas.drawPath(symbol, ink);
  }

  @override
  bool shouldRepaint(covariant _ChromePainter old) => old.state != state;
}
