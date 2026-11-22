import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Tarsi & GCash Inspired Forest / Emerald Green Brand Palette
  static const primary = Color(0xFF2D6A4F); // Rich Tarsi Forest Green
  static const primaryLight = Color(0xFF52B788); // Fresh Emerald Leaf
  static const primaryDark = Color(0xFF1B4332); // Deep Pine Green
  static const primaryGradientEnd = Color(0xFF40916C); // Vibrant Sage Emerald
  static const primaryContainer = Color(0xFFE3F2EA); // Soft Sage Pill Container
  static const primarySoft = Color(0xFFEDF7F1); // Light Mint Tint

  // Scenic Header Nature Palette (matching Tarsi hill & rice-terrace header)
  static const scenicSkyTop = Color(0xFFE3F1E7);
  static const scenicSkyBottom = Color(0xFFC9E4D2);
  static const scenicHillLight = Color(0xFF8CC49E);
  static const scenicHillMid = Color(0xFF5A9E72);
  static const scenicHillDark = Color(0xFF35744D);

  // Background & Surface
  static const background = Color(0xFFF5F8F6); // Crisp sage-tinted off-white
  static const surface = Colors.white;
  static const surfaceSubtle = Color(0xFFF0F5F2);
  static const border = Color(0xFFE3EBE6);
  static const borderLight = Color(0xFFE9F0EC);

  // Dark Typography
  static const text = Color(0xFF18281F); // Deep forest charcoal heading
  static const textMuted = Color(0xFF6B7B71); // Muted sage-gray secondary text
  static const textSecondary = Color(0xFF829188);

  // Tarsi Accent Sets (matching the screenshot's donut chart, streak badge, and overdue pills)
  // 1. Coral / Peach (Streak flame & alerts)
  static const peachBg = Color(0xFFFFF0E6);
  static const peachColor = Color(0xFFFF6B2C);

  // 2. Pink / Rose (Tarsi 95% donut ring & overdue badge)
  static const pinkBg = Color(0xFFFDE8EF);
  static const pinkColor = Color(0xFFEC4899);
  static const overdueBg = Color(0xFFFCE8EA);
  static const overdueText = Color(0xFFD63649);

  // 3. Sky Blue (GCash / Info accent)
  static const blueBg = Color(0xFFE8F3FF);
  static const blueColor = Color(0xFF007DFE);

  // 4. Amber / Yellow
  static const yellowBg = Color(0xFFFFF6D8);
  static const yellowColor = Color(0xFFF59E0B);
  static const amberColor = Color(0xFFD97706);

  // 5. Mint / Green (Done / Taken)
  static const mintBg = Color(0xFFE3F6EB);
  static const mintColor = Color(0xFF1E8E53);
  static const greenColor = mintColor;
  static const greenBg = mintBg;

  // Semantic Aliases
  static const warning = amberColor;
  static const warningSoft = yellowBg;
  static const missed = overdueText;
  static const skipped = amberColor;
  static const pending = textSecondary;
  static const chip = primarySoft;

  // Status mapping
  static Color statusColor(String? status) => switch (status) {
        'taken' || 'done' => const Color(0xFF2D6A4F),
        'in_progress' || 'due' => const Color(0xFFD63649),
        'skipped' => const Color(0xFFD97706),
        'missed' || 'overdue' => const Color(0xFFD63649),
        _ => const Color(0xFF4F6257),
      };

  static Color statusBg(String? status) => switch (status) {
        'taken' || 'done' => const Color(0xFFE3F2EA),
        'in_progress' || 'due' => const Color(0xFFFCE8EA),
        'skipped' => const Color(0xFFFFF6D8),
        'missed' || 'overdue' => const Color(0xFFFCE8EA),
        _ => const Color(0xFFF0F4F1),
      };

  static Color forStatus(String? status) => statusColor(status);
  static IconData iconForStatus(String? status) => switch (status) {
        'taken' || 'done' => Icons.check_circle_rounded,
        'missed' || 'overdue' => Icons.error_outline_rounded,
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
