"use client";

import { useActionState, useId } from "react";
import type { ActionResult, BoundAction } from "@/lib/action-result";

type InlineActionFormProps = {
  action: BoundAction;
  label: string;
  pendingLabel?: string;
  ariaLabel?: string;
  formClassName?: string;
  buttonClassName?: string;
  errorClassName?: string;
};

/**
 * A small Server Action form with honest pending and expected-error states.
 * Bound actions still enforce account scope and RLS on the server; this
 * component only makes their result visible and prevents double submits.
 */
export function InlineActionForm({
  action,
  label,
  pendingLabel = "Saving…",
  ariaLabel,
  formClassName = "",
  buttonClassName = "",
  errorClassName = "",
}: InlineActionFormProps) {
  const [state, formAction, pending] = useActionState<ActionResult, FormData>(action, null);
  const errorId = useId();

  return (
    <form action={formAction} className={`inline-flex flex-col items-start gap-1 ${formClassName}`}>
      <button
        type="submit"
        disabled={pending}
        aria-label={ariaLabel}
        aria-busy={pending || undefined}
        aria-describedby={state?.error ? errorId : undefined}
        className={`focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--color-border-strong)] disabled:pointer-events-none disabled:opacity-50 ${buttonClassName}`}
      >
        {pending ? pendingLabel : label}
      </button>
      {state?.error ? (
        <span
          id={errorId}
          role="alert"
          className={`max-w-56 text-xs text-[var(--color-danger-text)] ${errorClassName}`}
        >
          {state.error}
        </span>
      ) : null}
    </form>
  );
}
