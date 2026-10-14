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
import '../../services/curiosities_service.dart';
import '../widgets/curiosity_badge.dart';
import '../../services/collection_grouping.dart';

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

  /// Curiosidades do disco (ⓘ à direita de cada disco); nulo com o plugin de Curiosidades (D2) desligado.
  final Future<List<Curiosity>> Function(CollectionItem item)? curiositiesFor;

  const CollectionScreen({
    super.key,
    required this.collection,
    required this.tracklistFor,
    this.account,
    this.discogs,
    this.onAddRecord,
    this.onPlayItem,
    this.curiositiesFor,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> with SingleTickerProviderStateMixin {
  // preserve: o brilho roda mesmo com as animações do Android desligadas (Opções do desenvolvedor)
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
    animationBehavior: AnimationBehavior.preserve,
  );

  /// Brilho prateado do ⓘ ao abrir a tela, disco após disco.
  void _startShine() {
    if (widget.curiositiesFor == null || !mounted) return;
    final n = widget.collection.count.clamp(1, 60);
    _shine.duration = Duration(milliseconds: n * CuriosityBadge.stepMs + CuriosityBadge.glowMs);
    _shine.forward(from: 0);
  }

  @override
  void dispose() {
    _shine.dispose();
    _scroll.dispose();
    super.dispose();
  }
  CollectionSort _sort = CollectionSort.recentlyPlayed;

  /// Por artista/banda (padrão, como numa loja de discos), por nome do disco, ou a lista do menu.
  CollectionGrouping _grouping = CollectionGrouping.artist;
  final ScrollController _scroll = ScrollController();
  String? _touchedLetter;

  // Alturas fixas das linhas: o abecedário calcula onde cada letra começa sem medir a tela
  static const double _tileHeight = 94;
  static const double _gap = 8;
  static const double _headerHeight = 42;
  static const double _topPadding = 8;

  double _rowHeight(CollectionRow r) => r.isHeader ? _headerHeight : _tileHeight + _gap;

  /// Vai para a primeira linha da letra [letter] (ou da seguinte que tiver discos).
  void _jumpTo(String letter, List<CollectionRow> rows) {
    final order = CollectionGrouper.alphabet;
    final want = order.indexOf(letter);
    var offset = _topPadding;
    for (final r in rows) {
      if (order.indexOf(r.letter) >= want) break;
      offset += _rowHeight(r);
    }
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  static Map<CollectionSort, String> get _sortLabels => {
        CollectionSort.recentlyPlayed: l10n.sortRecentlyPlayed,
        CollectionSort.mostPlayed: l10n.sortMostPlayed,
        CollectionSort.recentlyAdded: l10n.sortRecentlyAdded,
        CollectionSort.alphabetical: l10n.sortAlphabetical,
      };

  @override
  void initState() {
    super.initState();
    widget.collection.load().then((_) => _startShine());
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
        final grouped = _grouping != CollectionGrouping.none;
        final rows = CollectionGrouper.build(items, _grouping);
        final letters = {for (final r in rows) r.letter};
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
                onSelected: (s) => setState(() {
                  _sort = s;
                  _grouping = CollectionGrouping.none; // ordem do menu: lista simples
                }),
                itemBuilder: (_) => [
                  for (final s in CollectionSort.values)
                    PopupMenuItem(value: s, child: Text(_sortLabels[s]!, style: const TextStyle(color: AppTheme.cream))),
                ],
              ),
            ],
            bottom: items.isEmpty
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(46),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Row(
                        children: [
                          _groupChip(l10n.groupByArtist, Icons.person_outline, CollectionGrouping.artist),
                          const SizedBox(width: 8),
                          _groupChip(l10n.groupByAlbum, Icons.album_outlined, CollectionGrouping.album),
                        ],
                      ),
                    ),
                  ),
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: WoodBackground()),
              if (items.isEmpty)
                _emptyState()
              else ...[
                ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(grouped ? 30 : 12, _topPadding, 12, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, r) {
                    final row = rows[r];
                    if (row.isHeader) {
                      return SizedBox(height: _headerHeight, child: _groupHeader(row.header!));
                    }
                    return SizedBox(
                      height: _tileHeight + _gap,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: _tile(row.item!, row.itemIndex),
                      ),
                    );
                  },
                ),
                if (grouped)
                  Positioned(
                    left: 2,
                    top: 6,
                    bottom: 6,
                    width: 24,
                    child: _alphabetBar(letters, rows),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _groupChip(String label, IconData icon, CollectionGrouping g) {
    final on = _grouping == g;
    return Expanded(
      child: Material(
        color: on ? AppTheme.orange : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() {
            _grouping = g;
            if (_scroll.hasClients) _scroll.jumpTo(0);
          }),
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? Colors.white : AppTheme.cream),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label,
                        maxLines: 1,
                        style: TextStyle(color: on ? Colors.white : AppTheme.cream, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Divisor: nome do artista (por artista) ou a letra (por disco), com uma linha até a borda.
  Widget _groupHeader(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(
          children: [
            Flexible(child: RetroText(text, fontSize: text.length == 1 ? 24 : 20, depth: 2)),
            const SizedBox(width: 10),
            Expanded(child: Container(height: 1.2, color: AppTheme.wood.withValues(alpha: 0.7))),
          ],
        ),
      );

  /// Abecedário vertical à esquerda: tocar ou arrastar leva direto à letra (letras sem discos apagadas).
  Widget _alphabetBar(Set<String> available, List<CollectionRow> rows) {
    const letters = CollectionGrouper.alphabet;
    return LayoutBuilder(builder: (context, c) {
      final cell = c.maxHeight / letters.length;
      void pick(double dy) {
        final i = (dy / cell).floor().clamp(0, letters.length - 1);
        final l = letters[i];
        if (_touchedLetter != l) {
          setState(() => _touchedLetter = l);
          _jumpTo(l, rows);
        }
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => pick(d.localPosition.dy),
        onVerticalDragStart: (d) => pick(d.localPosition.dy),
        onVerticalDragUpdate: (d) => pick(d.localPosition.dy),
        onTapUp: (_) => setState(() => _touchedLetter = null),
        onVerticalDragEnd: (_) => setState(() => _touchedLetter = null),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              for (final l in letters)
                SizedBox(
                  height: cell,
                  child: Center(
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: (cell * 0.72).clamp(7.0, 11.0),
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                        color: l == _touchedLetter
                            ? AppTheme.orange
                            : available.contains(l)
                                ? AppTheme.cream
                                : Colors.white24,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
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

  Widget _tile(CollectionItem item, [int index = 0]) {
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
              if (widget.curiositiesFor != null)
                CuriosityBadge(
                  shine: _shine,
                  index: index,
                  tooltip: l10n.curiositiesTooltip,
                  onTap: () => _showCuriosities(item),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  /// Popup das curiosidades do disco (banco compartilhado, ou baixadas agora), com a fonte de cada uma.
  void _showCuriosities(CollectionItem item) {
    final future = widget.curiositiesFor!(item);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: RetroText(item.album, fontSize: 24, depth: 2, maxLines: 2),
        content: SizedBox(
          width: 420,
          child: FutureBuilder<List<Curiosity>>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.orange)),
                );
              }
              final facts = snap.data ?? const <Curiosity>[];
              if (facts.isEmpty) {
                return Text(l10n.curiositiesEmpty, style: const TextStyle(color: Colors.white70, height: 1.4));
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: facts.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 20),
                itemBuilder: (_, i) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(facts[i].text, style: const TextStyle(color: Colors.white, height: 1.45, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Text(l10n.curiositiesSource(facts[i].source),
                        style: const TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close))],
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
            const SizedBox(height: 24),
            // Remover o disco da coleção (com confirmação)
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text(l10n.removeFromCollection, style: const TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _danger,
                side: const BorderSide(color: _danger),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (!await _confirmRemove(ctx, item)) return;
                await widget.collection.remove(item.album, item.artist);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      backgroundColor: AppTheme.surfaceLight,
                      content: Text(l10n.removedFromCollection(item.album), style: const TextStyle(color: Colors.white)),
                    ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static const Color _danger = Color(0xFFFF8A80);

  /// "Tem certeza que quer excluir este disco da sua coleção?"
  Future<bool> _confirmRemove(BuildContext ctx, CollectionItem item) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l10n.removeRecordConfirmTitle, style: const TextStyle(color: AppTheme.cream)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.removeRecordConfirm, style: const TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 12),
            Text(item.album, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            Text(item.artist, style: const TextStyle(color: Colors.white54)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.rust, foregroundColor: Colors.white),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    return ok == true;
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
