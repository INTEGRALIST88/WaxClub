import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../engine/waxclub_engine.dart';
import '../../services/album_catalog_service.dart';
import '../../services/tracklist_matcher.dart';
import '../../services/tracklist_provider.dart';
import '../screens/discogs_login_screen.dart';
import '../theme/app_theme.dart';

/// Abre a janela "Mudar disco": lista todos os discos em que a música atual aparece (Discogs ou
/// MusicBrainz), permite buscar à mão e aplica o disco escolhido como padrão do usuário.
Future<void> showAlbumPickerSheet(
  BuildContext context, {
  required WaxClubEngine engine,
  required AlbumCatalogService catalog,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => AlbumPickerSheet(engine: engine, catalog: catalog, scrollController: scroll),
    ),
  );
}

/// Texto que explica a vantagem de conectar a conta Discogs (exibido ao marcar "Consultar Discogs").
String get kDiscogsBenefitsText => l10n.discogsExplanation;

class AlbumPickerSheet extends StatefulWidget {
  final WaxClubEngine engine;
  final AlbumCatalogService catalog;
  final ScrollController? scrollController;

  const AlbumPickerSheet({super.key, required this.engine, required this.catalog, this.scrollController});

  @override
  State<AlbumPickerSheet> createState() => _AlbumPickerSheetState();
}

class _AlbumPickerSheetState extends State<AlbumPickerSheet> {
  final TextEditingController _query = TextEditingController();
  AlbumCatalogResult? _result;
  bool _loading = true;
  String? _applyingId;
  String? _error;
  int _searchGen = 0;

  String get _title => widget.engine.currentTrack?.title ?? '';
  String get _artist => widget.engine.currentTrack?.artist ?? '';
  String? get _currentAlbum => widget.engine.lockedAlbumName ?? widget.engine.currentTrack?.album;

