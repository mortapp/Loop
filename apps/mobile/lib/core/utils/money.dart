/// Shared money helpers: LOOP stores every amount as integer cents
/// (`*_cents bigint` columns — see docs/DECISIONS.md "Money is always
/// integer cents"). These helpers convert to/from a dollar-denominated UI
/// the same way the web app does: parse the decimal digits exactly and format
/// cents back to a `$1,234.56`-style string.
///
/// No `intl` dependency is used here on purpose — it isn't already a
/// dependency of this app, and the formatting need is simple enough to do
/// by hand.
class MoneyUtils {
  const MoneyUtils._();

  static const maxMoneyCents = 100000000000;

  /// Parses a dollar-denominated string (e.g. from a text field) into
  /// integer cents without passing through a binary floating-point value.
  ///
  /// Returns null for a blank/unparseable input.
  static int? dollarsStringToCents(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(trimmed);
    if (match == null) return null;

    final wholeDollars = int.tryParse(match.group(1)!);
    if (wholeDollars == null) return null;
    final fractional = (match.group(2) ?? '').padRight(2, '0');
    final fractionalCents = int.parse(fractional.isEmpty ? '0' : fractional);
    final cents = wholeDollars * 100 + fractionalCents;
    if (cents > maxMoneyCents) return null;
    return cents;
  }

  /// Formats integer cents as a `$1,234.56`-style string. Negative amounts
  /// get a leading `-` before the currency symbol. Null renders as an
  /// em dash, matching the web app's `formatCents(null) => "—"`.
  static String formatCents(int? cents, {String currencySymbol = '\$'}) {
    if (cents == null) return '—';
    final negative = cents < 0;
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remainder = absCents % 100;
    final dollarsStr = _groupThousands(dollars);
    final centsStr = remainder.toString().padLeft(2, '0');
    return '${negative ? '-' : ''}$currencySymbol$dollarsStr.$centsStr';
  }

  static String _groupThousands(int n) {
    final s = n.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
