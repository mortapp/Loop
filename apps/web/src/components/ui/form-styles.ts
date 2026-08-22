/**
 * Shared classes for LOOP's plain `<input>`/`<select>`/`<textarea>`/
 * `<button>` create-forms (Contacts, Leads, Opportunities, ...) —
 * replaces the identical `rounded-lg border-zinc-300 ...` literal that
 * used to be copy-pasted into every one of these files.
 */
export const formInputClass =
  "rounded-[var(--radius-sm)] border border-[var(--color-border-strong)] bg-[var(--color-bg-secondary)] px-3 py-2 text-sm text-[var(--color-text-primary)] outline-none placeholder:text-[var(--color-text-tertiary)] focus:border-[var(--color-brand)]";

export const formButtonClass =
  "rounded-[var(--radius-sm)] bg-[var(--color-brand)] px-4 py-2 text-sm font-medium text-[var(--color-on-accent)] transition-colors hover:bg-[var(--color-brand-hover)] disabled:opacity-50";

export const formErrorClass = "text-sm text-[var(--color-danger-text)]";
