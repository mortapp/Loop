# LOOP Design System

## 2026-08-22 — Current: "Murex Noir" replaces "Imperial Verdigris"

Owner-directed rebrand (second one today): "Imperial Verdigris" (aged
oxidized-copper teal) is rejected in full — reads too close to a
mineral-green fintech accent, not distinctive enough. "Murex Noir"
replaces it. Concept: blackened royal ink — the historic Tyrian/murex
dye tradition (rare, imperial, expensive to produce) translated into a
near-black digital material where the royal hue only reveals itself up
close, never a bright/neon purple. Explicitly not medieval cosplay, not
crypto, not glassmorphism, not an AI-SaaS gradient template.

**Palette** (`apps/mobile/lib/core/theme/app_colors.dart`, mirrored in
`apps/web/src/app/globals.css`): Murex Noir (`#0A070B`/`#151019`/
`#1D171F`/`#251C25`, the world — four surface levels, deliberately not
dramatically lighter step to step) · Tyrian/Murex (`#2B1728` Imperial
Plum → `#401C38` Tyrian Deep → `#693754` Tyrian Royal → `#98637D` Murex
Bloom → `#C49AAF` Murex Veil, the LOOP identity) · Imperial Bone/Ivory
(`#F1EBDD` family, warm archival off-white, never plain white) ·
Blackened Platinum (structure — borders, icons) · Antique Champagne
(`#B89A68` family, *very* rare — prestige/value markers only, never a
general accent) · Royal Ruby (`#7A263D` family, extremely sparing —
rare seal/critical only) · Archival Sapphire (`#4D6474` family,
PROTECT/trust/information) · Success/Warning/Danger semantic states
(muted old-money tones, not brand identity).

