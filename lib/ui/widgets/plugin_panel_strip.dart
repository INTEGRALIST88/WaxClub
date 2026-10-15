import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/plugins/plugin_catalog.dart';
import '../theme/app_theme.dart';

/// Linha de plugins abaixo da barra de cima (em pé e no cockpit da transmissão): uma caixinha por plugin
/// que muda a tela (curiosidades e fontes de letras), com a luz na cor da categoria — acesa ligado, apagada
/// desligado, **vermelha** quando não encontrou nada para esta música (ou trouxe letra quebrada) — e o código
/// da jukebox (D1, S1...). Da esquerda para a direita é a prioridade: o primeiro plugin ligado que tem
/// conteúdo é o que aparece na tela, e ganha um **brilho embaixo**.
///
/// * Tocar liga/desliga.
/// * Arrastar para os lados troca de lugar: as outras caixinhas abrem espaço deslizando, e soltar grava a
///   ordem (da esquerda para a direita é a prioridade; nas fontes de letras, a ordem da busca).
/// * Arrastar para fora da linha (para cima ou para baixo) pergunta se quer ejetar o plugin.
///
/// As caixinhas dividem a largura da tela. O deslizar usa uma animação própria que roda mesmo com as
/// animações do Android desligadas.
class PluginPanelStrip extends StatefulWidget {
  final PluginStore store;

  /// Plugin que está aparecendo na tela (brilho embaixo).
  final String? shownId;

  /// Plugins que não encontraram nada para esta música (luz vermelha).
  final Set<String> failedIds;
  static const double height = 34;

  /// Vermelho reservado para "não encontrou".
  static const Color failedColor = Color(0xFFFF3B30);

  const PluginPanelStrip({super.key, required this.store, this.shownId, this.failedIds = const {}});

  /// Altura que a linha ocupa (zero sem plugins no painel).
  static double heightFor(PluginStore store) => store.panelPlugins().isEmpty ? 0 : height + 8;

  @override
  State<PluginPanelStrip> createState() => _PluginPanelStripState();
}

class _PluginPanelStripState extends State<PluginPanelStrip> with SingleTickerProviderStateMixin {
  final GlobalKey _rowKey = GlobalKey();

  /// Ordem mostrada agora (durante o arraste, já com o plugin arrastado na posição de destino).
  List<String> _order = [];
  String? _dragId;

