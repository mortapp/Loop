"use client";

import { useActionState, useRef } from "react";
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
    <form ref={formRef} action={formAction} className="flex items-start gap-2">
      <input
        name="title"
        required
        placeholder="Add something to do…"
        className="flex-1 rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
      />
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg bg-zinc-950 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200"
      >
        {pending ? "Adding…" : "Add"}
      </button>
      {state?.error ? (
        <p className="text-sm text-red-600 dark:text-red-400" role="alert">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
