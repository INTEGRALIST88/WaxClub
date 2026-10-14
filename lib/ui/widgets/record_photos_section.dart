import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/l10n.dart';
import '../../services/account/account_service.dart';
import '../theme/app_theme.dart';

/// Fotos do disco (My Collection): tirar com a câmera ou escolher na galeria, quantas quiser. Cada foto é
/// reduzida no aparelho (lado maior 1600 px, ~80% de qualidade) e guardada no banco do WaxClub, ligada a
/// este disco e à conta do usuário — só ele vê.
class RecordPhotosSection extends StatefulWidget {
  final AccountService account;

  /// Chave do disco na coleção (CollectionService.keyFor).
  final String itemKey;

  /// Para os testes (sem a câmera do aparelho).
  final ImagePicker? picker;

  const RecordPhotosSection({super.key, required this.account, required this.itemKey, this.picker});

  static const double maxSide = 1600;
  static const int quality = 80;

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

  Future<void> _add(ImageSource source) async {
    setState(() => _error = null);
    final List<XFile> files;
    try {
      if (source == ImageSource.camera) {
        final f = await _picker.pickImage(
          source: ImageSource.camera,
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
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.photosCameraFailed);
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading += files.length);
    for (final f in files) {
      try {
        final p = await widget.account.uploadPhoto(widget.itemKey, await f.readAsBytes());
        if (mounted) setState(() => _photos = [...?_photos, p]);
      } on AccountApiException catch (e) {
        if (mounted) {
          setState(() => _error = e.code == 'too_many_photos' ? l10n.photosTooMany : l10n.photosUploadFailed); // l10n-ignore
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
    if (delete != true || !mounted) return;
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
                    child: GestureDetector(
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _add(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(l10n.photosTake),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.cream, side: const BorderSide(color: AppTheme.rust)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _add(ImageSource.gallery),
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
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: Text(l10n.photosDeleteTitle, style: const TextStyle(color: AppTheme.cream)),
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
              if (ok == true && context.mounted) Navigator.of(context).pop(true);
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
