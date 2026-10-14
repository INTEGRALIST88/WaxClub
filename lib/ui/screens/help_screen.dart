import 'package:flutter/material.dart';
import '../widgets/retro_text.dart';
import '../../l10n/l10n.dart';
import '../../app_info.dart';
import '../theme/app_theme.dart';
import '../theme/wood.dart';

/// Um tópico do manual: título, ícone e parágrafos.
class HelpTopic {
  final IconData icon;
  final String title;
  final List<String> paragraphs;
  const HelpTopic(this.icon, this.title, this.paragraphs);
}

/// Manual do app em tópicos (substitui o antigo diálogo "How it works").
class HelpScreen extends StatelessWidget {
  /// Toque longo na versão: copia os logs da sessão (diagnóstico).
  final VoidCallback? onExportLogs;

  const HelpScreen({super.key, this.onExportLogs});

  /// Tópicos do manual no idioma atual.
  static List<HelpTopic> get topics => [
        HelpTopic(Icons.account_circle_outlined, l10n.helpAccount, [l10n.helpAccount1, l10n.helpAccount2]),
        HelpTopic(Icons.play_circle_outline, l10n.helpGettingStarted, [l10n.helpGettingStarted1, l10n.helpGettingStarted2]),
        HelpTopic(Icons.view_compact_alt_outlined, l10n.helpTopBar, [l10n.helpTopBar1, l10n.helpTopBar2]),
        HelpTopic(Icons.mic_none, l10n.helpListening, [l10n.helpListening1, l10n.helpListening2, l10n.helpListening3]),
        HelpTopic(Icons.flip, l10n.helpFlipping, [l10n.helpFlipping1]),
        HelpTopic(Icons.speed, l10n.helpSpeed, [l10n.helpSpeed1, l10n.helpSpeed2]),
        HelpTopic(Icons.timer_outlined, l10n.helpTiming, [l10n.helpTiming1]),
        HelpTopic(Icons.album_outlined, l10n.helpChangeRecord, [l10n.helpChangeRecord1, l10n.helpChangeRecord2]),
        HelpTopic(Icons.photo_camera_outlined, l10n.helpCamera, [l10n.helpCamera1, l10n.helpCamera2]),
        HelpTopic(Icons.toggle_on_outlined, l10n.helpManual, [l10n.helpManual1, l10n.helpManual2]),
        HelpTopic(Icons.lightbulb_outline, l10n.helpCuriosities, [l10n.helpCuriosities1, l10n.helpCuriosities2]),
        HelpTopic(Icons.library_music_outlined, l10n.helpCollection, [l10n.helpCollection1, l10n.helpCollection2]),
        HelpTopic(Icons.extension_outlined, l10n.helpPlugins, [l10n.helpPlugins1, l10n.helpPlugins2]),
        HelpTopic(Icons.cast, l10n.helpTv, [l10n.helpTv1, l10n.helpTv2, l10n.helpTv3, l10n.helpTv4]),
        HelpTopic(Icons.build_outlined, l10n.helpTroubleshooting,
            [l10n.helpTroubleshooting1, l10n.helpTroubleshooting2, l10n.helpTroubleshooting3]),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.cream,
        title: RetroText(l10n.help, fontSize: 28, depth: 3),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: WoodBackground()),
          ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              for (final t in topics)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppTheme.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: Icon(t.icon, color: AppTheme.orange),
                      title: RetroText(t.title, fontSize: 22, depth: 2, maxLines: 2),
                      iconColor: AppTheme.cream,
                      collapsedIconColor: Colors.white54,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final p in t.paragraphs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(p, style: const TextStyle(color: Colors.white70, height: 1.45)),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Center(
                child: GestureDetector(
                  onLongPress: onExportLogs,
                  child: Text('$kAppName · $kAppTagline · v$kAppVersion',
                      style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(l10n.helpCopyLogsHint,
                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(l10n.geoAttribution,
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
