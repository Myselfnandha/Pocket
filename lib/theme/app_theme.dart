import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/settings_model.dart';

class AppThemePalette {
  final String name;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color surfaceContainer;

  const AppThemePalette({
    required this.name,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    this.surfaceContainer = const Color(0xFF1B5E20),
  });

  static const emerald = AppThemePalette(
    name: 'Emerald Neon',
    primary: Color(0xFF4CAF50),
    primaryDark: Color(0xFF2E7D32),
    accent: Color(0xFFFFB74D),
    surfaceContainer: Color(0xFF1B5E20),
  );

  static const cyberpunk = AppThemePalette(
    name: 'Cyberpunk Purple',
    primary: Color(0xFFB388FF),
    primaryDark: Color(0xFF7C4DFF),
    accent: Color(0xFF00E5FF),
    surfaceContainer: Color(0xFF311B92),
  );

  static const sapphire = AppThemePalette(
    name: 'Midnight Sapphire',
    primary: Color(0xFF29B6F6),
    primaryDark: Color(0xFF0288D1),
    accent: Color(0xFFFFD54F),
    surfaceContainer: Color(0xFF01579B),
  );

  static const sunset = AppThemePalette(
    name: 'Sunset Gold',
    primary: Color(0xFFFFB300),
    primaryDark: Color(0xFFFF8F00),
    accent: Color(0xFFFF5252),
    surfaceContainer: Color(0xFFE65100),
  );

  static const rose = AppThemePalette(
    name: 'Rose Quartz',
    primary: Color(0xFFFF4081),
    primaryDark: Color(0xFFC2185B),
    accent: Color(0xFF00E676),
    surfaceContainer: Color(0xFF880E4F),
  );

  static AppThemePalette fromSettings({
    required AppThemePreset preset,
    int? customColorValue,
  }) {
    switch (preset) {
      case AppThemePreset.emerald:
        return emerald;
      case AppThemePreset.cyberpunk:
        return cyberpunk;
      case AppThemePreset.sapphire:
        return sapphire;
      case AppThemePreset.sunset:
        return sunset;
      case AppThemePreset.rose:
        return rose;
      case AppThemePreset.custom:
        final customColor = customColorValue != null ? Color(customColorValue) : const Color(0xFF4CAF50);
        final hsl = HSLColor.fromColor(customColor);
        final darkColor = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
        final containerColor = hsl.withLightness((hsl.lightness - 0.28).clamp(0.0, 1.0)).toColor();
        final accentColor = hsl.withHue((hsl.hue + 180) % 360).toColor();
        return AppThemePalette(
          name: 'Custom Accent',
          primary: customColor,
          primaryDark: darkColor,
          accent: accentColor,
          surfaceContainer: containerColor,
        );
    }
  }
}

class AppColors {
  // Brand colors default
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenLight = Color(0xFF4CAF50);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentOrangeLight = Color(0xFFFFB74D);

  // Semantics
  static const Color incomeGreen = Color(0xFF4CAF50);
  static const Color expenseRed = Color(0xFFEF5350);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color infoBlue = Color(0xFF29B6F6);

  // Dark Theme (Pure AMOLED vs Standard Dark)
  static const Color pureBlackBackground = Color(0xFF000000);
  static const Color darkBackground = Color(0xFF131313);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF282828);
  static const Color darkCardBorder = Color(0xFF2F2F2F);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkTextTertiary = Color(0xFF616161);

  // Light Theme
  static const Color lightBackground = Color(0xFFF7F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F4F2);
  static const Color lightCardBorder = Color(0xFFE0E0E0);
  static const Color lightTextPrimary = Color(0xFF1B1B1B);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightTextTertiary = Color(0xFF9E9E9E);
}

class AppTheme {
  static ThemeData getDarkTheme({
    bool isPureBlack = true,
    AppThemePalette palette = AppThemePalette.emerald,
  }) {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    final bgColor = isPureBlack ? AppColors.pureBlackBackground : AppColors.darkBackground;
    final surfaceColor = isPureBlack ? const Color(0xFF121212) : AppColors.darkSurface;
    final surfaceVariant = isPureBlack ? const Color(0xFF1C1C1C) : AppColors.darkSurfaceVariant;
    final borderColor = isPureBlack ? const Color(0xFF242424) : AppColors.darkCardBorder;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: ColorScheme.dark(
        primary: palette.primary,
        onPrimary: Colors.black,
        primaryContainer: palette.surfaceContainer,
        onPrimaryContainer: Colors.white,
        secondary: palette.accent,
        onSecondary: Colors.black,
        surface: surfaceColor,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: surfaceVariant,
        error: AppColors.expenseRed,
        outline: borderColor,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.darkTextPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.darkTextSecondary,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: palette.primary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        hintStyle: const TextStyle(
          color: Colors.white30,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: palette.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
      ),
    );
  }

  static ThemeData get darkTheme => getDarkTheme(isPureBlack: false);
  static ThemeData get pureBlackTheme => getDarkTheme(isPureBlack: true);

  static ThemeData getLightTheme({
    AppThemePalette palette = AppThemePalette.emerald,
  }) {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: ColorScheme.light(
        primary: palette.primaryDark,
        onPrimary: Colors.white,
        primaryContainer: palette.primary.withValues(alpha: 0.15),
        onPrimaryContainer: palette.primaryDark,
        secondary: palette.accent,
        onSecondary: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
        error: AppColors.expenseRed,
        outline: AppColors.lightCardBorder,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: AppColors.lightTextPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: AppColors.lightTextSecondary,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightCardBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: palette.primaryDark,
        unselectedItemColor: AppColors.lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        hintStyle: const TextStyle(
          color: Colors.black26,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.lightCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: palette.primaryDark,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
      ),
    );
  }

  static ThemeData get lightTheme => getLightTheme();
}
