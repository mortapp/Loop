import 'package:flutter/material.dart';

/// LOOP's shared color palette — the "Ledger" direction (premium
/// financial utility + editorial restraint). Same hex values as
/// apps/web/src/app/globals.css so the two platforms read as one product;
/// see docs/DESIGN_SYSTEM.md for the full rationale, the three directions
/// considered, and the WCAG contrast computations behind every pair.
///
/// These are the single source of truth for color across every LOOP
/// surface (MAKE / PROTECT / RECOVER and the shared Today / Money / Sell /
/// Business / AI navigation). Domain feature UIs should reference these
/// tokens rather than hardcoding colors, so the whole app reads as one
/// coherent product.
class AppColors {
  const AppColors._();

  // Brand — LOOP Green: primary value/momentum, MAKE+RECOVER's positive
  // outcomes. A real, distinctive green, not Material's default.
  static const Color brand = Color(0xFF2FAE7A);
  static const Color brandHover = Color(0xFF279467);
  static const Color brandPressed = Color(0xFF1F7A55);

  // Secondary — Ice Blue: PROTECT, informational state, data.
  static const Color info = Color(0xFF3D7EEB);

  // Warm Value Accent — recoverable value, RECOVER estimates. Explicitly
  // labeled as an estimate wherever it's shown, never implied guaranteed.
  static const Color opportunity = Color(0xFFD98A3D);

  // Neutrals — light mode. Deliberately warm, not cold: #FAFAF8, not
  // true #FFFFFF, is what separates "premium" from a default template.
  static const Color background = Color(0xFFFAFAF8);
  static const Color backgroundSecondary = Color(0xFFF2F1ED);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHover = Color(0xFFF5F4F0);
  static const Color border = Color(0xFFE5E4DF);
  static const Color borderStrong = Color(0xFFD3D2CB);

  static const Color textPrimary = Color(0xFF14141A);
  static const Color textSecondary = Color(0xFF55555D);
  static const Color textMuted = Color(0xFF8A8A90);

  // Neutrals — dark mode (default; a financial utility people check
  // often benefits from a calmer, lower-glare default). Warm near-black,
  // not true #000.
  static const Color backgroundDark = Color(0xFF0A0A0C);
  static const Color backgroundSecondaryDark = Color(0xFF101013);
  static const Color surfaceDark = Color(0xFF17171B);
  static const Color surfaceHoverDark = Color(0xFF1E1E23);
  static const Color borderDark = Color(0xFF24242A);
  static const Color borderStrongDark = Color(0xFF35353C);

  static const Color textPrimaryDark = Color(0xFFF5F5F2);
  static const Color textSecondaryDark = Color(0xFFA8A8AD);
  static const Color textMutedDark = Color(0xFF6E6E74);

  // Semantic
  static const Color success = brand;
  static const Color warning = Color(0xFFD9A73D);
  static const Color danger = Color(0xFFE0473F);

  // Foreground for text/icons placed ON a solid accent fill (buttons,
  // filled badges) — dark, not white. White-on-brand-green measured
  // 2.58:1 (WCAG fail); dark-on-brand-green measures 7.02:1.
  static const Color onAccent = Color(0xFF0A0A0C);

  // -soft tinted backgrounds (badges, subtle highlights) — never used as
  // a text color themselves.
  static const Color brandSoftLight = Color(0xFFE8F5EE);
  static const Color brandSoftDark = Color(0xFF12261C);
  static const Color infoSoftLight = Color(0xFFEAF1FE);
  static const Color infoSoftDark = Color(0xFF101B2E);
  static const Color opportunitySoftLight = Color(0xFFFBF0E2);
  static const Color opportunitySoftDark = Color(0xFF2A1E10);
  static const Color dangerSoftLight = Color(0xFFFDEAE8);
  static const Color dangerSoftDark = Color(0xFF2E1210);

  // Small colored text on a light background needs a darker variant of
  // the solid accent to clear WCAG AA (solid brand/opportunity on
  // #FAFAF8 measured 2.69:1 / 2.63:1 — real failures, fixed here).
  static const Color brandTextLight = brandPressed; // 5.06:1
  static const Color opportunityTextLight = Color(0xFF8A5119); // 6.14:1
  static const Color infoTextLight = Color(0xFF1E5BC4); // 6.00:1
  static const Color dangerTextLight = Color(0xFFB8362E); // 5.57:1

  // In dark mode the solid accent already clears AA on the dark
  // backgrounds above, so only light mode needs the darkened variant.
  static Color opportunityText(Brightness brightness) =>
      brightness == Brightness.light ? opportunityTextLight : opportunity;

  // Engine accents (MAKE / PROTECT / RECOVER) — used sparingly as accents,
  // never as full-surface colors, to keep the app feeling unified.
  static const Color makeAccent = opportunity;
  static const Color protectAccent = info;
  static const Color recoverAccent = brand;
}
