"use client";

import { useActionState, useRef, useState } from "react";
import { addValuation, createListing, recordSale, type FormState } from "./actions";

const inputClass =
  "w-24 rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-2 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";
const buttonClass =
  "rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-3 py-1.5 text-xs font-medium text-[var(--color-on-accent)] transition-colors hover:bg-[var(--color-brand-hover)] disabled:opacity-50";

function useItemForm(action: (prev: FormState, formData: FormData) => Promise<FormState>) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(async (prev, formData) => {
    const result = await action(prev, formData);
    if (!result) {
      formRef.current?.reset();
    }
    return result;
  }, null);
  return { formRef, state, formAction, pending };
}

export function ValuationForm({ itemId }: { itemId: string }) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(addValuation);

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-[var(--color-text-tertiary)] hover:underline">
        + Valuation
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="itemId" value={itemId} />
      <input name="value" type="number" step="0.01" min="0" placeholder="$ est." className={inputClass} />
      <button type="submit" disabled={pending} className={buttonClass}>
        Save
      </button>
      {state?.error ? <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span> : null}
    </form>
  );
}

export function ListingForm({ itemId }: { itemId: string }) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(createListing);

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-[var(--color-text-tertiary)] hover:underline">
        + List for sale
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="itemId" value={itemId} />
      <input name="marketplace" placeholder="Marketplace" className={inputClass} />
      <input name="listPrice" type="number" step="0.01" min="0" placeholder="$ price" className={inputClass} />
      <button type="submit" disabled={pending} className={buttonClass}>
        List
      </button>
      {state?.error ? <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span> : null}
    </form>
  );
}

export function SaleForm({ itemId, listingId }: { itemId: string; listingId?: string }) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(recordSale);

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-[var(--color-brand-text)] hover:underline">
        + Record sale
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="itemId" value={itemId} />
      {listingId ? <input type="hidden" name="listingId" value={listingId} /> : null}
      <input name="salePrice" type="number" step="0.01" min="0" placeholder="$ sold for" className={inputClass} />
      <input name="fees" type="number" step="0.01" min="0" placeholder="$ fees" className={inputClass} />
      <button type="submit" disabled={pending} className={buttonClass}>
        Save
      </button>
      {state?.error ? <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span> : null}
    </form>
  );
}
