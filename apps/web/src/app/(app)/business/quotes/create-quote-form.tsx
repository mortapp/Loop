"use client";

import { useActionState, useRef, useState } from "react";
import { Button } from "@/components/ui/button";
import { createQuote, type CreateQuoteState } from "./actions";

type Line = { description: string; quantity: string; unitPrice: string };

const EMPTY_LINE: Line = { description: "", quantity: "1", unitPrice: "" };
const MAX_QUOTE_LINES = 100;

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
    const quantity = Number(line.quantity);
    const unitPrice = Number(line.unitPrice);
    if (!Number.isFinite(quantity) || !Number.isFinite(unitPrice)) return Number.NaN;
    return sum + quantity * unitPrice;
  }, 0);

  function updateLine(index: number, patch: Partial<Line>) {
    setLines((prev) => prev.map((line, i) => (i === index ? { ...line, ...patch } : line)));
  }

  function removeLine(index: number) {
    setLines((prev) => prev.filter((_, i) => i !== index));
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
          <div
            key={i}
            className="grid grid-cols-1 items-center gap-2 sm:grid-cols-[minmax(0,1fr)_5rem_7rem_auto]"
          >
            <input
              name="lineDescription"
              required
              maxLength={500}
              value={line.description}
              onChange={(e) => updateLine(i, { description: e.target.value })}
              placeholder="Description"
              aria-label={`Line ${i + 1} description`}
              className={`${inputClass} min-w-0`}
            />
            <input
              name="lineQuantity"
              type="number"
              required
              min="1"
              max="1000000"
              step="1"
              value={line.quantity}
              onChange={(e) => updateLine(i, { quantity: e.target.value })}
              aria-label={`Line ${i + 1} quantity`}
              className={`${inputClass} min-w-0`}
            />
            <input
              name="lineUnitPrice"
              type="number"
              required
              min="0"
              max="1000000000"
              step="0.01"
              placeholder="$/unit"
              value={line.unitPrice}
              onChange={(e) => updateLine(i, { unitPrice: e.target.value })}
              aria-label={`Line ${i + 1} unit price`}
              className={`${inputClass} min-w-0`}
            />
            {lines.length > 1 ? (
              <button
                type="button"
                onClick={() => removeLine(i)}
                aria-label={`Remove line ${i + 1}`}
                className="min-h-10 rounded-[var(--radius-sm)] px-3 text-xs text-[var(--color-danger-text)] hover:bg-[var(--color-surface-hover)]"
              >
                Remove
              </button>
            ) : null}
          </div>
        ))}
        <button
          type="button"
          disabled={lines.length >= MAX_QUOTE_LINES}
          onClick={() =>
            setLines((prev) =>
              prev.length < MAX_QUOTE_LINES ? [...prev, { ...EMPTY_LINE }] : prev,
            )
          }
          className="self-start text-xs font-medium text-[var(--color-brand-text)] hover:underline disabled:pointer-events-none disabled:opacity-50"
        >
          + Add line
        </button>
      </div>

      <div className="flex items-center justify-between border-t border-[var(--color-border-subtle)] pt-3">
        <p className="text-sm font-medium text-[var(--color-text-primary)]">
          Total:{" "}
          {Number.isFinite(total)
            ? total.toLocaleString(undefined, { style: "currency", currency: "USD" })
            : "Check line values"}
        </p>
        <Button
          type="submit"
          loading={pending}
          disabled={contacts.length === 0 || !Number.isFinite(total)}
        >
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
