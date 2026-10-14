import 'dart:math';
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../app_info.dart';
import '../theme/app_theme.dart';
import 'retro_text.dart';

/// Frases da saudação da tela principal, variando com a hora do dia e a cada abertura do app.
class Greeting {
  final String title;
  final String subtitle;
  const Greeting(this.title, this.subtitle);

  /// Saudação para [name] no instante [now]; [seed] escolhe a variação (fixa durante a sessão).
  static Greeting forName(String? name, DateTime now, int seed) {
    final rnd = Random(seed);
    if (name == null || name.isEmpty) {
      return Greeting(l10n.greetingWelcome(kAppName), l10n.greetingWelcomeSubtitle);
    }
    final hour = now.hour;
    final timeOfDay = hour >= 5 && hour < 12
        ? l10n.goodMorning
        : (hour >= 12 && hour < 18 ? l10n.goodAfternoon : l10n.goodEvening);
    final titles = [
      l10n.greetingTimeOfDay(timeOfDay, name),
      l10n.greetingLetsGo(name),
      l10n.greetingLetsSpin(name),
      l10n.greetingTimeOfDay(timeOfDay, name),
    ];
    final subtitles = [
      l10n.greetingGreatDay(name),
      l10n.greetingWhichRecord,
      l10n.greetingDropNeedle,
      l10n.greetingPickSide,
    ];
    return Greeting(titles[rnd.nextInt(titles.length)], subtitles[rnd.nextInt(subtitles.length)]);
  }
}

/// Tela de boas-vindas (sem música tocando): ícone, saudação com o nome, etapa atual e dica de uso.
/// Cabe inteira em pé e deitado: o ícone diminui ou some e o texto fica compacto quando falta altura.
class HomeGreeting extends StatelessWidget {
  final String? name;
  final int seed;
  final VoidCallback onEditName;

  /// Altura livre embaixo para o botão de ouvir (centralizado sobre o conteúdo).
  final double bottomReserve;

  /// Etapa atual do reconhecimento (ex.: "Listening through the microphone..."), quando houver.
  final String? statusLine;

  const HomeGreeting({
    super.key,
    required this.name,
    required this.seed,
    required this.onEditName,
    this.bottomReserve = 0,
    this.statusLine,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = Greeting.forName(name, DateTime.now(), seed);
    // A barra superior fica sobre o conteúdo (extendBodyBehindAppBar): o espaço de topo já inclui a altura dela
    final topInset = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(builder: (context, constraints) {
      final free = constraints.maxHeight - topInset - bottomReserve;
      // Ícone grande em pé, menor em telas baixas e nenhum quando não cabe (ex.: celular deitado)
      final iconSize = free > 470 ? 148.0 : (free > 360 ? 96.0 : 0.0);
      final compact = free < 240;
      return Padding(
        padding: EdgeInsets.only(top: topInset, bottom: bottomReserve),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 2 : 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconSize > 0) ...[
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 24, offset: const Offset(0, 10)),
                        BoxShadow(color: AppTheme.orange.withValues(alpha: 0.18), blurRadius: 40, spreadRadius: 2),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.album, size: 80, color: AppTheme.orange),
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
                GestureDetector(
                  onTap: onEditName,
                  child: RetroText(
                    greeting.title,
                    fontSize: compact ? 24 : 32,
                    maxLines: 3,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: compact ? 4 : 10),
                Text(
                  greeting.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: compact ? 13 : 15, color: Colors.white70, height: 1.4),
                ),
                if (statusLine != null) ...[
                  SizedBox(height: compact ? 6 : 12),
                  Text(
                    statusLine!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13.5,
                      color: AppTheme.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: compact ? 8 : 20),
                if (name == null)
                  OutlinedButton.icon(
                    onPressed: onEditName,
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: Text(l10n.whatShouldWeCallYou),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cream,
                      side: const BorderSide(color: AppTheme.wood),
                      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  )
                else
                  Text(
                    kAppTagline.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.orange,
                      letterSpacing: 2.6,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