  @override
  void initState() {
    super.initState();
    widget.catalog.auth.load().then((_) => _reload());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_searchGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text = _query.text.trim();
      final result = text.isEmpty
          ? await widget.catalog.albumsForTrack(title: _title, artist: _artist, currentAlbum: _currentAlbum)
          : await widget.catalog.search(text, artist: _artist, currentAlbum: _currentAlbum);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _loading = false;
        _error = l10n.searchFailed;
      });
    }
  }

  /// Caixa "Consultar Discogs": sem conta conectada, explica a vantagem e leva à tela de login.
  Future<void> _toggleDiscogs(bool value) async {
    final auth = widget.catalog.auth;
    if (!value) {
      await auth.setEnabled(false);
      await _reload();
      return;
    }
    if (auth.isLoggedIn) {
      await auth.setEnabled(true);
      await _reload();
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            Icon(Icons.album, color: AppTheme.cream),
            SizedBox(width: 10),
            Expanded(child: Text(l10n.connectDiscogs, style: const TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(kDiscogsBenefitsText, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.cream, foregroundColor: Colors.black),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DiscogsLoginScreen(auth: auth)),
    );
    if (!mounted) return;
    if (connected == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(l10n.discogsConnectedAs(auth.username ?? l10n.you), style: const TextStyle(color: Colors.white)),
      ));
      await _reload();
    } else {
      setState(() {});
    }
  }

  Future<void> _logoutDiscogs() async {
    await widget.catalog.auth.logout();
    await _reload();
  }

  Future<void> _choose(ReleaseCandidate album) async {
    if (_applyingId != null) return;
    setState(() => _applyingId = album.releaseId);
    try {
      final tracks = await widget.catalog.loadTracklist(album);
      if (!mounted) return;
      if (tracks.isEmpty) {
        _snack(l10n.loadTracksFailed);
        return;
      }
      if (TracklistMatcher.findIndex(tracks, _title) == -1) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: Text(l10n.songNotOnRecord, style: const TextStyle(color: Colors.white)),
            content: Text(
              l10n.songNotOnRecordBody(_title, album.albumTitle),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.back)),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.use)),
            ],
          ),
        );
        if (proceed != true || !mounted) return;
      }
      await widget.engine.applyUserAlbumChoice(
        albumTitle: album.albumTitle,
        tracklist: tracks,
        coverUrl: album.coverUrl,
        releaseId: album.releaseId,
        releaseFormat: album.format,
        source: album.providerId,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppTheme.surfaceLight,
        content: Text(
          l10n.recordChanged(album.albumTitle),
          style: const TextStyle(color: Colors.white),
        ),
      ));
    } catch (e) {
      _snack(l10n.useRecordFailed(e.toString().replaceFirst('Exception: ', '') /* l10n-ignore */));
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppTheme.surfaceLight,
      content: Text(text, style: const TextStyle(color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.catalog.auth;
    final albums = _result?.albums ?? const <ReleaseCandidate>[];

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              const Icon(Icons.swap_horiz, color: AppTheme.cream),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.changeRecord,
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text(l10n.recordsWithSong(_title, _artist),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        // Caixa "Consultar Discogs"
        CheckboxListTile(
          dense: true,
          value: auth.isEnabled,
          onChanged: (v) => _toggleDiscogs(v ?? false),
          activeColor: AppTheme.cream,
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(l10n.searchDiscogs, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
          subtitle: Text(
            auth.isLoggedIn
                ? l10n.connectedAs(auth.username ?? l10n.yourAccount)
                : l10n.discogsSearchSubtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          secondary: auth.isLoggedIn
              ? TextButton(onPressed: _logoutDiscogs, child: Text(l10n.signOut, style: const TextStyle(color: Colors.white54)))
              : null,
        ),
        // Busca manual
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _reload(),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: l10n.searchAnotherRecord,
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: () {
                        _query.clear();
                        _reload();
                      },
                    ),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.carveLight),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        _sourceLine(),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.cream))
              : _error != null
                  ? _message(Icons.wifi_off, _error!)
                  : albums.isEmpty
                      ? _message(Icons.album_outlined, l10n.noRecordsFound)
                      : ListView.separated(
                          controller: widget.scrollController,
                          itemCount: albums.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (_, i) => _albumTile(albums[i]),
                        ),
        ),
      ],
    );
  }

  Widget _sourceLine() {
    final r = _result;
    if (r == null || _loading) return const SizedBox(height: 4);
    final name = r.source == 'discogs' ? 'Discogs' : 'MusicBrainz'; // l10n-ignore
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Icon(r.notice != null ? Icons.info_outline : Icons.storage, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              r.notice ?? l10n.recordsFromSource(r.albums.length, name),
              style: TextStyle(color: r.notice != null ? Colors.amber.shade200 : Colors.white38, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppTheme.textInactive),
              const SizedBox(height: 10),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
            ],
          ),
        ),
      );

  Widget _albumTile(ReleaseCandidate a) {
    final current = _currentAlbum;
    final isCurrent = current != null && TracklistMatcher.similarity(a.albumTitle, current) >= 0.9;
    final details = [
      if (a.artistName != null) a.artistName!,
      if (a.year != null) a.year!,
      if (a.country != null) a.country!,
    ].join(' • ');
    final applying = _applyingId == a.releaseId;

    return ListTile(
      onTap: applying ? null : () => _choose(a),
      tileColor: isCurrent ? AppTheme.cream.withValues(alpha: 0.10) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 52,
          height: 52,
          child: a.coverUrl != null
              ? Image.network(a.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _coverPlaceholder())
              : _coverPlaceholder(),
        ),
      ),
      title: Text(a.albumTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty)
              Text(details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: [
                if (isCurrent) _chip(l10n.chipCurrent, AppTheme.cream),
                if (a.isVinyl) _chip(l10n.chipVinyl, Colors.amber),
                if (!a.isVinyl && a.format != null) _chip(a.format!.split(',').first, Colors.white54),
                if (a.isCompilation) _chip(l10n.chipCompilation, AppTheme.rust),
                if (a.isLive) _chip(l10n.chipLive, AppTheme.orange),
                if (a.editions > 1) _chip(l10n.editionsCount(a.editions), Colors.white38),
              ],
            ),
          ],
        ),
      ),
      trailing: applying
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cream))
          : const Icon(Icons.chevron_right, color: Colors.white38),
    );
  }

  Widget _coverPlaceholder() => Container(
        color: AppTheme.surfaceLight,
        child: const Icon(Icons.album, color: AppTheme.cream),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
      );
}
