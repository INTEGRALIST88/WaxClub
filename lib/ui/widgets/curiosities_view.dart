import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../services/curiosities_service.dart';
import '../theme/app_theme.dart';

/// Uma curiosidade na linha do tempo da faixa: aparece em [start] e fica [length] segundos.
class CuriositySlot {
  final Curiosity curiosity;
  final bool aboutRecord;
  final double start;
  final double length;
  const CuriositySlot(this.curiosity, this.aboutRecord, this.start, this.length);
}

/// Curiosidades no lugar da letra (sem plugin de letra ou letra não encontrada): as do disco no começo
/// do lado e as da faixa distribuídas ao longo da música. Cada uma entra subindo, fica e sai esmaecendo,
/// na mesma curva da letra da TV.
class CuriositiesView extends StatelessWidget {
  final RecordCuriosities curiosities;
  final double positionSeconds;
  final double? durationSeconds;

  /// Primeira faixa do lado: as curiosidades do disco entram antes das da faixa.
  final bool sideStart;

  const CuriositiesView({
    super.key,
    required this.curiosities,
    required this.positionSeconds,
    this.durationSeconds,
    this.sideStart = false,
  });

  static const double _lead = 3.0; // espera antes da 1ª curiosidade
  static const double _maxShow = 12.0; // tempo máximo de cada uma na tela
  static const double _cycle = 10.0; // sem duração conhecida: uma a cada 10 s

  /// Distribui as curiosidades ao longo da faixa.
  static List<CuriositySlot> schedule(RecordCuriosities c, {double? duration, bool sideStart = false}) {
    final items = <(Curiosity, bool)>[
      if (sideStart || c.track.isEmpty) ...c.album.map((x) => (x, true)),
      ...c.track.map((x) => (x, false)),
    ];
    if (items.isEmpty) return const [];
    if (duration == null || duration <= _lead * 2 + 4) {
      return [for (var i = 0; i < items.length; i++) CuriositySlot(items[i].$1, items[i].$2, _lead + i * _cycle, _cycle)];
    }
    final slot = (duration - _lead * 2) / items.length;
    final len = slot < _maxShow ? slot : _maxShow;
    return [for (var i = 0; i < items.length; i++) CuriositySlot(items[i].$1, items[i].$2, _lead + i * slot, len)];
  }

  /// Curiosidade visível no instante [pos] e o progresso (0 a 1) dela; nulo entre uma e outra.
  static (CuriositySlot, double)? visibleAt(List<CuriositySlot> slots, double pos, {double? duration}) {
    if (slots.isEmpty) return null;
    var p = pos;
    // Sem duração: repete o ciclo
    if (duration == null && slots.isNotEmpty) {
      final total = slots.last.start + slots.last.length - _lead;
      if (p > _lead && total > 0) p = _lead + ((p - _lead) % total);
    }
    for (final s in slots) {
      if (p >= s.start && p < s.start + s.length) return (s, (p - s.start) / s.length);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final slots = schedule(curiosities, duration: durationSeconds, sideStart: sideStart);
    final now = visibleAt(slots, positionSeconds, duration: durationSeconds);
    final topInset = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Center(
        child: now == null ? const SizedBox.shrink() : _card(now.$1, now.$2),
      ),
    );
  }

  Widget _card(CuriositySlot slot, double t) {
    // entra subindo (15%), fica, sai esmaecendo e subindo um pouco (15%)
    const ease = Cubic(0.22, 0.8, 0.24, 1);
    double opacity;
    double dy;
    if (t < 0.15) {
      final k = ease.transform(t / 0.15);
      opacity = k;
      dy = 36 * (1 - k);
    } else if (t > 0.85) {
      final k = ease.transform((t - 0.85) / 0.15);
      opacity = 1 - k;
      dy = -18 * k;
    } else {
      opacity = 1;
      dy = 0;
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, dy),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (slot.aboutRecord ? l10n.curiosityAboutRecord : l10n.curiosityAboutTrack).toUpperCase(),
                  style: const TextStyle(color: AppTheme.orange, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                Text(
                  slot.curiosity.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter', // l10n-ignore
                    fontVariations: [FontVariation('wght', 700)], // l10n-ignore
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 21,
                    height: 1.35,
                    shadows: [Shadow(color: Color(0x59C2602F), blurRadius: 18)],
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.curiositySource(slot.curiosity.source), style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
