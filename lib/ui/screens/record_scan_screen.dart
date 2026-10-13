import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../engine/waxclub_engine.dart';
import '../../l10n/l10n.dart';
import '../../services/album_catalog_service.dart';
import '../../services/collection_service.dart';
import '../../services/discogs/discogs_collection_service.dart';
import '../../services/record_scan_parser.dart';
import '../../services/tracklist_provider.dart';
import '../../services/user_profile_store.dart';
import '../theme/app_theme.dart';
import '../widgets/record_scan_guide.dart';
import 'record_found_flow.dart';

enum ScanMode { barcode, catalog, typed }

/// Reconhecimento do disco pela câmera: código de barras (ao vivo), número de catálogo (foto + leitura
/// do texto no aparelho) ou digitado. O usuário escolhe a prensagem e segue para o cadastro e a escuta.
/// Fecha devolvendo `true` quando o usuário quer ouvir o disco agora.
class RecordScanScreen extends StatefulWidget {
  final WaxClubEngine engine;
  final AlbumCatalogService catalog;
  final CollectionService collection;
  final UserProfileStore profile;
  final DiscogsCollectionService? discogsCollection;

  const RecordScanScreen({
    super.key,
    required this.engine,
    required this.catalog,
    required this.collection,
    required this.profile,
    this.discogsCollection,
  });

  @override
  State<RecordScanScreen> createState() => _RecordScanScreenState();
}

class _RecordScanScreenState extends State<RecordScanScreen> {
  ScanMode _mode = ScanMode.barcode;
  MobileScannerController? _scanner;
  bool _torchOn = false;
  bool _suggestCatalog = false;
  Timer? _suggestTimer;

  bool _busy = false;
  String? _busyText;
  String? _query;
  AlbumCatalogResult? _results;
  String? _applyingId;

