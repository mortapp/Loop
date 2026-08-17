"use client";

import { useActionState, useRef, useState } from "react";
import { addValuation, createListing, recordSale, type FormState } from "./actions";

const inputClass =
  "w-24 rounded-lg border border-zinc-300 bg-white px-2 py-1.5 text-xs text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50";
const buttonClass =
  "rounded-lg bg-zinc-950 px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200";

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
      <button onClick={() => setOpen(true)} className="text-xs text-zinc-400 hover:underline dark:text-zinc-500">
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
      {state?.error ? <span className="text-xs text-red-600 dark:text-red-400">{state.error}</span> : null}
    </form>
  );
}

export function ListingForm({ itemId }: { itemId: string }) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(createListing);

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-zinc-400 hover:underline dark:text-zinc-500">
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
      {state?.error ? <span className="text-xs text-red-600 dark:text-red-400">{state.error}</span> : null}
    </form>
  );
}

export function SaleForm({ itemId, listingId }: { itemId: string; listingId?: string }) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(recordSale);

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-zinc-400 hover:underline dark:text-zinc-500">
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
      {state?.error ? <span className="text-xs text-red-600 dark:text-red-400">{state.error}</span> : null}
    </form>
  );
}
