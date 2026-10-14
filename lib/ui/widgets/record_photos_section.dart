import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/l10n.dart';
import '../../services/account/account_service.dart';
import '../theme/app_theme.dart';

/// Fotos do disco (My Collection): tirar com a câmera ou escolher na galeria, até [maxPhotos] por disco.
/// Cada foto é reduzida no aparelho (lado maior 1600 px, ~80% de qualidade) e guardada no banco do WaxClub,
/// ligada a este disco e ao usuário que a enviou — só ele vê e pode apagar (× na miniatura ou na lixeira).
class RecordPhotosSection extends StatefulWidget {
  final AccountService account;

  /// Chave do disco na coleção (CollectionService.keyFor).
  final String itemKey;

  /// Para os testes (sem a câmera do aparelho).
  final ImagePicker? picker;

  const RecordPhotosSection({super.key, required this.account, required this.itemKey, this.picker});

  static const double maxSide = 1600;
  static const int quality = 80;

  /// Limite por disco, por usuário (o servidor também confere).
  static const int maxPhotos = 7;

  @override
  State<RecordPhotosSection> createState() => _RecordPhotosSectionState();
}

class _RecordPhotosSectionState extends State<RecordPhotosSection> {
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  List<RecordPhoto>? _photos;
  int _uploading = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.account.listPhotos(widget.itemKey);
      if (mounted) setState(() => _photos = list);
    } catch (_) {
      if (mounted) setState(() {
        _photos = const [];
        _error = l10n.photosLoadFailed;
      });
    }
  }

  /// Quantas fotos ainda cabem neste disco.
  int get _remaining => RecordPhotosSection.maxPhotos - (_photos?.length ?? 0) - _uploading;

  Future<void> _add(ImageSource source) async {
    setState(() => _error = null);
    final room = _remaining;
    if (room <= 0) {
      setState(() => _error = l10n.photosTooMany(RecordPhotosSection.maxPhotos));
      return;
    }
    List<XFile> files;
    try {
      if (source == ImageSource.camera || room == 1) {
        final f = await _picker.pickImage(
          source: source,
          maxWidth: RecordPhotosSection.maxSide,
          maxHeight: RecordPhotosSection.maxSide,
          imageQuality: RecordPhotosSection.quality,
        );
        files = f == null ? const [] : [f];
      } else {
        files = await _picker.pickMultiImage(
          maxWidth: RecordPhotosSection.maxSide,
          maxHeight: RecordPhotosSection.maxSide,
          imageQuality: RecordPhotosSection.quality,
          limit: room,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.photosCameraFailed);
      return;
    }
    if (files.isEmpty || !mounted) return;
    if (files.length > room) {
      files = files.take(room).toList();
      setState(() => _error = l10n.photosTooMany(RecordPhotosSection.maxPhotos));
    }
    setState(() => _uploading += files.length);
    for (final f in files) {
      try {
        final p = await widget.account.uploadPhoto(widget.itemKey, await f.readAsBytes());
        if (mounted) setState(() => _photos = [...?_photos, p]);
      } on AccountApiException catch (e) {
        if (mounted) {
          setState(() => _error = e.code == 'too_many_photos' // l10n-ignore
              ? l10n.photosTooMany(RecordPhotosSection.maxPhotos)
              : l10n.photosUploadFailed);
        }
      } catch (_) {
        if (mounted) setState(() => _error = l10n.photosUploadFailed);
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
  }

  Future<void> _open(RecordPhoto p) async {
    final delete = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _PhotoViewer(url: widget.account.photoUrl(p.id), headers: widget.account.authHeaders),
    ));
    if (delete == true && mounted) await _delete(p);
  }

  /// "×" na miniatura: pergunta e apaga a foto do banco.
  Future<void> _confirmDelete(RecordPhoto p) async {
    if (await confirmDeletePhoto(context) && mounted) await _delete(p);
  }

  Future<void> _delete(RecordPhoto p) async {
    try {
      await widget.account.deletePhoto(p.id);
      if (mounted) setState(() => _photos = _photos?.where((x) => x.id != p.id).toList());
    } catch (_) {
      if (mounted) setState(() => _error = l10n.photosDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos == null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (photos.isEmpty && _uploading == 0)
          Text(l10n.photosEmpty, style: const TextStyle(color: Colors.white54, fontSize: 13))
        else
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final p in photos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _open(p),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              widget.account.photoUrl(p.id),
                              headers: widget.account.authHeaders,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              cacheWidth: 288,
                              errorBuilder: (_, __, ___) => Container(
                                width: 96,
                                height: 96,
                                color: AppTheme.surfaceLight,
                                child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
                              ),
                            ),
                          ),
                        ),
                        // Apagar direto da miniatura (com confirmação)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _confirmDelete(p),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, size: 16, color: Colors.white, semanticLabel: l10n.photosDelete),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (var i = 0; i < _uploading; i++)
                  Container(
                    width: 96,
                    height: 96,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          l10n.photosCount(photos?.length ?? 0, RecordPhotosSection.maxPhotos),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _remaining > 0 ? () => _add(ImageSource.camera) : null,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.photosTake),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.cream, side: const BorderSide(color: AppTheme.rust)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _remaining > 0 ? () => _add(ImageSource.gallery) : null,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(l10n.photosFromGallery),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.cream, side: const BorderSide(color: AppTheme.rust)),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13)),
          ),
      ],
    );
  }
}

/// "Apagar esta foto?" — `true` para apagar.
Future<bool> confirmDeletePhoto(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(l10n.photosDeleteTitle, style: const TextStyle(color: AppTheme.cream)),
      content: Text(l10n.photosDeleteInfo, style: const TextStyle(color: Colors.white70, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.rust, foregroundColor: Colors.white),
          child: Text(l10n.photosDelete),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Foto em tela cheia (com zoom); o botão de lixeira pede confirmação e devolve `true` para apagar.
class _PhotoViewer extends StatelessWidget {
  final String url;
  final Map<String, String> headers;
  const _PhotoViewer({required this.url, required this.headers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l10n.photosDelete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDeletePhoto(context) && context.mounted) Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(url, headers: headers, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
