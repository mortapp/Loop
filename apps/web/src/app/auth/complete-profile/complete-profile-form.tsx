"use client";

import { useActionState } from "react";
import { completeProfile, type CompleteProfileState } from "./actions";
import { LoopSeal } from "@/components/ui/loop-seal";

export function CompleteProfileForm({ suggestedName, next }: { suggestedName: string; next: string }) {
  const boundAction = completeProfile.bind(null, next);
  const [state, formAction, pending] = useActionState<CompleteProfileState, FormData>(boundAction, null);

  return (
    <div className="flex min-h-dvh items-center justify-center px-4">
      <form
        action={formAction}
        className="flex w-full max-w-sm flex-col gap-4 rounded-[var(--radius-lg)] border border-[var(--color-border-subtle)] bg-[var(--color-surface)] p-6"
      >
        <div className="flex flex-col items-center gap-3 text-center">
          <LoopSeal size={32} />
          <h1 className="text-lg font-semibold text-[var(--color-text-primary)]">Welcome to LOOP</h1>
          <p className="text-sm text-[var(--color-text-secondary)]">What should we call you?</p>
        </div>

        <label className="flex flex-col gap-1.5">
          <span className="text-[10px] font-semibold tracking-[0.15em] text-[var(--color-text-secondary)]">
            NAME
          </span>
          <input
            name="displayName"
            required
            defaultValue={suggestedName}
            autoFocus
            className="rounded-[var(--radius-sm)] border border-[var(--color-border-subtle)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]"
          />
        </label>

        {state?.error ? (
          <p className="text-sm text-[var(--color-danger-text)]" role="alert">
            {state.error}
          </p>
        ) : null}

        <button
          type="submit"
          disabled={pending}
          className="mt-1 rounded-[var(--radius-sm)] px-4 py-2.5 text-sm font-semibold tracking-wide text-[var(--color-on-accent)] transition-opacity disabled:opacity-50"
          style={{ background: "linear-gradient(90deg, #2B1728, #693754, #401C38)" }}
        >
          {pending ? "Saving…" : "Continue"}
        </button>
      </form>
    </div>
  );
}
