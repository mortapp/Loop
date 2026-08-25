"use client";

import { useState } from "react";
import type { Item } from "@loop/contracts";
import { buildListingText } from "./listing-text";

const buttonClass =
  "rounded-[var(--radius-sm)] px-2 py-1 text-xs text-[var(--color-text-tertiary)] transition-colors hover:text-[var(--color-text-primary)] hover:underline disabled:opacity-50";

type ValuationRow = { estimated_value_cents: number };
type ListingRow = { marketplace: string; status: string; list_price_cents: number | null };

/**
 * Real listing preparation, not a fake marketplace publish: Copy puts the
 * canonical listing text on the clipboard, Share uses the Web Share API
 * where supported, and Export downloads the same text as a `.txt` file.
 * There is no third-party marketplace integration behind any of these.
 * Mirrors `ListingPreparationActions` in
 * apps/mobile/lib/features/sell/listing_preparation_actions.dart.
 */
export function ListingPreparationActions({
  item,
  valuation,
  listings,
}: {
  item: Pick<Item, "name" | "category" | "condition">;
  valuation?: ValuationRow;
  listings: ListingRow[];
}) {
  const [status, setStatus] = useState<string | null>(null);
  const canShare = typeof navigator !== "undefined" && "share" in navigator;

  async function copy() {
    try {
      await navigator.clipboard.writeText(buildListingText(item, valuation, listings));
      setStatus("Listing copied.");
    } catch {
      setStatus("Couldn't copy this listing. Try again.");
    }
  }

  async function share() {
    const text = buildListingText(item, valuation, listings);
    try {
      if (canShare) {
        await navigator.share({ title: item.name, text });
        // A completed share (or an intentional dismiss) is not reported as
        // an error, but it is never claimed as "shared" either -- the share
        // sheet opening is the only thing this app can actually confirm.
        setStatus(null);
      } else {
        await navigator.clipboard.writeText(text);
        setStatus("Sharing isn't available here, so the listing was copied instead.");
      }
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") return;
      setStatus("Couldn't share this listing. Try again.");
    }
  }

  function exportListing() {
    try {
      const text = buildListingText(item, valuation, listings);
      const blob = new Blob([text], { type: "text/plain" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "listing.txt";
      document.body.appendChild(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
    } catch {
      setStatus("Couldn't export this listing. Try again.");
    }
  }

  return (
    <div className="flex flex-wrap items-center gap-1">
      <button type="button" onClick={copy} className={buttonClass}>
        Copy
      </button>
      <button type="button" onClick={share} className={buttonClass}>
        Share
      </button>
      <button type="button" onClick={exportListing} className={buttonClass}>
        Export
      </button>
      {status ? (
        <span className="text-xs text-[var(--color-text-tertiary)]" role="status">
          {status}
        </span>
      ) : null}
    </div>
  );
}