  List<String> _catalogCandidates = const [];
  bool _photoRead = false;
  final TextEditingController _catalogCtrl = TextEditingController();
  final TextEditingController _typedCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupMode(ScanMode.barcode);
    widget.catalog.auth.load(); // conta Discogs (busca principal), se conectada
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await widget.profile.load();
      if (!mounted || widget.profile.scanGuideSeen) return;
      await showRecordScanGuide(context);
      await widget.profile.setScanGuideSeen();
    });
  }

  @override
  void dispose() {
    _suggestTimer?.cancel();
    _scanner?.dispose();
    _catalogCtrl.dispose();
    _typedCtrl.dispose();
    super.dispose();
  }

  void _enterMode(ScanMode mode) {
    _setupMode(mode);
    setState(() {
      _mode = mode;
      _results = null;
      _query = null;
    });
  }

  void _setupMode(ScanMode mode) {
    _suggestTimer?.cancel();
    if (mode == ScanMode.barcode) {
      _scanner ??= MobileScannerController(
        formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
      _suggestCatalog = false;
      // Sem código de barras em ~10 s: sugere o número de catálogo (discos antigos não têm código)
      _suggestTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _mode == ScanMode.barcode && _results == null) setState(() => _suggestCatalog = true);
      });
    } else {
      _scanner?.dispose();
      _scanner = null;
      _torchOn = false;
    }
  }

  Future<void> _onBarcode(BarcodeCapture capture) async {
    if (_busy || _results != null) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstWhere(
          RecordScanParser.isValidBarcode,
          orElse: () => '',
        );
    if (raw.isEmpty) return;
    _suggestTimer?.cancel();
    await _scanner?.stop();
    await _search(raw, () => widget.catalog.byBarcode(raw));
  }

  Future<void> _takeCatalogPhoto() async {
    final granted = await Permission.camera.request();
    if (!granted.isGranted) {
      _snack(l10n.scanCameraUnavailable);
      return;
    }
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2200);
    if (photo == null || !mounted) return;
    setState(() {
      _busy = true;
      _busyText = l10n.scanReadingPhoto;
    });
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(InputImage.fromFilePath(photo.path));
      final found = RecordScanParser.catalogNumberCandidates(text.text);
      if (!mounted) return;
      setState(() {
        _catalogCandidates = found;
        _photoRead = true;
        if (found.isNotEmpty) _catalogCtrl.text = found.first;
      });
    } catch (e) {
      debugPrint('[RecordScan] Falha ao ler a foto: $e');
      if (mounted) setState(() => _photoRead = true);
    } finally {
      recognizer.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search(String query, Future<AlbumCatalogResult> Function() run) async {
    final q = query.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _busyText = l10n.scanSearching(q);
      _query = q;
    });
    try {
      final r = await run();
      if (!mounted) return;
      setState(() => _results = r);
    } catch (e) {
      debugPrint('[RecordScan] Busca falhou: $e');
      _snack(l10n.searchFailed);
      _restartScanner();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restartScanner() {
    if (_mode == ScanMode.barcode) _scanner?.start();
  }

  void _scanAgain() {
    setState(() {
      _results = null;
      _query = null;
    });
    _enterMode(_mode);
    _restartScanner();
  }

  Future<void> _choose(ReleaseCandidate release) async {
    if (_applyingId != null) return;
    setState(() => _applyingId = release.releaseId);
    try {
      final tracks = await widget.catalog.loadTracklist(release);
      if (!mounted) return;
      if (tracks.isEmpty) {
        _snack(l10n.loadTracksFailed);
        return;
      }
      final listen = await runRecordFoundFlow(
        context,
        engine: widget.engine,
        collection: widget.collection,
        discogsCollection: widget.discogsCollection,
        release: release,
        tracklist: tracks,
      );
      if (mounted) Navigator.of(context).pop(listen);
    } catch (e) {
      debugPrint('[RecordScan] Falha ao usar o disco: $e');
      _snack(l10n.loadTracksFailed);
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.cream,
        title: Text(l10n.scanTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: l10n.scanHowTo,
            onPressed: () => showRecordScanGuide(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: SegmentedButton<ScanMode>(
              segments: [
                ButtonSegment(value: ScanMode.barcode, icon: const Icon(Icons.qr_code_scanner_rounded), label: Text(l10n.scanModeBarcode)),
                ButtonSegment(value: ScanMode.catalog, icon: const Icon(Icons.numbers_rounded), label: Text(l10n.scanModeCatalog)),
                ButtonSegment(value: ScanMode.typed, icon: const Icon(Icons.keyboard_alt_outlined), label: Text(l10n.scanModeTyped)),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: _busy ? null : (s) => _enterMode(s.first),
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white70,
                selectedForegroundColor: Colors.black,
                selectedBackgroundColor: AppTheme.orange,
                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Expanded(child: _results != null ? _buildResults() : _buildMode()),
        ],
      ),
    );
  }

  Widget _buildMode() {
    if (_busy) return _busyView();
    switch (_mode) {
      case ScanMode.barcode:
        return _buildBarcode();
      case ScanMode.catalog:
        return _buildCatalog();
      case ScanMode.typed:
        return _buildTyped();
    }
  }

  Widget _busyView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.orange),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_busyText ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );

  Widget _buildBarcode() {
    final scanner = _scanner;
    if (scanner == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      // Deitado: moldura à esquerda, dica, sugestão e lanterna numa coluna à direita (a altura é pouca)
      final landscape = c.maxWidth > c.maxHeight * 1.2;
      final Rect window;
      if (landscape) {
        final w = (c.maxWidth * 0.52).clamp(200.0, 560.0);
        final h = (c.maxHeight * 0.48).clamp(70.0, 180.0);
        window = Rect.fromCenter(center: Offset(16 + w / 2, c.maxHeight * 0.48), width: w, height: h);
      } else {
        final w = c.maxWidth * 0.8;
        final h = (w * 0.45).clamp(90.0, 180.0);
        window = Rect.fromCenter(center: Offset(c.maxWidth / 2, c.maxHeight * 0.42), width: w, height: h);
      }
      final sideLeft = window.right + 20; // coluna à direita (deitado)
      return Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: scanner,
            scanWindow: window,
            onDetect: _onBarcode,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.scanCameraUnavailable, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ),
            ),
          ),
          IgnorePointer(child: CustomPaint(painter: _ScanWindowPainter(window))),
          Positioned(
            left: landscape ? sideLeft : 20,
            right: landscape ? 16 : 20,
            top: landscape ? window.top : window.bottom + 18,
            child: Text(
              l10n.scanBarcodeHint,
              textAlign: landscape ? TextAlign.start : TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 6)]),
            ),
          ),
          if (_suggestCatalog)
            Positioned(
              left: landscape ? sideLeft : 16,
              right: 16,
              bottom: landscape ? 72 : 76,
              child: Material(
                color: AppTheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _enterMode(ScanMode.catalog),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.numbers_rounded, color: AppTheme.orange),
                        const SizedBox(width: 10),
                        Expanded(child: Text(l10n.scanBarcodeTryCatalog, style: const TextStyle(color: Colors.white))),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            left: landscape ? sideLeft : 0,
            right: landscape ? null : 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: l10n.scanTorch,
                iconSize: 28,
                onPressed: () async {
                  await scanner.toggleTorch();
                  if (mounted) setState(() => _torchOn = !_torchOn);
                },
                icon: Icon(_torchOn ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildCatalog() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const Icon(Icons.photo_camera_outlined, color: AppTheme.orange, size: 52),
        const SizedBox(height: 10),
        Text(l10n.scanCatalogHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.45)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _takeCatalogPhoto,
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(l10n.scanTakePhoto),
        ),
        if (_photoRead) ...[
          const SizedBox(height: 18),
          Text(
            _catalogCandidates.isEmpty ? l10n.scanCatalogNoneFound : l10n.scanCatalogFound,
            style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _catalogCandidates)
                ActionChip(
                  label: Text(c),
                  backgroundColor: c == _catalogCtrl.text ? AppTheme.orange : AppTheme.surfaceLight,
                  labelStyle: TextStyle(color: c == _catalogCtrl.text ? Colors.black : Colors.white),
                  onPressed: () => setState(() => _catalogCtrl.text = c),
                ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        _searchField(_catalogCtrl, l10n.scanCatalogField,
            (q) => _search(q, () => widget.catalog.byCatalogNumber(q))),
      ],
    );
  }

  Widget _buildTyped() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _searchField(_typedCtrl, l10n.scanTypedField, (q) => _search(q, () => widget.catalog.search(q))),
      ],
    );
  }

  Widget _searchField(TextEditingController ctrl, String label, void Function(String) onSearch) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.search,
            onSubmitted: onSearch,
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: AppTheme.surface,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: l10n.search,
          onPressed: () => onSearch(ctrl.text),
          icon: const Icon(Icons.search_rounded),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final r = _results!;
    final albums = r.albums;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            albums.isEmpty ? l10n.scanNoResults(_query ?? '') : (r.notice ?? l10n.scanPickPressing),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final a = albums[i];
              final details = RecordSummary.detailsOf(a);
              return Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  onTap: _applyingId == null ? () => _choose(a) : null,
                  leading: RecordCover(url: a.coverUrl, size: 52),
                  title: Text(a.albumTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [a.artistName, details, a.format].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: _applyingId == a.releaseId
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppTheme.orange))
                      : const Icon(Icons.chevron_right, color: Colors.white38),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            onPressed: _applyingId == null ? _scanAgain : null,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.scanAgain),
          ),
        ),
      ],
    );
  }
}

/// Escurece a imagem da câmera fora da janela de leitura e desenha a moldura laranja.
class _ScanWindowPainter extends CustomPainter {
  final Rect window;
  _ScanWindowPainter(this.window);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(window, const Radius.circular(14));
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(r)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(r, Paint()
      ..color = AppTheme.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _ScanWindowPainter old) => old.window != window;
}
