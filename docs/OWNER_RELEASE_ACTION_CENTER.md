# Owner Release Action Center

Updated: 2026-08-25

**LOOP ENGINEERING STATE: `PRODUCTION_READY_EXTERNALLY_BLOCKED`**

Every internally-controllable Critical/High item is closed (see
`docs/LOOP_FINAL_STATE.md`, `docs/TEST_MATRIX.md`). Nothing below requires
more engineering to *discover* — it requires your decisions, your
credentials, your money, or your legal judgment. Each step names the exact
file to follow and says plainly whether it blocks a release.

## Step 1 — Decide whether Ask LOOP ships with live AI in the first release

**Why**: Ask LOOP currently fails closed with a truthful "not configured"
message. That's a legitimate shipping state, not just a placeholder — you
can release without it and enable it later with zero code changes.

**Required?** No — it's a product decision, not a technical requirement.
**Blocking?** No.
**If yes**: get an Anthropic API key, then follow
`docs/ASK_LOOP_PROVIDER_ENABLEMENT.md` exactly — it names the one
environment variable, where it goes, where it must never go, and the
7-step verification sequence. Takes minutes once you have the key.
**Engineering work after your action**: none. The code path is already
built and tested.

## Step 2 — Create a dedicated QA identity for authenticated E2E tests

**Why**: 60 of ~91 Playwright tests currently skip (truthfully — not
hidden failures) because no isolated test credential exists. The harness
itself is correct and needs no engineering.

**Required?** Recommended before you rely on CI to catch authenticated
regressions.
**Blocking?** No — the 31 non-gated tests plus the full database/Flutter
suites already provide strong coverage.
**Exact steps**: `docs/AUTHENTICATED_E2E_ENABLEMENT.md` — create a
disposable account, add two GitHub secrets, done.
**Engineering work after**: none.

## Step 3 — Decide on a Supabase plan upgrade

**Why**: LOOP is on Supabase's Free plan. Leaked-password protection
(checking new passwords against known-breach databases) requires a paid
plan. Backup/PITR guarantees on Free are also weaker — see
`docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md`'s "Backup / restore
reality" section for exactly what to check in the dashboard before relying
on it.

**Required?** Your call — strong mitigations already exist without this
(see `docs/KNOWN_ISSUES.md`'s "Deferred - Plan-Limited Security
Enhancement" section).
**Blocking?** No, but recommended before real users' financial-ledger data
is at stake.
**Action**: a payment decision only you can make. If you upgrade, enable
leaked-password protection immediately afterward and re-run
`get_advisors(type: security)` to confirm it clears that finding.
**Engineering work after**: none — it's a dashboard toggle once upgraded.

## Step 4 — macOS/Xcode for iOS

**Why**: no real iOS build has ever run (Windows can't run Xcode). Source
parity is verified and passing.

**Required?** Only if you intend to ship iOS. Android can release
independently.
**Blocking?** iOS only.
**Exact steps**: `docs/IOS_XCODE_HANDOFF.md` — `pod install`, open the
`.xcworkspace`, sign with your Apple Developer team, walk the same
physical QA sequence already proven on Android.
**Engineering work after**: likely none if the static parity review holds
up under a real build; budget time for whatever a first real Xcode build
always surfaces (a stale CocoaPods lock, a signing hiccup) that no amount
of static review can predict.

## Step 5 — Privacy/legal review

**Why**: LOOP has no published privacy policy yet, and Google's OAuth
consent screen plus Play's listing both require one before a real
release.

**Required?** Yes, before any public release.
**Blocking?** Yes, for both Play and a production Google OAuth consent
screen.
**Input for this**: `docs/TECHNICAL_DATA_INVENTORY.md` (what's actually
stored, table by table) and `docs/THIRD_PARTY_DATA_FLOWS.md` (which
outside services see what). Hand these to whoever drafts the policy —
they're technical inputs, not a policy themselves.
**Decision needed alongside this**: what account/data deletion should
actually do (see Step 6) — a privacy policy typically promises a deletion
mechanism, so decide the mechanism before or alongside writing the policy.
**Engineering work after**: writing/hosting the policy is not engineering
work this session can do; if the policy commits to specific deletion
behavior, that becomes Step 6's engineering scope.

## Step 6 — Account/data deletion

**Why**: no deletion path exists anywhere in the codebase today (verified
by exhaustive grep — zero matches). This is the most concrete remaining
internal gap, held back specifically because it needs your decision on
what happens to append-only Money/event history on deletion (anonymize?
retain for a legal minimum? actually delete?) before it can be built
correctly.

**Required?** Yes, in some form, before a public Play listing (Play's Data
Safety form asks directly) and before a privacy policy can honestly
promise it.
**Blocking?** Yes, for Play.
**Decision needed from you**: the retention policy above. Once decided,
this becomes a normal, scoped engineering task: a server RPC that removes
a profile's account membership, Storage objects, and PII, handles the
append-only tables per your decision, and a UI entry point (Settings →
Account, most naturally). A support-email-based manual process is an
acceptable interim step if you want to ship sooner and build the in-app
flow after.
**Engineering work after your decision**: moderate — a new RPC, tests
(including hostile-client and idempotency tests matching this project's
existing standard), and a UI flow. Not attempted this session because the
policy decision has to come first.

## Step 7 — Release signing

**Why**: verified tonight that the release build type signs with the
Android debug certificate — a real production keystore has never been
configured.

**Required?** Yes, before any Play upload.
**Blocking?** Yes.
**Exact steps**: `docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md` — generate/
obtain a keystore (Play App Signing recommended), wire it into
`build.gradle.kts` via a gitignored properties file, rebuild, re-verify
with `apksigner`.
**Engineering work after your action**: small — the `build.gradle.kts`
edit described in the runbook, then a rebuild and a repeat of the
verification this session already ran once (R8, manifest, 16KB check).

## Step 8 — Build the final release AAB

**Why**: once Step 7 is done, a real production artifact can be built.

**Required?** Yes.
**Blocking?** Yes (depends on Step 7).
**Exact steps**: `flutter build appbundle --release
--dart-define-from-file=dart_define.json` with the real signing config in
place. Retain the `.aab`, `mapping.txt`, its SHA-256, and the exact commit
per `docs/RELEASE_VERSIONING.md`'s artifact-retention convention.

## Step 9 — Final physical release-artifact smoke

**Why**: this session's physical Galaxy A14 certification (extensive —
see `docs/LOOP_FINAL_STATE.md`) was all on debug-signed QA builds. A
production-signed artifact should get at least one physical install and
smoke test before wide release, since signing changes can occasionally
interact with things debug builds don't exercise (app updates over an
existing install being the main one — a signing-key change breaks
in-place updates for anyone who installed a debug-signed build, which is
exactly why Play App Signing is recommended in Step 7).

**Required?** Strongly recommended.
**Blocking?** No, but skipping it shifts risk to real users.

## Step 10 — Play Console submission

**Why**: the actual release.

**Required?** This is the release itself.
**Blocking?** Depends on every step above.
**Input for this**: `docs/PLAY_RELEASE_READINESS.md` — identity,
permissions, signing, data-safety, and closed-test-history summary, plus
what only you can verify in Play Console itself (developer account
standing, app-ID availability, current closed-testing requirements,
content rating).
**Not performed by this session, ever**: no submission, no publication,
no store upload. That decision and action are entirely yours.

## What NOT to do based on this document

Don't treat any "Required? No" item as something to skip forever — they're
sequenced by blocking-ness, not by importance. Don't upgrade Supabase,
generate a production keystore, or take any payment action because a
document told you to; take it because you decided to, after reading the
"Why."
