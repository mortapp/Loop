# Claude Overnight Release-Readiness Pass

START_TIME=2026-08-25 (session start)
START_HEAD=8e4abcf058c681830999c980e3efb53a48f29243
START_ORIGIN_MAIN=8e4abcf058c681830999c980e3efb53a48f29243 (aligned)
START_TRACKED_TREE=clean (only untracked `artifacts/` and a stray
`supabase/.temp.pre-link-20260823/` present, both pre-existing and expected)
LAST_RUNTIME_COMMIT=48a0184e4a02412cfd9b3a891840714ff31596a0
PHYSICALLY_CERTIFIED_RUNTIME=48a0184e4a02412cfd9b3a891840714ff31596a0
PHYSICALLY_CERTIFIED_RUNTIME_STILL_CURRENT=YES (all 6 commits since 48a0184
are docs-only certification records; verified via
`git log --oneline 48a0184..HEAD`)
CURRENT_FINAL_STATE=PRODUCTION_READY_EXTERNALLY_BLOCKED

This is a recovery ledger for an overnight release-readiness pass: audit,
document, and prepare — not another product-build session. Runtime code
changes only for a proven Critical/High release defect. See
`docs/OVERNIGHT_DIRECTIVE_SUMMARY.md`-equivalent context in
`docs/LOOP_FINAL_STATE.md`, `docs/TEST_MATRIX.md`, and
`docs/CLAUDE_FINAL_COMPLETION_RUN.md` for what was already proven before
tonight.

## Progress log

Update this table after each phase or checkpoint.

