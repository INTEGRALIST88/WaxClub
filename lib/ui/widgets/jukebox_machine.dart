import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Um disco (plugin instalado) na pilha da jukebox.
class JukeboxDisc {
  final String code;
  final Color color;

  /// Ligado ("no prato"): o disco acende.
  final bool active;

  /// Fora do filtro de categoria escolhido: apagado.
  final bool dimmed;

  const JukeboxDisc({required this.code, required this.color, this.active = false, this.dimmed = false});
}

/// Vitrine da jukebox: à esquerda a pilha de discos vista de lado (um por plugin instalado, na cor da
/// categoria, com a etiqueta do código) e o prato girando no alto; à direita o mecanismo — trilho cromado,
/// carrinho com o braço que vai buscar o disco escolhido, engrenagens e o medidor de neon dos ligados.
class JukeboxMachine extends StatefulWidget {
  final List<JukeboxDisc> discs;

  /// Disco escolhido (índice em [discs]); o braço vai até ele e o puxa um pouco para fora.
  final int? selected;
  final ValueChanged<int> onTapDisc;

  const JukeboxMachine({super.key, required this.discs, required this.onTapDisc, this.selected});

  @override
  State<JukeboxMachine> createState() => _JukeboxMachineState();
}

class _JukeboxMachineState extends State<JukeboxMachine> with TickerProviderStateMixin {
  /// Giro contínuo do prato, das engrenagens e do pisca dos LEDs.
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  /// Viagem do braço até o disco escolhido.
  late final AnimationController _arm = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  double _from = -1; // -1 = estacionado no prato
  double _to = -1;

  @override
  void initState() {
    super.initState();
    _to = _from = (widget.selected ?? -1).toDouble();
    _arm.value = 1;
  }

  @override
  void didUpdateWidget(covariant JukeboxMachine old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _from = _armIndex;
      _to = (widget.selected ?? -1).toDouble();
      _arm.forward(from: 0);
    }
  }

  double get _armIndex => _from + (_to - _from) * Curves.easeInOutCubic.transform(_arm.value);

  @override
  void dispose() {
    _spin.dispose();
    _arm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final i = _JukeboxGeometry(size, widget.discs.length).discAt(d.localPosition);
          if (i != null) widget.onTapDisc(i);
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _arm]),
          builder: (context, _) => CustomPaint(
            size: size,
            painter: _JukeboxPainter(
              discs: widget.discs,
              selected: widget.selected,
              armIndex: _armIndex,
              // o disco só sai da pilha quando o braço chega
              slideOut: widget.selected == null ? 0 : Curves.easeOut.transform(((_arm.value - 0.55) / 0.45).clamp(0.0, 1.0)),
              spin: _spin.value,
            ),
          ),
        ),
      );
    });
  }
}

/// Posições de tudo na vitrine (compartilhadas pelo desenho e pelo toque).
class _JukeboxGeometry {
  final Size size;
  final int count;
  _JukeboxGeometry(this.size, this.count);

  static const double pad = 10;
  static const double tagW = 34;

  double get mechW => (size.width * 0.34).clamp(78.0, 150.0);
  double get stackLeft => pad + tagW + 8;
  double get stackRight => size.width - mechW - 4;
  double get stackW => stackRight - stackLeft;
  double get platterH => (size.height * 0.15).clamp(22.0, 40.0);
  Rect get platter => Rect.fromCenter(
        center: Offset((stackLeft + stackRight) / 2, pad + platterH / 2 + 2),
        width: stackW * 0.96,
        height: platterH,
      );
  double get top => platter.bottom + 10;
  double get bottom => size.height - pad;

  /// Espaço de cada disco: pilha justa (no máximo 28 px por disco), ocupando a altura se houver muitos.
  double get slot => count == 0 ? 0 : math.min((bottom - top) / count, 30);
  double get thickness => (slot * 0.82).clamp(7.0, 24.0);
  double discTop(int i) => top + i * slot;
  double discCenter(double i) => i < 0 ? platter.center.dy : top + i * slot + thickness / 2;

