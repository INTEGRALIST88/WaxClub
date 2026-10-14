import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Letra retrô 3D da marca (fonte Berdano): miolo creme, contorno marrom e "degraus" de sombra
/// para baixo e para a direita, como na amostra do usuário. Só para textos curtos de destaque
/// (música/banda, títulos das telas, saudação, nome WaxClub) — a letra da música fica na fonte normal.
class RetroText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fill;
  final Color outline;
  final int? maxLines;
  final TextAlign? textAlign;

  /// Quantos degraus de relevo (0 = só contorno, para textos pequenos).
  final int depth;

  const RetroText(
    this.text, {
    super.key,
    this.fontSize = 22,
    this.fill = AppTheme.cream,
    this.outline = retroBrown,
    this.maxLines = 1,
    this.textAlign,
    this.depth = 4,
  });

  static const String fontFamily = 'Berdano'; // l10n-ignore
  static const Color retroBrown = Color(0xFF4A2814);

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontFamily: fontFamily, fontSize: fontSize, height: 1.2, letterSpacing: 0.3);
    final stroke = (fontSize * 0.09).clamp(1.2, 6.0);
    final step = (fontSize * 0.025).clamp(0.6, 2.5);
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;

    final inherited = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);

    // Camadas decorativas (relevo e contorno): RichText fora da leitura de tela; o texto "de verdade"
    // é só a camada de cima (creme).
    Widget layer(Paint paint, {List<Shadow>? shadows}) => ExcludeSemantics(
          child: RichText(
            maxLines: maxLines,
            overflow: overflow ?? TextOverflow.clip,
            textAlign: textAlign ?? TextAlign.start,
            softWrap: maxLines != 1,
            textScaler: scaler,
            text: TextSpan(
              text: text,
              style: inherited.merge(base).copyWith(color: null, foreground: paint, shadows: shadows),
            ),
          ),
        );

    Paint strokePaint() => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = outline;

    return Padding(
        // espaço para o contorno e o relevo não serem cortados
        padding: EdgeInsets.only(right: step * depth + stroke / 2, bottom: step * depth + stroke / 2),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // relevo: cópias marrons deslocadas (a última com uma sombra suave)
            for (var i = depth; i >= 1; i--)
              Transform.translate(
                offset: Offset(step * i, step * i),
                child: layer(
                  strokePaint()..style = PaintingStyle.fill,
                  shadows: i == depth
                      ? [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: fontSize * 0.15, offset: Offset(step, step))]
                      : null,
                ),
              ),
            for (var i = depth; i >= 1; i--) Transform.translate(offset: Offset(step * i, step * i), child: layer(strokePaint())),
            layer(strokePaint()),
            Text(
              text,
              maxLines: maxLines,
              overflow: overflow,
              textAlign: textAlign,
              softWrap: maxLines != 1,
              style: base.copyWith(color: fill),
            ),
          ],
        ),
      );
  }
}
