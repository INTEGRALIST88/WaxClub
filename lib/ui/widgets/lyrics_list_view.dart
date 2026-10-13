import 'package:flutter/material.dart';
import '../../app_info.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../models/lyric_line.dart';
import '../theme/app_theme.dart';

/// Lista vertical com animação fluida de letras sincronizadas estilo karaokê (Spotify/Apple Music).
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

  @override
  State<LyricsListView> createState() => _LyricsListViewState();
}

class _LyricsListViewState extends State<LyricsListView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  int _lastScrolledIndex = -1;

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

  void _scrollToActiveIndex(int index) {
    if (!_itemScrollController.isAttached) return;

    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      alignment: 0.38, // Mantém a estrofe ativa centralizada no terço superior
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyrics.isEmpty) {
      return widget.emptyState ?? _buildEmptyState();
    }

    return ScrollablePositionedList.builder(
      itemCount: widget.lyrics.length,
      initialScrollIndex: widget.activeIndex > 0 ? widget.activeIndex : 0,
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      itemBuilder: (context, index) {
        final line = widget.lyrics[index];
        final isActive = index == widget.activeIndex;
        final isPast = index < widget.activeIndex;

        return _buildLyricItem(line, isActive, isPast, index);
      },
    );
  }

  Widget _buildLyricItem(LyricLine line, bool isActive, bool isPast, int index) {
    // Estilo e cores dinâmicas baseadas na proximidade da linha ativa
    final color = isActive
        ? AppTheme.textActive
        : (isPast ? AppTheme.textPast : AppTheme.textInactive);

    final fontSize = isActive ? 28.0 : 21.0;
    final fontWeight = isActive ? FontWeight.w800 : FontWeight.w600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: () {
          widget.onSeek?.call(line.timestamp.inMilliseconds / 1000.0);
        },
        splashColor: AppTheme.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: 1.35,
            letterSpacing: isActive ? -0.5 : 0.0,
            shadows: isActive
                ? [
                    Shadow(
                      color: AppTheme.orange.withOpacity(0.6),
                      blurRadius: 18,
                    ),
                    Shadow(
                      color: AppTheme.cream.withOpacity(0.4),
                      blurRadius: 28,
                    ),
                  ]
                : null,
          ),
          child: Text(line.text.isEmpty ? '♪' : line.text),
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
                  color: AppTheme.orange.withOpacity(0.35),
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
          const Text(
            kAppName,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            kAppTagline,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.cream,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the microphone to listen to your vinyl and sync the lyrics, with turntable speed compensation.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textInactive,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
