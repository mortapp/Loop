import 'package:flutter/material.dart';

/// LOOP's shared color palette — "Murex Noir" (blackened royal ink, the
/// Tyrian/murex dye tradition translated into a near-black digital
/// material rather than a bright purple). Same hex values as
/// apps/web/src/app/globals.css so the two platforms read as one product;
/// see docs/DESIGN_SYSTEM.md for the full rationale and the WCAG contrast
/// computations behind every text/fill pairing below.
///
/// Supersedes "Imperial Verdigris" (2026-08-22, aged-copper teal) and the
/// earlier "Ledger" (mint green) system — both rejected by the owner as
/// reading like generic fintech. Every semantic getter here is
/// contrast-verified for its stated use — do not substitute a "looks
/// right" color for the one named. Several raw swatches fail WCAG AA as
/// small text directly on Murex Noir; that's why the dedicated *Text
/// roles below exist instead of using the raw swatch everywhere.
class AppColors {
  const AppColors._();

  // ---- Murex Noir (the world — near-black, barely-there plum undertone) ----
  static const murexNoir = Color(0xFF0A070B);
  static const murexInk = Color(0xFF151019);
  static const surfaceRaised = Color(0xFF1D171F);
  static const surfaceDialog = Color(0xFF251C25);

  // ---- Tyrian / Murex (LOOP identity — blackened royal ink, not neon
  // violet/SaaS purple) ----
  static const imperialPlum = Color(0xFF2B1728);
  static const tyrianDeep = Color(0xFF401C38);
  static const tyrianRoyal = Color(0xFF693754);
  static const murexBloom = Color(0xFF98637D);
  static const murexVeil = Color(0xFFC49AAF);

  // ---- Imperial Bone / Ivory (readability — warm, never sterile white) ----
  static const royalBone = Color(0xFFF1EBDD);
  static const agedIvory = Color(0xFFD9D0BE);
  static const parchmentAsh = Color(0xFFABA091);
  static const archiveDust = Color(0xFF756D66);

  // ---- Blackened Platinum (structure — borders, icons) ----
  static const platinum = Color(0xFFBCBAB5);
  static const smokedPlatinum = Color(0xFF858381);
  static const blackPlatinum = Color(0xFF48464A);
  static const platinumGhost = Color(0xFFD6D3CC);

  // ---- Antique Champagne (very rare — prestige/value markers only) ----
  static const champagne = Color(0xFFB89A68);
  static const champagneLight = Color(0xFFD0B782);
  static const champagneDark = Color(0xFF735C38);

  // ---- Royal Ruby (extremely sparing — rare seal / critical emphasis) ----
  static const royalRuby = Color(0xFF7A263D);
  static const rubyDeep = Color(0xFF481522);
  static const rubyLight = Color(0xFFA65368);

  // ---- Archival Sapphire (PROTECT / trust / information — restrained) ----
  static const sapphireAsh = Color(0xFF4D6474);
  static const sapphirePale = Color(0xFF7D94A2);
  static const sapphireDeep = Color(0xFF2B3D49);

  // ---- Semantic states (muted old-money tones, not brand identity) ----
  static const success = Color(0xFF65856E);
  static const successBright = Color(0xFF8EA894);
  static const successDeep = Color(0xFF405B48);
  static const warning = Color(0xFFB18A55);
  static const danger = Color(0xFFA44B5A);

  // =========================================================================
  // WCAG-verified semantic roles. Contrast ratios computed against the
  // dark-mode default surfaces (Murex Noir / Murex Ink); see
  // docs/DESIGN_SYSTEM.md for the full table.
  // =========================================================================

  /// Primary body text on dark surfaces. 16.9:1 on Murex Noir.
  static const textPrimary = royalBone;

  /// Secondary text — captions, supporting copy. 13.1:1 on Murex Noir.
  static const textSecondary = agedIvory;

  /// Tertiary / muted text — timestamps, placeholders. 7.8:1 on Murex Noir.
  static const textMuted = parchmentAsh;

  /// Structural labels (field labels, table headers, uppercase micro-
  /// labels). 10.3:1 on Murex Noir.
  static const textStructural = platinum;

