import 'package:flutter/material.dart';
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

  static const List<HelpTopic> topics = [
    HelpTopic(Icons.play_circle_outline, 'Getting started', [
      'Put a record on your turntable, drop the needle and tap the microphone button. WaxClub listens for a few seconds, identifies the song and shows the lyrics in sync with the music.',
      'Keep the phone close to the speakers and avoid talking near it while it listens.',
    ]),
    HelpTopic(Icons.mic_none, 'Listening and syncing', [
      'The first listen is quick (4 seconds); harder songs get up to 12 seconds automatically.',
      'While a song plays, WaxClub checks the sync now and then through the microphone and corrects the timing.',
      'At the end of each track it predicts the next one from the record\'s tracklist and confirms it by listening.',
    ]),
    HelpTopic(Icons.flip, 'Flipping the record', [
      'When a side ends, the button turns into "Flip the record". Tap it before or after you flip: the lyrics of the first track of the new side appear right away and start as soon as the needle hits the music.',
    ]),
    HelpTopic(Icons.speed, 'Turntable speed', [
      'Turntables rarely spin at exactly 33⅓ RPM. WaxClub measures your turntable\'s real speed while songs play and keeps the lyrics on time.',
      'In the controls you can fine-tune the speed, reset it or lock it.',
    ]),
    HelpTopic(Icons.timer_outlined, 'Lyrics running early or late', [
      'Use the −0.5s / +0.5s buttons to nudge the lyrics. The offset is remembered for that song.',
    ]),
    HelpTopic(Icons.album_outlined, 'Change record and Discogs', [
      'Songs often appear on several records (albums, compilations, soundtracks). Tap the cover at the top of the screen, then "Change record" to pick the exact record on your turntable; it becomes the default for those songs.',
      'Tick "Search Discogs" to search the largest vinyl database. Your Discogs sign-in stays on this phone only.',
    ]),
    HelpTopic(Icons.library_music_outlined, 'Your collection', [
      'Tap the cover of the record that is playing and choose "Add to collection". Open your collection with the records icon at the top of the screen.',
      'WaxClub counts how many times each record was played and when: any track heard counts the record once per listening session.',
    ]),
    HelpTopic(Icons.cast, 'Showing the lyrics on the TV', [
      'Tap the cast icon. Chromecast and Google TV devices appear automatically.',
      'Fire TV: open the WaxClub app on the TV first; it appears in the list. If it does not, use "Add by IP" with the address shown on the TV.',
      'No Chromecast? Choose "Cast via browser" and open the address shown in your TV\'s browser.',
      'The phone and the TV must be on the same Wi-Fi.',
    ]),
    HelpTopic(Icons.build_outlined, 'Troubleshooting', [
      'Song not recognized: move the phone closer to the speakers and try again. Some rare records are not in the recognition catalog.',
      'Nothing is ever recognized: another app may be using the microphone (voice assistants, call apps). Close it and try again.',
      'TV not found: check that it is on and on the same Wi-Fi, and tap "Search again". After a TV update it may take a few minutes to show up again.',
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.cream,
        title: const Text('Help', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      title: Text(t.title, style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w700)),
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
              const Center(
                child: Text('Long-press the version to copy the session logs.',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
