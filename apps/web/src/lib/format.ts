/**
 * Shared money formatting — consolidates five near-identical `formatCents`
 * functions that had drifted slightly (some supported `null`, one took a
 * `currency` param, others hardcoded USD). One implementation, superset of
 * what every call site needed.
 */
export function formatCents(
  cents: number | null | undefined,
  currency = "USD",
  { signDisplay = false }: { signDisplay?: boolean } = {},
): string {
  if (cents === null || cents === undefined) return "—";
  return (cents / 100).toLocaleString(undefined, {
    style: "currency",
    currency,
    signDisplay: signDisplay ? "exceptZero" : "auto",
  });
}
