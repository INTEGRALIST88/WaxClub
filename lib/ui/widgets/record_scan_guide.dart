import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../theme/app_theme.dart';

/// Guia ilustrado da câmera: onde apontar em cada situação para reconhecer o disco.
/// Aparece na primeira vez que o usuário abre a câmera e pelo botão de ajuda da tela.
Future<void> showRecordScanGuide(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const _RecordScanGuide());
}

class _GuidePage {
  final IconData icon;
  final String title;
  final String body;
  const _GuidePage(this.icon, this.title, this.body);
}

class _RecordScanGuide extends StatefulWidget {
  const _RecordScanGuide();

  @override
  State<_RecordScanGuide> createState() => _RecordScanGuideState();
}

class _RecordScanGuideState extends State<_RecordScanGuide> {
  final PageController _pages = PageController();
  int _index = 0;

  List<_GuidePage> get _content => [
        _GuidePage(Icons.qr_code_scanner_rounded, l10n.guideBarcodeTitle, l10n.guideBarcodeBody),
        _GuidePage(Icons.numbers_rounded, l10n.guideCatalogTitle, l10n.guideCatalogBody),
        _GuidePage(Icons.wb_sunny_outlined, l10n.guideLightTitle, l10n.guideLightBody),
        _GuidePage(Icons.album_outlined, l10n.guidePressingTitle, l10n.guidePressingBody),
      ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _content;
    final last = _index == pages.length - 1;
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.scanHowTo,
                  style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Flexible(
                child: PageView(
                  controller: _pages,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final p in pages)
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.orange.withValues(alpha: 0.16),
                                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.6), width: 1.5),
                              ),
                              child: Icon(p.icon, color: AppTheme.orange, size: 42),
                            ),
                            const SizedBox(height: 14),
                            Text(p.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                            const SizedBox(height: 10),
                            Text(p.body,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 14)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? AppTheme.orange : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    if (last) {
                      Navigator.of(context).pop();
                    } else {
                      _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    }
                  },
                  child: Text(last ? l10n.guideDone : l10n.guideNext,
                      style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
