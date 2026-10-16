import 'dart:async';
import 'dart:ui' show FontVariation;
import 'package:flutter/material.dart';
import '../../services/imagine/imagined_music.dart';
import '../theme/app_theme.dart';

/// Modo imersivo do A3 no celular: a frase de destaque aparece exatamente quando a linha dela começa a ser
/// cantada e some quando a música passa para a próxima linha (cada frase uma vez, com pelo menos ~10 s entre
/// uma e outra — não fica aparecendo o tempo todo). Posição alternada, como na TV.
class ImmersiveQuotes extends StatefulWidget {
  final List<ImagineQuote> quotes;

  /// Linha da letra tocando agora (-1 antes da primeira).
  final int Function() activeLine;

  const ImmersiveQuotes({super.key, required this.quotes, required this.activeLine});

  static const Duration gap = Duration(seconds: 10);
  static const Duration minShown = Duration(milliseconds: 3500);
  static const Duration tick = Duration(milliseconds: 200);

  /// Fonte das frases: Fraunces (serifa clássica e arredondada, OFL), itálico macio.
  static const TextStyle style = TextStyle(
    fontFamily: 'Fraunces', // l10n-ignore
    fontVariations: [FontVariation('SOFT', 100), FontVariation('opsz', 72), FontVariation('wght', 600)], // l10n-ignore
    color: AppTheme.cream,
    fontSize: 34,
    fontStyle: FontStyle.italic,
    height: 1.2,
    shadows: [Shadow(color: Colors.black, blurRadius: 18), Shadow(color: Colors.black87, blurRadius: 4)],
  );

  @override
  State<ImmersiveQuotes> createState() => _ImmersiveQuotesState();
}

class _ImmersiveQuotesState extends State<ImmersiveQuotes> {
  static const _spots = [Alignment(0, -0.45), Alignment(-0.6, 0.35), Alignment(0.6, 0.1)];

  final Set<int> _seen = {};
  Timer? _timer;
  String? _text;
  int? _line;
  bool _visible = false;
  int _spot = 0;
  // tempo contado pelos próprios toques do relógio (ms)
  int _clock = 0;
  int _lastShown = -1 << 30;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(ImmersiveQuotes.tick, (_) => _check());
  }

  @override
  void didUpdateWidget(ImmersiveQuotes old) {
    super.didUpdateWidget(old);
    if (!identical(old.quotes, widget.quotes)) {
      _seen.clear(); // outra música
      _visible = false;
      _line = null;
    }
  }

  void _check() {
    if (!mounted) return;
    _clock += ImmersiveQuotes.tick.inMilliseconds;
    final line = widget.activeLine();
    final now = _clock;
    if (_visible) {
      // Some quando a música passa da linha da frase (depois de um mínimo na tela)
      if (line != _line && now - _lastShown >= ImmersiveQuotes.minShown.inMilliseconds) {
        setState(() => _visible = false);
      }
      return;
    }
    if (now - _lastShown < ImmersiveQuotes.gap.inMilliseconds) return;
    for (var i = 0; i < widget.quotes.length; i++) {
      final q = widget.quotes[i];
      if (q.line != line || _seen.contains(i)) continue;
      _seen.add(i);
      _lastShown = now;
      setState(() {
        _text = q.text;
        _line = q.line;
        _visible = true;
        _spot = (_spot + 1) % _spots.length;
      });
      return;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    return Align(
      alignment: _spots[_spot],
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(text, textAlign: TextAlign.center, style: ImmersiveQuotes.style),
        ),
      ),
    );
  }
}