  /// Posição (em caixinhas) de onde cada uma parte e para onde vai, para deslizar suave.
  final Map<String, double> _from = {};
  final Map<String, double> _to = {};
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    animationBehavior: AnimationBehavior.preserve,
  );

  PluginStore get _store => widget.store;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    _syncFromStore(animate: false);
  }

  @override
  void didUpdateWidget(covariant PluginPanelStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_onStore);
      widget.store.addListener(_onStore);
      _syncFromStore(animate: false);
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _slide.dispose();
    super.dispose();
  }

  void _onStore() {
    if (_dragId == null && mounted) setState(() => _syncFromStore(animate: true));
  }

  void _syncFromStore({required bool animate}) => _moveTo(_store.panelPlugins().map((p) => p.id).toList(), animate: animate);

  /// Nova ordem: cada caixinha desliza da posição atual para a nova.
  void _moveTo(List<String> order, {required bool animate}) {
    final t = Curves.easeOutCubic.transform(_slide.value);
    final now = {for (final id in _to.keys) id: _lerp(id, t)};
    _order = List.of(order);
    _from.clear();
    _to.clear();
    for (var i = 0; i < _order.length; i++) {
      final id = _order[i];
      _to[id] = i.toDouble();
      _from[id] = animate ? (now[id] ?? i.toDouble()) : i.toDouble();
    }
    if (animate) {
      _slide.forward(from: 0);
    } else {
      _slide.value = 1;
    }
  }

  double _lerp(String id, double t) {
    final a = _from[id] ?? 0;
    final b = _to[id] ?? a;
    return a + (b - a) * t;
  }

  RenderBox? get _rowBox {
    final box = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box : null;
  }

  /// O centro da caixinha arrastada está fora da linha (mais que meia altura acima ou abaixo).
  bool _outside(Offset feedbackTopLeft, double w) {
    final box = _rowBox;
    if (box == null) return false;
    final c = box.globalToLocal(feedbackTopLeft + Offset(w / 2, PluginPanelStrip.height / 2));
    return c.dy < -PluginPanelStrip.height / 2 || c.dy > box.size.height + PluginPanelStrip.height / 2;
  }

  /// Arrastando sobre a linha: o plugin vai para a posição sob o dedo e os outros abrem espaço.
  void _hover(Offset feedbackTopLeft, double w) {
    final id = _dragId;
    final box = _rowBox;
    if (id == null || box == null) return;
    final c = box.globalToLocal(feedbackTopLeft + Offset(w / 2, PluginPanelStrip.height / 2));
    final target = (c.dx / w).floor().clamp(0, _order.length - 1);
    final current = _order.indexOf(id);
    if (current < 0 || current == target) return;
    final next = List.of(_order)
      ..removeAt(current)
      ..insert(target, id);
    setState(() => _moveTo(next, animate: true));
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
    final byId = {for (final p in _store.panelPlugins()) p.id: p};
    final ids = _order.where(byId.containsKey).toList();
    if (ids.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: SizedBox(
        key: _rowKey,
        height: PluginPanelStrip.height,
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth / ids.length;
          return DragTarget<String>(
            onWillAcceptWithDetails: (d) => byId.containsKey(d.data),
            onMove: (d) => _hover(d.offset, w),
            onLeave: (_) {
              // Saiu da linha: volta a mostrar a ordem gravada (pode estar indo ejetar)
              if (_dragId != null) setState(() => _syncFromStore(animate: true));
            },
            onAcceptWithDetails: (_) => _store.setPanelOrder(List.of(_order)),
            builder: (context, _, __) => AnimatedBuilder(
              animation: _slide,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_slide.value);
                final shown = widget.shownId;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Brilho embaixo do plugin que está aparecendo na tela (desliza junto)
                    if (shown != null && ids.contains(shown) && _dragId != shown)
                      Positioned(
                        left: _lerp(shown, t) * w + w * 0.15,
                        width: w * 0.7,
                        top: PluginPanelStrip.height + 2,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.cream,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(color: AppTheme.cream.withValues(alpha: 0.9), blurRadius: 8, spreadRadius: 1),
                              BoxShadow(color: byId[shown]!.category.color.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 2),
                            ],
                          ),
                        ),
                      ),
                    for (final id in ids)
                      Positioned(
                        key: ValueKey(id),
                        left: _lerp(id, t) * w,
                        top: 0,
                        width: w,
                        height: PluginPanelStrip.height,
                        child: _draggableChip(byId[id]!, w),
                      ),
                  ],
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _draggableChip(PluginInfo p, double w) {
    final on = _store.isActive(p);
    final failed = on && widget.failedIds.contains(p.id);
    final shown = on && widget.shownId == p.id;
    final chip = _PluginChip(plugin: p, on: on, failed: failed, shown: shown, onTap: () => _store.toggle(p));
    return Draggable<String>(
      data: p.id,
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: w,
          height: PluginPanelStrip.height,
          child: Transform.scale(scale: 1.08, child: _PluginChip(plugin: p, on: on, failed: failed, shown: shown, onTap: () {})),
        ),
      ),
      // No lugar da caixinha arrastada fica só o contorno (mostra onde ela vai cair)
      childWhenDragging: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cream.withValues(alpha: 0.45), width: 1.2),
          ),
        ),
      ),
      onDragStarted: () => setState(() => _dragId = p.id),
      onDragEnd: (d) {
        final outside = !d.wasAccepted && _outside(d.offset, w);
        setState(() {
          _dragId = null;
          _syncFromStore(animate: true);
        });
        if (outside) _confirmEject(p);
      },
      child: chip,
    );
  }
}

class _PluginChip extends StatelessWidget {
  final PluginInfo plugin;
  final bool on;

  /// Não encontrou nada para esta música: luz vermelha.
  final bool failed;

  /// É o que está aparecendo na tela.
  final bool shown;
  final VoidCallback onTap;

  const _PluginChip({required this.plugin, required this.on, required this.failed, required this.shown, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = failed ? PluginPanelStrip.failedColor : plugin.category.color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      // Rótulo para leitores de tela (sem Tooltip: o toque longo não disputa com o arraste)
      child: Semantics(
        button: true,
        label: '${plugin.code} · ${plugin.name} — ${failed ? l10n.panelPluginNothing : (on ? l10n.panelPluginOn : l10n.panelPluginOff)}', // l10n-ignore
        child: Material(
          color: Colors.black.withValues(alpha: on ? 0.35 : 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: shown ? AppTheme.cream : (on ? color.withValues(alpha: 0.6) : Colors.white12), width: shown ? 1.4 : 1),
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
                        color: shown ? AppTheme.cream : (on ? Colors.white : Colors.white38),
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
