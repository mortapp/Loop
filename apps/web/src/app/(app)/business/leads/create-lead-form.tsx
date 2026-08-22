"use client";

import { useActionState, useRef } from "react";
import { formInputClass, formButtonClass, formErrorClass } from "@/components/ui/form-styles";
import { createLead, type CreateLeadState } from "./actions";

export function CreateLeadForm({ contacts }: { contacts: { id: string; display_name: string }[] }) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<CreateLeadState, FormData>(
    async (prev, formData) => {
      const result = await createLead(prev, formData);
      if (!result) {
        formRef.current?.reset();
      }
      return result;
    },
    null,
  );

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-3">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <select name="contactId" required defaultValue="" className={formInputClass}>
          <option value="" disabled>
            Contact…
          </option>
          {contacts.map((contact) => (
            <option key={contact.id} value={contact.id}>
              {contact.display_name}
            </option>
          ))}
        </select>
        <input name="source" placeholder="Source (optional)" className={formInputClass} />
      </div>
      <textarea name="notes" placeholder="Notes (optional)" rows={2} className={formInputClass} />
      <div className="flex items-center gap-3">
        <button type="submit" disabled={pending || contacts.length === 0} className={formButtonClass}>
          {pending ? "Adding…" : "Add lead"}
        </button>
        {state?.error ? (
          <p className={formErrorClass} role="alert">
            {state.error}
          </p>
        ) : null}
      </div>
    </form>
  );
}
