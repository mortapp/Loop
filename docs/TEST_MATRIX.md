# LOOP Test Matrix

Updated: 2026-08-25

| Area                          | Command or evidence                                                      | Result                                                               |
| ----------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| Database replay               | `npx supabase db reset --local`                                          | PASS - all 27 migrations and seed applied                            |
| Database regression           | `npx supabase test db --local`                                           | PASS - 14 files, 209 tests                                           |
| Migration parity              | Hosted `list_migrations` vs local filenames                              | PASS - exact 27-entry match                                          |
| AI confirmation               | pgTAP `010_ai_confirmation_idempotency.sql`                              | PASS - account/user/tool/input/tamper/expiry/retry boundaries        |
| Item photos                   | pgTAP `011_atomic_item_photos.sql`                                       | PASS - atomic attach/detach and cross-account denial                 |
| Private Storage               | pgTAP `008_private_storage.sql`                                          | PASS - private buckets, paths, MIME, size, isolation                 |
| Money lifecycle               | pgTAP `009_atomic_money_lifecycle.sql`                                   | PASS - atomic purchase/listing/sale/refund                           |
| Quote acceptance idempotency  | pgTAP `014_quote_acceptance_money.sql`                                   | PASS - exactly-once Money event, retry-proof                         |
| Flutter format                | `dart format --output=none --set-exit-if-changed lib test`               | PASS - 92 files, 0 changes                                           |
| Flutter analysis              | `flutter analyze --no-pub`                                               | PASS - no issues                                                     |
| Flutter tests                 | `flutter test --no-pub --concurrency=1`                                  | PASS - 99/99; all 24 test files pass                                 |
| Ask LOOP mobile failures      | Account scope plus repository focused tests                              | PASS - 11/11                                                         |
| Web typecheck                 | `npm run typecheck --workspaces --if-present`                            | PASS                                                                 |
| Web lint                      | `npm run lint --workspaces --if-present`                                 | PASS                                                                 |
| Web unit tests                | `npm run test:unit` (apps/web)                                           | PASS - 4/4                                                           |
| Web build                     | `npm run build --workspace apps/web`                                     | PASS - Next.js production build, 24 routes                           |
| Web E2E                       | `npx playwright test`                                                    | PASS - 31 pass, 60 credential-gated skips, 0 fail                    |
| Public accessibility          | axe WCAG 2 A/AA specs                                                    | PASS on public auth surfaces                                         |
| Responsive web                | Playwright at 360/390/430/768/1024/1280/1440                             | PASS on public surfaces                                              |
| Production Vercel             | `list_deployments` plus HTTP smoke                                       | PASS - source `fc3f54d` (current HEAD); sign-in HTTP 200             |
| Android APK build             | Configured debug build from `48a0184` (worktree outside OneDrive)        | PASS - 162,052,706 bytes                                             |
| Android APK signature         | `apksigner verify --verbose --print-certs`                               | PASS - v2, Android debug certificate                                 |
| Android APK identity          | `apkanalyzer manifest`                                                   | PASS - `com.loop.app.loop_mobile`, `1.0.0`, minSdk 24, targetSdk 36  |
| APK secret scan               | Extracted-APK grep for secret-shaped strings                             | PASS - no matches                                                    |
| Galaxy A14 connection         | `adb devices -l` (wireless)                                              | PASS - `10.0.0.151:38827`                                            |
| Galaxy final APK install      | `adb install -r`, session preserved                                      | PASS                                                                 |
| Authenticated Galaxy gauntlet | Today, Money, Sell, Business, Protect, Ask LOOP, account, sign-out/in    | PASS - see `docs/LOOP_FINAL_STATE.md` follow-up physical passes      |
| Sell Copy/Share/Export        | Physical: clipboard, native share sheet, named `.txt` export             | PASS                                                                 |
| Returned-item eligibility     | Physical: pre-existing and freshly-transitioned `returned` item          | PASS                                                                 |
| Multi-line quote              | Physical: two-line quote, $0.05 server total, accept, Money event        | PASS                                                                 |
| Protect purchase/return/refund| Physical: purchase, `initiated`→`shipped`→`received`→`refunded`          | PASS                                                                 |
| 100%/150% text and rotation   | Physical: `font_scale 1.5`, landscape rotation, all five tabs            | PASS                                                                 |
| Native Google login           | Owner physical confirmation                                              | PASS - returning user reached Today with no onboarding/Vercel        |
| Live AI provider              | Controlled provider request                                              | OWNER_ACTION_REQUIRED - key unavailable                              |
| iOS source/config parity      | Static Android/iOS/shared-source audit                                   | PASS                                                                 |
| Native iOS build               | GitHub macOS Xcode Simulator build, run `33068098716`                    | PASS - unsigned Simulator build on `54a1ec8`                         |
| GitHub CI                     | Quality run `33069806560` on `ec677dd`                                  | PASS - both jobs, every executed step, no Node 20 action warning     |
| Security advisors             | `get_advisors` (security)                                                | ACCEPTED_WITH_EVIDENCE - 7 SECURITY DEFINER + leaked-password (plan) |
| Performance advisors          | `get_advisors` (performance)                                             | ACCEPTED_WITH_EVIDENCE - unused-index INFO only, no new findings     |

## Not re-attempted this pass

- Real alternate-account isolation switch (physical) — covered at the code/DB
  level by the account-graph-integrity and business-members test suites, not
  re-walked physically this session.
- A fresh warranty claim mutation (physical).
- A valid Flutter frame-timing profile — no ANR/OOM/jank observed, but no
  profiler artifact was captured.

## Notes

- The 60 Playwright skips are explicit credential-gated tests, not hidden
  failures. They require a dedicated QA identity rather than the owner's account.
- Local Supabase uses LOOP's isolated ports 55321-55329 and never touches MORT.
- Current advisors are classified in `docs/KNOWN_ISSUES.md`; no correct index was
  dropped merely because the hosted dataset has little usage telemetry.
