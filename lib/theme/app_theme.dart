import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Figma Primary Brand (Royal Purple)
  static const primary = Color(0xFF5F33E1); // Vibrant Royal Purple
  static const primaryLight = Color(0xFF8764FF);
  static const primaryDark = Color(0xFF4C23CE);
  static const primaryGradientEnd = Color(0xFF6C40FE);
  static const primaryContainer = Color(0xFFEDE8FF); // Soft Lavender
  static const primarySoft = Color(0xFFF0EDFD);

  // Background & Surface
  static const background = Color(0xFFF9F9FC); // Crisp soft background matching Slide 1 & 2
  static const surface = Colors.white;
  static const surfaceSubtle = Color(0xFFF8F9FE);
  static const border = Color(0xFFF0EEF8);
  static const borderLight = Color(0xFFECE8F6);

  // Dark Typography
  static const text = Color(0xFF24252C); // Deep charcoal heading
  static const textMuted = Color(0xFF7A7A85); // Muted secondary text
  static const textSecondary = Color(0xFF8E8E93);

  // Figma Pastel Accent Sets matching Slide 1 & 2
  // 1. Coral / Peach
  static const peachBg = Color(0xFFFFF0E8);
  static const peachColor = Color(0xFFFF7D53);

  // 2. Pink / Rose
  static const pinkBg = Color(0xFFFFEBF4);
  static const pinkColor = Color(0xFFFF5C98);

  // 3. Sky Blue
  static const blueBg = Color(0xFFEBF5FF);
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

  // Status mapping matching Slide 2
  static Color statusColor(String? status) => switch (status) {
        'taken' || 'done' => const Color(0xFF5F33E1), // Royal purple on soft lavender
        'in_progress' || 'due' => const Color(0xFFFF7A00), // Vibrant orange
        'skipped' => const Color(0xFFFFA927), // Amber
        'missed' => const Color(0xFFFF5C98), // Rose
        _ => const Color(0xFF0087FF), // Sky blue ("To-do")
      };

  static Color statusBg(String? status) => switch (status) {
        'taken' || 'done' => const Color(0xFFEDE8FF), // Soft lavender pill
        'in_progress' || 'due' => const Color(0xFFFFF0E6), // Soft peach pill
        'skipped' => const Color(0xFFFFF6D4), // Soft yellow pill
        'missed' => const Color(0xFFFFEBF4), // Soft rose pill
        _ => const Color(0xFFEBF5FF), // Soft sky blue pill
      };

  static Color forStatus(String? status) => statusColor(status);
  static IconData iconForStatus(String? status) => switch (status) {
        'taken' || 'done' => Icons.check_circle_rounded,
        'missed' => Icons.error_outline_rounded,
        'skipped' => Icons.remove_circle_outline_rounded,
        _ => Icons.medication_outlined,
      };
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    );

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
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: roundedBorder(AppColors.border),
        enabledBorder: roundedBorder(AppColors.border),
        focusedBorder: roundedBorder(AppColors.primary, 1.8),
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textMuted, fontSize: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }
}
