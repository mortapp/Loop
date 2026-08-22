import { LoopSeal } from "@/components/ui/loop-seal";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative flex min-h-full flex-1 flex-col items-center justify-center overflow-hidden bg-[var(--color-bg)] px-4 py-16">
      {/* Felt, not seen: a single radial wash, no blur/shader. */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-0"
        style={{
          background:
            "radial-gradient(ellipse 60% 45% at 50% 8%, rgba(43,23,40,0.35), transparent 70%)",
        }}
      />
      <div
        aria-hidden
        className="pointer-events-none absolute -right-24 top-8 opacity-[0.035]"
      >
        <LoopSeal size={420} />
      </div>

      <div className="relative w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center gap-2 text-center">
          <LoopSeal size={40} />
          <span
            className="mt-1 text-3xl tracking-[0.2em] text-[var(--color-text-primary)]"
            style={{ fontFamily: "var(--font-display)", fontWeight: 600 }}
          >
            LOOP
          </span>
          <span className="text-[10px] font-medium tracking-[0.3em] text-[var(--color-opportunity)]">
            PRIVATE VALUE LEDGER
          </span>
          <p className="mt-1 text-xs text-[var(--color-text-tertiary)]">
            Earn. Buy. Own. Return or resell. Earn again.
          </p>
        </div>
        {children}
      </div>
    </div>
  );
}
