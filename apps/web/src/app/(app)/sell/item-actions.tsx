"use client";

import { useActionState, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import {
  addValuation,
  createListing,
  recordSale,
  attachItemPhoto,
  type FormState,
} from "./actions";

const inputClass =
  "w-24 rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-2 py-1.5 text-xs text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";
const buttonClass =
  "rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-3 py-1.5 text-xs font-medium text-[var(--color-on-accent)] transition-colors hover:bg-[var(--color-brand-hover)] disabled:opacity-50";

function useItemForm(action: (prev: FormState, formData: FormData) => Promise<FormState>) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<FormState, FormData>(
    async (prev, formData) => {
      const result = await action(prev, formData);
      if (!result) {
        formRef.current?.reset();
      }
      return result;
    },
    null,
  );
  return { formRef, state, formAction, pending };
}

const ALLOWED_PHOTO_TYPES = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"];
const MAX_PHOTO_BYTES = 8 * 1024 * 1024;

/**
 * Uploads directly to Supabase Storage from the browser (authenticated,
 * RLS-scoped by `has_account_access` on the `item-photos` bucket -- see
 * supabase/migrations/20260822145553_item_photos_storage.sql), then calls
 * the `attachItemPhoto` Server Action to record the resulting object path
 * on `items.photos`. Never a base64 blob in the row, never a public URL.
 */
export function AddPhotoControl({ itemId, accountId }: { itemId: string; accountId: string }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleFile(file: File) {
    if (!ALLOWED_PHOTO_TYPES.includes(file.type)) {
      setError("Use a JPEG, PNG, WEBP, or HEIC image.");
      return;
    }
    if (file.size > MAX_PHOTO_BYTES) {
      setError("Photo must be 8MB or smaller.");
      return;
    }

    setUploading(true);
    setError(null);
    try {
      const ext = file.name.split(".").pop()?.toLowerCase() || "jpg";
      const objectPath = `${accountId}/${itemId}/${crypto.randomUUID()}.${ext}`;

      const supabase = createClient();
      const { error: uploadError } = await supabase.storage
        .from("item-photos")
        .upload(objectPath, file, { contentType: file.type });
      if (uploadError) {
        setError("We couldn't upload that photo. Check the file and try again.");
        return;
      }

      const result = await attachItemPhoto(itemId, objectPath);
      if (result?.error) {
        setError(result.error);
        await supabase.storage.from("item-photos").remove([objectPath]);
      }
    } catch {
      setError("Upload failed. Check your connection and try again.");
    } finally {
      setUploading(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  }

  return (
    <div className="flex items-center gap-2">
      <label className="cursor-pointer text-xs text-[var(--color-text-tertiary)] hover:underline">
        {uploading ? "Uploading…" : "+ Photo"}
        <input
          ref={inputRef}
          type="file"
          accept={ALLOWED_PHOTO_TYPES.join(",")}
          disabled={uploading}
          className="hidden"
          onChange={(e) => {
            const file = e.target.files?.[0];
            if (file) handleFile(file);
          }}
        />
      </label>
      {error ? <span className="text-xs text-[var(--color-danger-text)]">{error}</span> : null}
    </div>
  );
}

export function ValuationForm({ itemId }: { itemId: string }) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(addValuation);

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className="text-xs text-[var(--color-text-tertiary)] hover:underline"
      >
        + Valuation
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="itemId" value={itemId} />
      <input
        name="value"
        type="number"
        step="0.01"
        min="0"
        placeholder="$ est."
        className={inputClass}
      />
      <button type="submit" disabled={pending} className={buttonClass}>
        Save
      </button>
      {state?.error ? (
        <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span>
      ) : null}
    </form>
  );
}

export function ListingForm({ itemId, primary = false }: { itemId: string; primary?: boolean }) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(createListing);

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className={
          primary
            ? "rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-3 py-2 text-xs font-semibold text-[var(--color-on-accent)] transition-opacity hover:opacity-90"
            : "text-xs text-[var(--color-text-tertiary)] hover:underline"
        }
      >
        List for sale
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="itemId" value={itemId} />
      <input name="marketplace" placeholder="Marketplace" className={inputClass} />
      <input
        name="listPrice"
        type="number"
        step="0.01"
        min="0"
        placeholder="$ price"
        className={inputClass}
      />
      <button type="submit" disabled={pending} className={buttonClass}>
        List
      </button>
      {state?.error ? (
        <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span>
      ) : null}
    </form>
  );
}

export function SaleForm({
  itemId,
  listingId,
  primary = false,
}: {
  itemId: string;
  listingId?: string;
  primary?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const { formRef, state, formAction, pending } = useItemForm(recordSale);

  if (!open) {
    return (
      <button
        onClick={() => setOpen(true)}
        className={
          primary
            ? "rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-3 py-2 text-xs font-semibold text-[var(--color-on-accent)] transition-opacity hover:opacity-90"
            : "text-xs text-[var(--color-text-tertiary)] hover:underline"
        }
      >
        {primary ? "Record sale" : "Sold already?"}
      </button>
    );
  }

  return (
    <form ref={formRef} action={formAction} className="flex items-center gap-2">
      <input type="hidden" name="itemId" value={itemId} />
      {listingId ? <input type="hidden" name="listingId" value={listingId} /> : null}
      <input
        name="salePrice"
        type="number"
        step="0.01"
        min="0"
        placeholder="$ sold for"
        className={inputClass}
      />
      <input
        name="fees"
        type="number"
        step="0.01"
        min="0"
        placeholder="$ fees"
        className={inputClass}
      />
      <button type="submit" disabled={pending} className={buttonClass}>
        Save
      </button>
      {state?.error ? (
        <span className="text-xs text-[var(--color-danger-text)]">{state.error}</span>
      ) : null}
    </form>
  );
}