  /// Decorative/whisper only — measures 4.0:1 on Murex Noir, which clears
  /// the 3:1 large-text/UI floor but NOT the 4.5:1 small-text threshold.
  /// Use for large (18px+ bold / 24px+) display text or non-text
  /// decoration only; never small body copy.
  static const textWhisper = archiveDust;

  /// Tyrian used as small TEXT (links, the emphasized word in "Sign in" /
  /// "Sign up" toggles) — 8.2:1 on Murex Noir. Raw `tyrianRoyal` only
  /// measures 2.2:1 as text and must not be used for text at any size;
  /// reserve it for fills and icons.
  static const tyrianText = murexVeil;

  /// Tyrian as a non-text UI accent (focus rings, active-state borders,
  /// the loop seal stroke) — 4.2:1 on Murex Noir, clears the 3:1 UI-
  /// component threshold. Not for text.
  static const tyrianAccent = murexBloom;

  /// Danger as small TEXT on dark surfaces (inline validation errors) —
  /// raw `danger` only measures 3.6:1 as text (fails AA 4.5:1), so this
  /// dedicated lighter tint (4.6:1) exists instead of using the raw
  /// swatch directly. Raw `danger` remains correct for fills/badges/icons.
  static const dangerText = Color(0xFFB0636E);

  /// Royal Ruby as small TEXT (rare — critical deadlines, destructive
  /// confirmations) — raw `royalRuby` measures 2.1:1 as text, a severe
  /// fail; this tint measures 5.3:1.
  static const rubyText = Color(0xFFAA757D);

  /// Archival Sapphire as small TEXT (PROTECT module accents, info
  /// copy) — raw `sapphireAsh` measures 3.2:1 as text (fails AA); this
  /// lighter tint (`sapphirePale`) measures 6.3:1.
  static const sapphireText = sapphirePale;

  /// Foreground for text/icons placed ON a solid Tyrian/Ruby/Sapphire/
  /// Danger fill (buttons, filled badges) — Royal Bone, not a dark ink.
  /// Dark-on-Tyrian measures 2.2:1 (fails AA normal text); Bone-on-Tyrian
  /// measures 7.8:1.
  static const onAccentFill = royalBone;

  /// Foreground for text/icons on a solid Success/Warning/Champagne
  /// fill — dark ink, not Bone (Bone-on-Success measures 3.4:1, fails;
  /// Murex Noir-on-Success measures 4.9:1).
  static const onSemanticFill = murexNoir;

  // ---- Light mode (Royal Bone ground, never plain white) ----
  static const lightBackground = royalBone;
  static const lightSurface = Color(0xFFEBE3D2);
  static const lightSurfaceRaised = Color(0xFFF8F4E9);
  static const lightBorder = agedIvory;
  static const lightTextPrimary = murexNoir;
  static const lightTextSecondary = blackPlatinum;

  /// Tertiary text in light mode — a darkened Archive Dust tint (5.0:1
  /// on Royal Bone). Raw `archiveDust` only measures 4.3:1 on Bone,
  /// marginally failing AA small text.
  static const lightTextTertiary = Color(0xFF6A635D);

  /// Accent text in light mode (links, toggle emphasis) — 12.3:1 on
  /// Royal Bone. Raw `murexBloom`/`tyrianRoyal` both fail as light-mode
  /// text (4.0:1 / 1.9:1); `tyrianDeep` is the one pairing that clears.
  static const lightTyrianText = tyrianDeep;
  static const lightDangerText = royalRuby;
  static const lightSapphireText = sapphireDeep;
  static const lightSuccessText = successDeep;
  static const lightChampagneText = champagneDark;

  // Engine accents (MAKE/Business, PROTECT, RECOVER/Sell) — used as small
  // accents (icons, thin rules, badges), never full-surface colors. Mirrors
  // the directive's per-module semantic cues: Business+Platinum, Protect+
  // Sapphire, Sell+Champagne, Money+Champagne.
  static const makeAccent = platinum;
  static const protectAccent = sapphireAsh;
  static const recoverAccent = champagne;
  static const moneyAccent = champagne;

  static Color opportunityText(Brightness brightness) =>
      brightness == Brightness.light ? champagneDark : warning;
}
