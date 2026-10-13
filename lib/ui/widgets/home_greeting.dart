import 'dart:math';
import 'package:flutter/material.dart';
import '../../app_info.dart';
import '../theme/app_theme.dart';

/// Frases da saudação da tela principal, variando com a hora do dia e a cada abertura do app.
class Greeting {
  final String title;
  final String subtitle;
  const Greeting(this.title, this.subtitle);

  /// Saudação para [name] no instante [now]; [seed] escolhe a variação (fixa durante a sessão).
  static Greeting forName(String? name, DateTime now, int seed) {
    final rnd = Random(seed);
    if (name == null || name.isEmpty) {
      return const Greeting('Welcome to $kAppName!', 'Drop the needle and tap the microphone to start.');
    }
    final hour = now.hour;
    final timeOfDay = hour >= 5 && hour < 12
        ? 'Good morning'
        : (hour >= 12 && hour < 18 ? 'Good afternoon' : 'Good evening');
    final titles = [
      '$timeOfDay, $name!',
      "Let's go, $name!",
      "Let's spin, $name!",
      '$timeOfDay, $name!',
    ];
    final subtitles = [
      '$name, today is a great day to listen to some music.',
      'Which record is on the platter today?',
      'Drop the needle and tap the microphone.',
      'Pick a side, and the lyrics follow along.',
    ];
    return Greeting(titles[rnd.nextInt(titles.length)], subtitles[rnd.nextInt(subtitles.length)]);
  }
}

/// Tela de boas-vindas (sem música tocando): ícone entalhado, saudação com o nome e dica de uso.
class HomeGreeting extends StatelessWidget {
  final String? name;
  final int seed;
  final VoidCallback onEditName;

  const HomeGreeting({super.key, required this.name, required this.seed, required this.onEditName});

  @override
  Widget build(BuildContext context) {
    final greeting = Greeting.forName(name, DateTime.now(), seed);
    // A barra superior fica sobre o conteúdo (extendBodyBehindAppBar): o espaço de topo já inclui a altura dela
    final topInset = MediaQuery.paddingOf(context).top;
    return LayoutBuilder(builder: (context, constraints) {
      final free = constraints.maxHeight - topInset - 96;
      // Ícone grande em pé, menor em telas baixas, nenhum quando não cabe (ex.: celular deitado)
      final iconSize = free > 520 ? 148.0 : (free > 400 ? 96.0 : 0.0);
      return Padding(
      padding: EdgeInsets.only(top: topInset),
      child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
            const SizedBox(height: 30),
            ],
            GestureDetector(
              onTap: onEditName,
              child: Text(
                greeting.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: AppTheme.cream, letterSpacing: -0.4),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              greeting.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 22),
            if (name == null)
              OutlinedButton.icon(
                onPressed: onEditName,
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('What should we call you?'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cream,
                  side: const BorderSide(color: AppTheme.wood),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )
            else
              Text(
                kAppTagline.toUpperCase(),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.orange, letterSpacing: 2.6),
              ),
          ],
        ),
      ),
      ),
      );
    });
  }
}
