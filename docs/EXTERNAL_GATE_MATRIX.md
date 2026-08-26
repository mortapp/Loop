# External Gate Matrix

Updated: 2026-08-25

Every gate currently between LOOP and a public release, in one table. See
`docs/OWNER_RELEASE_ACTION_CENTER.md` for the ordered, narrative version of
the same information.

| Gate | Current status | Owner action | Claude prep complete? | Requires payment? | Requires external device? | Requires a secret? | Blocks Android release? | Blocks iOS release? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Live AI (Ask LOOP) | Fails closed, truthful | Configure `ANTHROPIC_API_KEY` in Vercel | Yes — `docs/ASK_LOOP_PROVIDER_ENABLEMENT.md` | Yes (Anthropic API usage) | No | Yes | No — optional feature | No — optional feature |
| Authenticated E2E (Playwright) | 60/91 tests truthfully skip | Create dedicated QA identity + 2 GitHub secrets | Yes — `docs/AUTHENTICATED_E2E_ENABLEMENT.md` | No | No | Yes (test credential) | No | No |
| Supabase leaked-password protection | Unavailable on Free plan | Upgrade to a paid Supabase plan, then enable in dashboard | Yes — mitigations documented in `docs/KNOWN_ISSUES.md`; upgrade path in `docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md` | Yes (plan upgrade) | No | No | No | No |
| Supabase backup/PITR posture | Not independently re-verified against current published policy tonight | Check Database → Backups in dashboard; decide if a plan upgrade or manual export cadence is warranted | Yes — checklist in `docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md` | Possibly (if upgrading) | No | No | Recommended before production trust | Recommended before production trust |
| Native iOS build | Never attempted (Windows) | Run on macOS/Xcode per the exact handoff steps | Yes — `docs/IOS_XCODE_HANDOFF.md`, static source parity already PASS | No (beyond existing Apple Developer membership) | Yes (a Mac, ideally a physical iPhone too) | No | No | **Yes** |
| Release signing | Debug-signed only (verified) | Generate/obtain a production keystore, wire into `build.gradle.kts` | Yes — exact steps in `docs/ANDROID_RELEASE_ARTIFACTS_RUNBOOK.md` | No (keystore generation is free; Play App Signing is free) | No | Yes (keystore + passwords) | **Yes** | No (iOS has its own separate signing via Apple) |
| Privacy policy | Does not exist | Write and host one, informed by the technical data inventory | Yes — `docs/TECHNICAL_DATA_INVENTORY.md`, `docs/THIRD_PARTY_DATA_FLOWS.md` | Possibly (legal counsel) | No | No | **Yes** (Play requires it) | **Yes** (App Store requires it) |
| Account/data deletion | Does not exist anywhere in the codebase | Decide retention policy for append-only tables, then approve building it | Yes — gap fully documented, decision framed, in `docs/TECHNICAL_DATA_INVENTORY.md` and `docs/OWNER_RELEASE_ACTION_CENTER.md` | No | No | No | **Yes** (Play Data Safety asks directly) | Likely (App Store has a similar expectation) |
| Product/legal/operational approval | Not sought | Your own internal process | N/A — not something Claude can prepare beyond the technical inputs above | No | No | No | **Yes** | **Yes** |
| App Store / Google Play publication authorization | Not authorized | Your explicit go-ahead, after every gate above | N/A | Play: one-time $25 registration if not already a developer. App Store: $99/year Apple Developer Program | No | No | **Yes** | **Yes** |

## Reading this table

"Claude prep complete" means the technical/documentation groundwork is
done — not that the gate is closed. Every gate marked "Blocks" a platform
release genuinely does; none of them can be closed by more code review or
documentation alone from this point.
