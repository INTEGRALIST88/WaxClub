import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/plugins/plugin_catalog.dart';

/// Linha de plugins abaixo da barra de cima (em pé e no cockpit da transmissão): uma caixinha por plugin
/// que muda a tela (letras e exibição), com a luz na cor da categoria — acesa ligado, apagada desligado —
/// e o código da jukebox (D2, S1...). Tocar liga/desliga; segurar e arrastar troca de lugar (da esquerda
/// para a direita é a prioridade; nas fontes de letras, a ordem da busca). As caixinhas dividem a largura.
class PluginPanelStrip extends StatelessWidget {
  final PluginStore store;
  static const double height = 34;

  const PluginPanelStrip({super.key, required this.store});

  /// Altura que a linha ocupa (zero sem plugins no painel).
  static double heightFor(PluginStore store) => store.panelPlugins().isEmpty ? 0 : height + 8;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final plugins = store.panelPlugins();
        if (plugins.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: SizedBox(
            height: height,
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth / plugins.length;
              return ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                itemExtent: w,
                itemCount: plugins.length,
                onReorder: (from, to) => store.movePanelPlugin(from, to > from ? to - 1 : to),
                proxyDecorator: (child, _, __) => Material(color: Colors.transparent, elevation: 6, child: child),
                itemBuilder: (context, i) => _PluginChip(
                  key: ValueKey(plugins[i].id),
                  plugin: plugins[i],
                  on: store.isActive(plugins[i]),
                  onTap: () => store.toggle(plugins[i]),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _PluginChip extends StatelessWidget {
  final PluginInfo plugin;
  final bool on;
  final VoidCallback onTap;

  const _PluginChip({super.key, required this.plugin, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = plugin.category.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: '${plugin.code} · ${plugin.name} — ${on ? l10n.panelPluginOn : l10n.panelPluginOff}',
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
