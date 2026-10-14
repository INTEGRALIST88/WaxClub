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
import '../widgets/seven_inch_record.dart';

/// Página de plugins em forma de jukebox: cada plugin é um compacto de 7" cuja cor diz a categoria
/// (Language, Display, AI...). Seleciona-se pelo código da cartela (teclado da jukebox) ou tocando no disco.
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
  static const Color _panel2 = Color(0xFF221B2A);
  static const Color _line = Color(0xFF3A3045);
  static const Color _muted = Color(0xFFA99FB5);
  static const Color _stripColor = Color(0xFFF3EAD6);
  static const Color _ink = Color(0xFF2B2231);
  static const Color _amber = Color(0xFFF6B74A);

  PluginStore get _store => widget.store;
  String _typed = '';
  String? _message;
  String? _selectedId;
  PluginCategory? _filter;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  void _press(String key) {
    setState(() {
      if (key == 'clear') { // l10n-ignore
        _typed = '';
        _message = null;
        return;
      }
      final cat = PluginCategory.fromLetter(key);
      if (cat != null) {
        _typed = key;
        _message = l10n.jukeboxNowNumber(cat.label);
      } else if (_typed.length == 1) {
        _typed += key;
        _message = l10n.jukeboxPressSelect;
      } else {
        _message = l10n.jukeboxStartWithLetter;
      }
    });
  }

  void _selectTyped() {
    if (_typed.length < 2) {
      setState(() => _message = l10n.jukeboxTypeCode);
      return;
    }
    final code = _typed;
    setState(() => _typed = '');
    final p = _store.byCode(code);
    if (p == null) {
      setState(() => _message = l10n.jukeboxNoSuchCode(code));
      return;
    }
    _open(p);
  }

  Future<void> _open(PluginInfo p) async {
    setState(() {
      _selectedId = p.id;
      _message = '${p.code} · ${p.name}';
    });
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PluginSheet(store: _store, plugin: p, installer: widget.installer, myLyrics: widget.myLyrics, clouds: widget.clouds),
    );
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
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Text(l10n.jukeboxLede, style: const TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 16),
            _cabinet(),
            const SizedBox(height: 22),
            _sectionTitle(l10n.jukeboxOnThePlatter),
            _platter(),
            const SizedBox(height: 22),
            _sectionTitle(l10n.jukeboxSelectionStrips),
            _filters(),
            const SizedBox(height: 10),
            _strips(),
            if (_store.notInstalled().isNotEmpty) ...[
              const SizedBox(height: 22),
              _sectionTitle(l10n.jukeboxCrate),
              Text(l10n.jukeboxCrateHint, style: const TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 10),
              _crate(),
            ],
            const SizedBox(height: 22),
            _moreOnSite(),
            const SizedBox(height: 22),
            _legend(),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
      );

  // ---------- Gabinete: vitrine, mostrador e teclado ----------
  Widget _cabinet() {
    final installed = _store.installed();
    return CustomPaint(
      painter: _NeonArchPainter(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(150), bottom: Radius.circular(18)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2E1C), Color(0xFF2A1A10), Color(0xFF1A110B)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text('WAXCLUB', // l10n-ignore
                style: TextStyle(color: AppTheme.cream, fontSize: 15, letterSpacing: 6, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            // Vitrine com os compactos instalados
            Container(
              padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0910),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(110), bottom: Radius.circular(10)),
                border: Border.all(color: _line),
                gradient: RadialGradient(
                  center: const Alignment(0, -1),
                  radius: 1.2,
                  colors: [PluginCategory.ai.color.withValues(alpha: 0.18), const Color(0xFF0B0910)],
                ),
              ),
              child: SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: installed.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final p = installed[i];
                    final on = _store.isActive(p);
                    final selected = _selectedId == p.id;
                    return GestureDetector(
                      onTap: () => _open(p),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSlide(
                            offset: selected ? const Offset(0, -0.05) : Offset.zero,
                            duration: const Duration(milliseconds: 300),
                            child: SevenInchRecord(color: p.category.color, code: p.code, size: 80, glow: on || selected),
                          ),
                          const SizedBox(height: 6),
                          Text(p.code,
                              style: TextStyle(
                                color: on ? Colors.white : _muted,
                                fontFamily: 'monospace', // l10n-ignore
                                fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                              )),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Mostrador
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF050407), borderRadius: BorderRadius.circular(10), border: Border.all(color: _line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_typed.isNotEmpty ? _typed[0] : '_'} ${_typed.length > 1 ? _typed[1] : '_'}',
                    style: const TextStyle(
                      color: _amber,
                      fontSize: 26,
                      letterSpacing: 5,
                      fontFamily: 'monospace', // l10n-ignore
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Color(0x99F6B74A), blurRadius: 10)],
                    ),
                  ),
                  Text(_message ?? l10n.jukeboxChooseSelection, style: const TextStyle(color: _muted, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _keypad(),
          ],
        ),
      ),
    );
  }

  Widget _keypad() {
    Widget key(String label, VoidCallback onTap, {Color? top, Color? bottom, Color textColor = _ink, int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Ink(
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [top ?? const Color(0xFFFBF6EA), bottom ?? const Color(0xFFDDD2BB)],
                  ),
                  boxShadow: const [BoxShadow(color: Color(0xFF8E8170), offset: Offset(0, 3))],
                ),
                child: Center(
                  child: Text(label,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace', // l10n-ignore
                        fontSize: label.length > 2 ? 13 : 16,
                      )),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final letters = [
      for (final c in PluginCategory.values)
        key(c.letter, () => _press(c.letter),
            top: Color.lerp(c.color, Colors.white, 0.75), bottom: Color.lerp(c.color, Colors.white, 0.35)),
    ];
    final digits = [for (var i = 1; i <= 9; i++) '$i'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        children: [
          Row(children: letters),
          Row(children: [for (final d in digits.sublist(0, 5)) key(d, () => _press(d))]),
          Row(children: [for (final d in digits.sublist(5)) key(d, () => _press(d)), key('0', () => _press('0'))]),
          Row(children: [
            key(l10n.jukeboxClear, () => _press('clear'), flex: 2), // l10n-ignore
            key(l10n.jukeboxSelect, _selectTyped,
                flex: 3, top: const Color(0xFFFF9D7A), bottom: const Color(0xFFE8673F), textColor: Colors.white),
          ]),
        ],
      ),
    );
  }

  // ---------- No prato ----------
  Widget _platter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
      child: Column(
        children: [
          for (final c in PluginCategory.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.label, style: TextStyle(color: c.color, fontWeight: FontWeight.w800)),
                        Text(c.rule, style: const TextStyle(color: _muted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _store.activeIn(c).isEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(l10n.jukeboxNothingPlaying, style: const TextStyle(color: _muted, fontSize: 13)),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final p in _store.activeIn(c))
                                GestureDetector(
                                  onTap: () => _open(p),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                                    decoration: BoxDecoration(color: _panel2, borderRadius: BorderRadius.circular(999)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SevenInchRecord(color: c.color, code: p.code, size: 40, spinning: true),
                                        const SizedBox(width: 8),
                                        Flexible(child: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13))),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Cartelas ----------
  Widget _filters() {
    Widget chip(String label, PluginCategory? c) {
      final on = _filter == c;
      return ChoiceChip(
        selected: on,
        onSelected: (_) => setState(() => _filter = c),
        showCheckmark: false,
        backgroundColor: _panel,
        selectedColor: _panel2,
        side: BorderSide(color: on ? (c?.color ?? Colors.white) : _line),
        avatar: c == null ? null : CircleAvatar(radius: 5, backgroundColor: c.color),
        label: Text(label, style: TextStyle(color: on ? Colors.white : _muted, fontSize: 13)),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: [
      chip(l10n.jukeboxAll, null),
      for (final c in PluginCategory.values) chip(c.label, c),
    ]);
  }

  Widget _strips() {
    final list = _store.catalog.where((p) => _store.isInstalled(p) && (_filter == null || p.category == _filter)).toList();
    return Column(children: [for (final p in list) _strip(p)]);
  }

  Widget _strip(PluginInfo p) {
    final on = _store.isActive(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _stripColor,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(p),
          child: Container(
            decoration: BoxDecoration(border: on ? Border.all(color: p.category.color, width: 3) : null, borderRadius: BorderRadius.circular(4)),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 56,
                    color: p.category.color,
                    alignment: Alignment.center,
                    child: Text(p.code,
                        style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace')), // l10n-ignore
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(p.name, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 14.5))),
                              _badge(p),
                            ],
                          ),
                          Text(p.author, style: const TextStyle(color: _ink, fontSize: 12)),
                          Text(p.license, style: const TextStyle(color: Color(0xFF6B5D48), fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(PluginInfo p) {
    final String text;
    final Color bg;
    final Color fg;
    if (p.isComingSoon) {
      text = l10n.jukeboxComingSoon;
      bg = const Color(0xFF6B5D48);
      fg = _stripColor;
    } else if (_store.isActive(p)) {
      text = l10n.jukeboxOnPlatter;
      bg = _ink;
      fg = _stripColor;
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text.toUpperCase(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
    );
  }

  // ---------- Caixote (em breve / para instalar) ----------
  Widget _crate() {
    final list = _store.notInstalled();
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 3 : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final p in list)
            SizedBox(
              width: w,
              child: Material(
                color: _panel2,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _open(p),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          SevenInchRecord(color: p.category.color, code: p.code, size: 46, dimmed: p.isComingSoon),
                          const SizedBox(width: 10),
                          Expanded(child: Text(p.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 6),
                        Text('${p.category.label} · ${p.isComingSoon ? l10n.jukeboxComingSoon : p.author}',
                            style: const TextStyle(color: _muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  /// Mais plugins no site: no celular, o "Install" de cada um abre o app e instala sozinho.
  Widget _moreOnSite() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            for (final c in PluginCategory.values) ...[
              SevenInchRecord(color: c.color, code: '', size: 24),
              const SizedBox(width: 4),
            ],
          ]),
          const SizedBox(height: 10),
          Text(l10n.jukeboxMoreOnSiteTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(l10n.jukeboxMoreOnSite, style: const TextStyle(color: _muted, fontSize: 13, height: 1.4)),
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

  Widget _legend() {
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        for (final c in PluginCategory.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            SevenInchRecord(color: c.color, code: '', size: 22),
            const SizedBox(width: 8),
            Text('${c.letter} · ${c.label}', style: const TextStyle(color: _muted, fontSize: 13)),
          ]),
      ],
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

  /// Plugin S5: escolher arquivos .lrc/.txt (celular, Google Drive, OneDrive, Dropbox) e importar.
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
class _NeonArchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect.deflate(1.5),
      topLeft: const Radius.circular(150),
      topRight: const Radius.circular(150),
      bottomLeft: const Radius.circular(18),
      bottomRight: const Radius.circular(18),
    );
    final colors = [
      PluginCategory.display.color,
      PluginCategory.ai.color,
      const Color(0xFFF6B74A),
      PluginCategory.language.color,
    ];
    final shader = SweepGradient(colors: [...colors, colors.first]).createShader(rect);
    canvas.drawRRect(rrect, Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(rrect, Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _NeonArchPainter oldDelegate) => false;
}
