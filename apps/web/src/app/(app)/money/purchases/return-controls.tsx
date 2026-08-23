"use client";

import { useActionState, useRef, useState } from "react";
import { InlineActionForm } from "@/components/ui/inline-action-form";
import { StatusBadge } from "@/components/ui/status-badge";
import { startReturn, setReturnStatus, refundReturn, type FormState } from "./actions";
import type { ReturnStatus } from "@loop/contracts";

const inputClass =
  "w-32 rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-2 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";
const buttonClass =
  "rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-3 py-1.5 text-xs font-medium text-[var(--color-on-accent)] transition-colors hover:bg-[var(--color-brand-hover)] disabled:opacity-50";

const STATUS_TONE: Record<ReturnStatus, "neutral" | "info" | "brand" | "danger"> = {
  initiated: "neutral",
  shipped: "info",
  received: "info",
  refunded: "brand",
  denied: "danger",
};

const FORWARD_RETURN_STATUSES: Partial<Record<ReturnStatus, Array<"shipped" | "received">>> = {
  initiated: ["shipped", "received"],
  shipped: ["received"],
  received: [],
};

function StartReturnForm({ purchaseId, itemId }: { purchaseId: string; itemId: string | null }) {
  const [open, setOpen] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(
    async (prev, formData) => {
      const result = await startReturn(prev, formData);
      if (!result) formRef.current?.reset();
      return result;
    },
    null,
  );

  if (!itemId) {
    return (
      <p className="text-xs text-[var(--color-text-tertiary)]">
        No item linked — can&apos;t start a return.
      </p>
    );
  }

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="text-xs text-[var(--color-text-tertiary)] hover:underline"
      >
        + Start return
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="purchaseId" value={purchaseId} />
      <input type="hidden" name="itemId" value={itemId} />
      <input name="reason" placeholder="Reason" className={inputClass} />
      <button type="submit" disabled={pending} className={buttonClass}>
        Start
      </button>
      {state?.error ? (
        <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span>
      ) : null}
    </form>
  );
}

function RefundForm({ returnId, itemId }: { returnId: string; itemId: string }) {
  const [open, setOpen] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(
    async (prev, formData) => {
      const result = await refundReturn(prev, formData);
      if (!result) formRef.current?.reset();
      return result;
    },
    null,
  );

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="text-xs text-[var(--color-brand-text)] hover:underline"
      >
        Refund
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="returnId" value={returnId} />
      <input type="hidden" name="itemId" value={itemId} />
      <input
        name="amount"
        type="number"
        step="0.01"
        min="0"
        placeholder="$ refunded"
        className={inputClass}
      />
      <button type="submit" disabled={pending} className={buttonClass}>
        Confirm
      </button>
      {state?.error ? (
        <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span>
      ) : null}
    </form>
  );
}

export function ReturnControls({
  purchaseId,
  itemId,
  existingReturn,
}: {
  purchaseId: string;
  itemId: string | null;
  existingReturn: { id: string; status: ReturnStatus } | null;
}) {
  if (!existingReturn) {
    return <StartReturnForm purchaseId={purchaseId} itemId={itemId} />;
  }

  const nextSimpleStatuses = FORWARD_RETURN_STATUSES[existingReturn.status] ?? [];

  return (
    <div className="flex flex-wrap items-center gap-2">
      <StatusBadge
        label={`Return: ${existingReturn.status}`}
        tone={STATUS_TONE[existingReturn.status]}
      />
      {existingReturn.status !== "refunded" && existingReturn.status !== "denied" ? (
        <>
          {nextSimpleStatuses.map((status) => (
            <InlineActionForm
              key={status}
              action={setReturnStatus.bind(null, existingReturn.id, status)}
              label={status}
              buttonClassName="text-xs text-[var(--color-text-tertiary)] hover:underline"
            />
          ))}
          <InlineActionForm
            action={setReturnStatus.bind(null, existingReturn.id, "denied")}
            label="deny"
            buttonClassName="text-xs text-[var(--color-danger-text)] hover:underline"
          />
          {itemId ? <RefundForm returnId={existingReturn.id} itemId={itemId} /> : null}
        </>
      ) : null}
    </div>
  );
}
