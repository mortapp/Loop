"use client";

import { useActionState, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { createQuote, type CreateQuoteState } from "./actions";

type Line = { description: string; quantity: string; unitPrice: string };

const EMPTY_LINE: Line = { description: "", quantity: "1", unitPrice: "" };

export function CreateQuoteForm({
  contacts,
  opportunities,
}: {
  contacts: { id: string; display_name: string }[];
  opportunities: { id: string; title: string }[];
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const [lines, setLines] = useState<Line[]>([{ ...EMPTY_LINE }]);

  const [state, formAction, pending] = useActionState<CreateQuoteState, FormData>(
    async (prev, formData) => {
      const result = await createQuote(prev, formData);
      if (!result) {
        formRef.current?.reset();
        setLines([{ ...EMPTY_LINE }]);
      }
      return result;
    },
    null,
  );

  const inputClass =
    "rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-surface)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none focus:border-[var(--color-brand)]";

  const total = lines.reduce((sum, line) => {
    const qty = Number(line.quantity) || 0;
    const price = Number(line.unitPrice) || 0;
    return sum + qty * price;
  }, 0);

  function updateLine(index: number, patch: Partial<Line>) {
    setLines((prev) => prev.map((line, i) => (i === index ? { ...line, ...patch } : line)));
  }

  return (
    <form ref={formRef} action={formAction} className="flex flex-col gap-4">
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <select name="contactId" required defaultValue="" className={inputClass}>
          <option value="" disabled>
            Contact…
          </option>
          {contacts.map((contact) => (
            <option key={contact.id} value={contact.id}>
              {contact.display_name}
            </option>
          ))}
        </select>
        <select name="opportunityId" defaultValue="" className={inputClass}>
          <option value="">No linked opportunity</option>
          {opportunities.map((opp) => (
            <option key={opp.id} value={opp.id}>
              {opp.title}
            </option>
          ))}
        </select>
      </div>

      <div className="flex flex-col gap-2">
        <p className="text-xs font-medium text-[var(--color-text-tertiary)]">Line items</p>
        {lines.map((line, i) => (
          <div key={i} className="grid grid-cols-[1fr_5rem_6rem] items-center gap-2">
            <input
              name="lineDescription"
              value={line.description}
              onChange={(e) => updateLine(i, { description: e.target.value })}
              placeholder="Description"
              className={inputClass}
            />
            <input
              name="lineQuantity"
              type="number"
              min="0"
              step="1"
              value={line.quantity}
              onChange={(e) => updateLine(i, { quantity: e.target.value })}
              className={inputClass}
            />
            <input
              name="lineUnitPrice"
              type="number"
              min="0"
              step="0.01"
              placeholder="$/unit"
              value={line.unitPrice}
              onChange={(e) => updateLine(i, { unitPrice: e.target.value })}
              className={inputClass}
            />
          </div>
        ))}
        <button
          type="button"
          onClick={() => setLines((prev) => [...prev, { ...EMPTY_LINE }])}
          className="self-start text-xs font-medium text-[var(--color-brand-text)] hover:underline"
        >
          + Add line
        </button>
      </div>

      <div className="flex items-center justify-between border-t border-[var(--color-border-subtle)] pt-3">
        <p className="text-sm font-medium text-[var(--color-text-primary)]">
          Total: {total.toLocaleString(undefined, { style: "currency", currency: "USD" })}
        </p>
        <Button type="submit" loading={pending} disabled={contacts.length === 0}>
          {pending ? "Creating" : "Create quote"}
        </Button>
      </div>
      {state?.error ? (
        <p className="text-sm text-[var(--color-danger-text)]" role="alert">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
