"use client";

import { useActionState } from "react";
import { formInputClass, formButtonClass, formErrorClass } from "@/components/ui/form-styles";
import { createBusiness, type CreateBusinessState } from "./actions";

export function CreateBusinessForm() {
  const [state, formAction, pending] = useActionState<CreateBusinessState, FormData>(
    createBusiness,
    null,
  );

  return (
    <form action={formAction} className="flex flex-col gap-3 sm:flex-row sm:items-end">
      <label className="flex flex-1 flex-col gap-1.5">
        <span className="text-[10px] font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
          BUSINESS NAME
        </span>
        <input name="name" required placeholder="Acme Repair Co." className={formInputClass} />
      </label>
      <button type="submit" disabled={pending} className={formButtonClass}>
        {pending ? "Creating…" : "Create business"}
      </button>
      {state?.error ? (
        <p className={formErrorClass} role="alert">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
