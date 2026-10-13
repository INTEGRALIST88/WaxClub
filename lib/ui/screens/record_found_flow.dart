import 'dart:async';
import 'package:flutter/material.dart';
import '../../engine/waxclub_engine.dart';
import '../../services/recognition_catalog_service.dart';
import '../../l10n/l10n.dart';
import '../../models/track_entry.dart';
import '../../services/collection_service.dart';
import '../../services/discogs/discogs_collection_service.dart';
import '../../services/discogs/discogs_grades.dart';
import '../../services/tracklist_provider.dart';
import '../theme/app_theme.dart';

/// Depois do reconhecimento pela câmera: "Add to collection?" → cadastro → "Let's listen?".
/// O disco reconhecido vira o disco padrão das faixas (o modo automático já o trava).
/// Retorna `true` se o usuário quer ouvir agora.
Future<bool> runRecordFoundFlow(
  BuildContext context, {
  required WaxClubEngine engine,
  required CollectionService collection,
  required DiscogsCollectionService? discogsCollection,
  required ReleaseCandidate release,
  required List<TrackEntry> tracklist,
  RecognitionCatalogService? catalog,
}) async {
  final artist = release.artistName ?? '';
  final already = collection.contains(release.albumTitle, artist);

  final add = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(already ? release.albumTitle : l10n.foundAddToCollectionTitle,
          style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w800)),
      content: RecordSummary(release: release, trackCount: tracklist.length, note: already ? l10n.foundAlreadyInCollection : null),
      actions: already
          ? [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.ok))]
          : [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.no)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.yes)),
            ],
    ),
  );
  if (!context.mounted) return false;

  if (add == true) {
    final canDiscogs = discogsCollection != null && discogsCollection.canWrite && release.providerId == 'discogs'; // l10n-ignore
    final entry = await Navigator.of(context).push<CollectionEntryResult>(MaterialPageRoute(
      builder: (_) => CollectionEntryScreen(release: release, offerDiscogs: canDiscogs),
    ));
    if (!context.mounted) return false;
    if (entry != null) {
      await collection.add(entry.item);
      var message = l10n.addedToCollection(release.albumTitle);
      if (entry.alsoDiscogs && canDiscogs) {
        final ok = await discogsCollection.addRelease(release.releaseId, rating: entry.item.rating);
        message = '$message ${ok ? l10n.entryDiscogsAdded : l10n.entryDiscogsFailed}';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.surfaceLight,
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ));
      }
    }
  }

  // O disco reconhecido fica pronto para o modo automático (lista de faixas + disco padrão)
  await engine.prepareScannedRecord(
    albumTitle: release.albumTitle,
    artist: artist,
    tracklist: tracklist,
    coverUrl: release.coverUrl,
    releaseId: release.releaseId,
    releaseFormat: release.format,
    source: release.providerId,
  );
  if (!context.mounted) return false;

  // O disco está no catálogo de reconhecimento? Se não estiver, avisa e liga o Modo Manual
  final check = await _checkRecognitionCatalog(context, catalog ?? RecognitionCatalogService(), release, tracklist);
  if (!context.mounted) return false;
  if (check != null && !check.found) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(l10n.catalogNotFoundTitle, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w800)),
        content: Text(l10n.catalogNotFoundBody, style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok))],
      ),
    );
    engine.setManualMode(true);
    if (!context.mounted) return false;
  }

  final listen = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(l10n.letsListenTitle, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w800)),
      content: Text(l10n.letsListenBody(release.albumTitle), style: const TextStyle(color: Colors.white70, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.no)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.yes)),
      ],
    ),
  );
  return listen == true;
}

/// Consulta o catálogo de reconhecimento mostrando "Checking..."; nulo se não deu para consultar.
Future<CatalogCheckResult?> _checkRecognitionCatalog(
  BuildContext context,
  RecognitionCatalogService service,
  ReleaseCandidate release,
  List<TrackEntry> tracklist,
) async {
  final future = service.check(
    barcode: release.barcode,
    artist: release.artistName ?? '',
    album: release.albumTitle,
    tracklist: tracklist,
  );
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      future.whenComplete(() {
        if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      });
      return AlertDialog(
        backgroundColor: AppTheme.surface,
        content: Row(children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.orange)),
          const SizedBox(width: 16),
          Expanded(child: Text(l10n.catalogChecking, style: const TextStyle(color: Colors.white))),
        ]),
      );
    },
  ));
  final result = await future;
  // dá tempo do diálogo fechar antes do próximo
  await Future<void>.delayed(const Duration(milliseconds: 150));
  return result;
}

