"use client";

import { useActionState, useRef } from "react";
import { Button } from "@/components/ui/button";
import { createAction, type CreateActionState } from "./actions";

export function QuickAddForm() {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<CreateActionState, FormData>(
    async (prev, formData) => {
      const result = await createAction(prev, formData);
      if (!result) {
        formRef.current?.reset();
      }
      return result;
    },
    null,
  );

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-2">
      <div className="flex items-start gap-2">
        <label className="flex-1">
          <span className="sr-only">Add something to do</span>
          <input
            name="title"
            required
            placeholder="Add something to do…"
            className="w-full rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]"
          />
        </label>
        <Button type="submit" loading={pending}>
          {pending ? "Adding" : "Add"}
        </Button>
      </div>
      {state?.error ? (
        <p className="text-sm text-[var(--color-danger-text)]" role="alert">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
