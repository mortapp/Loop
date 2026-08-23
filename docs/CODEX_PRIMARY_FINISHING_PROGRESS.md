# LOOP Codex Primary Finishing Progress

Updated: 2026-08-23T05:27:00-04:00

## Repository

- Active repository: `C:\Users\micha\OneDrive\Desktop\Loop`
- Branch: `main`
- Starting HEAD: `40692e8fdb22284b57b0a8e0742e585b1f177e4e`
- Auth/onboarding checkpoint: `87a25000f9656b81bf0e19a137ee44d5894a09b5`
- Remote: `git@github.com:mortapp/Loop.git`
- Remote policy: ordinary fast-forward pushes only; no force push. The
  backend/quote checkpoint travels with this progress update after all listed
  source and hosted rollback gates passed.
- Source version: `1.0.0+1`
- MORT status: reference-only; not modified

## Current Phase

`PHASE 7 - hosted account graph, private Storage, and atomic quote integrity`

## Verified Evidence

- Hosted Supabase project `zqalnvfwxmfrnyjcuehq` is active.
- Google and email authentication are enabled.
- The valid callback `com.loop.app.loop-mobile://app/login-callback` is in
  Android, iOS, compiled Dart, and the hosted Auth allowlist. The legacy
  underscore callback is absent from the configured QA APK's compiled Dart.
- OAuth waits for a consistent Supabase session/user pair, with duplicate,
  timeout, cancel, retry, and cold-session coverage.
- Onboarding requires display name + globally unique username, atomically
  saves both, and adds a password to Google-only users without creating a
  second account. Flutter is 41/41 green at the current checkpoint.
- Hosted migration `20260823050806_enforce_account_graph_integrity` blocks
  forged cross-account nested UUIDs, derives actor IDs from Auth, restricts
  profile email updates, and removes unnecessary trigger-function RPC access.
  Its hosted pgTAP suite passes 32/32 in a rolled-back synthetic transaction.
- Hosted migration `20260823051328_harden_private_storage_limits` keeps both
  buckets private, adds fail-closed UUID path parsing, sets 12 MiB document / 8
  MiB photo limits and MIME allowlists, and binds document metadata paths to
  their account. Hosted pgTAP passes 18/18.
- Hosted migration `20260823052248_harden_quote_rpc_inputs` recomputes quote
  totals, validates lines, derives the actor, and adds direct-write constraints.
  Hosted pgTAP passes 13/13.
- Mobile quote creation now calls that atomic RPC instead of leaving a possible
  orphan header, guards post-await widget disposal, and sanitizes errors on
  mobile and web. Focused Flutter quote tests pass 3/3; analyzer is clean.
- Security advisor no longer reports anonymous execution of
  `rls_auto_enable()`. Remaining helper-function warnings are reviewed,
  intentional RLS recursion breakers; leaked-password protection remains a
  plan-limited enhancement.

## Physical QA

- Device: Samsung SM-A146U, Android API 35
- Wireless ADB serial: `10.0.0.151:33757`
- Package: `com.loop.app.loop_mobile`
- Installed version: `1.0.0+1`
- Current gate: owner must complete Google account selection; LOOP is
  backgrounded and Chrome is foreground. No private account chooser content
  has been captured or displayed.

## Active Work

- Main agent: backend/RLS/Storage red-team remediation and shared app flow
  correctness.
- Sosa and the wireless QA agent completed their bounded assignments and were
  closed; no extra agents are running.

## External Gates

- Google account selection requires the owner on the physical phone.
- iOS Xcode, signing, TestFlight, and physical iPhone validation require Apple tooling and credentials.

## Next Automatic Checkpoint

Continue profile, Today, Money, Protect, and Recover flow audits while polling
the owner-gated Samsung callback state.
