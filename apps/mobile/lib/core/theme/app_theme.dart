import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Builds LOOP's shared Material theme (light and dark) — the "Ledger"
/// direction. See docs/DESIGN_SYSTEM.md for the full rationale; this is
/// the single design system every engine (MAKE, PROTECT, RECOVER) and
/// every shared surface (Today, Money, Sell, Business, AI) draws from.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.info,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    return _base(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.background,
      surface: AppColors.surface,
      surfaceHover: AppColors.surfaceHover,
      border: AppColors.border,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.dark,
      primary: AppColors.brand,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.info,
      surface: AppColors.surfaceDark,
      error: AppColors.danger,
    );

    return _base(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.backgroundDark,
      surface: AppColors.surfaceDark,
      surfaceHover: AppColors.surfaceHoverDark,
      border: AppColors.borderDark,
      textPrimary: AppColors.textPrimaryDark,
      textSecondary: AppColors.textSecondaryDark,
    );
  }

  static ThemeData _base({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color surface,
    required Color surfaceHover,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final textTheme = TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: surfaceHover,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.brandSoftDark.withValues(alpha: 1),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colorScheme.primary : textSecondary,
          );
        }),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: AppColors.onAccent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
