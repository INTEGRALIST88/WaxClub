import 'package:flutter/material.dart';

/// Tema visual do WaxClub, na paleta do ícone: nogueira (madeira entalhada), vinil preto e o selo
/// do disco em creme e laranja queimado.
///
/// Madeira: ébano (fundo) → nogueira escura (painéis) → nogueira (elevado); bordas do entalhe com
/// nogueira clara na luz e quase-preto na sombra. Destaques: creme do selo e laranja do selo.
class AppTheme {
  static const Color background = Color(0xFF160F0A); // ébano quente
  static const Color surface = Color(0xFF24170F); // nogueira escura
  static const Color surfaceLight = Color(0xFF342216); // nogueira (elevado)

  // Entalhe: sombra na borda de cima/esquerda, luz na borda de baixo/direita
  static const Color carveLight = Color(0xFF4A3122); // nogueira clara
  static const Color carveShadow = Color(0xFF080503);
  static const Color woodGrain = Color(0xFF3A2618); // veio da madeira
  static const Color wood = Color(0xFF8A5532); // nogueira do ícone

  // Selo do disco (ícone)
  static const Color cream = Color(0xFFEBD5B0); // creme do selo: destaques e títulos
  static const Color orange = Color(0xFFC2602F); // laranja queimado: ações principais
  static const Color rust = Color(0xFF8E3B1E); // ferrugem: alertas suaves e detalhes

  static const Color textActive = Colors.white;
  static const Color textInactive = Color(0x66F3E6D0);
  static const Color textPast = Color(0x3DF3E6D0);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: orange,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        secondary: cream,
        surface: surface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}
