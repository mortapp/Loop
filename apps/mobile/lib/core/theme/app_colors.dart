import 'package:flutter/material.dart';

/// LOOP's shared color palette.
///
/// These are the single source of truth for color across every LOOP
/// surface (MAKE / PROTECT / RECOVER and the shared Today / Money / Sell /
/// Business / AI navigation). Domain feature UIs should reference these
/// tokens rather than hardcoding colors, so the whole app reads as one
/// coherent product.
class AppColors {
  const AppColors._();

  // Brand
  static const Color primary = Color(0xFF3B5BFB);
  static const Color primaryDark = Color(0xFF2A3FD6);
  static const Color secondary = Color(0xFF00C2A8);

  // Neutrals
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEFF1F5);
  static const Color border = Color(0xFFE2E5EB);

  static const Color textPrimary = Color(0xFF13161C);
  static const Color textSecondary = Color(0xFF5A6273);
  static const Color textMuted = Color(0xFF9AA1B1);

  // Dark mode neutrals
  static const Color backgroundDark = Color(0xFF0E1015);
  static const Color surfaceDark = Color(0xFF181B22);
  static const Color surfaceAltDark = Color(0xFF20242E);
  static const Color borderDark = Color(0xFF2B303B);

  static const Color textPrimaryDark = Color(0xFFF2F3F6);
  static const Color textSecondaryDark = Color(0xFFAEB4C2);
  static const Color textMutedDark = Color(0xFF6E7484);

  // Semantic
  static const Color success = Color(0xFF1FA971);
  static const Color warning = Color(0xFFE0A61F);
  static const Color danger = Color(0xFFE5484D);

  // Engine accents (MAKE / PROTECT / RECOVER) — used sparingly as accents,
  // never as full-surface colors, to keep the app feeling unified.
  static const Color makeAccent = Color(0xFFFF8A3D); // MAKE / QuoteCloser
  static const Color protectAccent = Color(0xFF3B5BFB); // PROTECT / ReturnGuard
  static const Color recoverAccent = Color(0xFF00C2A8); // RECOVER / ResellLens
}
