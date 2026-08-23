"use client";

import { useActionState } from "react";
import { formInputClass, formButtonClass, formErrorClass } from "@/components/ui/form-styles";
import { updateProfile, type FormState } from "./actions";

export function ProfileForm({ initialDisplayName }: { initialDisplayName: string }) {
  const [state, formAction, pending] = useActionState<FormState, FormData>(updateProfile, null);

  return (
    <form action={formAction} className="flex flex-col gap-3">
      <label className="flex flex-col gap-1.5">
        <span className="text-[10px] font-semibold tracking-[0.1em] text-[var(--color-text-secondary)]">
          DISPLAY NAME
        </span>
        <input
          name="displayName"
          defaultValue={initialDisplayName}
          required
          maxLength={80}
          className={formInputClass}
        />
      </label>

      <div className="flex items-center gap-3">
        <button type="submit" disabled={pending} className={formButtonClass}>
          {pending ? "Saving…" : "Save"}
        </button>
        {state && "error" in state ? <span className={formErrorClass}>{state.error}</span> : null}
        {!pending && state && "success" in state ? (
          <span className="text-xs text-[var(--color-text-tertiary)]">Saved</span>
        ) : null}
      </div>
    </form>
  );
}
