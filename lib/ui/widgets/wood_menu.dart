import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Item do menu de madeira (botão ☰): botão de madeira pequeno com o nome na frente.
class WoodMenuItem {
  final String asset;
  final String label;
  final VoidCallback onTap;

  /// Etiqueta à direita (ex.: ON/OFF do Manual); nula, nada.
  final String? badge;
  final bool badgeOn;

  const WoodMenuItem({required this.asset, required this.label, required this.onTap, this.badge, this.badgeOn = false});
}

/// Abre o menu de madeira logo abaixo do botão [anchor]: um balão de nogueira com os itens um abaixo do outro,
/// que descem em sequência. Tocar fora fecha; tocar num item fecha e chama a ação dele.
Future<void> showWoodMenu(BuildContext context, {required GlobalKey anchor, required List<WoodMenuItem> items}) {
  final box = anchor.currentContext?.findRenderObject() as RenderBox?;
  final origin = box == null ? const Offset(8, 80) : box.localToGlobal(Offset(0, box.size.height));
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: Duration(milliseconds: 220 + 40 * items.length),
    pageBuilder: (ctx, animation, _) => _WoodMenu(animation: animation, origin: origin, items: items),
  );
}

class _WoodMenu extends StatelessWidget {
  final Animation<double> animation;
  final Offset origin;
  final List<WoodMenuItem> items;

  const _WoodMenu({required this.animation, required this.origin, required this.items});

  static const double iconSize = 30;

  @override
  Widget build(BuildContext context) {
    final n = items.length;
    final balloon = CurvedAnimation(parent: animation, curve: const Interval(0, 0.45, curve: Curves.easeOutCubic));
    return Stack(
      children: [
        Positioned(
          left: origin.dx,
          top: origin.dy + 4,
          child: FadeTransition(
            opacity: balloon,
            child: ScaleTransition(
              scale: Tween(begin: 0.92, end: 1.0).animate(balloon),
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A2618), Color(0xFF2E1E13)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.carveLight, width: 1.6),
                    boxShadow: const [
                      BoxShadow(color: AppTheme.carveShadow, spreadRadius: 1.5, offset: Offset(0, 2)),
                      BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 10)),
                    ],
                  ),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < n; i++) _item(context, items[i], _step(i, n)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Cada item entra um pouco depois do anterior (descendo e aparecendo).
  Animation<double> _step(int i, int n) {
    final start = (0.15 + 0.6 * i / n).clamp(0.0, 0.9);
    return CurvedAnimation(
        parent: animation, curve: Interval(start, (start + 0.35).clamp(0.0, 1.0), curve: Curves.easeOutBack));
  }

  Widget _item(BuildContext context, WoodMenuItem it, Animation<double> a) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - a.value) * -14), child: child),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.of(context).pop();
          it.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            children: [
              Image.asset(it.asset, width: iconSize, height: iconSize, filterQuality: FilterQuality.medium),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  it.label,
                  style: const TextStyle(
                    color: AppTheme.cream,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black, offset: Offset(0, 1))],
                  ),
                ),
              ),
              if (it.badge != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: it.badgeOn ? AppTheme.orange : Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    it.badge!,
                    style: TextStyle(
                      color: it.badgeOn ? const Color(0xFF1B140E) : Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
