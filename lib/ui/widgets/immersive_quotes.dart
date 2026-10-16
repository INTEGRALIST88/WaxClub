import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/imagine/imagined_music.dart';
import '../theme/app_theme.dart';

/// Modo imersivo do A3 no celular: a cada ~22 s uma frase de destaque da letra aparece, fica ~6,5 s e
/// esmaece, alternando a posição (como na TV). Escolhe a frase já cantada mais recente que ainda não
/// apareceu; se não houver, a próxima da lista.
class ImmersiveQuotes extends StatefulWidget {
  final List<ImagineQuote> quotes;

  /// Linha da letra tocando agora (-1 antes da primeira).
  final int Function() activeLine;

  const ImmersiveQuotes({super.key, required this.quotes, required this.activeLine});

  static const Duration firstAfter = Duration(seconds: 6);
  static const Duration gap = Duration(seconds: 22);
  static const Duration shown = Duration(milliseconds: 6500);

  @override
  State<ImmersiveQuotes> createState() => _ImmersiveQuotesState();
}

class _ImmersiveQuotesState extends State<ImmersiveQuotes> {
  static const _spots = [Alignment(0, -0.45), Alignment(-0.6, 0.35), Alignment(0.6, 0.1)];

  final Set<int> _seen = {};
  Timer? _next;
  Timer? _hide;
  String? _text;
  bool _visible = false;
  int _spot = 0;

  @override
  void initState() {
    super.initState();
    _next = Timer(ImmersiveQuotes.firstAfter, _show);
  }

  @override
  void didUpdateWidget(ImmersiveQuotes old) {
    super.didUpdateWidget(old);
    if (!identical(old.quotes, widget.quotes)) _seen.clear(); // outra música
  }

  void _show() {
    if (!mounted || widget.quotes.isEmpty) return;
    final line = widget.activeLine();
    if (_seen.length >= widget.quotes.length) _seen.clear();
    ImagineQuote? pick;
    for (var i = 0; i < widget.quotes.length; i++) {
      final q = widget.quotes[i];
      if (_seen.contains(i)) continue;
      if (q.line <= line && (pick == null || q.line > pick.line)) pick = q;
    }
    pick ??= widget.quotes.firstWhere((q) => !_seen.contains(widget.quotes.indexOf(q)), orElse: () => widget.quotes.first);
    _seen.add(widget.quotes.indexOf(pick));
    setState(() {
      _text = pick!.text;
      _visible = true;
      _spot = (_spot + 1) % _spots.length;
    });
    _hide = Timer(ImmersiveQuotes.shown, () {
      if (mounted) setState(() => _visible = false);
    });
    _next = Timer(ImmersiveQuotes.gap, _show);
  }

  @override
  void dispose() {
    _next?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    return AnimatedAlign(
      alignment: _spots[_spot],
      duration: Duration.zero,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.cream,
              fontSize: 26,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              height: 1.25,
              shadows: [Shadow(color: Colors.black, blurRadius: 18), Shadow(color: Colors.black87, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}
