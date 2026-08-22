"use client";

import { useActionState, useRef } from "react";
import { formInputClass, formButtonClass, formErrorClass } from "@/components/ui/form-styles";
import { createOpportunity, type CreateOpportunityState } from "./actions";

export function CreateOpportunityForm({
  contacts,
}: {
  contacts: { id: string; display_name: string }[];
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<CreateOpportunityState, FormData>(
    async (prev, formData) => {
      const result = await createOpportunity(prev, formData);
      if (!result) {
        formRef.current?.reset();
      }
      return result;
    },
    null,
  );

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-3">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
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
        <input name="title" required placeholder="Title" className={formInputClass} />
        <input
          name="estimatedValue"
          type="number"
          step="0.01"
          min="0"
          placeholder="Est. value ($, optional)"
          className={formInputClass}
        />
      </div>
      <div className="flex items-center gap-3">
        <button type="submit" disabled={pending || contacts.length === 0} className={formButtonClass}>
          {pending ? "Adding…" : "Add opportunity"}
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
