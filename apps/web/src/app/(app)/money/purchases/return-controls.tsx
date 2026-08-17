"use client";

import { useActionState, useRef, useState } from "react";
import { startReturn, setReturnStatus, refundReturn, type FormState } from "./actions";
import type { ReturnStatus } from "@loop/contracts";

const inputClass =
  "w-32 rounded-lg border border-zinc-300 bg-white px-2 py-1.5 text-xs text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50";
const buttonClass =
  "rounded-lg bg-zinc-950 px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200";

const STATUS_STYLES: Record<ReturnStatus, string> = {
  initiated: "bg-zinc-100 text-zinc-600 dark:bg-zinc-900 dark:text-zinc-400",
  shipped: "bg-blue-100 text-blue-700 dark:bg-blue-950 dark:text-blue-400",
  received: "bg-purple-100 text-purple-700 dark:bg-purple-950 dark:text-purple-400",
  refunded: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400",
  denied: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400",
};

function StartReturnForm({ purchaseId, itemId }: { purchaseId: string; itemId: string | null }) {
  const [open, setOpen] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(async (prev, formData) => {
    const result = await startReturn(prev, formData);
    if (!result) formRef.current?.reset();
    return result;
  }, null);

  if (!itemId) {
    return <p className="text-xs text-zinc-400 dark:text-zinc-600">No item linked — can&apos;t start a return.</p>;
  }

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-zinc-400 hover:underline dark:text-zinc-500">
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
      {state?.error ? <span className="text-xs text-red-600 dark:text-red-400">{state.error}</span> : null}
    </form>
  );
}

function RefundForm({ returnId, itemId }: { returnId: string; itemId: string }) {
  const [open, setOpen] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(async (prev, formData) => {
    const result = await refundReturn(prev, formData);
    if (!result) formRef.current?.reset();
    return result;
  }, null);

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-emerald-600 hover:underline dark:text-emerald-400">
        Refund
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="returnId" value={returnId} />
      <input type="hidden" name="itemId" value={itemId} />
      <input name="amount" type="number" step="0.01" min="0" placeholder="$ refunded" className={inputClass} />
      <button type="submit" disabled={pending} className={buttonClass}>
        Confirm
      </button>
      {state?.error ? <span className="text-xs text-red-600 dark:text-red-400">{state.error}</span> : null}
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

  const simpleStatuses: Array<"initiated" | "shipped" | "received" | "denied"> = [
    "initiated",
    "shipped",
    "received",
    "denied",
  ];
  const nextSimpleStatuses = simpleStatuses.filter((s) => s !== existingReturn.status);

  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className={`rounded-full px-2 py-0.5 text-xs font-medium ${STATUS_STYLES[existingReturn.status]}`}>
        return: {existingReturn.status}
      </span>
      {existingReturn.status !== "refunded" && existingReturn.status !== "denied" ? (
        <>
          {nextSimpleStatuses
            .filter((s) => s !== "denied")
            .map((status) => (
              <form key={status} action={setReturnStatus.bind(null, existingReturn.id, status)}>
                <button type="submit" className="text-xs text-zinc-400 hover:underline dark:text-zinc-500">
                  {status}
                </button>
              </form>
            ))}
          <form action={setReturnStatus.bind(null, existingReturn.id, "denied")}>
            <button type="submit" className="text-xs text-red-500 hover:underline dark:text-red-400">
              deny
            </button>
          </form>
          {itemId ? <RefundForm returnId={existingReturn.id} itemId={itemId} /> : null}
        </>
      ) : null}
    </div>
  );
}
