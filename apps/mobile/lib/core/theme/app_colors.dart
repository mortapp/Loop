import 'package:flutter/material.dart';

/// LOOP's shared color palette — "Imperial Verdigris" (old-world royal
/// treasury × private financial ledger). Same hex values as
/// apps/web/src/app/globals.css so the two platforms read as one product;
/// see docs/DESIGN_SYSTEM.md for the full rationale and the WCAG contrast
/// computations behind every text/fill pairing below.
///
/// Every semantic getter here is contrast-verified for its stated use —
/// do not substitute a "look right" color for the one named. The raw
/// swatches (Verdigris, Oxblood, Danger) fail WCAG AA as small text
/// directly on dark surfaces; that's why the *Text variants exist.
class AppColors {
  const AppColors._();

  // ---- Royal Obsidian (the world) ----
  static const obsidian = Color(0xFF08090A);
  static const deepInk = Color(0xFF0E1011);
  static const ledgerBlack = Color(0xFF151718);
  static const raisedInk = Color(0xFF1B1E1F);

  // ---- Imperial Verdigris (LOOP identity — aged oxidized copper, not
  // mint/emerald/banking green) ----
  static const verdigris = Color(0xFF356C67);
  static const verdigrisDeep = Color(0xFF1D4543);
  static const verdigrisDark = Color(0xFF102F2F);
  static const verdigrisBright = Color(0xFF5E9891);
  static const verdigrisLight = Color(0xFF8BBAB2);
  static const verdigrisGhost = Color(0xFFB8D5CE);
  static const verdigrisShadow = Color(0xFF081D1E);

  // ---- Cathedral Ivory (clarity / premium typography) ----
  static const ivory = Color(0xFFF1ECDD);
  static const agedIvory = Color(0xFFD8D0BF);
  static const parchment = Color(0xFFBDB3A1);
  static const mutedParchment = Color(0xFF8F877A);

  // ---- Blackened Silver / Pewter (structure) ----
  static const blackenedSilver = Color(0xFF777D7B);
  static const agedSilver = Color(0xFFA8ACA6);
  static const royalPewter = Color(0xFFC2C4BC);
  static const palePewter = Color(0xFFD8D9D1);

  // ---- Oxblood Seal (rare archival/royal emphasis — used sparingly) ----
  static const oxblood = Color(0xFF6D2934);
  static const oxbloodDeep = Color(0xFF421820);
  static const oxbloodLight = Color(0xFF98505B);

  // ---- Archival Blue (information / protection — restrained) ----
  static const archivalBlue = Color(0xFF536D73);
  static const archivalBlueLight = Color(0xFF7F999E);
  static const archivalBlueDark = Color(0xFF30474B);

  // ---- Semantic states ----
  static const success = Color(0xFF6E9B78);
  static const successDeep = Color(0xFF456C50);
  static const warning = Color(0xFFB38A51);
  static const danger = Color(0xFFA14E53);

  // =========================================================================
  // WCAG-verified semantic roles. Contrast ratios computed against the
  // dark-mode default surfaces (Obsidian/Ink/LedgerBlack); see
  // docs/DESIGN_SYSTEM.md for the full table.
  // =========================================================================

  /// Primary body text on dark surfaces. 16.9:1 on Obsidian.
  static const textPrimary = ivory;

  /// Secondary text — captions, supporting copy. 9.6:1 on Obsidian.
  static const textSecondary = parchment;

  /// Tertiary / muted text — timestamps, placeholders. 5.6:1 on Obsidian.
  static const textMuted = mutedParchment;

  /// Structural labels (field labels, table headers). 8.7:1 on Obsidian.
  static const textStructural = agedSilver;

  /// Verdigris used as small TEXT (links, the emphasized word in "Sign
  /// in" / "Sign up" toggles) — 6.1:1 on Obsidian. The raw `verdigris`
  /// swatch only measures 3.3:1 as text and must not be used for text
  /// at body size; reserve it for fills, icons, and large (18px+ bold
  /// or 24px+) headings, where 3:1 is the correct AA threshold.
  static const verdigrisText = verdigrisBright;

  /// Danger/Oxblood as small TEXT on dark surfaces (inline error copy,
  /// overdue-deadline emphasis) — neither raw swatch clears 4.5:1 as
  /// text (Oxblood 1.9:1, Danger 3.5:1), so both get a lighter,
  /// text-specific tint here instead of being used directly.
  static const dangerText = Color(0xFFC97882);
  static const oxbloodText = Color(0xFFC08088);

  /// Foreground for text/icons placed ON a solid Verdigris/Oxblood/
  /// Danger/ArchivalBlue fill (buttons, filled badges) — Ivory, not a
  /// dark ink. Dark-on-Verdigris measured 3.3:1 (fails AA normal text);
  /// Ivory-on-Verdigris measures 5.1:1.
  static const onAccentFill = ivory;

  /// Foreground for text/icons on a solid Success/Warning fill — dark
  /// ink, not Ivory (Ivory-on-Success measures 2.7:1, fails).
  static const onSemanticFill = obsidian;

  // ---- Light mode (Cathedral Ivory ground, never plain white) ----
  static const lightBackground = ivory;
  static const lightSurface = Color(0xFFF7F3E8);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightBorder = agedIvory;
  static const lightTextPrimary = obsidian;
  static const lightTextSecondary = Color(0xFF4A4740);
  static const lightVerdigrisText = verdigrisDeep;

  // Engine accents (MAKE / PROTECT / RECOVER) — used as small accents,
  // never full-surface colors.
  static const makeAccent = oxbloodLight;
  static const protectAccent = archivalBlueLight;
  static const recoverAccent = verdigrisBright;

  // ===========================================================================
  // Compatibility aliases for the pre-"Imperial Verdigris" ("Ledger") token
  // names. The Step 1 reconstruction directive redesigns only a handful of
  // reference screens first (auth, Today, Money, Sell, Business/Quotes) —
  // every other screen keeps compiling and inherits the new palette
  // automatically through these aliases until it gets its own real pass.
  // Do not add new call sites against these names; use the semantic roles
  // above instead. Remove once every screen has been migrated off them.
  // ===========================================================================
  static const brand = verdigris;
  static const info = archivalBlueLight;
  static const opportunity = warning;
  static const background = obsidian;
  static const backgroundDark = obsidian;
  static const surface = ledgerBlack;
  static const surfaceDark = ledgerBlack;
  static const surfaceHover = raisedInk;
  static const surfaceHoverDark = raisedInk;
  static const border = blackenedSilver;
  static const borderDark = blackenedSilver;
  static const textPrimaryDark = ivory;
  static const textSecondaryDark = parchment;
  static const onAccent = ivory;
  static const brandSoftDark = verdigrisDark;

  static Color opportunityText(Brightness brightness) =>
      brightness == Brightness.light ? Color(0xFF8A6423) : warning;
}
