import 'package:flutter/material.dart';

/// Tema visual escuro do WaxClub: madeira escura entalhada no entorno e nos controles,
/// mantendo as cores de destaque (ciano/roxo do ícone) e as cores da letra.
///
/// Paleta de madeira (mesma família da tela da TV, #120C08):
/// ébano (fundo) → nogueira escura (painéis) → nogueira (elevado); bordas do entalhe com
/// nogueira inglesa (#3E2B23) na luz e quase-preto (#070403) na sombra.
class AppTheme {
  static const Color background = Color(0xFF120C08); // ébano
  static const Color surface = Color(0xFF1E140D); // nogueira escura
  static const Color surfaceLight = Color(0xFF2B1D13); // nogueira (elevado)

  // Entalhe: sombra na borda de cima/esquerda, luz na borda de baixo/direita
  static const Color carveLight = Color(0xFF3E2B23); // nogueira inglesa
  static const Color carveShadow = Color(0xFF070403);
  static const Color woodGrain = Color(0xFF2E1E14); // veio da madeira

  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFFA855F7);
  static const Color neonPink = Color(0xFFFF2A85);

  static const Color textActive = Colors.white;
  static const Color textInactive = Color(0x55FFFFFF);
  static const Color textPast = Color(0x33FFFFFF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: neonPurple,
      colorScheme: const ColorScheme.dark(
        primary: neonPurple,
        secondary: neonCyan,
        surface: surface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neonPurple,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
