"use client";

import { useActionState, useRef, useState } from "react";
import { addWarranty, setWarrantyClaimStatus, type FormState } from "./actions";

const inputClass =
  "w-32 rounded-lg border border-zinc-300 bg-white px-2 py-1.5 text-xs text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50";
const buttonClass =
  "rounded-lg bg-zinc-950 px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200";

type Warranty = { id: string; provider: string | null; expires_at: string | null; claim_status: string | null };

function AddWarrantyForm({ itemId }: { itemId: string }) {
  const [open, setOpen] = useState(false);
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(async (prev, formData) => {
    const result = await addWarranty(prev, formData);
    if (!result) formRef.current?.reset();
    return result;
  }, null);

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="text-xs text-zinc-400 hover:underline dark:text-zinc-500">
        + Warranty
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="itemId" value={itemId} />
      <input name="provider" placeholder="Provider" className={inputClass} />
      <input name="expiresAt" type="date" className={inputClass} />
      <button type="submit" disabled={pending} className={buttonClass}>
        Save
      </button>
      {state?.error ? <span className="text-xs text-red-600 dark:text-red-400">{state.error}</span> : null}
    </form>
  );
}

export function WarrantyControls({ itemId, warranties }: { itemId: string | null; warranties: Warranty[] }) {
  if (!itemId) return null;

  return (
    <div className="flex flex-wrap items-center gap-2">
      {warranties.map((warranty) => (
        <span
          key={warranty.id}
          className="flex items-center gap-1 rounded-full bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-700 dark:bg-purple-950 dark:text-purple-400"
        >
          {warranty.provider ?? "Warranty"}
          {warranty.expires_at ? ` until ${new Date(warranty.expires_at).toLocaleDateString()}` : ""}
          {warranty.claim_status ? ` · ${warranty.claim_status}` : ""}
          {!warranty.claim_status ? (
            <form action={setWarrantyClaimStatus.bind(null, warranty.id, "filed")}>
              <button type="submit" className="underline">
                file claim
              </button>
            </form>
          ) : null}
        </span>
      ))}
      <AddWarrantyForm itemId={itemId} />
    </div>
  );
}
