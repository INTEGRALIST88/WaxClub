import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/plugins/plugin_catalog.dart';
import '../theme/app_theme.dart';

/// Linha de plugins abaixo da barra de cima (em pé e no cockpit da transmissão): uma caixinha por plugin
/// que muda a tela (letras e exibição), com a luz na cor da categoria — acesa ligado, apagada desligado —
/// e o código da jukebox (D2, S1...). Tocar liga/desliga. Segurar e arrastar: soltar em outra caixinha
/// troca de lugar (da esquerda para a direita é a prioridade; nas fontes de letras, a ordem da busca);
/// soltar fora da linha pergunta se quer ejetar o plugin. As caixinhas dividem a largura da tela.
class PluginPanelStrip extends StatefulWidget {
  final PluginStore store;
  static const double height = 34;

  const PluginPanelStrip({super.key, required this.store});

  /// Altura que a linha ocupa (zero sem plugins no painel).
  static double heightFor(PluginStore store) => store.panelPlugins().isEmpty ? 0 : height + 8;

  @override
  State<PluginPanelStrip> createState() => _PluginPanelStripState();
}

class _PluginPanelStripState extends State<PluginPanelStrip> {
  final GlobalKey _rowKey = GlobalKey();
  String? _dragging;

  PluginStore get _store => widget.store;

  /// A caixinha foi solta fora da linha (mais que meia altura acima ou abaixo, ou fora da tela).
  bool _droppedOutside(Offset globalTopLeft, double chipHeight) {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final center = globalTopLeft + Offset(0, chipHeight / 2);
    return center.dy < rect.top - chipHeight / 2 || center.dy > rect.bottom + chipHeight / 2;
  }

  Future<void> _confirmEject(PluginInfo p) async {
    final canEject = p.isInstallable;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        icon: Icon(Icons.eject_rounded, color: p.category.color, size: 36),
        title: Text(canEject ? l10n.ejectPluginTitle : l10n.ejectBuiltInTitle, style: const TextStyle(color: AppTheme.cream)),
        content: Text(
          canEject ? l10n.ejectPluginConfirm('${p.code} · ${p.name}') : l10n.ejectBuiltInInfo('${p.code} · ${p.name}'),
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: canEject
            ? [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.rust, foregroundColor: Colors.white),
                  child: Text(l10n.ejectPlugin),
                ),
              ]
            : [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.ok))],
      ),
    );
    if (ok == true && canEject) await _store.uninstall(p);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final plugins = _store.panelPlugins();
        if (plugins.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: SizedBox(
            key: _rowKey,
            height: PluginPanelStrip.height,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth / plugins.length;
              return Row(
                children: [
                  for (var i = 0; i < plugins.length; i++) _slot(plugins, i, w),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  /// Uma posição da linha: recebe a caixinha arrastada (troca de lugar) e mostra a caixinha dela.
  Widget _slot(List<PluginInfo> plugins, int i, double w) {
    final p = plugins[i];
    final on = _store.isActive(p);
    final chip = _PluginChip(plugin: p, on: on, onTap: () => _store.toggle(p));
    return SizedBox(
      width: w,
      child: DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != p.id,
        onAcceptWithDetails: (d) {
          final from = plugins.indexWhere((x) => x.id == d.data);
          if (from >= 0) _store.movePanelPlugin(from, i);
        },
        builder: (context, candidates, _) => LongPressDraggable<String>(
          data: p.id,
          feedback: Material(
            color: Colors.transparent,
            elevation: 8,
            child: SizedBox(width: w, height: PluginPanelStrip.height, child: _PluginChip(plugin: p, on: on, onTap: () {})),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: chip),
          onDragStarted: () => setState(() => _dragging = p.id),
          onDragEnd: (d) {
            setState(() => _dragging = null);
            if (!d.wasAccepted && _droppedOutside(d.offset, PluginPanelStrip.height)) _confirmEject(p);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: candidates.isNotEmpty && _dragging != null ? Border.all(color: AppTheme.cream, width: 1.5) : null,
            ),
            child: chip,
          ),
        ),
      ),
    );
  }
}

class _PluginChip extends StatelessWidget {
  final PluginInfo plugin;
  final bool on;
  final VoidCallback onTap;

  const _PluginChip({required this.plugin, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = plugin.category.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      // Rótulo para leitores de tela (sem Tooltip: o "segurar" fica só para arrastar)
      child: Semantics(
        button: true,
        label: '${plugin.code} · ${plugin.name} — ${on ? l10n.panelPluginOn : l10n.panelPluginOff}', // l10n-ignore
        child: Material(
          color: Colors.black.withValues(alpha: on ? 0.35 : 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: on ? color.withValues(alpha: 0.6) : Colors.white12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Luz da categoria: acesa ligado, apagada desligado
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: on ? color : color.withValues(alpha: 0.2),
                        boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.9), blurRadius: 6, spreadRadius: 1)] : null,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      plugin.code,
                      style: TextStyle(
                        color: on ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
