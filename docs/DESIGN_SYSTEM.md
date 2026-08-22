# LOOP Design System

## Direction chosen: "Ledger" — premium financial utility + editorial restraint

### Three directions considered

| | Ledger (chosen) | Paper | Terminal |
|---|---|---|---|
| Tone | Calm, deliberate, trustworthy | Warm, human, content-first | High-energy, technical |
| Background | Deep near-black ink / warm porcelain white | Cream/off-white paper | Pure black |
| Primary accent | Muted forest-mint green | Terracotta | Electric green |
| Typography | Geist Sans (UI) + Geist Mono (numbers) | Serif display + sans body | Monospace everywhere |
| Reads as | Premium financial utility | Editorial/blog product | Crypto trading terminal |
| Risk | None significant | Too content-led for a daily-use utility app; undersells "control" | Explicitly what Part 2 of the brief says to avoid — reads as crypto/gambling, not trust |

**Paper** was rejected because LOOP is a tool people open to *do* something
(log a quote, check a deadline), not read something — a content-editorial
register undersells the control/clarity the product needs to communicate in
seconds. **Terminal** was rejected for the same reason the brief explicitly
warns against it: an all-monospace, pure-black, electric-green treatment
reads as crypto/trading, not as a trustworthy place to track real returns
and real money.

**Ledger** wins on product fit (the closest real-world analog to what LOOP
does — a ledger — literally names the direction), distinctiveness (a
genuine green identity that isn't Tailwind's default `emerald-500`/
`green-500`), and low implementation cost (extends the token system that
was about to be built anyway rather than requiring new dependencies).

### Why not just use Inter

The existing scaffold already loads **Geist Sans** and **Geist Mono** via
`next/font/google` — evaluated before replacing, per the brief's own
instruction, rather than defaulting to Inter because that's the common
AI-generated-app choice. Geist is distinctive, highly legible, has real
tabular figures in the Mono face (critical for money), and is already
correctly bundled with zero additional dependency weight. Kept.

## Tokens

Defined in `apps/web/src/app/globals.css` via Tailwind v4's CSS-first
`@theme` block — every token below is a real CSS custom property, not a
one-off literal. Dark is the default (a financial utility people check
often benefits from a calmer, lower-glare default); light is a real,
equally-designed second mode, not an afterthought.

### Neutrals (ink / porcelain)

| Token | Dark value | Light value | Use |
|---|---|---|---|
| `--color-bg` | `#0A0A0C` | `#FAFAF8` | Page background |
| `--color-bg-secondary` | `#101013` | `#F2F1ED` | Section background |
| `--color-surface` | `#17171B` | `#FFFFFF` | Cards, panels |
| `--color-surface-hover` | `#1E1E23` | `#F5F4F0` | Hover/pressed surface |
| `--color-border-subtle` | `#242429` | `#E5E4DF` | Default hairline border |
| `--color-border-strong` | `#35353C` | `#D3D2CB` | Emphasized border, focus rings |
| `--color-text-primary` | `#F5F5F2` | `#14141A` | Headings, primary content |
| `--color-text-secondary` | `#A8A8AD` | `#55555D` | Supporting text |
| `--color-text-tertiary` | `#6E6E74` | `#8A8A90` | Metadata, captions |

Deliberately warm, not cold — `#0A0A0C` and `#FAFAF8` both carry a faint
warmth rather than true `#000`/`#FFF`, which is what separates "premium"
from "default dark mode template."

### Brand and semantic accents

| Token | Value | Meaning |
|---|---|---|
| `--color-brand` | `#2FAE7A` | LOOP Green — primary value/momentum, MAKE+RECOVER's positive outcomes |
| `--color-brand-hover` | `#279467` | Hover state |
| `--color-brand-pressed` | `#1F7A55` | Pressed state |
| `--color-brand-soft` | `#12261C` dark / `#E8F5EE` light | Tinted backgrounds (badges, subtle highlights) |
| `--color-info` | `#3D7EEB` | Ice Blue — PROTECT, informational state, data |
| `--color-info-soft` | `#101B2E` dark / `#EAF1FE` light | Tinted backgrounds |
| `--color-opportunity` | `#D98A3D` | Warm Value Accent — recoverable value, RECOVER estimates |
| `--color-opportunity-soft` | `#2A1E10` dark / `#FBF0E2` light | Tinted backgrounds |
| `--color-success` | `#2FAE7A` | Same hue as brand — a completed/positive state *is* the brand's value proposition, not a separate color |
| `--color-warning` | `#D9A73D` | Caution, non-destructive |
| `--color-danger` | `#E0473F` | Destructive, overdue, at-risk |
| `--color-danger-soft` | `#2E1210` dark / `#FDEAE8` light | Tinted backgrounds |

