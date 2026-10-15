import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/retro_text.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud/cloud_folder.dart';
import '../../services/cloud/google_drive_folder.dart';
import '../../services/local_lyrics_library.dart';
import 'cloud_login_screen.dart';
import '../../services/plugins/plugin_catalog.dart';
import '../../services/plugins/plugin_links.dart';
import '../../services/plugins/plugin_manifest.dart';
import '../theme/app_theme.dart';
import '../widgets/jukebox_machine.dart';
import '../widgets/seven_inch_record.dart';

/// Página de plugins em forma de jukebox: cada plugin instalado é um disco na pilha da vitrine, na cor da
/// categoria (Language, Display, AI...), com o mecanismo ao lado; no corpo, as cartelas de seleção com
/// ON/OFF e detalhes. Botões-joia filtram por categoria. Deitado: vitrine à esquerda, cartelas à direita.
class PluginJukeboxScreen extends StatefulWidget {
  final PluginStore store;

  /// Instala pelo site (baixa o manifesto); sem ele, o caixote só mostra os plugins.
  final PluginInstaller? installer;

  /// Letras do próprio usuário (plugin S5) e as pastas delas na nuvem (Dropbox, OneDrive, Google Drive).
  final LocalLyricsLibrary? myLyrics;
  final List<CloudLyricsFolder> clouds;
  const PluginJukeboxScreen({super.key, required this.store, this.installer, this.myLyrics, this.clouds = const []});

  @override
  State<PluginJukeboxScreen> createState() => _PluginJukeboxScreenState();
}

class _PluginJukeboxScreenState extends State<PluginJukeboxScreen> {
  static const Color _bg = Color(0xFF0E0B12);
  static const Color _panel = Color(0xFF18131E);
  static const Color _muted = Color(0xFFA99FB5);
  static const Color _stripColor = Color(0xFFF3EAD6);
  static const Color _stripDim = Color(0xFFD9CDB4);
  static const Color _ink = Color(0xFF2B2231);
  static const Color _red = Color(0xFFB8432B);
  static const Color _amber = Color(0xFFF6B74A);
  static const List<Color> _chrome = [Color(0xFF6D6A73), Color(0xFFE9E6EE), Color(0xFF9B97A3), Color(0xFF55525B)];

  PluginStore get _store => widget.store;
  String? _selectedId;
  PluginCategory? _filter;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  /// Escolhe o plugin: o braço da jukebox vai buscar o disco e, em seguida, abrem os detalhes.
  Future<void> _choose(PluginInfo p) async {
    final wasSelected = _selectedId == p.id;
    setState(() => _selectedId = p.id);
    if (!wasSelected && _store.isInstalled(p)) await Future.delayed(const Duration(milliseconds: 520));
    if (mounted) await _open(p);
  }

