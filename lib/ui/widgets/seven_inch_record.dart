import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Compacto de 7" em vinil colorido (um plugin na jukebox): sulcos, brilho, selo creme com o código
/// de seleção e o furo grande dos discos de 45 rpm. [spinning] gira como no prato; [scratched] = com erro.
class SevenInchRecord extends StatefulWidget {
  final Color color;
  final String code;
  final double size;
  final bool spinning;
  final bool glow;
  final bool dimmed;
  final bool scratched;

  const SevenInchRecord({
    super.key,
    required this.color,
    required this.code,
    this.size = 84,
    this.spinning = false,
    this.glow = false,
    this.dimmed = false,
    this.scratched = false,
  });

  @override
  State<SevenInchRecord> createState() => _SevenInchRecordState();
}

class _SevenInchRecordState extends State<SevenInchRecord> with SingleTickerProviderStateMixin {
  // 45 rpm = 1,333 s por volta
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1333));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant SevenInchRecord old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_spin.isAnimating) _spin.repeat();
    if (!widget.spinning && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = CustomPaint(
      size: Size.square(widget.size),
      painter: _RecordPainter(color: widget.color, code: widget.code, scratched: widget.scratched),
    );
    Widget child = widget.spinning
        ? RotationTransition(turns: _spin, child: record)
        : record;
    if (widget.dimmed) child = Opacity(opacity: 0.45, child: child);
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: widget.size * 0.18, offset: Offset(0, widget.size * 0.07)),
          if (widget.glow) BoxShadow(color: widget.color.withValues(alpha: 0.75), blurRadius: widget.size * 0.3, spreadRadius: 2),
        ],
      ),
      child: child,
    );
  }
}

class _RecordPainter extends CustomPainter {
  final Color color;
  final String code;
  final bool scratched;

  _RecordPainter({required this.color, required this.code, required this.scratched});

  static const Color _label = Color(0xFFF3EAD6);
  static const Color _ink = Color(0xFF2B2231);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final vinyl = scratched ? Color.lerp(color, Colors.grey, 0.6)! : color;

    // Vinil colorido com um leve degradê
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.lerp(vinyl, Colors.white, 0.12)!, vinyl, Color.lerp(vinyl, Colors.black, 0.35)!],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Sulcos
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.012)
      ..color = Colors.black.withValues(alpha: 0.22);
    for (var gr = r * 0.40; gr < r * 0.96; gr += r * 0.045) {
      canvas.drawCircle(c, gr, groove);
    }
    // Brilho (reflexo de luz)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.36, -0.44),
          radius: 0.6,
          colors: [Colors.white.withValues(alpha: 0.42), Colors.white.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r - 0.5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12));

    // Selo creme e furo grande de 45 rpm
    canvas.drawCircle(c, r * 0.40, Paint()..color = _label);
    canvas.drawCircle(c, r * 0.11, Paint()..color = const Color(0xFF0E0B12));

    // Código de seleção no selo
    final tp = TextPainter(
      text: TextSpan(
        text: code,
        style: TextStyle(color: _ink, fontSize: r * 0.17, fontWeight: FontWeight.w900, fontFamily: 'monospace', height: 1), // l10n-ignore
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Código na parte de cima do selo, entre a borda do selo e o furo
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - r * 0.135 - tp.height));

    // Disco riscado (plugin com erro)
    if (scratched) {
      final scratch = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = math.max(1, r * 0.025);
      canvas.drawLine(c + Offset(-r * 0.8, r * 0.35), c + Offset(r * 0.75, -r * 0.45), scratch);
      canvas.drawLine(c + Offset(-r * 0.5, -r * 0.7), c + Offset(r * 0.2, r * 0.85), scratch..color = Colors.white.withValues(alpha: 0.55));
    }
  }

  @override
  bool shouldRepaint(covariant _RecordPainter old) => old.color != color || old.code != code || old.scratched != scratched;
}
