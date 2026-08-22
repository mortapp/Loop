"use client";

import { useActionState, useRef, useState } from "react";
import { StatusBadge } from "@/components/ui/status-badge";
import { addWarranty, setWarrantyClaimStatus, type FormState } from "./actions";

const inputClass =
  "w-32 rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-2 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";
const buttonClass =
  "rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-3 py-1.5 text-xs font-medium text-[var(--color-on-accent)] transition-colors hover:bg-[var(--color-brand-hover)] disabled:opacity-50";

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
      <button onClick={() => setOpen(true)} className="text-xs text-[var(--color-text-tertiary)] hover:underline">
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
      {state?.error ? <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span> : null}
    </form>
  );
}

export function WarrantyControls({ itemId, warranties }: { itemId: string | null; warranties: Warranty[] }) {
  if (!itemId) return null;

  return (
    <div className="flex flex-wrap items-center gap-2">
      {warranties.map((warranty) => (
        <div key={warranty.id} className="flex items-center gap-1.5">
          <StatusBadge
            tone="info"
            label={`${warranty.provider ?? "Warranty"}${
              warranty.expires_at ? ` until ${new Date(warranty.expires_at).toLocaleDateString()}` : ""
            }${warranty.claim_status ? ` · ${warranty.claim_status}` : ""}`}
          />
          {!warranty.claim_status ? (
            <form action={setWarrantyClaimStatus.bind(null, warranty.id, "filed")}>
              <button type="submit" className="text-xs text-[var(--color-info-text)] hover:underline">
                file claim
              </button>
            </form>
          ) : null}
        </div>
      ))}
      <AddWarrantyForm itemId={itemId} />
    </div>
  );
}
