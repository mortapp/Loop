import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// Builds LOOP's shared Material theme (light and dark) — "Imperial
/// Verdigris": old-world private treasury × modern financial ledger. See
/// docs/DESIGN_SYSTEM.md for the full rationale, the WCAG contrast
/// computations, and why this replaced the earlier "Ledger" green system.
/// This is the single design system every engine (MAKE, PROTECT, RECOVER)
/// and every shared surface (Today, Money, Sell, Business, AI) draws from.
class AppTheme {
  const AppTheme._();

  /// Editorial heritage serif — wordmark, hero amounts, section titles
  /// only. Never body copy; see [_textTheme]'s per-style overrides for
  /// exactly which roles get it.
  static TextStyle _display(TextStyle base) =>
      GoogleFonts.fraunces(textStyle: base, fontWeight: FontWeight.w600);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.verdigris,
      brightness: Brightness.light,
      primary: AppColors.verdigrisDeep,
      onPrimary: AppColors.ivory,
      secondary: AppColors.archivalBlueDark,
      surface: AppColors.lightSurfaceRaised,
      error: AppColors.danger,
    );

    return _base(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.lightBackground,
      surface: AppColors.lightSurfaceRaised,
      surfaceHover: AppColors.lightSurface,
      border: AppColors.lightBorder,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      focusRing: AppColors.verdigrisDeep,
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.verdigris,
      brightness: Brightness.dark,
      primary: AppColors.verdigris,
      onPrimary: AppColors.onAccentFill,
      secondary: AppColors.archivalBlueLight,
      surface: AppColors.ledgerBlack,
      error: AppColors.danger,
    );

    return _base(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.obsidian,
      surface: AppColors.ledgerBlack,
      surfaceHover: AppColors.raisedInk,
      border: AppColors.blackenedSilver,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      focusRing: AppColors.verdigrisBright,
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
    required Color focusRing,
  }) {
    final baseTextTheme = GoogleFonts.interTextTheme();
    final textTheme = baseTextTheme
        .copyWith(
          headlineLarge: _display(
            baseTextTheme.headlineLarge!.copyWith(
              fontSize: 34,
              color: textPrimary,
              letterSpacing: 0.2,
              height: 1.05,
            ),
          ),
          headlineMedium: _display(
            baseTextTheme.headlineMedium!.copyWith(
              fontSize: 24,
              color: textPrimary,
              letterSpacing: 0.1,
            ),
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.1,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontSize: 16,
            color: textPrimary,
            height: 1.45,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: textSecondary,
            height: 1.45,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.3,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontSize: 12,
            color: textSecondary,
            letterSpacing: 0.2,
          ),
        )
        .apply(fontFamily: GoogleFonts.inter().fontFamily);

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
          side: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.35),
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBackground,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: 0.2,
            color: selected ? colorScheme.primary : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : textSecondary,
            size: 22,
          );
        }),
      ),
      iconTheme: IconThemeData(color: textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHover,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: focusRing, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.dangerText),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: border.withValues(alpha: 0.25),
          disabledForegroundColor: textSecondary.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: border.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.verdigrisText,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
