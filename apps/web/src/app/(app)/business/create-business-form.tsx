"use client";

import { useActionState } from "react";
import { createBusiness, type CreateBusinessState } from "./actions";

export function CreateBusinessForm() {
  const [state, formAction, pending] = useActionState<CreateBusinessState, FormData>(
    createBusiness,
    null,
  );

  return (
    <form action={formAction} className="flex flex-col gap-3 sm:flex-row sm:items-end">
      <label className="flex flex-1 flex-col gap-1 text-sm">
        <span className="font-medium text-zinc-700 dark:text-zinc-300">Business name</span>
        <input
          name="name"
          required
          placeholder="Acme Repair Co."
          className="rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
        />
      </label>
      <button
        type="submit"
        disabled={pending}
        className="rounded-lg bg-zinc-950 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200"
      >
        {pending ? "Creating…" : "Create business"}
      </button>
      {state?.error ? (
        <p className="text-sm text-red-600 dark:text-red-400" role="alert">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
