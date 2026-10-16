import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Selo pequeno no canto da capa quando o disco tocando não está em My Collection: um "+" laranja que pulsa
/// de leve para chamar a atenção (tocar na capa abre o disco, com "Add to collection").
class NotInCollectionBadge extends StatefulWidget {
  const NotInCollectionBadge({super.key});

  @override
  State<NotInCollectionBadge> createState() => _NotInCollectionBadgeState();
}

class _NotInCollectionBadgeState extends State<NotInCollectionBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: l10n.notInCollectionBadge,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final v = Curves.easeInOut.transform(_pulse.value);
          return Transform.scale(
            scale: 1.0 + 0.12 * v,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.orange,
                border: Border.all(color: AppTheme.cream, width: 1.5),
                boxShadow: [
                  BoxShadow(color: AppTheme.orange.withValues(alpha: 0.35 + 0.45 * v), blurRadius: 4 + 6 * v, spreadRadius: v),
                ],
              ),
              child: child,
            ),
          );
        },
        child: const Icon(Icons.add, size: 14, color: Colors.white),
      ),
    );
  }
}
