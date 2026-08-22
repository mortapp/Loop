"use client";

import { useActionState, useRef } from "react";
import { Button } from "@/components/ui/button";
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
    "rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";
  const labelClass = "flex flex-col gap-1 text-xs text-[var(--color-text-tertiary)]";

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
        <Button type="submit" loading={pending} variant="secondary">
          {pending ? "Adding" : "Add purchase"}
        </Button>
        {state?.error ? (
          <p className="text-sm text-[var(--color-danger-text)]" role="alert">
            {state.error}
          </p>
        ) : null}
      </div>
    </form>
  );
}
