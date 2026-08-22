/// MADE/PROTECTED/RECOVERED/SPENT/FEES/NET for an account — the shape
/// returned by the canonical `public.account_money_totals` RPC (see
/// supabase/migrations/20260822163000_money_integrity.sql). This is the
/// one place the formula lives; this class only carries the result.
class MoneyTotals {
  const MoneyTotals({
    required this.madeCents,
    required this.protectedCents,
    required this.recoveredCents,
    required this.spentCents,
    required this.feesCents,
    required this.netCents,
  });

  static const zero = MoneyTotals(
    madeCents: 0,
    protectedCents: 0,
    recoveredCents: 0,
    spentCents: 0,
    feesCents: 0,
    netCents: 0,
  );

  factory MoneyTotals.fromJson(Map<String, dynamic> json) {
    int cents(String key) => (json[key] as num?)?.toInt() ?? 0;
    return MoneyTotals(
      madeCents: cents('made_cents'),
      protectedCents: cents('protected_cents'),
      recoveredCents: cents('recovered_cents'),
      spentCents: cents('spent_cents'),
      feesCents: cents('fees_cents'),
      netCents: cents('net_cents'),
    );
  }

  final int madeCents;
  final int protectedCents;
  final int recoveredCents;
  final int spentCents;
  final int feesCents;
  final int netCents;
}
