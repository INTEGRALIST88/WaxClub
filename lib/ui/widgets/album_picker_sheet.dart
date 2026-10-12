import 'package:flutter/material.dart';
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
const String kDiscogsBenefitsText =
    'O Discogs é a maior base de discos de vinil do mundo, mantida por colecionadores: cada prensagem, '
    'edição nacional e importada, coletâneas, lados A/B, capas e listas de faixas.\n\n'
    'Conectando a sua conta, o WaxClub consulta essa base para encontrar exatamente o disco que está '
    'na sua vitrola — e acerta a ordem das músicas, os lados e a capa.\n\n'
    'O acesso fica guardado com segurança só neste celular, para as próximas vezes. O app apenas '
    'consulta o catálogo (não altera a sua coleção) e você pode desconectar quando quiser.';

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
        _error = 'Não foi possível consultar os discos agora. Verifique a internet.';
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
        title: const Row(
          children: [
            Icon(Icons.album, color: AppTheme.neonCyan),
            SizedBox(width: 10),
            Expanded(child: Text('Conectar sua conta Discogs', style: TextStyle(color: Colors.white, fontSize: 18))),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(kDiscogsBenefitsText, style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.neonCyan, foregroundColor: Colors.black),
            child: const Text('OK'),
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
        content: Text('Discogs conectado como ${auth.username ?? "você"}.', style: const TextStyle(color: Colors.white)),
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
        _snack('Não foi possível carregar as faixas deste disco. Tente outro ou outra base.');
        return;
      }
      if (TracklistMatcher.findIndex(tracks, _title) == -1) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text('Música não encontrada no disco', style: TextStyle(color: Colors.white)),
            content: Text(
              '"$_title" não aparece na lista de faixas de "${album.albumTitle}". Usar este disco mesmo assim?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usar')),
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
          'Disco alterado para "${album.albumTitle}". Ele passa a ser o padrão para estas músicas.',
          style: const TextStyle(color: Colors.white),
        ),
      ));
    } catch (e) {
      _snack('Não foi possível usar este disco: ${e.toString().replaceFirst('Exception: ', '')}');
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
              const Icon(Icons.swap_horiz, color: AppTheme.neonCyan),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mudar disco',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Discos com "$_title" — $_artist',
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
          activeColor: AppTheme.neonCyan,
          checkColor: Colors.black,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Consultar Discogs', style: TextStyle(color: Colors.white, fontSize: 14.5)),
          subtitle: Text(
            auth.isLoggedIn
                ? 'Conectado como ${auth.username ?? "sua conta"}'
                : 'Base mais completa de vinis e coletâneas (requer sua conta)',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          secondary: auth.isLoggedIn
              ? TextButton(onPressed: _logoutDiscogs, child: const Text('Sair', style: TextStyle(color: Colors.white54)))
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
              hintText: 'Buscar outro disco (artista, título...)',
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
              ? const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
              : _error != null
                  ? _message(Icons.wifi_off, _error!)
                  : albums.isEmpty
                      ? _message(Icons.album_outlined, 'Nenhum disco encontrado. Tente buscar pelo nome do disco.')
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
    final name = r.source == 'discogs' ? 'Discogs' : 'MusicBrainz';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Icon(r.notice != null ? Icons.info_outline : Icons.storage, size: 14, color: Colors.white38),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              r.notice ?? '${r.albums.length} discos • base $name',
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
      tileColor: isCurrent ? AppTheme.neonCyan.withValues(alpha: 0.10) : null,
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
                if (isCurrent) _chip('Atual', AppTheme.neonCyan),
                if (a.isVinyl) _chip('Vinil', Colors.amber),
                if (!a.isVinyl && a.format != null) _chip(a.format!.split(',').first, Colors.white54),
                if (a.isCompilation) _chip('Coletânea', AppTheme.neonPink),
                if (a.isLive) _chip('Ao vivo', AppTheme.neonPurple),
                if (a.editions > 1) _chip('${a.editions} edições', Colors.white38),
              ],
            ),
          ],
        ),
      ),
      trailing: applying
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.neonCyan))
          : const Icon(Icons.chevron_right, color: Colors.white38),
    );
  }

  Widget _coverPlaceholder() => Container(
        color: AppTheme.surfaceLight,
        child: const Icon(Icons.album, color: AppTheme.neonCyan),
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
