"use client";

import { useActionState, useRef } from "react";
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
    "rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50";

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
        <button
          type="submit"
          disabled={pending}
          className="rounded-lg bg-zinc-950 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200"
        >
          {pending ? "Adding…" : "Add item"}
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