| Phase | Status | Notes |
| --- | --- | --- |
| 0 — Recover truth | DONE | Clean tree, HEAD=origin/main=8e4abcf |
| 0.1 — Read certification docs | DONE | Already in context from writing them this session |
| 0.2 — Create this ledger | DONE | |
| 1 — Freeze baseline | DONE | No runtime changes since 48a0184 |
| 2 — Android release config audit | DONE | Clean: 1 permission (INTERNET), documented; no unnecessary components |
| 2.1 — Permission minimization | DONE | Only INTERNET + auto-generated DYNAMIC_RECEIVER perm; nothing to remove |
| 2.2 — Exported component security | DONE | Only MainActivity (required) + AndroidX ProfileInstallReceiver (DUMP-protected, not attacker-reachable) |
| 2.3 — Deep link/callback audit | DONE | Scheme consistent across Android manifest, iOS plist, Dart contract |
| 3 — Release versioning strategy | DONE | docs/RELEASE_VERSIONING.md written; no version bump (no release being cut) |
| 4 — Dependency security audit | DONE | npm audit: 0 vulnerabilities. flutter pub outdated: only normal version drift, no CVEs |
| 4.1 — License inventory | PENDING | |
| 5 — Production config audit | DONE | No hardcoded localhost/placeholder/staging endpoints in production paths |
| 5.1 — Secret scan deep pass | DONE | Clean; one self-labeled "test-only" placeholder string in a Playwright spec, not a real secret |
| 6 — Supabase release-readiness | DONE (re-confirmed same as prior session) | 27/27 migration parity, advisors unchanged |
| 6.1 — SECURITY DEFINER inventory | DONE | docs/SECURITY_DEFINER_INVENTORY.md — 13 functions, 7 RPC-callable, all search_path-hardened |
| 6.2 — DB recovery runbook | DONE | docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md |
| 6.3 — Backup/restore reality | DONE | Free plan confirmed via get_organization; exact backup policy needs owner dashboard check (not fabricated) |
| 7 — Auth release readiness | DONE | Verified no client-side key exposure, callback consistency, web callback derives origin dynamically |
| 7.1 — Google OAuth release checklist | DONE | docs/GOOGLE_OAUTH_RELEASE_CHECKLIST.md |
| 8 — Ask LOOP provider prep | DONE | Verified: ANTHROPIC_API_KEY server-only, 3 usages, mobile never touches it, calls web API only |
| 8.1 — AI enablement runbook | DONE | docs/ASK_LOOP_PROVIDER_ENABLEMENT.md |
| 9 — Playwright credential prep | DONE | docs/AUTHENTICATED_E2E_ENABLEMENT.md; harness already correct, just needs the secret |
| 10 — Privacy & data inventory | DONE | docs/TECHNICAL_DATA_INVENTORY.md — full table-by-table inventory |
| 10.1 — Third-party data flows | DONE | docs/THIRD_PARTY_DATA_FLOWS.md; confirmed repo is genuinely public via `gh repo view` |
| 11 — Play data safety input | DONE | docs/PLAY_DATA_SAFETY_TECHNICAL_INPUT.md |
| 11.1 — Play permission declaration input | DONE | docs/ANDROID_PERMISSION_DECLARATION_INPUT.md |
| 12 — Account deletion audit | DONE | Zero matches for delete-account patterns anywhere; real gap documented, not built (product/legal semantics needed first) |
| 13 — Logging & redaction audit | DONE | Clean: main.dart's debugPrint is kDebugMode-gated and never prints secrets; web's safeMetadata() whitelists only code/status fields |
| 14 — Failure-mode audit | DONE | docs/FAILURE_MODE_AUDIT.md; no new defect found |
| 15 — Operations runbook | DONE | docs/PRODUCTION_OPERATIONS_RUNBOOK.md |
| 15.1 — Security incident checklist | DONE | docs/SECURITY_INCIDENT_CHECKLIST.md |
| 16 — CI/CD release readiness | DONE | Single clean workflow, no hidden failures, paths-ignore for docs, minimal permissions |
| 16.1 — Release build workflow design | DEFERRED | No production signing secrets exist yet; adding an untestable workflow now is complexity without benefit. Manual process fully documented in the Android runbook instead |
| 17 — Android release build dry run | DONE | Real `flutter build appbundle/apk --release` from 48a0184; see Android runbook |
| 17.1 — 16KB page size check | DONE | `zipalign -c -P 16` verification successful |
| 17.2 — Release artifacts runbook | DONE | docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md |
| 18 — iOS source parity | DONE | docs/IOS_XCODE_HANDOFF.md |
| 19 — Play release readiness | DONE | docs/PLAY_RELEASE_READINESS.md |
| 19.1 — Play listing draft | SKIPPED | Explicitly optional per directive; lower priority than real audits |
| 4.1 — License inventory | DONE | docs/THIRD_PARTY_DEPENDENCY_INVENTORY.md (direct deps only; all well-known vendor/official packages) |
| 20 — TODO/placeholder audit | PENDING | |
| 20.1 — Dead code audit | PENDING | |
| 21 — Owner action center | PENDING | |
| 21.1 — External gate matrix | PENDING | |
| 22 — Final regression (only if justified) | PENDING | |
| 23 — Git checkpoints | ONGOING | |
| 24 — Final overnight report | PENDING | |

## Runtime changes this pass

None. No Critical/High release defect was found that required a runtime
change. A real release build/signing gap was found (release build type
signs with the debug certificate — `docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md`)
but the fix requires an owner-provided production keystore, not a code
change, so it's documented as OWNER_ACTION_REQUIRED rather than "fixed."

## Notable findings

- **No account-deletion path exists anywhere in the codebase** (grepped
  mobile/web/database for delete-account patterns — zero matches). This is
  a real gap for Play Data Safety / account-deletion policy compliance, but
  building it is new runtime work with product/legal semantics (what
  happens to Money history, receipts, quotes on deletion?) that shouldn't
  be invented unilaterally overnight. Documented as an owner decision point
  in `docs/OWNER_RELEASE_ACTION_CENTER.md` and
  `docs/PLAY_DATA_SAFETY_TECHNICAL_INPUT.md` rather than built.
- Release build type signs with the Android debug certificate (stock
  Flutter template default, never overridden) — confirmed via a real
  `flutter build appbundle --release` / `apk --release` dry run. Everything
  else about the release build pipeline (R8, tree-shaking, manifest,
  16KB native-library alignment) verified clean. See
  `docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md`.

## Owner action required (accumulating)

See `docs/OWNER_RELEASE_ACTION_CENTER.md` once written (Phase 21) for the
authoritative, ordered list.

## Next action

Phase 2: Android release configuration audit
(`apps/mobile/android/app/build.gradle`, `AndroidManifest.xml`, signing
config, permissions).
