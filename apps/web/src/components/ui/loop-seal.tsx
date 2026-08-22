/**
 * LOOP's brand mark: the "double loop seal" — two precisely interlocked
 * rings, each drawn with an engraved double line (outer Platinum, inner
 * Tyrian) and a tiny Champagne key point where they cross. Reads at once
 * as a banking seal, an archive stamp, and a monogram — deliberately not
 * a crown or shield. A handful of static SVG strokes; costs nothing to
 * render, no filters, no animation.
 *
 * Colors are fixed hex (Platinum #BCBAB5 / Murex Bloom #98637D /
 * Champagne #B89A68 — same values as globals.css's --color-* tokens and
 * apps/mobile's AppColors) rather than `var(--color-*)`, since SVG
 * presentation attributes resolve CSS custom properties inconsistently
 * across renderers; this mark should always read the same regardless.
 */
export function LoopSeal({ size = 40, className }: { size?: number; className?: string }) {
  const height = size * 0.7;
  return (
    <svg
      width={size}
      height={height}
      viewBox="0 0 40 28"
      fill="none"
      aria-hidden="true"
      className={className}
    >
      <circle cx="12.7" cy="14" r="12" stroke="#BCBAB5" strokeOpacity="0.85" strokeWidth="1.4" />
      <circle cx="27.3" cy="14" r="12" stroke="#BCBAB5" strokeOpacity="0.85" strokeWidth="1.4" />
      <circle cx="12.7" cy="14" r="9" stroke="#98637D" strokeWidth="1" />
      <circle cx="27.3" cy="14" r="9" stroke="#98637D" strokeWidth="1" />
      <circle cx="20" cy="14" r="1.1" fill="#B89A68" />
    </svg>
  );
}
