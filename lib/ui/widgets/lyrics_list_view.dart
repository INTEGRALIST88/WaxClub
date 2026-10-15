import 'package:flutter/material.dart';
import 'retro_text.dart';
import '../../l10n/l10n.dart';
import '../../app_info.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/lyric_line.dart';
import '../theme/app_theme.dart';

/// Letra sincronizada no mesmo estilo da tela da TV (web_receiver/index.html):
/// - fonte Inter 800, centralizada, em caixa alta quando o texto é em alfabeto latino;
/// - 3 linhas em destaque do mesmo tamanho (anterior, atual e próxima); a atual em branco com brilho;
/// - a 2ª linha de distância em 76% e apagada; as demais em 62% e quase invisíveis;
/// - a linha atual sempre no centro da área visível, com as bordas de cima e de baixo esmaecendo.
class LyricsListView extends StatefulWidget {
  final List<LyricLine> lyrics;
  final int activeIndex;
  final Function(double seconds)? onSeek;

  /// Conteúdo exibido quando não há letra (ex.: a saudação da tela principal).
  final Widget? emptyState;

  const LyricsListView({
    super.key,
    required this.lyrics,
    required this.activeIndex,
    this.onSeek,
    this.emptyState,
  });

  /// Mesma regra da TV: caixa alta só quando o texto é todo em alfabeto latino (com números,
  /// pontuação e acentos). Textos em outros alfabetos ficam como estão.
  static bool isLatinText(String text) => _hasLatin.hasMatch(text) && _latinOnly.hasMatch(text);
  static final RegExp _latinOnly =
      RegExp(r'^[\p{Script=Latin}\p{Script=Common}\p{Script=Inherited}]+$', unicode: true);
  static final RegExp _hasLatin = RegExp(r'\p{Script=Latin}', unicode: true);

  /// Escala e cor de uma linha a [distance] linhas da atual (as mesmas da TV).
  static double scaleFor(int distance) => distance <= 1 ? 1.0 : (distance == 2 ? 0.76 : 0.62);
  static double opacityFor(int distance) =>
      distance == 0 ? 1.0 : (distance == 1 ? 0.92 : (distance == 2 ? 0.24 : 0.16));

  @override
  State<LyricsListView> createState() => _LyricsListViewState();
}

class _LyricsListViewState extends State<LyricsListView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  /// Curva das transições da TV (cubic-bezier(0.22, 0.8, 0.24, 1)).
  static const Curve _ease = Cubic(0.22, 0.8, 0.24, 1);

  int _lastScrolledIndex = -1;
  double _viewport = 0;
  double _fontSize = 24;

  @override
  void didUpdateWidget(covariant LyricsListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.activeIndex != oldWidget.activeIndex &&
        widget.activeIndex >= 0 &&
        widget.activeIndex < widget.lyrics.length &&
        widget.activeIndex != _lastScrolledIndex) {
      _lastScrolledIndex = widget.activeIndex;
      _scrollToActiveIndex(widget.activeIndex);
    }
  }

  /// Posição (fração da área visível) da borda de cima da linha para que o MEIO dela fique no centro.
  double get _centerAlignment {
    if (_viewport <= 0) return 0.42;
    // Com tradução, cada linha tem a original e, embaixo, a tradução (62% do tamanho)
    final translated = widget.lyrics.any((l) => l.translation != null);
    final lineHeight = _fontSize * 1.25 + 16 + (translated ? _fontSize * 0.62 * 1.25 + 2 : 0);
    return (0.5 - (lineHeight / 2) / _viewport).clamp(0.0, 1.0);
  }

  void _scrollToActiveIndex(int index) {
    if (!_itemScrollController.isAttached) return;

    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 800),
      curve: _ease,
      alignment: _centerAlignment,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return widget.emptyState ?? _buildEmptyState();
    }

    // A barra superior fica sobre o conteúdo: a área visível começa abaixo dela
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: LayoutBuilder(builder: (context, constraints) {
        _viewport = constraints.maxHeight;
        // Tamanho da linha proporcional à altura visível (na TV: 5.52% da altura da tela)
        _fontSize = (constraints.maxHeight * 0.058).clamp(18.0, 34.0);
        return ShaderMask(
          // Bordas esmaecendo, como na TV (transparente → opaco em 18% → opaco até 82% → transparente)
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, 0.18, 0.82, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ScrollablePositionedList.builder(
            itemCount: widget.lyrics.length,
            initialScrollIndex: widget.activeIndex > 0 ? widget.activeIndex : 0,
            initialAlignment: _centerAlignment,
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            // Espaço para a primeira e a última linha também chegarem ao centro
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: constraints.maxHeight * 0.42),
            itemBuilder: (context, index) => _buildLyricItem(widget.lyrics[index], index),
          ),
        );
      }),
    );
  }

  Widget _buildLyricItem(LyricLine line, int index) {
    final active = widget.activeIndex;
    final distance = active < 0 ? (index + 3) : (index - active).abs();
    final isCurrent = distance == 0;
    final text = line.text.trim();
    final isGap = text.isEmpty;
    final display = isGap ? '♪' : (LyricsListView.isLatinText(text) ? text.toUpperCase() : text);

    return InkWell(
      onTap: () => widget.onSeek?.call(line.timestamp.inMilliseconds / 1000.0),
      splashColor: AppTheme.orange.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedScale(
          scale: LyricsListView.scaleFor(distance),
          duration: const Duration(milliseconds: 700),
          curve: _ease,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter', // l10n-ignore
              fontVariations: const [FontVariation('wght', 800)], // l10n-ignore
              fontWeight: FontWeight.w800,
              fontSize: isGap ? _fontSize * 0.8 : _fontSize,
              height: 1.25,
              letterSpacing: LyricsListView.isLatinText(text) ? 0 : -0.02 * _fontSize,
              color: Color.fromRGBO(isCurrent ? 255 : 244, isCurrent ? 255 : 244, isCurrent ? 255 : 246,
                  LyricsListView.opacityFor(distance)),
              shadows: isCurrent
                  ? [Shadow(color: AppTheme.orange.withValues(alpha: 0.35), blurRadius: _fontSize * 0.9)]
                  : const [],
            ),
            child: line.translation == null
                ? Text(display, textAlign: TextAlign.center)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(display, textAlign: TextAlign.center),
                    // Tradução (plugin A2): menor, em itálico e creme, logo abaixo da linha original
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        line.translation!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter', // l10n-ignore
                          fontVariations: const [FontVariation('wght', 500)], // l10n-ignore
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          fontSize: _fontSize * 0.62,
                          height: 1.25,
                          letterSpacing: 0,
                          color: AppTheme.cream.withValues(alpha: LyricsListView.opacityFor(distance) * 0.9),
                          shadows: const [],
                        ),
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.orange.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/icon/app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.surface,
                  child: const Icon(Icons.album, size: 70, color: AppTheme.orange),
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const RetroText(kAppName, fontSize: 44),
          const SizedBox(height: 4),
          const Text(
            kAppTagline,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.cream, letterSpacing: 2.2),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              l10n.lyricsEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textInactive, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
