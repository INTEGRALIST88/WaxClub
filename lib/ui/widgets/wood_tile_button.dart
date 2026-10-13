import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Botão de madeira entalhada (arte em PNG: câmera, estante = My Collection, plugue = Plugins, "?" = Help).
class WoodTileButton extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback onPressed;
  final double size;

  const WoodTileButton({
    super.key,
    required this.asset,
    required this.label,
    required this.onPressed,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkResponse(
        onTap: onPressed,
        radius: size * 0.75,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Semantics(
            button: true,
            label: label,
            child: Image.asset(asset, width: size, height: size, filterQuality: FilterQuality.medium),
          ),
        ),
      ),
    );
  }
}

/// Nome de um botão para a apresentação da abertura: [anchor] é a chave do botão.
class IntroLabelSpec {
  final GlobalKey anchor;
  final String text;
  final Duration delay;

  /// Nome acima do botão (senão, abaixo). Alternar acima/abaixo evita que nomes vizinhos se toquem.
  final bool above;
  const IntroLabelSpec({required this.anchor, required this.text, required this.delay, this.above = false});
}

/// Camada que, na abertura do app, mostra o nome de cada botão logo abaixo dele, revelado da esquerda
/// para a direita e apagado também da esquerda para a direita. Fica no corpo da tela (a barra superior
/// corta o que passa da altura dela) e mede a posição dos botões a cada quadro, acompanhando a rotação.
class IntroLabelsLayer extends StatefulWidget {
  final List<IntroLabelSpec> specs;
  const IntroLabelsLayer({super.key, required this.specs});

  @override
  State<IntroLabelsLayer> createState() => _IntroLabelsLayerState();
}

class _IntroLabelsLayerState extends State<IntroLabelsLayer> with SingleTickerProviderStateMixin {
  /// Tempo de cada nome na tela.
  static const Duration labelDuration = Duration(milliseconds: 1900);

  /// Espera após o primeiro quadro, para a sequência não coincidir com a carga inicial do app.
  static const Duration startDelay = Duration(milliseconds: 1200);

  /// Linha do tempo única para toda a sequência: mesmo que a tela trave, a ordem e o intervalo
  /// entre os nomes se mantêm (temporizadores separados disparavam todos juntos depois da trava).
  /// preserve: mantém a duração mesmo com as animações do sistema desligadas.
  late final Duration _total = widget.specs.isEmpty
      ? labelDuration
      : widget.specs.map((s) => s.delay).reduce((a, b) => a > b ? a : b) + labelDuration;
  late final AnimationController _timeline =
      AnimationController(vsync: this, duration: _total, animationBehavior: AnimationBehavior.preserve);
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startTimer = Timer(startDelay, () {
        if (mounted) _timeline.forward(from: 0);
      });
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _timeline.dispose();
    super.dispose();
  }

  /// Progresso (0 a 1) do nome [i] no instante atual da linha do tempo; nulo fora da janela dele.
  double? _progressOf(int i) {
    if (!_timeline.isAnimating) return null;
    final elapsedMs = _timeline.value * _total.inMilliseconds;
    final t = (elapsedMs - widget.specs[i].delay.inMilliseconds) / labelDuration.inMilliseconds;
    return (t <= 0 || t >= 1) ? null : t;
  }

  /// Centro da borda de baixo (ou de cima, com [top]) do botão, no sistema de coordenadas desta camada.
  Offset? _anchorPoint(GlobalKey key, {bool top = false}) {
    final target = key.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (target is! RenderBox || me is! RenderBox || !target.hasSize || !target.attached || !me.attached) return null;
    return me.globalToLocal(target.localToGlobal(Offset(target.size.width / 2, top ? 0 : target.size.height)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _timeline,
      builder: (context, _) {
        final children = <Widget>[];
        for (var i = 0; i < widget.specs.length; i++) {
          final t = _progressOf(i);
          if (t == null) continue;
          final spec = widget.specs[i];
          final at = _anchorPoint(spec.anchor, top: spec.above);
          if (at == null) continue;
          final label = Align(
            alignment: Alignment.topCenter,
            child: IntroWipeLabel(text: spec.text, animation: AlwaysStoppedAnimation(t)),
          );
          children.add(Positioned(
            left: at.dx - 120,
            width: 240,
            // Acima: o nome sobe a própria altura a partir da borda de cima do botão
            top: spec.above ? at.dy - 4 : at.dy + 6,
            child: spec.above ? FractionalTranslation(translation: const Offset(0, -1), child: label) : label,
          ));
        }
        // Material transparente: a camada fica fora do Scaffold e precisa do tema de texto do app
        return IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: Stack(clipBehavior: Clip.none, children: children),
          ),
        );
      },
    );
  }
}

/// Etiqueta revelada e apagada da esquerda para a direita, com borda suave, conforme [animation]
/// vai de 0 a 1: entra no primeiro quarto, fica visível e sai no último quarto.
class IntroWipeLabel extends StatelessWidget {
  final String text;
  final Animation<double> animation;

  const IntroWipeLabel({super.key, required this.text, required this.animation});

  /// Faixa visível (início, fim) da etiqueta, em fração da largura, no instante [t].
  static (double, double) visibleRange(double t) {
    const reveal = 0.22, hide = 0.78;
    if (t <= reveal) return (0.0, Curves.easeOut.transform(t / reveal));
    if (t < hide) return (0.0, 1.0);
    return (Curves.easeIn.transform((t - hide) / (1 - hide)), 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final (start, end) = visibleRange(animation.value);
        if (end <= 0 || start >= 1) return const SizedBox.shrink();
        const feather = 0.12;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            colors: const [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
            stops: [
              (start - feather).clamp(0.0, 1.0),
              start.clamp(0.0, 1.0),
              end.clamp(0.0, 1.0),
              (end + feather).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xE62A1A10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.carveLight.withValues(alpha: 0.6)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(color: AppTheme.cream, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
    );
  }
}