/// Capa, título, artista e os dados da prensagem (ano, país, gravadora, nº de catálogo, formato).
class RecordSummary extends StatelessWidget {
  final ReleaseCandidate release;
  final int? trackCount;
  final String? note;

  const RecordSummary({super.key, required this.release, this.trackCount, this.note});

  static String detailsOf(ReleaseCandidate r) =>
      [r.year, r.country, r.label, r.catalogNumber].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final details = detailsOf(release);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecordCover(url: release.coverUrl, size: 84),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(release.albumTitle,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  if (release.artistName != null)
                    Text(release.artistName!, style: const TextStyle(color: AppTheme.cream, fontSize: 14)),
                  if (details.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(details, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                    ),
                  if (release.format != null)
                    Text(release.format!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  if (trackCount != null && trackCount! > 0)
                    Text(l10n.tracksOnRecord(trackCount!), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(note!, style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

/// Capa pequena do disco (ou um disco genérico quando não há imagem).
class RecordCover extends StatelessWidget {
  final String? url;
  final double size;
  const RecordCover({super.key, this.url, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: AppTheme.surfaceLight,
      child: Icon(Icons.album, color: AppTheme.cream.withValues(alpha: 0.5), size: size * 0.6),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: (url == null || url!.isEmpty)
          ? placeholder
          : Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

class CollectionEntryResult {
  final CollectionItem item;
  final bool alsoDiscogs;
  const CollectionEntryResult(this.item, this.alsoDiscogs);
}

/// Cadastro do disco na coleção: os campos do Discogs vêm preenchidos; nota, estado do disco e da capa
/// e observações são opcionais.
class CollectionEntryScreen extends StatefulWidget {
  final ReleaseCandidate release;
  final bool offerDiscogs;

  const CollectionEntryScreen({super.key, required this.release, this.offerDiscogs = false});

  @override
  State<CollectionEntryScreen> createState() => _CollectionEntryScreenState();
}

class _CollectionEntryScreenState extends State<CollectionEntryScreen> {
  int? _rating;
  String? _media;
  String? _sleeve;
  final TextEditingController _notes = TextEditingController();
  late bool _alsoDiscogs = widget.offerDiscogs;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final r = widget.release;
    final notes = _notes.text.trim();
    Navigator.of(context).pop(CollectionEntryResult(
      CollectionItem(
        album: r.albumTitle,
        artist: r.artistName ?? '',
        coverUrl: r.coverUrl,
        year: r.year,
        format: r.format,
        discogsReleaseId: r.providerId == 'discogs' ? r.releaseId : null, // l10n-ignore
        musicBrainzReleaseId: r.providerId == 'musicbrainz' ? r.releaseId : null, // l10n-ignore
        label: r.label,
        catalogNumber: r.catalogNumber,
        barcode: r.barcode,
        addedAt: DateTime.now(),
        rating: _rating,
        mediaCondition: _media,
        sleeveCondition: _sleeve,
        notes: notes.isEmpty ? null : notes,
      ),
      _alsoDiscogs,
    ));
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(text, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w700)),
      );

  Widget _grade(List<String> options, String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      dropdownColor: AppTheme.surfaceLight,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface, border: OutlineInputBorder()),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(l10n.entryNotSet, style: const TextStyle(color: Colors.white54))),
        for (final o in options) DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.cream,
        title: Text(l10n.entryTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          RecordSummary(release: widget.release),
          _label(l10n.entryRating),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = _rating == i ? null : i),
                  icon: Icon(
                    (_rating ?? 0) >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: AppTheme.orange,
                    size: 32,
                  ),
                ),
            ],
          ),
          _label(l10n.entryMediaCondition),
          _grade(DiscogsGrades.media, _media, (v) => setState(() => _media = v)),
          _label(l10n.entrySleeveCondition),
          _grade(DiscogsGrades.sleeve, _sleeve, (v) => setState(() => _sleeve = v)),
          _label(l10n.entryNotes),
          TextField(
            controller: _notes,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(filled: true, fillColor: AppTheme.surface, border: OutlineInputBorder()),
          ),
          if (widget.offerDiscogs)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _alsoDiscogs,
              onChanged: (v) => setState(() => _alsoDiscogs = v ?? false),
              title: Text(l10n.entryAlsoDiscogs, style: const TextStyle(color: Colors.white)),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.library_add_check_outlined),
            label: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
