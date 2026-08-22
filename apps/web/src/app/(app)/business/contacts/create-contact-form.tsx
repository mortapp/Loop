"use client";

import { useActionState, useRef } from "react";
import { formInputClass, formButtonClass, formErrorClass } from "@/components/ui/form-styles";
import { createContact, type CreateContactState } from "./actions";

export function CreateContactForm() {
  const formRef = useRef<HTMLFormElement>(null);
  const [state, formAction, pending] = useActionState<CreateContactState, FormData>(
    async (prev, formData) => {
      const result = await createContact(prev, formData);
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
        <input name="displayName" required placeholder="Name" className={formInputClass} />
        <input name="company" placeholder="Company (optional)" className={formInputClass} />
        <input name="email" type="email" placeholder="Email (optional)" className={formInputClass} />
        <input name="phone" placeholder="Phone (optional)" className={formInputClass} />
      </div>
      <div className="flex items-center gap-3">
        <button type="submit" disabled={pending} className={formButtonClass}>
          {pending ? "Adding…" : "Add contact"}
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
