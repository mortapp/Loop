"use client";

import { useActionState, useRef } from "react";
import { createPurchase, type FormState } from "./actions";

export function CreatePurchaseForm({ items }: { items: { id: string; name: string }[] }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(async (prev, formData) => {
    const result = await createPurchase(prev, formData);
    if (!result) {
      formRef.current?.reset();
    }
    return result;
  }, null);

  const inputClass =
    "rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50";
  const labelClass = "flex flex-col gap-1 text-xs text-zinc-500 dark:text-zinc-400";

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-3">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <label className={labelClass}>
          Item (optional)
          <select name="itemId" defaultValue="" className={inputClass}>
            <option value="">Not linked to an item</option>
            {items.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
        </label>
        <label className={labelClass}>
          Vendor
          <input name="vendorName" placeholder="Where you bought it" className={inputClass} />
        </label>
        <label className={labelClass}>
          Price
          <input name="price" type="number" step="0.01" min="0" placeholder="$ paid" className={inputClass} />
        </label>
        <label className={labelClass}>
          Purchase date
          <input name="purchaseDate" type="date" className={inputClass} />
        </label>
        <label className={labelClass}>
          Return window ends
          <input name="returnWindowExpiresAt" type="date" className={inputClass} />
        </label>
        <label className={labelClass}>
          Warranty ends
          <input name="warrantyExpiresAt" type="date" className={inputClass} />
        </label>
      </div>
      <div className="flex items-center gap-3">
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-zinc-950 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200"
        >
          {pending ? "Adding…" : "Add purchase"}
        </button>
        {state?.error ? (
          <p className="text-sm text-red-600 dark:text-red-400" role="alert">
            {state.error}
          </p>
        ) : null}
      </div>
    </form>
  );
}
