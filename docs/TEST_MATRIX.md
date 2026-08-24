# LOOP Test Matrix

Updated: 2026-08-24

| Area                          | Command or evidence                                                      | Result                                                               |
| ----------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| Database replay               | GitHub Quality clean replay                                              | PASS - all 27 migrations and seed applied                            |
| Database regression           | GitHub Quality database security/integrity step                          | PASS - 14 files, 209 tests                                           |
| Migration parity              | Hosted `list_migrations` vs local filenames                              | PASS - exact 27-entry match                                          |
| AI confirmation               | pgTAP `010_ai_confirmation_idempotency.sql`                              | PASS - account/user/tool/input/tamper/expiry/retry boundaries        |
| Item photos                   | pgTAP `011_atomic_item_photos.sql`                                       | PASS - atomic attach/detach and cross-account denial                 |
| Private Storage               | pgTAP `008_private_storage.sql`                                          | PASS - private buckets, paths, MIME, size, isolation                 |
| Money lifecycle               | pgTAP `009_atomic_money_lifecycle.sql`                                   | PASS - atomic purchase/listing/sale/refund                           |
| Flutter format                | `dart format --output=none --set-exit-if-changed lib test`               | PASS - 83 files, 0 changes                                           |
| Flutter analysis              | `flutter analyze --no-pub`                                               | PASS - no issues                                                     |
| Flutter tests                 | GitHub Quality plus local file-by-file rerun                             | PASS - 93/93; all 22 test files pass                                 |
| Ask LOOP mobile failures      | Account scope plus repository focused tests                              | PASS - 11/11                                                         |
| Web typecheck                 | `npm run typecheck --workspace apps/web`                                 | PASS                                                                 |
| Web lint                      | `npm run lint --workspace apps/web`                                      | PASS                                                                 |
| Web build                     | `npm run build --workspace apps/web`                                     | PASS - Next.js production build, 24 routes                           |
| Web E2E                       | `npm run test:e2e`                                                       | PASS - 31 pass, 60 credential-gated skips, 0 fail                    |
| Public accessibility          | axe WCAG 2 A/AA specs                                                    | PASS on public auth surfaces                                         |
| Responsive web                | Playwright at 360/390/430/768/1024/1280/1440                             | PASS on public surfaces                                              |
| Production Vercel             | GitHub deployment status plus HTTP smoke                                 | PASS - source `66188b9`; sign-in HTTP 200                            |
| Android APK build             | Configured debug build from `66188b9`                                    | PASS - 157,684,544 bytes                                             |
| Android APK signature         | `apksigner verify --verbose --print-certs`                               | PASS - v2, Android debug certificate                                 |
| Android APK identity          | `apkanalyzer manifest`                                                   | PASS - `com.loop.app.loop_mobile`, `1.0.0+1`                         |
| Android config audit          | Git-ignored public project config plus config unit tests                 | PASS - hosted ref matches; no service-role field                     |
| Galaxy secure startup         | Prior configured APK wireless retest                                     | PASS for prior checkpoint `228679e`                                  |
| Galaxy final APK              | `adb devices -l` then install/traverse exact final APK                   | EXTERNAL_BLOCKER - no ADB or mDNS device currently listed            |
| Native Google login           | Owner physical confirmation                                              | PASS for authentication capability; preserve callback architecture   |
| Authenticated Galaxy gauntlet | Today, Money, Sell, Business, Protect, AI, account, sign-out/sign-in     | EXTERNAL_BLOCKER - device unavailable                                |
| Live AI provider              | Controlled provider request                                              | OWNER_ACTION_REQUIRED - key unavailable                              |
| iOS source/config parity      | Static Android/iOS/shared-source audit                                   | PASS                                                                 |
| Native iOS build              | Xcode build and device/TestFlight                                        | EXTERNAL_BLOCKER - macOS/Xcode required                              |
| GitHub CI                     | Quality run `32728072991` on `66188b9`                                   | PASS - both jobs, every executed step                                |

## Notes

- The 60 Playwright skips are explicit credential-gated tests, not hidden
  failures. They require a dedicated QA identity rather than the owner's account.
- Local Supabase uses LOOP's isolated ports 55321-55329 and never touches MORT.
- Current advisors are classified in `docs/KNOWN_ISSUES.md`; no correct index was
  dropped merely because the hosted dataset has little usage telemetry.
