# Play Data Safety — Technical Input

Updated: 2026-08-25

**This is NOT a Play Console submission and does not itself satisfy Play's
Data Safety form.** It's a technical answer key, built from
`docs/TECHNICAL_DATA_INVENTORY.md` and `docs/THIRD_PARTY_DATA_FLOWS.md`,
for whoever fills out the actual Play Console form. Do not copy this
verbatim into Play Console without owner/legal review — Play's categories
have precise definitions that don't always map one-to-one onto this
project's schema.

## Data categories likely collected (map to Play's exact taxonomy at
submission time)

| Play category (approximate) | Collected? | Source in LOOP |
| --- | --- | --- |
| Name | Yes | `profiles.display_name`, contact records the user enters |
| Email address | Yes | `profiles.email` (own account) and `contacts.email` (business contacts the user enters about others) |
| Phone number | Optional, user-entered | `contacts.phone` |
| Photos | Yes | Item photos, private Storage bucket |
| Financial info (purchase history) | Yes | `purchases`, `money_events`, `sales` — user-entered ledger data, not a real payment processor |
| App activity (in-app actions) | Arguably yes | `actions`, `events` tables track in-app activity for the Today engine — this is functional, not analytics/advertising |
| App info and performance (crash logs, diagnostics) | No third-party crash/analytics SDK present | — |

## Is data shared with third parties?

Per `docs/THIRD_PARTY_DATA_FLOWS.md`: Supabase (processor, not a data
"share" in the marketing sense — it's the backend), Google (OAuth
identity, only for users who choose that sign-in method), Anthropic (only
if `ANTHROPIC_API_KEY` is configured — currently not). No advertising or
analytics data sharing exists.

## Is data encrypted in transit?

Yes — Supabase (HTTPS/TLS), Vercel (HTTPS/TLS), and the Android manifest
explicitly sets `android:usesCleartextTraffic="false"` (verified this
session), which blocks the app from making any plaintext HTTP connection
at the OS level.

## Is data encrypted at rest?

Supabase's underlying Postgres/Storage infrastructure — this is a claim
about Supabase's own infrastructure, not LOOP's code, so verify Supabase's
current published security documentation rather than asserting a specific
mechanism here.

## Can users request data deletion?

**Not yet, in-app.** See the "Account/data deletion — the real gap"
section of `docs/TECHNICAL_DATA_INVENTORY.md`. Play's Data Safety form has
a specific question about this; answering it honestly today means
answering "no in-app deletion" unless a manual/support-based deletion
process is stood up first (e.g. an email address users can contact to
request deletion, handled manually until an in-app flow exists). Decide
this before submitting the form — see
`docs/OWNER_RELEASE_ACTION_CENTER.md`.

## Is collection optional or required?

Account creation (email or Google) is required to use the app at all.
Within the app, most content (contacts, items, quotes) is optional and
entirely user-initiated — LOOP doesn't require entering any of it to keep
using other parts of the app.

## AI feature disclosure

If Ask LOOP ships enabled (i.e. `ANTHROPIC_API_KEY` configured) in the
version submitted to Play, disclose that user-entered prompt content is
sent to a third-party AI provider (Anthropic) for processing. If it ships
disabled, no such disclosure is needed for that release.

## What this document explicitly does not claim

Compliance with Play's policy, GDPR, CCPA, or any other regulation. Those
are legal determinations for the owner and counsel, informed by — not
replaced by — this technical inventory.
