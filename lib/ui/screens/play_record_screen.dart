import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/track_entry.dart';
import '../../services/album_catalog_service.dart';
import '../../services/collection_service.dart';
import '../../services/tracklist_provider.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import '../widgets/retro_text.dart';
import 'record_found_flow.dart';

/// Disco escolhido para tocar: lista de faixas e se deve entrar na coleção antes.
class PlayRecordChoice {
  final ReleaseCandidate release;
  final List<TrackEntry> tracks;
  final bool addToCollection;
  const PlayRecordChoice({required this.release, required this.tracks, this.addToCollection = false});
}

/// O disco da coleção como "prensagem" (com o id do Discogs, quando houver).
ReleaseCandidate releaseFromCollectionItem(CollectionItem item) => ReleaseCandidate(
      providerId: item.discogsReleaseId != null ? 'discogs' : 'collection', // l10n-ignore
      releaseId: item.discogsReleaseId ?? item.key,
      albumTitle: item.album,
      artistName: item.artist,
      coverUrl: item.coverUrl,
      year: item.year,
      format: item.format,
      label: item.label,
      catalogNumber: item.catalogNumber,
      barcode: item.barcode,
    );

/// Faixas de um disco da coleção: as guardadas no aparelho ou, com o id do Discogs, as da prensagem.
Future<List<TrackEntry>> tracksForCollectionItem(
  CollectionItem item, {
  required List<TrackEntry> Function(String album, String artist) tracklistFor,
  required AlbumCatalogService catalog,
}) async {
  final cached = tracklistFor(item.album, item.artist);
  if (cached.isNotEmpty) return cached;
  if (item.discogsReleaseId == null) return const [];
  try {
    return await catalog.loadTracklist(releaseFromCollectionItem(item));
  } catch (_) {
    return const [];
  }
}

/// "Play a record" (toque no logo sem nada tocando): busca por artista e/ou disco — primeiro a coleção
/// do usuário (inteira com o campo vazio), depois o Discogs. Escolhido o disco, mostra as faixas e
/// "Play and add to collection" / "Just play" (ou só "Play", se o disco já é da coleção).
class PlayRecordScreen extends StatefulWidget {
  final CollectionService collection;
  final AlbumCatalogService catalog;
  final List<TrackEntry> Function(String album, String artist) tracklistFor;

  const PlayRecordScreen({super.key, required this.collection, required this.catalog, required this.tracklistFor});

  @override
  State<PlayRecordScreen> createState() => _PlayRecordScreenState();
}

class _PlayRecordScreenState extends State<PlayRecordScreen> {
  final TextEditingController _query = TextEditingController();
  AlbumCatalogResult? _remote;
  bool _searching = false;
  String? _remoteError;
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    widget.collection.load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<CollectionItem> get _collectionMatches {
    final words = _query.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final all = widget.collection.items(sort: CollectionSort.alphabetical);
    if (words.isEmpty) return all;
    return all.where((i) {
      final text = '${i.album} ${i.artist}'.toLowerCase();
      return words.every(text.contains);
    }).toList();
  }