**WCAG contrast, computed live, not assumed** — real relative-luminance
math (script discarded after use; re-derive with the standard formula
before shipping any new pairing), same discipline as the Verdigris pass
below. The identity hue is deliberately dark and low-contrast against
Murex Noir (that's the "emerges from black" effect the brief wants),
which means every accent needs a dedicated small-text-safe tint —
using the raw swatch as text anywhere is a real accessibility bug, not
a style choice:
- `tyrianRoyal` (`#693754`) measures 2.2:1 as text on Murex Noir — a
  severe fail even against the 3:1 large-text/UI floor. Fixed with
  `tyrianText` → `murexVeil` (`#C49AAF`, 8.2:1) for small text/links,
  and `tyrianAccent` → `murexBloom` (`#98637D`, 4.2:1) for non-text UI
  accents (focus rings, active borders) where only the 3:1 floor
  applies. Raw `tyrianRoyal`/`tyrianDeep` stay reserved for fills and
  large (18px+ bold/24px+) headings.
- `danger` (`#A44B5A`) measures 3.6:1 as text — fails AA 4.5:1. Fixed
  with a dedicated `dangerText` tint (`#B0636E`, 4.6:1).
- `royalRuby` (`#7A263D`) measures 2.1:1 as text — fixed with `rubyText`
  (`#AA757D`, 5.3:1).
- `sapphireAsh` (`#4D6474`) measures 3.2:1 as text — fixed with
  `sapphireText` → `sapphirePale` (`#7D94A2`, 6.3:1).
- `champagne` and `success`/`warning` all clear 4.5:1 directly as text
  on Murex Noir (7.5:1 / 4.9:1 / 6.3:1) — no separate tint needed.
- Button foregrounds: Bone-on-Tyrian measures 7.8:1, dark-ink-on-Tyrian
  measures 2.2:1 (fails) — every Tyrian/Ruby/Sapphire/Danger fill uses
  Royal Bone as foreground (`onAccentFill`). Bone-on-Success measures
  only 3.4:1 (fails); dark-ink-on-Success measures 4.9:1 — Success/
  Warning/Champagne fills use Murex Noir ink as foreground
  (`onSemanticFill`) instead.
- Light mode (Royal Bone ground, never plain white): `murexBloom`/
  `tyrianRoyal` both fail as light-mode text (4.0:1 / 1.9:1);
  `tyrianDeep` (12.3:1) is the pairing that clears, so light-mode
  accent text uses `lightTyrianText` → `tyrianDeep`. Raw `archiveDust`
  measures 4.3:1 on Bone (marginal fail); `lightTextTertiary` is a
  darkened tint (`#6A635D`, 5.0:1) instead.

**Typography**: unchanged from Verdigris — `google_fonts`' Fraunces
(heritage serif, OFL) for the wordmark/hero figures/section titles
only, Inter for everything else. Web now loads Fraunces too
(`next/font/google`, `apps/web/src/app/layout.tsx`, exposed as
`--font-display`) so the two platforms share the same editorial/
utility split, not just the color tokens.

**Material language**: the "double loop seal" brand mark — two
interlocked rings, each with an engraved double line (outer Platinum,
inner Tyrian) and a tiny Champagne key point where they cross — drawn
natively on both platforms (`CustomPainter` in
`apps/mobile/lib/features/auth/auth_screen.dart`, inline SVG in
`apps/web/src/components/ui/loop-seal.tsx`), not imported art. Border
language tightened toward the brief's "whisper" tier (12–16% alpha
Platinum hairlines, down from Verdigris's 35–50%) for card/divider/
input borders — restraint over visible chrome. Auth screen: persistent
tiny uppercase field labels (EMAIL/PASSWORD) above bare hint-only
inputs instead of Material floating labels, an engraved divider with a
centered archival diamond (◇) instead of the word "or", a subtle
3-stop Tyrian gradient on the primary CTA (Imperial Plum → Tyrian Royal
→ Tyrian Deep, reads as dyed silk rather than a flat fill), and a
"PRIVATE VALUE LEDGER" Champagne micro-label under the wordmark. Same
Galaxy A14 performance constraints as before: no `BackdropFilter`, no
blur, gradients and watermarks are single cheap paints under ~4%
opacity.

**What this pass covers vs. defers**: the token systems (mobile
`AppColors`/`AppTheme`, web `globals.css`) are fully Murex Noir on both
platforms — every screen that already drew from the shared semantic
roles (`textPrimary`, `success`, `danger`, `protectAccent`, the CSS
`--color-*` vars, …) inherited the new palette automatically the
moment the token files changed, with zero per-screen edits, because
the Verdigris-era architecture was already organized around semantic
roles rather than literal color names. Confirmed via `flutter analyze`
(0 issues), `flutter test` (5/5), `tsc --noEmit`, `eslint`, and
`next build` (all clean) — see docs/AUTONOMOUS_BUILD_STATUS.md.
Structurally redesigned this pass: mobile + web auth (the brief's
required first reference screen). Mobile Today/Money/Sell/Business
screens and the five web reference screens (Today, Money, Sell,
Business/Quotes) already had row-based/ledger-style structural passes
from the Verdigris session and inherited the new palette without
further structural change. **Not yet done**: the web vertical-rail nav
(still a horizontal pill nav), Money's "hero screen" treatment on web,
Sell's auction-catalog gallery layout, Business's non-Quotes
subpages (contacts/leads/opportunities) and AI (both still on raw
Tailwind zinc/emerald, never migrated to tokens under any design
system), and physical Galaxy A14 verification (device not connected —
see docs/KNOWN_ISSUES.md). Real, valuable follow-up work, not treated
as done.

## 2026-08-22 — Superseded: "Imperial Verdigris" replaces "Ledger"

Owner-directed rebrand: the "Ledger" system below (mint-green accent,
Geist Sans everywhere) was judged too generic — read as "standard
fintech / starter SaaS / default Supabase auth" rather than a premium
product. "Imperial Verdigris" replaces it in full. Concept: old-world
royal treasury × private financial ledger × modern 2026 software —
communicated through material, typography, and restraint, never through
literal crowns/shields/medieval cosplay.

**Palette** (`apps/mobile/lib/core/theme/app_colors.dart`, mirrored in
`apps/web/src/app/globals.css`): Royal Obsidian (`#08090A`/`#0E1011`/
`#151718`/`#1B1E1F`, the world) · Imperial Verdigris (`#356C67` family,
aged oxidized-copper green — the LOOP identity, deliberately mineral,
not mint/Spotify/banking green) · Cathedral Ivory (`#F1ECDD` family,
warm archival off-white, never plain `#FFF`) · Blackened Silver/Pewter
(structure — borders, dividers) · Oxblood Seal (`#6D2934` family, rare
emphasis only) · Archival Blue (`#536D73` family, information/PROTECT)
· Success/Warning/Danger semantic states.

**WCAG contrast, computed live, not assumed** — the literal hex list in
the design brief has real failures as direct body text on dark
surfaces, found and fixed here:
- `verdigris` (`#356C67`) measures 3.3:1 as text on Obsidian — fails
  AA normal text (4.5:1), only clears the 3:1 large-text/UI floor.
  Fixed with a dedicated `verdigrisText` role pointing at the brighter
  `verdigrisBright` (`#5E9891`, 6.1:1) for any small text/link use;
  raw `verdigris` stays reserved for fills, icons, and large headings.
- `oxblood` (`#6D2934`) measures 1.9:1 as text — a severe fail. `danger`
  (`#A14E53`) measures 3.5:1 — also fails AA normal text. Both get
  dedicated lighter text-only tints (`oxbloodText` `#C08088`, 6.3:1;
  `dangerText` `#C97882`, 6.2:1) rather than being used directly as
  small text; the raw swatches remain correct for fills/badges/icons.
- Button foregrounds: dark ink on a Verdigris fill measures only 3.3:1
  (fails as button-label text) — Ivory-on-Verdigris (5.1:1) is the only
  foreground that clears AA on that fill. Every accent fill
  (Verdigris/Oxblood/Danger/Archival Blue) uses Ivory as its
  foreground; Success/Warning fills use dark ink instead (Ivory-on-
  Success measures 2.7:1 and fails).
Full computed table lives in git history of this file's companion
contrast script output; re-derive with the standard relative-luminance
formula against any new pairing before shipping it as text.

**Typography**: `google_fonts` package — Fraunces (heritage serif,
OFL-licensed) for the wordmark, hero figures, and section titles only;
Inter (grotesk sans, OFL-licensed) for everything else — forms, nav,
tables, body copy. Never render the whole app in serif. Runtime-fetched
via `google_fonts`'s default caching (no bundled font assets), which
keeps APK size unaffected; falls back gracefully if the first fetch has
no network.

**Material language**: hairline borders (Blackened Silver/Pewter,
~35-50% alpha) instead of elevation/shadow, moderate 12px radius on
primary surfaces, a single lightweight `CustomPainter`-drawn brand mark
(two interlocking circles — "the loop," deliberately not a crown or
shield), a subtle ~16%-alpha radial Verdigris gradient behind the auth
screen (no blur filter, no image asset). Explicitly avoiding
`BackdropFilter`/heavy blur/large shadows per the brief's Galaxy A14
performance constraint.

**Reference screens built and physically verified so far**: mobile auth
(`apps/mobile/lib/features/auth/auth_screen.dart`) — installed on a
real Samsung Galaxy A14 (Android 15), screenshotted, confirmed the
primary CTA reads as aged mineral teal rather than mint/Spotify green,
the Fraunces wordmark reads distinctive, the Google button and divider
read restrained, no overflow/clipping. Every other screen still
inherits the new palette automatically through `AppColors`'
backward-compatible aliases (old token names like `AppColors.brand`
now resolve to the new palette) but has not had its own structural
redesign pass yet — see `docs/LOOP_COMPLETION_LEDGER.md` for exactly
which screens are done vs. still pending.

The "Ledger" system's rationale below is preserved for history, not
current guidance.

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
