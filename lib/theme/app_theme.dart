import 'package:flutter/material.dart';

class AppColors {
  // Figma Primary Brand
  static const primary = Color(0xFF5F33E1); // Vibrant Royal Purple
  static const primaryLight = Color(0xFF8764FF);
  static const primaryGradientEnd = Color(0xFF6C40FE);
  static const primaryContainer = Color(0xFFEDE4FF); // Soft Lavender
  static const primarySoft = Color(0xFFEEE9FF);

  // Background & Surface
  static const background = Color(0xFFF9F9FB);
  static const surface = Colors.white;
  static const surfaceSubtle = Color(0xFFF8F9FE);
  static const border = Color(0xFFF0EEF8);
  static const borderLight = Color(0xFFEBE8F5);

  // Dark Typography
  static const text = Color(0xFF24252C); // Deep off-black heading
  static const textMuted = Color(0xFF6E6A7C); // Muted subtitle text
  static const textSecondary = Color(0xFF8E8B9A);

  // Figma Pastel Accent Sets
  // 1. Coral / Peach
  static const peachBg = Color(0xFFFFE9E1);
  static const peachColor = Color(0xFFFF7D53);

  // 2. Pink / Rose
  static const pinkBg = Color(0xFFFFE4F2);
  static const pinkColor = Color(0xFFF478B8);

  // 3. Sky Blue
  static const blueBg = Color(0xFFE7F3FF);
  static const blueColor = Color(0xFF0087FF);

  // 4. Amber / Yellow
  static const yellowBg = Color(0xFFFFF6D4);
  static const yellowColor = Color(0xFFFFD12E);
  static const amberColor = Color(0xFFFFA927);

  // 5. Mint / Green (Done / Taken)
  static const mintBg = Color(0xFFE8F8F0);
  static const mintColor = Color(0xFF22C55E);
  static const greenColor = mintColor;
  static const greenBg = mintBg;

  // Semantic Aliases
  static const warning = amberColor;
  static const warningSoft = yellowBg;
  static const missed = pinkColor;
  static const skipped = amberColor;
  static const pending = textSecondary;
  static const chip = primarySoft;

  // Status mapping
  static Color statusColor(String? status) => switch (status) {
        'taken' => mintColor,
        'missed' => pinkColor,
        'skipped' => amberColor,
        _ => blueColor,
      };

  static Color statusBg(String? status) => switch (status) {
        'taken' => mintBg,
        'missed' => pinkBg,
        'skipped' => yellowBg,
        _ => blueBg,
      };

  static Color forStatus(String? status) => statusColor(status);
  static IconData iconForStatus(String? status) => switch (status) {
        'taken' => Icons.check_circle_rounded,
        'missed' => Icons.error_outline_rounded,
        'skipped' => Icons.remove_circle_outline_rounded,
        _ => Icons.medication_outlined,
      };
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.background,
    );

    OutlineInputBorder roundedBorder(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: roundedBorder(AppColors.border),
        enabledBorder: roundedBorder(AppColors.border),
        focusedBorder: roundedBorder(AppColors.primary, 1.8),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }
}
