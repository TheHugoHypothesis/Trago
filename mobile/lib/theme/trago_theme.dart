import 'package:flutter/material.dart';

class TragoColors {
  // Cores principais extraídas diretamente de InitialAssets/Design.png
  static const Color navy = Color(0xFF001C44);
  static const Color navyLight = Color(0xFF0A2E63);
  static const Color coral = Color(0xFFFE5656);
  static const Color coralDark = Color(0xFFE63E3E);
  static const Color coralSoft = Color(0xFFFFECEC);

  // Tons de confiança, verificação e cálculo fiscal
  static const Color verifiedBlue = Color(0xFF007AFF);
  static const Color skyLight = Color(0xFFEAF5FE);
  static const Color skyBorder = Color(0xFFC7E2FC);
  static const Color mintLight = Color(0xFFD7F2E4);
  static const Color mintBorder = Color(0xFFA7E3C5);
  static const Color mint = Color(0xFF0E9F6E);
  static const Color starAmber = Color(0xFFF59E0B);

  // Superfícies e tipografia
  static const Color ink = Color(0xFF101828);
  static const Color slate = Color(0xFF344054);
  static const Color muted = Color(0xFF64748B);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF3F6FA);
  static const Color borderGray = Color(0xFFE2E8F0);

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF001C44).withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get coralGlow => [
    BoxShadow(
      color: coral.withValues(alpha: 0.35),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

class TragoTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: TragoColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: TragoColors.coral,
        primary: TragoColors.coral,
        secondary: TragoColors.navy,
        surface: TragoColors.paper,
        error: TragoColors.coralDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TragoColors.paper,
        foregroundColor: TragoColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: TragoColors.navy,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: TragoColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: TragoColors.borderGray, width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TragoColors.coral,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TragoColors.navy,
          side: const BorderSide(color: TragoColors.borderGray, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TragoColors.paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TragoColors.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TragoColors.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TragoColors.navy, width: 1.5),
        ),
        labelStyle: const TextStyle(color: TragoColors.muted, fontSize: 14),
        hintStyle: const TextStyle(color: TragoColors.muted, fontSize: 14),
      ),
    );
  }
}