Every pair below was computed (WCAG relative-luminance formula, run live
via Node, not assumed) — this caught two real failures before they ever
shipped, not after:

| Pair | Ratio | Verdict |
|---|---|---|
| text-primary / bg (dark) | 18.11:1 | pass |
| text-secondary / bg (dark) | 8.35:1 | pass |
| text-primary / bg (light) | 17.55:1 | pass |
| text-secondary / bg (light) | 7.07:1 | pass |
| brand / bg (dark) | 7.02:1 | pass |
| info / bg (dark) | 5.07:1 | pass |
| opportunity / bg (dark) | 7.21:1 | pass |
| danger / bg (dark) | 4.84:1 | pass |
| **brand / bg (light)** | **2.69:1** | **fail — solid `--color-brand` is icon/large-UI/button-fill only in light mode, never small text** |
| **opportunity / bg (light)** | **2.63:1** | **fail — same rule** |
| **porcelain text on brand button fill** | **2.58:1** | **fail — buttons use dark (`#0A0A0C`) foreground text on every accent fill, not white; verified 7.02:1** |

Two new tokens exist specifically because of those failures — small
colored text/links in light mode use a darker variant, never the solid
accent:

| Token | Value | Ratio on light bg |
|---|---|---|
| `--color-brand-text-light` | `#1F7A55` (= `brand-pressed`) | 5.06:1 |
| `--color-opportunity-text-light` | `#8A5119` | 6.14:1 |
| `--color-info-text-light` | `#1E5BC4` | 6.00:1 |
| `--color-danger-text-light` | `#B8362E` | 5.57:1 |

Rule going forward: the solid `--color-{brand,info,opportunity,danger}`
tokens are for icons, large text (≥18px/24px bold), borders, and button
fills paired with dark foreground text — never for small colored body
text on a light background. The `-text-light` tokens exist for exactly
that case. Dark mode's solid tokens already clear AA for text directly,
so no dark-mode equivalent was needed. The `-soft` tokens are background
tints only, never used as a text color themselves.

### Radius

| Token | Value | Use |
|---|---|---|
| `--radius-sm` | `6px` | Inputs, small buttons, chips |
| `--radius-md` | `10px` | Cards, buttons |
| `--radius-lg` | `16px` | Sheets, dialogs, large panels |

Deliberately not one radius everywhere — small interactive elements read
as more precise with a tighter radius; larger containers get more.

### Spacing

Tailwind's default scale (4px rhythm: 1/2/3/4/6/8/12/16 → 4/8/12/16/24/32/
48/64px) already matches the brief's suggested scale. Not reinvented.

## Components

Shared primitives in `apps/web/src/components/ui/`:

- `Button` — primary/secondary/ghost/danger variants, loading state,
  disabled state. Replaces every one-off `<button className="rounded-lg
  border...">` across the app.
- `Card` — the one surface container, replacing repeated
  `rounded-2xl border bg-white` literals.
- `Amount` — tabular-numeral money formatting (uses Geist Mono's real
  tabular figures), sign-aware coloring (positive uses `--color-brand`,
  negative uses `--color-danger`, neutral uses `--color-text-primary`),
  never a plain `{cents}` string.
- `StatusBadge` — status communicated via icon + text + color together,
  never color alone (accessibility requirement, Part 23 of the brief).
- `EmptyState` — one first-class empty-state component instead of ad hoc
  "No X yet" paragraphs per page.

Mobile equivalents live in `apps/mobile/lib/core/theme/` (extending the
existing `AppColors`/`AppSpacing`/`AppTheme` token files rather than
replacing them) and `apps/mobile/lib/core/widgets/` for shared primitives.

## What this pass covers vs. defers

This session implemented the token system, the shared component
primitives, and applied both to the five representative screens named in
the brief (Today, Money, Business/quote workflow, Protect/purchase
detail, Sell/item detail) on web, plus Today and the shared theme on
mobile. Full propagation across every remaining screen (auth polish,
settings, all of Business's sub-screens, AI, every mobile screen) is
real, valuable follow-up work — seeing this land is what proves the
system is strong before spending the time to spread it everywhere, which
is the brief's own explicit sequencing (Part 4: build representative
screens, critique, *then* propagate).
