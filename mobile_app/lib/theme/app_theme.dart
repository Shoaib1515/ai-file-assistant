import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Design tokens taken from the Stitch "Intelligent Asset System" design spec.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF4648D4);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF6063EE);
  static const onPrimaryContainer = Color(0xFFFFFBFF);

  static const primaryFixed = Color(0xFFE1E0FF);
  static const primaryFixedDim = Color(0xFFC0C1FF);
  static const onPrimaryFixed = Color(0xFF07006C);
  static const onPrimaryFixedVariant = Color(0xFF2F2EBE);

  static const secondary = Color(0xFF575E70);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD9DFF5);
  static const onSecondaryContainer = Color(0xFF5C6274);
  static const secondaryFixed = Color(0xFFDCE2F7);
  static const onSecondaryFixed = Color(0xFF141B2B);
  static const onSecondaryFixedVariant = Color(0xFF404758);

  static const tertiary = Color(0xFF904900);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFB55D00);
  static const onTertiaryContainer = Color(0xFFFFFBFF);
  static const tertiaryFixed = Color(0xFFFFDCC5);
  static const tertiaryFixedDim = Color(0xFFFFB783);
  static const onTertiaryFixed = Color(0xFF301400);
  static const onTertiaryFixedVariant = Color(0xFF703700);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const background = Color(0xFFF8F9FA);
  static const onBackground = Color(0xFF191C1D);

  static const surface = Color(0xFFF8F9FA);
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF464554);
  static const surfaceDim = Color(0xFFD9DADB);
  static const surfaceBright = Color(0xFFF8F9FA);
  static const surfaceVariant = Color(0xFFE1E3E4);

  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F4F5);
  static const surfaceContainer = Color(0xFFEDEEEF);
  static const surfaceContainerHigh = Color(0xFFE7E8E9);
  static const surfaceContainerHighest = Color(0xFFE1E3E4);

  static const outline = Color(0xFF767586);
  static const outlineVariant = Color(0xFFC7C4D7);

  // Semantic helpers used across file-type icons / status chips.
  static const success = Color(0xFF16A34A);
  static const successContainer = Color(0xFFDCFCE7);
  static const warning = Color(0xFF92730A);
  static const warningContainer = Color(0xFFFEF9C3);
}

class AppRadius {
  AppRadius._();
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 24.0;
  static const full = 999.0;
}

class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const containerPadding = 20.0;
  static const stackGap = 12.0;
}

class AppTextStyles {
  AppTextStyles._();

  static const _font = 'Inter';

  static const headlineXl = TextStyle(
    fontFamily: _font,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.6,
    color: AppColors.onSurface,
  );

  static const headlineLg = TextStyle(
    fontFamily: _font,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    letterSpacing: -0.2,
    color: AppColors.onSurface,
  );

  static const headlineLgMobile = TextStyle(
    fontFamily: _font,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 28 / 22,
    color: AppColors.onSurface,
  );

  static const bodyMd = TextStyle(
    fontFamily: _font,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AppColors.onSurface,
  );

  static const bodySm = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.onSurfaceVariant,
  );

  static const labelMd = TextStyle(
    fontFamily: _font,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.onSurface,
  );

  static const labelSm = TextStyle(
    fontFamily: _font,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    color: AppColors.onSurfaceVariant,
  );
}

class AppTheme {
  AppTheme._();

  static const String _themePrefKey = "is_dark_mode";
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  static Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_themePrefKey) ?? false;
      themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  static Future<void> toggleTheme(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themePrefKey, isDark);
    } catch (_) {}
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.headlineXl,
        headlineMedium: AppTextStyles.headlineLg,
        headlineSmall: AppTextStyles.headlineLgMobile,
        bodyLarge: AppTextStyles.bodyMd,
        bodyMedium: AppTextStyles.bodySm,
        labelLarge: AppTextStyles.labelMd,
        labelSmall: AppTextStyles.labelSm,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkSurface = Color(0xFF1E1F24);
    const darkBackground = Color(0xFF121316);
    const darkOnSurface = Color(0xFFE2E2E6);

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF8183F5),
        onPrimary: Color(0xFF14154B),
        primaryContainer: Color(0xFF4648D4),
        onPrimaryContainer: Color(0xFFFFFFFF),
        secondary: Color(0xFFA0A6BC),
        onSecondary: Color(0xFF1A2030),
        surface: darkSurface,
        onSurface: darkOnSurface,
        onSurfaceVariant: Color(0xFFA5A4B5),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        outline: Color(0xFF8E8D9F),
        outlineVariant: Color(0xFF383844),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.headlineXl.copyWith(color: darkOnSurface),
        headlineMedium: AppTextStyles.headlineLg.copyWith(color: darkOnSurface),
        headlineSmall: AppTextStyles.headlineLgMobile.copyWith(color: darkOnSurface),
        bodyLarge: AppTextStyles.bodyMd.copyWith(color: darkOnSurface),
        bodyMedium: AppTextStyles.bodySm.copyWith(color: const Color(0xFFA5A4B5)),
        labelLarge: AppTextStyles.labelMd.copyWith(color: darkOnSurface),
        labelSmall: AppTextStyles.labelSm.copyWith(color: const Color(0xFFA5A4B5)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkOnSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4648D4),
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.labelMd.copyWith(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF282930),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFF383844)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFF8183F5), width: 1.5),
        ),
      ),
    );
  }
}
