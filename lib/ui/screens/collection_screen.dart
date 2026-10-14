import 'package:flutter/material.dart';
import '../widgets/retro_text.dart';
import '../../l10n/l10n.dart';
import '../../models/track_entry.dart';
import '../../services/account/account_service.dart';
import '../../services/collection_service.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';
import '../../services/plugins/plugin_catalog.dart';
import '../widgets/wood_tile_button.dart';
import 'sync_screen.dart';

/// Datas relativas da coleção e da conta ("Today 14:05", "Yesterday 09:10"...).
class CollectionScreenFormat {
  static String when(DateTime? when, {DateTime? now}) => _CollectionScreenState.formatWhen(when, now: now);
}

/// Tela "My Collection": os discos do usuário com quantas vezes e quando cada um foi ouvido.
class CollectionScreen extends StatefulWidget {
  final CollectionService collection;

  /// Lista de faixas conhecida de um disco (cache do app / trilhas), para o detalhe.
  final List<TrackEntry> Function(String album, String artist) tracklistFor;

  /// Conta WaxClub (botão da nuvem no topo: sincronização); sem ela o botão não aparece.
  final AccountService? account;

  /// Plugin C1 (Discogs), mostrado na tela de sincronização.
  final PluginConnection? discogs;

  /// Botão "+": adicionar um disco (abre o Identify).
  final VoidCallback? onAddRecord;

  /// "Play" no detalhe de um disco: prepara o disco para tocar.
  final void Function(CollectionItem item)? onPlayItem;

  const CollectionScreen({
    super.key,
    required this.collection,
    required this.tracklistFor,
    this.account,
    this.discogs,
    this.onAddRecord,
    this.onPlayItem,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  CollectionSort _sort = CollectionSort.recentlyPlayed;

  static Map<CollectionSort, String> get _sortLabels => {
        CollectionSort.recentlyPlayed: l10n.sortRecentlyPlayed,
        CollectionSort.mostPlayed: l10n.sortMostPlayed,
        CollectionSort.recentlyAdded: l10n.sortRecentlyAdded,
        CollectionSort.alphabetical: l10n.sortAlphabetical,
      };

  @override
  void initState() {
    super.initState();
    widget.collection.load();
  }

  static String formatWhen(DateTime? when, {DateTime? now}) {
    if (when == null) return l10n.whenNever;
    final n = now ?? DateTime.now();
    final d = n.difference(when);
    if (d.inMinutes < 1) return l10n.whenJustNow;
    if (d.inHours < 1) return l10n.whenMinutesAgo(d.inMinutes);
    if (d.inDays < 1 && n.day == when.day) return l10n.whenToday(_hhmm(when));
    if (d.inDays < 2) return l10n.whenYesterday(_hhmm(when));
    return '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year} ${_hhmm(when)}';
  }

  static String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.collection,
      builder: (context, _) {
        final items = widget.collection.items(sort: _sort);
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.cream,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RetroText(l10n.myCollection, fontSize: 26, depth: 3),
                Text(l10n.recordCount(items.length),
                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
            actions: [
              if (widget.onAddRecord != null)
                WoodTileButton(
                  asset: 'assets/images/btn_add.png',
                  label: l10n.collectionAddRecord,
                  onPressed: widget.onAddRecord!,
                  size: 36,
                ),
              if (widget.account != null)
                WoodTileButton(
                  asset: 'assets/images/btn_cloud.png',
                  label: l10n.syncTooltip,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SyncScreen(account: widget.account!, discogs: widget.discogs)),
                  ),
                  size: 36,
                ),
              PopupMenuButton<CollectionSort>(
                tooltip: l10n.sort,
                icon: const Icon(Icons.sort_rounded),
                initialValue: _sort,
                color: AppTheme.surfaceLight,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final s in CollectionSort.values)
                    PopupMenuItem(value: s, child: Text(_sortLabels[s]!, style: const TextStyle(color: AppTheme.cream))),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: WoodBackground()),
              if (items.isEmpty)
                _emptyState()
              else
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _tile(items[i]),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_music_outlined, size: 64, color: AppTheme.wood),
              SizedBox(height: 16),
              RetroText(l10n.collectionEmpty, fontSize: 28, depth: 3, maxLines: 2, textAlign: TextAlign.center),
              SizedBox(height: 10),
              Text(
                l10n.collectionEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
            ],
          ),
        ),
      );

  Widget _cover(String? url, double size) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: (url != null && url.isNotEmpty)
              ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _coverPlaceholder(size))
              : _coverPlaceholder(size),
        ),
      );

  Widget _coverPlaceholder(double size) => Container(
        color: AppTheme.surfaceLight,
        child: Icon(Icons.album, color: AppTheme.wood, size: size * 0.6),
      );

  Widget _tile(CollectionItem item) {
    final stats = widget.collection.statsFor(item.album, item.artist);
    return Material(
      color: AppTheme.surface.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _cover(item.coverUrl, 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RetroText(item.album, fontSize: 21, depth: 2),
                    const SizedBox(height: 2),
                    Text(item.artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      stats.playCount == 0
                          ? l10n.notPlayedYet
                          : l10n.playedTimesLast(stats.playCount, formatWhen(stats.lastPlayedAt)),
                      style: const TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(CollectionItem item) {
    final stats = widget.collection.statsFor(item.album, item.artist);
    final history = widget.collection.historyFor(item.album, item.artist);
    final tracks = widget.tracklistFor(item.album, item.artist);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _cover(item.coverUrl, 92),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RetroText(item.album, fontSize: 26, depth: 3, maxLines: 3),
                      const SizedBox(height: 3),
                      Text(item.artist, style: const TextStyle(color: Colors.white70)),
                      if (item.year != null || item.format != null)
                        Text([item.year, item.format].whereType<String>().join(' · '),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.onPlayItem != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onPlayItem!(item);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.playRecordPlay),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.orange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _stat(l10n.plays, '${stats.playCount}'),
                _stat(l10n.firstPlayed, formatWhen(stats.firstPlayedAt)),
                _stat(l10n.lastPlayed, formatWhen(stats.lastPlayedAt)),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.addedWhen(formatWhen(item.addedAt)), style: const TextStyle(color: Colors.white38, fontSize: 12)),
            if (tracks.isNotEmpty) ...[
              _section(l10n.tracklist),
              for (final t in tracks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(t.number ?? '${t.position}',
                            style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(t.artist == null ? t.title : '${t.title} — ${t.artist}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
            ],
            _section(l10n.listeningHistory),
            if (history.isEmpty)
              Text(l10n.noPlaysYet, style: const TextStyle(color: Colors.white54))
            else
              for (final p in history.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 128,
                        child: Text(formatWhen(p.at), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(p.track,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.removeFromCollection),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.orange,
                side: const BorderSide(color: AppTheme.rust),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await widget.collection.remove(item.album, item.artist);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: AppTheme.cream, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      );
}