  Future<void> _open(PluginInfo p) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PluginSheet(store: _store, plugin: p, installer: widget.installer, myLyrics: widget.myLyrics, clouds: widget.clouds),
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggle(PluginInfo p) async {
    setState(() => _selectedId = p.id);
    await _store.toggle(p);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: AppTheme.cream,
        title: RetroText(l10n.jukeboxTitle, fontSize: 28, depth: 3),
      ),
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) => LayoutBuilder(builder: (context, c) {
          final landscape = c.maxWidth > c.maxHeight * 1.15;
          if (landscape) {
            // Deitado: gabinete à esquerda, cartelas à direita
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: math.min(c.maxWidth * 0.48, 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 6, 12),
                  child: Column(children: [
                    Expanded(child: _cabinet()),
                    const SizedBox(height: 8),
                    _controlBand(),
                  ]),
                ),
              ),
              Expanded(
                child: Padding(padding: const EdgeInsets.fromLTRB(6, 0, 12, 12), child: _stripsBody()),
              ),
            ]);
          }
          // Em pé: gabinete no alto, faixa de comando e as cartelas no corpo
          final cabinetH = (c.maxHeight * 0.38).clamp(230.0, 360.0);
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
              SizedBox(height: cabinetH, child: _cabinet()),
              const SizedBox(height: 8),
              _controlBand(),
              const SizedBox(height: 8),
              Expanded(child: _stripsBody()),
            ]),
          );
        }),
      ),
    );
  }

  // ---------- Gabinete: madeira, cromado, neon e a vitrine com a pilha e o mecanismo ----------
  Widget _cabinet() {
    final installed = _store.installed();
    final discs = [
      for (final p in installed)
        JukeboxDisc(
          code: p.code,
          color: p.category.color,
          active: _store.isActive(p),
          dimmed: _filter != null && p.category != _filter,
        ),
    ];
    final selectedIndex = installed.indexWhere((p) => p.id == _selectedId);
    return CustomPaint(
      foregroundPainter: _NeonFramePainter(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(46), bottom: Radius.circular(14)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A3620), Color(0xFF3A2414), Color(0xFF24160C)],
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final c in PluginCategory.values) _lamp(c.color),
            const SizedBox(width: 10),
            const Text('WAXCLUB', // l10n-ignore
                style: TextStyle(color: AppTheme.cream, fontSize: 13, letterSpacing: 6, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            for (final c in PluginCategory.values.toList().reversed) _lamp(c.color),
          ]),
          const SizedBox(height: 8),
          // Vitrine (vidro escuro com friso cromado)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(34), bottom: Radius.circular(10)),
                gradient: LinearGradient(colors: _chrome),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32), bottom: Radius.circular(8)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.8),
                      radius: 1.3,
                      colors: [PluginCategory.ai.color.withValues(alpha: 0.22), const Color(0xFF120E17), const Color(0xFF07060A)],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                  child: installed.isEmpty
                      ? Center(child: Text(l10n.jukeboxNothingPlaying, style: const TextStyle(color: _muted)))
                      : JukeboxMachine(
                          discs: discs,
                          selected: selectedIndex < 0 ? null : selectedIndex,
                          onTapDisc: (i) => _choose(installed[i]),
                        ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _lamp(Color c) => Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(c, Colors.white, 0.25),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 6)],
        ),
      );

  // ---------- Faixa de comando: visor âmbar e botões-joia por categoria ----------
  Widget _controlBand() {
    final sel = _selectedId == null ? null : _store.byId(_selectedId!);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _chrome),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // visor
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0806),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.black, width: 1.5),
          ),
          child: Text(
            sel == null ? l10n.jukeboxTapToChoose : '${sel.code} · ${sel.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _amber,
              fontSize: 14,
              letterSpacing: 1.2,
              fontFamily: 'monospace', // l10n-ignore
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Color(0xAAF6B74A), blurRadius: 8)],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _jewel(l10n.jukeboxAll, const Color(0xFFF3EAD6), _filter == null, () => setState(() => _filter = null), flex: 2),
          for (final c in PluginCategory.values)
            _jewel(c.letter, c.color, _filter == c, () => setState(() => _filter = _filter == c ? null : c)),
        ]),
      ]),
    );
  }

  Widget _jewel(String label, Color color, bool on, VoidCallback onTap, {int flex = 1}) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: on
                        ? [Color.lerp(color, Colors.white, 0.45)!, color]
                        : [Color.lerp(color, Colors.black, 0.45)!, Color.lerp(color, Colors.black, 0.7)!],
                  ),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.6)),
                  boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.75), blurRadius: 10)] : null,
                ),
                child: Text(label,
                    style: TextStyle(
                      color: on ? _ink : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      fontFamily: 'monospace', // l10n-ignore
                    )),
              ),
            ),
          ),
        ),
      );

  // ---------- Corpo: cartelas de seleção (instalados), caixote (a instalar) e o site ----------
  Widget _stripsBody() {
    final installed = _store.installed().where((p) => _filter == null || p.category == _filter).toList();
    final crate = _store.notInstalled().where((p) => _filter == null || p.category == _filter).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2414), Color(0xFF24160C)],
        ),
        border: Border.all(color: const Color(0xFF6D6A73), width: 1.5),
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            for (var i = 0; i < installed.length; i++) _strip(installed[i], i + 1),
            if (installed.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.jukeboxNothingPlaying, style: const TextStyle(color: _muted), textAlign: TextAlign.center),
              ),
            if (crate.isNotEmpty) ...[
              _crateHeader(),
              for (var i = 0; i < crate.length; i++) _strip(crate[i], installed.length + i + 1, inCrate: true),
            ],
            const SizedBox(height: 8),
            _moreOnSite(),
          ],
        ),
      ),
    );
  }

  /// Cartela de seleção (como os títulos datilografados das jukeboxes): número, código e nome,
  /// categoria e autor, botão ON/OFF e detalhes.
  Widget _strip(PluginInfo p, int number, {bool inCrate = false}) {
    final on = _store.isActive(p);
    final selected = _selectedId == p.id;
    final color = p.category.color;
    final paper = inCrate ? _stripDim : _stripColor;
    return Padding(
      key: ValueKey('strip-${p.id}'), // l10n-ignore
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: paper,
        borderRadius: BorderRadius.circular(5),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _choose(p),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 6),
                top: BorderSide(color: selected ? color : Colors.transparent, width: 2),
                bottom: BorderSide(color: selected ? color : Colors.transparent, width: 2),
                right: BorderSide(color: selected ? color : Colors.transparent, width: 2),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
            child: Row(children: [
              SizedBox(
                width: 34,
                child: Text(number.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: inCrate ? _ink.withValues(alpha: 0.5) : _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace', // l10n-ignore
                    )),
              ),
              Container(width: 2, height: 34, color: _red.withValues(alpha: 0.75)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Text(p.code,
                        style: TextStyle(
                          color: Color.lerp(color, _ink, 0.55),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          fontFamily: 'monospace', // l10n-ignore
                        )),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: inCrate ? _ink.withValues(alpha: 0.65) : _ink, fontWeight: FontWeight.w800, fontSize: 14.5)),
                    ),
                  ]),
                  Text(
                    '${p.category.label} · ${p.isComingSoon ? l10n.jukeboxComingSoon : p.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _ink.withValues(alpha: 0.6), fontSize: 11.5),
                  ),
                ]),
              ),
              const SizedBox(width: 6),
              if (!inCrate) _onOff(p, on),
              if (inCrate) _crateBadge(p),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l10n.jukeboxDetails,
                icon: Icon(Icons.info_outline_rounded, color: _ink.withValues(alpha: 0.75), size: 22),
                onPressed: () => _choose(p),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Botão ON/OFF da cartela: aceso na cor da categoria quando o disco está no prato.
  Widget _onOff(PluginInfo p, bool on) {
    final color = p.category.color;
    final canToggle = _store.canToggle(p);
    return Semantics(
      button: canToggle,
      toggled: on,
      child: GestureDetector(
        onTap: canToggle ? () => _toggle(p) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 46,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: on ? color : const Color(0xFF4A4250),
            border: Border.all(color: _ink.withValues(alpha: 0.5)),
            boxShadow: on ? [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 8)] : null,
          ),
          child: Text(on ? l10n.jukeboxOn : l10n.jukeboxOff,
              style: TextStyle(
                color: on ? _ink : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.8,
              )),
        ),
      ),
    );
  }

  Widget _crateBadge(PluginInfo p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: _ink.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(6)),
        child: Text(
          (p.isComingSoon ? l10n.jukeboxComingSoon : l10n.jukeboxInstall).toUpperCase(),
          style: const TextStyle(color: _stripColor, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
      );

  Widget _crateHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined, color: AppTheme.cream, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.jukeboxCrate, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w800, fontSize: 15)),
              Text(l10n.jukeboxCrateHint, style: const TextStyle(color: _muted, fontSize: 11.5)),
            ]),
          ),
        ]),
      );

  /// Mais plugins no site: no celular, o "Install" de cada um abre o app e instala sozinho.
  Widget _moreOnSite() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.jukeboxMoreOnSiteTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(l10n.jukeboxMoreOnSite, style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => PluginLinks.instance.openUrl(PluginCatalog.siteUrl),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.jukeboxOpenSite),
              style: OutlinedButton.styleFrom(foregroundColor: _amber, side: const BorderSide(color: _amber)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Detalhes de um plugin: disco grande, categoria, autor, licença, descrição e o botão de ligar/desligar.
class _PluginSheet extends StatefulWidget {
  final PluginStore store;
  final PluginInfo plugin;
  final PluginInstaller? installer;
  final LocalLyricsLibrary? myLyrics;
  final List<CloudLyricsFolder> clouds;
  const _PluginSheet({required this.store, required this.plugin, this.installer, this.myLyrics, this.clouds = const []});

  @override
  State<_PluginSheet> createState() => _PluginSheetState();
}

class _PluginSheetState extends State<_PluginSheet> {
  bool _busy = false;
  String? _installError;

  String? _importReport;

  /// Plugin S5: escolher arquivos .lrc (celular, Google Drive, OneDrive, Dropbox) e importar.
  Future<void> _importMyLyrics(LocalLyricsLibrary lib) async {
    setState(() => _busy = true);
    final files = await PluginLinks.instance.pickLyricsFiles();
    final r = files.isEmpty ? null : await lib.importFiles(files);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _importReport = r == null
          ? null
          : [
              l10n.myLyricsImported(r.added),
              if (r.skipped.isNotEmpty) l10n.myLyricsSkipped(r.skipped.take(5).join(', ')),
            ].join('\n');
    });
  }

  /// Resultado da última sincronização de cada nuvem.
  final Map<String, String> _syncReports = {};

  Future<void> _syncCloud(CloudLyricsFolder c, LocalLyricsLibrary lib) async {
    setState(() {
      _busy = true;
      _syncReports.remove(c.cloudId);
    });
    String report;
    try {
      final r = await c.syncInto(lib);
      report = [
        l10n.cloudSynced(c.serviceName, r.added, r.updated, r.removed),
        if (r.skipped.isNotEmpty) l10n.myLyricsSkipped(r.skipped.take(5).join(', ')),
      ].join('\n');
    } catch (_) {
      report = l10n.cloudSyncFailed(c.serviceName);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _syncReports[c.cloudId] = report;
    });
  }

  Future<void> _connectCloud(CloudLyricsFolder c, LocalLyricsLibrary lib) async {
    bool ok = false;
    if (c is WebLoginCloudFolder) {
      ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CloudLoginScreen(folder: c))) == true;
    } else if (c is GoogleDriveFolder) {
      setState(() => _busy = true);
      ok = await c.connect();
      if (mounted) setState(() => _busy = false);
      if (!ok && mounted) setState(() => _syncReports[c.cloudId] = l10n.cloudLoginFailed(c.serviceName));
    }
    if (ok && mounted) await _syncCloud(c, lib);
  }

  static const Map<String, Color> _cloudColors = {
    'dropbox': Color(0xFF3D9AE8), // l10n-ignore
    'onedrive': Color(0xFF2B88D8), // l10n-ignore
    'gdrive': Color(0xFF34A853), // l10n-ignore
  };

  /// Pasta de letras numa nuvem: conectar, sincronizar e desconectar.
  Widget _cloudCard(CloudLyricsFolder c, LocalLyricsLibrary lib) {
    final color = _cloudColors[c.cloudId] ?? const Color(0xFF3D9AE8);
    final hint = switch (c.cloudId) {
      'gdrive' => l10n.gdriveHint(c.folderLabel), // l10n-ignore
      _ => l10n.cloudAppFolderHint(c.folderLabel, c.serviceName),
    };
    final report = _syncReports[c.cloudId];
    return AnimatedBuilder(
      animation: Listenable.merge([c, lib]),
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.cloud_sync, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    c.isConnected ? l10n.cloudConnectedAs(c.serviceName, c.accountName ?? l10n.yourAccount) : c.serviceName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              c.isConnected
                  ? l10n.cloudFolderStatus(c.folderLabel, lib.countFrom(c.cloudId),
                      c.lastSync == null ? l10n.cloudNeverSynced : MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(c.lastSync!)))
                  : hint,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 10),
            if (!c.isConnected)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _connectCloud(c, lib),
                  icon: const Icon(Icons.login),
                  label: Text(l10n.cloudConnect(c.serviceName)),
                  style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                ),
              )
            else
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _syncCloud(c, lib),
                    icon: const Icon(Icons.sync),
                    label: Text(l10n.cloudSyncNow),
                    style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _busy ? null : () => c.disconnect(),
                  child: Text(l10n.disconnect, style: const TextStyle(color: Colors.white54)),
                ),
              ]),
            if (report != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(report, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }

  /// Plugin S5: quantas letras há, importar, direitos autorais e como nomear os arquivos.
  List<Widget> _myLyricsSection(LocalLyricsLibrary lib) {
    return [
      const SizedBox(height: 10),
      AnimatedBuilder(
        animation: lib,
        builder: (context, _) => Text(l10n.myLyricsCount(lib.count),
            style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 6),
      Text(l10n.myLyricsHowTo, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
      const SizedBox(height: 6),
      Text(l10n.myLyricsRights, style: const TextStyle(color: Color(0xFFF6B74A), fontSize: 13, height: 1.4)),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _importMyLyrics(lib),
          icon: const Icon(Icons.folder_open),
          label: Text(l10n.myLyricsImport),
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.plugin.category.color,
            side: BorderSide(color: widget.plugin.category.color),
          ),
        ),
      ),
      if (_importReport != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_importReport!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      for (final c in widget.clouds.where((c) => c.configured)) ...[
        const SizedBox(height: 12),
        _cloudCard(c, lib),
      ],
      if (lib.count > 0)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              await lib.clear();
              if (mounted) setState(() => _importReport = null);
            },
            child: Text(l10n.myLyricsClear, style: const TextStyle(color: Colors.white54)),
          ),
        ),
    ];
  }

  /// Instala pelo site (o mesmo manifesto do botão "Install" do navegador).
  Future<void> _install() async {
    final installer = widget.installer;
    if (installer == null) return;
    setState(() {
      _busy = true;
      _installError = null;
    });
    final r = await installer.install(widget.plugin.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _installError = switch (r) {
        PluginInstallResult.installed || PluginInstallResult.alreadyInstalled || PluginInstallResult.builtIn => null,
        PluginInstallResult.needsUpdate => l10n.pluginNeedsUpdate,
        PluginInstallResult.notFound => l10n.pluginNotFound,
        PluginInstallResult.invalid => l10n.pluginInvalid,
        PluginInstallResult.network => l10n.pluginNetworkError,
      };
    });
  }

  /// Plugin de conexão (Connections): conta do serviço, entrar e sair.
  List<Widget> _connection(PluginInfo p, PluginConnection c) {
    final connected = c.isConnected();
    Future<void> run(Future<void> Function() action) async {
      setState(() => _busy = true);
      try {
        await action();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    return [
      const SizedBox(height: 10),
      Row(
        children: [
          Icon(connected ? Icons.link : Icons.link_off, color: p.category.color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connected ? l10n.connectedAs(c.accountName() ?? l10n.yourAccount) : l10n.jukeboxNotConnected,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          if (connected)
            TextButton(
              onPressed: _busy ? null : () => run(c.disconnect),
              child: Text(l10n.jukeboxDisconnect, style: const TextStyle(color: Colors.white54)),
            ),
        ],
      ),
      if (!connected) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : () => run(() async => await c.connect()),
            icon: const Icon(Icons.login),
            label: Text(l10n.jukeboxConnectAccount(p.name)),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.category.color,
              side: BorderSide(color: p.category.color),
            ),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plugin;
    final store = widget.store;
    final on = store.isActive(p);
    final String status;
    final installed = store.isInstalled(p);
    if (p.isComingSoon) {
      status = l10n.jukeboxComingSoonHint;
    } else if (!installed) {
      status = l10n.jukeboxNotInstalledHint;
    } else if (p.locked) {
      status = l10n.jukeboxLockedHint;
    } else if (p.category.exclusive && on) {
      status = l10n.jukeboxExclusiveHint(p.category.label);
    } else {
      status = on ? l10n.jukeboxIsOn : l10n.jukeboxIsOff;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SevenInchRecord(color: p.category.color, code: p.code, size: 96, spinning: on, dimmed: p.isComingSoon, glow: on),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${p.code} · ${p.category.label}', style: TextStyle(color: p.category.color, fontWeight: FontWeight.w700)),
                      Text(p.author, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(p.description, style: const TextStyle(color: Colors.white70, height: 1.45)),
            const SizedBox(height: 10),
            Text('${l10n.jukeboxLicense}: ${p.license}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (p.category == PluginCategory.ai)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(l10n.jukeboxAiNotice, style: const TextStyle(color: Color(0xFFF6B74A), fontSize: 13)),
              ),
            const SizedBox(height: 14),
            Text(status, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w600)),
            if (store.connectionFor(p) case final c?) ..._connection(p, c),
            if (p.id == PluginCatalog.myLyricsId && installed && widget.myLyrics != null) ..._myLyricsSection(widget.myLyrics!),
            const SizedBox(height: 12),
            if (p.isInstallable && !installed && widget.installer != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _install,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: Text(l10n.jukeboxInstall),
                  style: FilledButton.styleFrom(backgroundColor: p.category.color, foregroundColor: Colors.black),
                ),
              ),
              if (_installError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_installError!, style: const TextStyle(color: Color(0xFFFF8A80))),
                ),
            ],
            if (store.canToggle(p))
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await store.toggle(p);
                    if (mounted) setState(() {});
                  },
                  child: Text(on ? l10n.jukeboxTurnOff : l10n.jukeboxTurnOn),
                ),
              ),
            if (p.isInstallable && installed)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await store.uninstall(p);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.jukeboxUninstall),
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Arco de neon colorido em volta do gabinete da jukebox.
/// Tubo de neon contornando o gabinete, nas cores das categorias.
class _NeonFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect.deflate(1.5),
      topLeft: const Radius.circular(46),
      topRight: const Radius.circular(46),
      bottomLeft: const Radius.circular(14),
      bottomRight: const Radius.circular(14),
    );
    final colors = [for (final c in PluginCategory.values) c.color];
    final shader = SweepGradient(colors: [...colors, colors.first]).createShader(rect);
    canvas.drawRRect(rrect, Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawRRect(rrect, Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2);
  }

  @override
  bool shouldRepaint(covariant _NeonFramePainter oldDelegate) => false;
}
