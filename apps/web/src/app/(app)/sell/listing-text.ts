import type { Item } from "@loop/contracts";
import { formatCents } from "@/lib/format";

type ValuationRow = { estimated_value_cents: number };
type ListingRow = { marketplace: string; status: string; list_price_cents: number | null };

/**
 * The one canonical text representation of an item's listing, shared by
 * Copy/Share/Export. Mirrors `buildListingText` in
 * apps/mobile/lib/features/sell/listing_text.dart field-for-field.
 *
 * Deliberately excludes ids, account ids, Storage paths, and every other
 * backend/authorization detail — this text is meant to leave the device.
 */
export function buildListingText(
  item: Pick<Item, "name" | "category" | "condition">,
  valuation: ValuationRow | undefined,
  listings: ListingRow[],
): string {
  const lines = [item.name];

  const details = [item.category, item.condition].filter(Boolean).join(" · ");
  if (details) lines.push(details);

  const activeListing = listings.find((l) => l.status === "draft" || l.status === "active");
  if (activeListing) {
    lines.push(
      activeListing.list_price_cents != null
        ? `Asking ${formatCents(activeListing.list_price_cents)} on ${activeListing.marketplace}`
        : `Listed on ${activeListing.marketplace}`,
    );
  } else if (valuation) {
    lines.push(`Estimated value ${formatCents(valuation.estimated_value_cents)}`);
  }

  return lines.join("\n");
}