  int? discAt(Offset p) {
    if (count == 0 || p.dx > stackRight + 24) return null;
    for (var i = 0; i < count; i++) {
      final y = discTop(i);
      if (p.dy >= y - (slot - thickness) / 2 - 1 && p.dy <= y + thickness + (slot - thickness) / 2 + 1) return i;
    }
    return null;
  }
}

class _JukeboxPainter extends CustomPainter {
  final List<JukeboxDisc> discs;
  final int? selected;
  final double armIndex;
  final double slideOut;
  final double spin;

  _JukeboxPainter({required this.discs, required this.selected, required this.armIndex, required this.slideOut, required this.spin});

  static Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
  static Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

  static const _chrome = [Color(0xFF6D6A73), Color(0xFFE9E6EE), Color(0xFF9B97A3), Color(0xFF55525B)];

  @override
  void paint(Canvas canvas, Size size) {
    final g = _JukeboxGeometry(size, discs.length);
    _paintMechanismBase(canvas, g);
    _paintPlatter(canvas, g);
    for (var i = 0; i < discs.length; i++) {
      _paintDisc(canvas, g, i);
    }
    _paintRailAndArm(canvas, g);
    _paintMeter(canvas, g);
  }

  // ---------- prato com o disco escolhido girando ----------
  void _paintPlatter(Canvas canvas, _JukeboxGeometry g) {
    final r = g.platter;
    final sel = selected != null && selected! < discs.length ? discs[selected!] : null;
    final base = sel?.color ?? const Color(0xFF2A2430);
    // sombra e base cromada do prato
    canvas.drawOval(r.shift(const Offset(0, 4)).inflate(2), Paint()..color = Colors.black.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawOval(r.inflate(3), Paint()..shader = const LinearGradient(colors: _chrome).createShader(r.inflate(3)));
    canvas.drawOval(r, Paint()..shader = RadialGradient(colors: [_lighten(base, 0.15), _darken(base, 0.45)]).createShader(r));
    // sulcos
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.black.withValues(alpha: 0.28);
    for (final f in [0.86, 0.72, 0.58]) {
      canvas.drawOval(Rect.fromCenter(center: r.center, width: r.width * f, height: r.height * f), groove);
    }
    // brilho girando (a luz passando pelo vinil)
    canvas.save();
    canvas.clipPath(Path()..addOval(r));
    canvas.translate(r.center.dx, r.center.dy);
    canvas.scale(1, r.height / r.width);
    canvas.rotate(spin * 2 * math.pi * 3);
    final rad = r.width / 2;
    canvas.drawCircle(
      Offset.zero,
      rad,
      Paint()
        ..shader = SweepGradient(colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.22),
          Colors.transparent,
          Colors.transparent,
          Colors.white.withValues(alpha: 0.14),
          Colors.transparent,
        ], stops: const [0.0, 0.08, 0.18, 0.5, 0.58, 0.68])
            .createShader(Rect.fromCircle(center: Offset.zero, radius: rad)),
    );
    canvas.restore();
    // selo creme com o código
    final label = Rect.fromCenter(center: r.center, width: r.width * 0.26, height: r.height * 0.36);
    canvas.drawOval(label, Paint()..color = const Color(0xFFF3EAD6));
    if (sel != null) _text(canvas, sel.code, label.center, 9, const Color(0xFF2B2231), bold: true);
  }

  // ---------- disco visto de lado ----------
  void _paintDisc(Canvas canvas, _JukeboxGeometry g, int i) {
    final d = discs[i];
    final isSel = selected == i;
    final dx = isSel ? slideOut * 16 : 0.0;
    final t = g.thickness;
    final y = g.discTop(i);
    final rect = Rect.fromLTWH(g.stackLeft + dx, y, g.stackW, t);
    final color = d.dimmed ? Color.lerp(d.color, const Color(0xFF3A3340), 0.75)! : d.color;

    // Disco visto um pouco de cima: face elíptica (sulcos e selo) sobre a borda lateral (um cilindro achatado)
    final faceH = t * 0.62;
    final edge = t - faceH;
    final face = Rect.fromLTWH(rect.left, y, rect.width, faceH);
    final bottomOval = face.shift(Offset(0, edge));
    final body = Path()
      ..addRect(Rect.fromLTRB(rect.left, face.center.dy, rect.right, bottomOval.center.dy))
      ..addOval(bottomOval);

    if (d.active && !d.dimmed) {
      canvas.drawPath(body.shift(Offset.zero), Paint()..color = d.color.withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawOval(face.inflate(2), Paint()..color = d.color.withValues(alpha: 0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    // borda: sombreada como um cilindro (escura nas pontas, brilho à esquerda)
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [_darken(color, 0.55), _lighten(color, 0.15), color, _darken(color, 0.25), _darken(color, 0.6)],
          stops: const [0.0, 0.2, 0.45, 0.8, 1.0],
        ).createShader(rect),
    );
    // face de cima
    canvas.drawOval(
      face,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.4),
          radius: 0.9,
          colors: [_lighten(color, 0.45), color, _darken(color, 0.2)],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(face),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.black.withValues(alpha: d.dimmed ? 0.12 : 0.22);
    for (final f in [0.86, 0.68]) {
      canvas.drawOval(Rect.fromCenter(center: face.center, width: face.width * f, height: face.height * f), groove);
    }
    canvas.drawOval(
      Rect.fromCenter(center: face.center, width: face.width * 0.2, height: face.height * 0.42),
      Paint()..color = d.dimmed ? const Color(0xFF6B6370) : const Color(0xFFF3EAD6),
    );
    if (isSel) {
      canvas.drawOval(face, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = Colors.white.withValues(alpha: 0.9));
    }

    // etiqueta do código à esquerda
    final tagH = math.min(18.0, math.max(t + 2, 13.0));
    final tag = RRect.fromRectAndRadius(
      Rect.fromLTWH(_JukeboxGeometry.pad, y + t / 2 - tagH / 2, _JukeboxGeometry.tagW, tagH),
      const Radius.circular(4),
    );
    canvas.drawRRect(tag, Paint()..color = d.dimmed ? color : _lighten(d.color, 0.2));
    if (d.active && !d.dimmed) {
      canvas.drawRRect(tag, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.8));
    }
    _text(canvas, d.code, tag.center, math.min(11, tagH * 0.65), d.dimmed ? Colors.white54 : const Color(0xFF1F1A24), bold: true);
  }

  // ---------- mecanismo: base, engrenagens ----------
  void _paintMechanismBase(Canvas canvas, _JukeboxGeometry g) {
    final x0 = g.stackRight + 10;
    final w = g.size.width - x0 - 6;
    if (w <= 20) return;
    final h = g.size.height;
    // engrenagens (giram devagar; a pequena ao contrário)
    final r1 = (w * 0.30).clamp(14.0, 34.0);
    final c1 = Offset(x0 + w * 0.58, h - r1 - 12);
    final r2 = r1 * 0.58;
    final c2 = Offset(c1.dx - r1 - r2 + 3, c1.dy - r1 * 0.55);
    final c3 = Offset(c1.dx + r1 * 0.2, c1.dy - r1 * 2.1);
    _gear(canvas, c3, r1 * 0.72, 12, -spin * 2 * math.pi * 1.4, const Color(0xFF6E6977));
    _gear(canvas, c1, r1, 16, spin * 2 * math.pi, const Color(0xFF8C8794));
    _gear(canvas, c2, r2, 10, -spin * 2 * math.pi * (r1 / r2), const Color(0xFF7A7583));
  }

  void _gear(Canvas canvas, Offset c, double r, int teeth, double angle, Color color) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final body = Paint()
      ..shader = RadialGradient(colors: [_lighten(color, 0.45), color, _darken(color, 0.4)], stops: const [0.0, 0.6, 1.0])
          .createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    final toothW = 2 * math.pi * r / teeth * 0.5;
    for (var k = 0; k < teeth; k++) {
      canvas.save();
      canvas.rotate(k * 2 * math.pi / teeth);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -r), width: toothW, height: r * 0.32), const Radius.circular(1.5)),
        body,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, r * 0.88, body);
    canvas.drawCircle(Offset.zero, r * 0.88, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: 0.35));
    // raios e cubo
    final spoke = Paint()
      ..color = _darken(color, 0.55)
      ..strokeWidth = r * 0.12
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 2;
      canvas.drawLine(Offset.zero, Offset(math.cos(a), math.sin(a)) * r * 0.62, spoke);
    }
    canvas.drawCircle(Offset.zero, r * 0.22, Paint()..color = _lighten(color, 0.5));
    canvas.drawCircle(Offset.zero, r * 0.09, Paint()..color = _darken(color, 0.6));
    canvas.restore();
  }

  // ---------- trilho, carrinho e braço ----------
  void _paintRailAndArm(Canvas canvas, _JukeboxGeometry g) {
    final railX = g.stackRight + 22;
    final railTop = g.platter.top - 2;
    final railBottom = g.size.height - 8;
    final rail = Rect.fromLTWH(railX - 4, railTop, 8, railBottom - railTop);
    canvas.drawRRect(RRect.fromRectAndRadius(rail, const Radius.circular(4)),
        Paint()..shader = const LinearGradient(colors: _chrome).createShader(rail));

    // braço do toca-discos: pivô no alto do trilho, agulha na borda do prato
    final pivot = Offset(railX, g.platter.top + 2);
    final needle = Offset(g.platter.right - g.platter.width * 0.16, g.platter.center.dy - 1);
    final tone = Paint()
      ..color = const Color(0xFFCFCBD6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(pivot, needle, tone);
    canvas.drawCircle(pivot, 6, Paint()..shader = const RadialGradient(colors: [Color(0xFFF2F0F5), Color(0xFF6D6A73)]).createShader(Rect.fromCircle(center: pivot, radius: 6)));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: needle, width: 9, height: 5), const Radius.circular(1.5)),
        Paint()..color = const Color(0xFF9B97A3));

    // carrinho na altura do disco escolhido
    final y = g.discCenter(armIndex);
    final sel = selected != null && selected! < discs.length ? discs[selected!] : null;
    final led = sel?.color ?? const Color(0xFFFF4FA3);
    final car = Rect.fromCenter(center: Offset(railX, y), width: 24, height: 18);
    // braço até a borda do disco (mais longo quando o disco sai da pilha)
    if (armIndex >= -0.001) {
      final reachX = g.stackRight + (selected != null ? slideOut * 16 : 0) - 2;
      final arm = Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _chrome)
            .createShader(Rect.fromLTRB(reachX, y - 3, car.left, y + 3));
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(reachX, y - 2.5, car.left + 2, y + 2.5), const Radius.circular(2)), arm);
      // garra
      final claw = Paint()..color = const Color(0xFFBDB9C4);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(reachX - 2, y - 7, 4, 5), const Radius.circular(1)), claw);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(reachX - 2, y + 2, 4, 5), const Radius.circular(1)), claw);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(car.shift(const Offset(0, 2)), const Radius.circular(4)),
        Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(RRect.fromRectAndRadius(car, const Radius.circular(4)),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _chrome).createShader(car));
    final blink = 0.55 + 0.45 * math.sin(spin * 2 * math.pi * 6).abs();
    canvas.drawCircle(car.center, 5.5, Paint()..color = led.withValues(alpha: 0.45 * blink)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(car.center, 3, Paint()..color = _lighten(led, 0.3));
  }

  // ---------- medidor de neon: um segmento por disco, aceso se ligado ----------
  void _paintMeter(Canvas canvas, _JukeboxGeometry g) {
    if (discs.isEmpty) return;
    final x = g.size.width - 9;
    final top = g.top;
    final bottom = math.min(g.bottom, g.discTop(discs.length - 1) + g.thickness);
    final segH = (bottom - top) / discs.length;
    for (var i = 0; i < discs.length; i++) {
      final d = discs[i];
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x - 3, top + i * segH + 1.5, 6, segH - 3), const Radius.circular(2));
      if (d.active) {
        canvas.drawRRect(r.inflate(1.5), Paint()..color = d.color.withValues(alpha: 0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        canvas.drawRRect(r, Paint()..color = _lighten(d.color, 0.25));
      } else {
        canvas.drawRRect(r, Paint()..color = Colors.white.withValues(alpha: 0.08));
      }
    }
  }

  void _text(Canvas canvas, String s, Offset center, double size, Color color, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w900 : FontWeight.w500, fontFamily: 'monospace'), // l10n-ignore
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _JukeboxPainter old) => true;
}
