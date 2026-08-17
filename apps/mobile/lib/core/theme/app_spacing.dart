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

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
}