  Future<void> _searchRemote() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final id = ++_searchId;
    setState(() {
      _searching = true;
      _remoteError = null;
    });
    try {
      final result = await widget.catalog.search(q);
      if (!mounted || id != _searchId) return;
      setState(() {
        _remote = result;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _searching = false;
        _remoteError = l10n.searchFailed;
      });
    }
  }

  Future<void> _open(ReleaseCandidate release, {CollectionItem? item}) async {
    final choice = await Navigator.of(context).push<PlayRecordChoice>(MaterialPageRoute(
      builder: (_) => _RecordTracksScreen(
        release: release,
        inCollection: item != null || widget.collection.contains(release.albumTitle, release.artistName ?? ''),
        loadTracks: () => item != null
            ? tracksForCollectionItem(item, tracklistFor: widget.tracklistFor, catalog: widget.catalog)
            : widget.catalog.loadTracklist(release),
      ),
    ));
    if (choice != null && mounted) Navigator.of(context).pop(choice);
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: RetroText(text, fontSize: 22, depth: 2),
      );

  Widget _tile({required String? cover, required String title, required String subtitle, required VoidCallback onTap}) =>
      Card(
        color: AppTheme.surface,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          leading: RecordCover(url: cover, size: 52),
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: onTap,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mine = _collectionMatches;
    final remote = _remote;
    final hasQuery = _query.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.cream,
        title: RetroText(l10n.playRecordTitle, fontSize: 28, depth: 3),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: WoodBackground()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: TextField(
                  controller: _query,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: AppTheme.cream),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _searchRemote(),
                  decoration: InputDecoration(
                    hintText: l10n.playRecordSearchHint,
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: AppTheme.surface,
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: hasQuery
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () => setState(() {
                              _query.clear();
                              _remote = null;
                              _remoteError = null;
                            }),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  children: [
                    _header(l10n.playRecordMyCollection),
                    if (mine.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Text(
                          widget.collection.count == 0 ? l10n.playRecordEmptyCollection : l10n.playRecordNoCollectionMatch,
                          style: const TextStyle(color: Colors.white60),
                        ),
                      )
                    else
                      for (final i in mine)
                        _tile(
                          cover: i.coverUrl,
                          title: i.album,
                          subtitle: [i.artist, i.year, i.format].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                          onTap: () => _open(releaseFromCollectionItem(i), item: i),
                        ),
                    if (hasQuery) ...[
                      if (remote == null && !_searching)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton.icon(
                            onPressed: _searchRemote,
                            icon: const Icon(Icons.travel_explore),
                            label: Text(l10n.playRecordSearchMore),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.cream,
                              minimumSize: const Size.fromHeight(46),
                              side: const BorderSide(color: AppTheme.wood),
                            ),
                          ),
                        ),
                      if (_searching)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.orange)),
                        ),
                      if (_remoteError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_remoteError!, style: const TextStyle(color: AppTheme.orange)),
                        ),
                      if (remote != null && !_searching) ...[
                        _header(l10n.playRecordFrom(remote.source == 'musicbrainz' ? 'MusicBrainz' : 'Discogs')), // l10n-ignore
                        if (remote.notice != null)
                          Text(remote.notice!, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                        if (remote.albums.isEmpty)
                          Text(l10n.signUpNoResults, style: const TextStyle(color: Colors.white60))
                        else
                          for (final a in remote.albums)
                            _tile(
                              cover: a.coverUrl,
                              title: a.albumTitle,
                              subtitle: [a.artistName, a.year, a.country, a.format, a.label]
                                  .whereType<String>()
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              onTap: () => _open(a),
                            ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Um disco escolhido: capa, dados e faixas; "Play" (já é da coleção) ou "Play and add to collection"
/// / "Just play".
class _RecordTracksScreen extends StatefulWidget {
  final ReleaseCandidate release;
  final bool inCollection;
  final Future<List<TrackEntry>> Function() loadTracks;

  const _RecordTracksScreen({required this.release, required this.inCollection, required this.loadTracks});

  @override
  State<_RecordTracksScreen> createState() => _RecordTracksScreenState();
}

class _RecordTracksScreenState extends State<_RecordTracksScreen> {
  List<TrackEntry>? _tracks;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    widget.loadTracks().then((t) {
      if (mounted) setState(() => _tracks = t);
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _choose(bool add) {
    final tracks = _tracks;
    if (tracks == null || tracks.isEmpty) return;
    Navigator.of(context).pop(PlayRecordChoice(release: widget.release, tracks: tracks, addToCollection: add));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    final tracks = _tracks;
    final ready = tracks != null && tracks.isNotEmpty;
    final noTracks = _failed || (tracks != null && tracks.isEmpty);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(backgroundColor: AppTheme.surface, foregroundColor: AppTheme.cream),
      body: Stack(
        children: [
          const Positioned.fill(child: WoodBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecordCover(url: r.coverUrl, size: 110),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RetroText(r.albumTitle, fontSize: 26, depth: 3, maxLines: 3),
                        if (r.artistName != null) Text(r.artistName!, style: const TextStyle(color: Colors.white70)),
                        Text([r.year, r.country, r.format, r.label, r.catalogNumber].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        if (widget.inCollection)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(children: [
                              const Icon(Icons.library_music, size: 15, color: AppTheme.orange),
                              const SizedBox(width: 4),
                              Text(l10n.playRecordInCollection, style: const TextStyle(color: AppTheme.orange, fontSize: 12.5)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Botões logo abaixo da capa e dos dados
              if (widget.inCollection)
                FilledButton.icon(
                  onPressed: ready ? () => _choose(false) : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.playRecordPlay),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.orange, minimumSize: const Size.fromHeight(50)),
                )
              else ...[
                FilledButton.icon(
                  onPressed: ready ? () => _choose(true) : null,
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.playRecordPlayAndAdd),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.orange, minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: ready ? () => _choose(false) : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(l10n.playRecordJustPlay),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.cream,
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppTheme.wood),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              RetroText(l10n.tracklist, fontSize: 22, depth: 2),
              const SizedBox(height: 6),
              if (tracks == null && !_failed)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(color: AppTheme.orange)),
                )
              else if (noTracks)
                Text(l10n.playRecordNoTracks, style: const TextStyle(color: AppTheme.orange))
              else
                for (final t in tracks!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 38,
                          child: Text(t.number ?? '${t.position}',
                              style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ),
                        Expanded(
                          child: Text(t.artist == null ? t.title : '${t.title} — ${t.artist}',
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                        ),
                        if ((t.lengthMs ?? 0) > 0)
                          Text(_mmss(t.lengthMs!), style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  static String _mmss(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
