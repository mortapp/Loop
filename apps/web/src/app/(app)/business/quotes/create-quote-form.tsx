"use client";

import { useActionState, useRef, useState } from "react";
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
    "rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-950 outline-none focus:border-zinc-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50";

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
        <p className="text-xs font-medium text-zinc-500 dark:text-zinc-400">Line items</p>
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
          className="self-start text-xs font-medium text-zinc-500 underline hover:text-zinc-950 dark:text-zinc-400 dark:hover:text-zinc-50"
        >
          + Add line
        </button>
      </div>

      <div className="flex items-center justify-between border-t border-zinc-200 pt-3 dark:border-zinc-800">
        <p className="text-sm font-medium text-zinc-950 dark:text-zinc-50">
          Total: {total.toLocaleString(undefined, { style: "currency", currency: "USD" })}
        </p>
        <div className="flex items-center gap-3">
          <button
            type="submit"
            disabled={pending || contacts.length === 0}
            className="rounded-lg bg-zinc-950 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-zinc-800 disabled:opacity-50 dark:bg-zinc-50 dark:text-zinc-950 dark:hover:bg-zinc-200"
          >
            {pending ? "Creating…" : "Create quote"}
          </button>
        </div>
      </div>
      {state?.error ? (
        <p className="text-sm text-red-600 dark:text-red-400" role="alert">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
