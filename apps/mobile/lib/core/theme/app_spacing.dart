/// Shared spacing scale used across every LOOP screen.
///
/// Keep to this scale rather than inventing one-off values so density
/// stays consistent between Today / Money / Sell / Business / AI and the
/// MAKE / PROTECT / RECOVER domain screens built on top of them.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Same values as apps/web's --radius-sm/md/lg (docs/DESIGN_SYSTEM.md) —
  // deliberately not one radius everywhere. Small interactive elements
  // read as more precise with a tighter radius; larger containers get
  // more.
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;
}
