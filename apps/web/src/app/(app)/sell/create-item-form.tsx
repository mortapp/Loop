"use client";

import { useActionState, useRef } from "react";
import { Button } from "@/components/ui/button";
import { createItem, type FormState } from "./actions";

export function CreateItemForm() {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(async (prev, formData) => {
    const result = await createItem(prev, formData);
    if (!result) {
      formRef.current?.reset();
    }
    return result;
  }, null);

  const inputClass =
    "rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-3">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-4">
        <input name="name" required placeholder="Item name" className={inputClass} />
        <input name="category" placeholder="Category (optional)" className={inputClass} />
        <input name="condition" placeholder="Condition (optional)" className={inputClass} />
        <input
          name="purchasePrice"
          type="number"
          step="0.01"
          min="0"
          placeholder="Paid ($, optional)"
          className={inputClass}
        />
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" loading={pending} variant="secondary">
          {pending ? "Adding" : "Add item"}
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
