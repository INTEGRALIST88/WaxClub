import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/l10n.dart';
import '../../services/brain/brain_chips.dart';
import '../../services/brain/brain_service.dart';
import '../../services/plugins/plugin_links.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_text.dart';

/// WaxBrain: o usuário encaixa as próprias chaves de IA (BYOK) em chips. Nenhum chip vem encaixado.
///
/// Encaixe pensado para leigos: o app abre a página da chave no navegador do celular (o login do Google
/// não funciona dentro do app), o usuário cria e copia a chave e, ao voltar, o app a reconhece na área de
/// transferência, testa no provedor e acende o chip. Colar à mão fica como reserva.
class WaxBrainScreen extends StatefulWidget {
  final BrainService brain;
  const WaxBrainScreen({super.key, required this.brain});

  @override
  State<WaxBrainScreen> createState() => _WaxBrainScreenState();
}

class _WaxBrainScreenState extends State<WaxBrainScreen> with WidgetsBindingObserver {
  /// Chip cuja página de chave foi aberta: ao voltar ao app, procura a chave copiada.
  BrainChip? _awaiting;
  bool _plugging = false;

  BrainService get _brain => widget.brain;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _brain.addListener(_changed);
    _brain.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _brain.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final chip = _awaiting;
    if (state == AppLifecycleState.resumed && chip != null) {
      _awaiting = null;
      // pequeno atraso: a área de transferência só fica legível com o app de volta em primeiro plano
      Future.delayed(const Duration(milliseconds: 400), () => _checkClipboard(chip, manual: false));
    }
  }

  // ---------- encaixe ----------

  Future<void> _startPlug(BrainChip chip) async {
    final paste = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _chipIcon(chip, size: 34, lit: true),
                const SizedBox(width: 12),
                Expanded(child: RetroText(l10n.brainPlugTitle(chip.name), fontSize: 24, depth: 2, maxLines: 2)),
                _badge(chip.free),
              ]),
              if (!chip.free) ...[
                const SizedBox(height: 12),
                Text(l10n.brainPaidWarning(chip.vendor), style: const TextStyle(color: AppTheme.orange, fontSize: 13, height: 1.35)),
              ],
              const SizedBox(height: 14),
              _step(1, l10n.brainStep1(chip.vendor)),
              _step(2, l10n.brainStep2),
              _step(3, l10n.brainStep3),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l10n.brainOpenKeyPage(chip.vendor)),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.orange, foregroundColor: Colors.white),
                  onPressed: () {
                    _awaiting = chip;
                    Navigator.pop(ctx);
                    PluginLinks.instance.openUrl(chip.keyPageUrl);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.brainPasteHint, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: paste,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l10n.brainPasteField,
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.content_paste_rounded, size: 18, color: AppTheme.cream),
                        tooltip: l10n.brainPasteButton,
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          paste.text = (data?.text ?? '').trim();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.cream, foregroundColor: Colors.black),
                  onPressed: () {
                    final key = paste.text.trim();
                    if (key.isEmpty) return;
                    Navigator.pop(ctx);
                    _plugKey(chip, key);
                  },
                  child: Text(l10n.brainPlugButton),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    paste.dispose();
  }

  Widget _step(int n, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppTheme.cream,
            child: Text('$n', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35))),
        ]),
      );

  /// Ao voltar da página do provedor: procura a chave copiada. Aceita a do chip escolhido ou, se o usuário
  /// copiou a de outro provedor, a desse outro.
  Future<void> _checkClipboard(BrainChip chip, {required bool manual}) async {
    if (!mounted || _plugging) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final found = BrainChip.detect(data?.text, expected: chip) ?? BrainChip.detect(data?.text);
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        duration: const Duration(seconds: 6),
        content: Text(l10n.brainNoKeyCopied(chip.name), style: const TextStyle(color: Colors.white)),
        action: SnackBarAction(label: l10n.brainTryAgain, textColor: AppTheme.orange, onPressed: () => _startPlug(chip)),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: RetroText(l10n.brainKeyFoundTitle, fontSize: 24, depth: 2, maxLines: 2),
        content: Text(l10n.brainKeyFoundBody(found.chip.name, BrainChip.hintOf(found.key)),
            style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.brainPlugButton)),
        ],
      ),
    );
    if (ok == true) await _plugKey(found.chip, found.key);
  }

  Future<void> _plugKey(BrainChip chip, String key) async {
    if (_plugging) return;
    setState(() => _plugging = true);
    final status = await _brain.plug(chip, key);
    if (!mounted) return;
    setState(() => _plugging = false);
    if (status != BrainKeyStatus.invalid) {
      // A chave não fica exposta na área de transferência
      await Clipboard.setData(const ClipboardData(text: ''));
    }
    if (!mounted) return;
    final plugged = status != BrainKeyStatus.invalid;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: RetroText(plugged ? l10n.brainPluggedTitle(chip.name) : l10n.brainRejectedTitle, fontSize: 24, depth: 2, maxLines: 2),
        content: Text(
          switch (status) {
            BrainKeyStatus.ok => l10n.brainPluggedBody(chip.name),
            BrainKeyStatus.limit => l10n.brainPluggedLimitBody(chip.name),
            BrainKeyStatus.offline => l10n.brainPluggedOfflineBody(chip.name),
            BrainKeyStatus.invalid => l10n.brainRejectedBody(chip.vendor),
          },
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))],
      ),
    );
  }

  Future<void> _unplug(PluggedChip p) async {
    final chip = p.chip;
    if (chip == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: RetroText(l10n.brainUnplugTitle(chip.name), fontSize: 24, depth: 2, maxLines: 2),
        content: Text(l10n.brainUnplugBody, style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.brainUnplugButton)),
        ],
      ),
    );
    if (ok == true) await _brain.unplug(p.id);
  }

  // ---------- visual ----------

  Widget _badge(bool free) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (free ? Colors.greenAccent : AppTheme.orange).withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: free ? Colors.greenAccent : AppTheme.orange, width: 1),
        ),
        child: Text(free ? l10n.brainFree : l10n.brainPaid,
            style: TextStyle(color: free ? Colors.greenAccent : AppTheme.orange, fontSize: 11, fontWeight: FontWeight.bold)),
      );

  /// O "chip" (processador) desenhado: aceso na cor do provedor quando encaixado.
  Widget _chipIcon(BrainChip chip, {double size = 40, bool lit = false}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: lit ? chip.color.withValues(alpha: 0.22) : Colors.white10,
          borderRadius: BorderRadius.circular(size * 0.2),
          border: Border.all(color: lit ? chip.color : Colors.white24, width: 1.5),
          boxShadow: lit ? [BoxShadow(color: chip.color.withValues(alpha: 0.55), blurRadius: size * 0.4)] : null,
        ),
        child: Icon(Icons.memory_rounded, size: size * 0.62, color: lit ? chip.color : Colors.white38),
      );

  (String, Color) _statusOf(BrainKeyStatus s) => switch (s) {
        BrainKeyStatus.ok => (l10n.brainStatusOk, Colors.greenAccent),
        BrainKeyStatus.limit => (l10n.brainStatusLimit, Colors.amberAccent),
        BrainKeyStatus.invalid => (l10n.brainStatusInvalid, Colors.redAccent),
        BrainKeyStatus.offline => (l10n.brainStatusOffline, Colors.white54),
      };

  Widget _pluggedTile(PluggedChip p, int index) {
    final chip = p.chip!;
    final (label, color) = _statusOf(p.status);
    return Container(
      key: ValueKey(p.id),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chip.color.withValues(alpha: 0.6)),
      ),
      child: ListTile(
        leading: _chipIcon(chip, lit: true),
        title: Row(children: [
          Text('${index + 1}. ${chip.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _badge(chip.free),
        ]),
        subtitle: Row(children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text('$label · …${p.hint}', style: const TextStyle(color: Colors.white60, fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ]),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: AppTheme.surface,
          onSelected: (v) async {
            if (v == 'test') { // l10n-ignore
              await _brain.recheck(p.id);
            } else if (v == 'change') { // l10n-ignore
              await _startPlug(chip);
            } else {
              await _unplug(p);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'test', child: Text(l10n.brainTestAgain, style: const TextStyle(color: Colors.white))), // l10n-ignore
            PopupMenuItem(value: 'change', child: Text(l10n.brainChangeKey, style: const TextStyle(color: Colors.white))), // l10n-ignore
            PopupMenuItem(value: 'unplug', child: Text(l10n.brainUnplugButton, style: const TextStyle(color: Colors.redAccent))), // l10n-ignore
          ],
        ),
      ),
    );
  }

  Widget _socket(BrainChip chip) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _plugging ? null : () => _startPlug(chip),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _chipIcon(chip, size: 34),
                const Spacer(),
                _badge(chip.free),
              ]),
              const SizedBox(height: 10),
              Text(chip.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(chip.vendor, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Text(l10n.brainTapToPlug, style: TextStyle(color: chip.color, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final plugged = _brain.plugged;
    final sockets = [for (final c in BrainChip.all) if (!_brain.isPlugged(c.id)) c];
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.cream,
        title: RetroText(l10n.waxBrain, fontSize: 26, depth: 3),
        bottom: _plugging
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2, color: AppTheme.orange))
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Image.asset('assets/images/btn_brain.png', width: 76, height: 76),
            const SizedBox(width: 14),
            Expanded(child: Text(l10n.brainIntro, style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4))),
          ]),
          const SizedBox(height: 20),
          if (plugged.isNotEmpty) ...[
            Text(l10n.brainPluggedSection, style: const TextStyle(color: AppTheme.cream, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(l10n.brainOrderHint, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorderItem: (a, b) => _brain.reorder(a, b),
              children: [for (var i = 0; i < plugged.length; i++) if (plugged[i].chip != null) _pluggedTile(plugged[i], i)],
            ),
            const SizedBox(height: 18),
          ],
          Text(l10n.brainSocketsSection, style: const TextStyle(color: AppTheme.cream, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(plugged.isEmpty ? l10n.brainSocketsHintEmpty : l10n.brainSocketsHint,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [for (final c in sockets) _socket(c)],
          ),
          const SizedBox(height: 18),
          Text(l10n.brainPrivacyNote, style: const TextStyle(color: Colors.white38, fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}
