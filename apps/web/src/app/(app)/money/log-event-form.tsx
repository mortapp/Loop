"use client";

import { useActionState, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { logMoneyEvent, type FormState } from "./actions";

export function LogEventForm({ initialRequestId }: { initialRequestId: string }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [requestId, setRequestId] = useState(initialRequestId);
  const [state, formAction, pending] = useActionState<FormState, FormData>(
    async (prev, formData) => {
      const result = await logMoneyEvent(prev, formData);
      if (!result) {
        formRef.current?.reset();
        setRequestId(crypto.randomUUID());
      }
      return result;
    },
    null,
  );

  const inputClass =
    "rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-3">
      <input type="hidden" name="requestId" value={requestId} />
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <label className="flex flex-col gap-1">
          <span className="sr-only">Kind</span>
          <select name="kind" required defaultValue="earn" className={inputClass}>
            <option value="earn">Earn</option>
            <option value="spend">Spend</option>
            <option value="refund">Refund</option>
            <option value="fee">Fee</option>
            <option value="recovered">Recovered</option>
          </select>
        </label>
        <label className="flex flex-col gap-1">
          <span className="sr-only">Amount</span>
          <input
            name="amount"
            type="number"
            step="0.01"
            min="0.01"
            required
            placeholder="$ amount"
            className={inputClass}
          />
        </label>
        <label className="flex flex-col gap-1">
          <span className="sr-only">Description</span>
          <input name="description" placeholder="Description (optional)" className={inputClass} />
        </label>
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" loading={pending} disabled={!requestId} variant="secondary">
          {pending ? "Logging" : "Log entry"}
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
