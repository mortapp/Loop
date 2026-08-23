# LOOP Codex Primary Finishing Progress

Updated: 2026-08-23T07:04:18Z

## Repository

- Active repository: `C:\Users\micha\OneDrive\Desktop\Loop`
- Branch: `main`
- Starting HEAD: `40692e8fdb22284b57b0a8e0742e585b1f177e4e`
- Auth/onboarding checkpoint: `87a25000f9656b81bf0e19a137ee44d5894a09b5`
- Backend/account/storage/quote checkpoint: `4ab112bfeb05b4cc3e4f1063b92fe4790fd37a62`
- Remote: `git@github.com:mortapp/Loop.git`
- Remote policy: ordinary fast-forward pushes only; no force push. The current
  atomic lifecycle/error-safety checkpoint is pending its final scoped commit.
- Source version: `1.0.0+1`
- MORT status: reference-only; not modified

## Current Phase

`PHASE 8 - atomic Money/Protect/Recover lifecycle and cross-platform error safety`

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
  second account. Flutter is 47/47 green at the current checkpoint.
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
- Hosted migration `20260823060632_enforce_atomic_money_lifecycle` adds four
  authenticated, security-invoker RPCs for purchases, listings, sales, and
  refunds; direct-write guards, integer-cent/state constraints, source-event
  uniqueness, and one-sale-per-item enforcement keep legacy clients safe.
- Hosted migration
  `20260823062451_order_lifecycle_guards_after_account_integrity` preserves the
  established cross-account SQLSTATE contract by deterministically running
  account guards before lifecycle validation.
- Hosted migration `20260823070326_consolidate_business_member_policies`
  preserves all member/admin behavior while reducing SELECT/DELETE from
  multiple permissive policies to exactly one policy per command. The
  performance advisor now reports zero multiple-policy warnings.
- A current-CLI clean local reset now replays every migration and seed from
  empty. `supabase/roles.sql` supplies only the unattached local compatibility
  helper that the hosted platform owns; applied migrations remain immutable.
- Fresh database regression is 166/166 across nine pgTAP suites. Mobile is
  47/47, `flutter analyze --no-pub` is clean, and web typecheck, ESLint, and
  optimized Next.js build pass.
- Mobile and web purchase/listing/sale/refund flows use the same atomic RPCs.
  Async widget disposal is guarded, account selection survives refresh, return
  transitions only move forward, money caches invalidate after mutations, and
  browser/mobile/AI responses no longer expose raw backend/provider errors.
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

Commit and push the verified lifecycle/error-safety checkpoint, then continue
Today, Money, Protect, Recover, and account-action UX audits while polling the
owner-gated Samsung callback state.
