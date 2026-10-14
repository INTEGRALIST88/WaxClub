import 'package:flutter/material.dart';
import 'retro_text.dart';
import '../../l10n/l10n.dart';
import '../../models/track_entry.dart';
import '../theme/app_theme.dart';

/// Escolha de onde a agulha começa no Modo Manual: faixa (por lado) e se o microfone acha o começo.
class ManualStartChoice {
  final int trackIndex;
  final bool useMic;
  const ManualStartChoice(this.trackIndex, this.useMic);
}

Future<ManualStartChoice?> showManualStartSheet(BuildContext context, List<TrackEntry> tracks, {String? album}) {
  return showModalBottomSheet<ManualStartChoice>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => ManualStartSheet(tracks: tracks, album: album, scrollController: scroll),
    ),
  );
}

class ManualStartSheet extends StatefulWidget {
  final List<TrackEntry> tracks;
  final String? album;
  final ScrollController? scrollController;
  const ManualStartSheet({super.key, required this.tracks, this.album, this.scrollController});

  @override
  State<ManualStartSheet> createState() => _ManualStartSheetState();
}

class _ManualStartSheetState extends State<ManualStartSheet> {
  bool _useMic = true;

  static String length(int? ms) {
    if (ms == null || ms <= 0) return '—';
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.tracks;
    final rows = <Widget>[];
    String? lastSide;
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      final side = (t.side ?? '').toUpperCase();
      if (side.isNotEmpty && side != lastSide) {
        lastSide = side;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(l10n.sideLabel(side), style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w800)),
        ));
      }
      rows.add(ListTile(
        dense: true,
        leading: SizedBox(
          width: 36,
          child: Text(t.number ?? '${t.position}', style: const TextStyle(color: AppTheme.cream, fontWeight: FontWeight.w700)),
        ),
        title: Text(t.title, style: const TextStyle(color: Colors.white)),
        trailing: Text(length(t.lengthMs), style: const TextStyle(color: Colors.white54)),
        onTap: () => Navigator.of(context).pop(ManualStartChoice(i, _useMic)),
      ));
    }
    final missing = tracks.where((t) => (t.lengthMs ?? 0) <= 0).length;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: RetroText(l10n.manualStartTitle, fontSize: 24, depth: 2, maxLines: 2),
        ),
        if (widget.album != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(widget.album!, style: const TextStyle(color: Colors.white70)),
          ),
        SwitchListTile(
          value: _useMic,
          onChanged: (v) => setState(() => _useMic = v),
          activeThumbColor: AppTheme.orange,
          title: Text(l10n.manualUseMic, style: const TextStyle(color: Colors.white)),
          subtitle: Text(_useMic ? l10n.manualUseMicHint : l10n.manualNoMicHint,
              style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
        ),
        if (missing > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.manualMissingDurations(missing),
                style: const TextStyle(color: Color(0xFFF6B74A), fontSize: 12.5)),
          ),
        ...rows,
      ],
    );
  }
}
