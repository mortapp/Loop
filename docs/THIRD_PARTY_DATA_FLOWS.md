# Third-Party Data Flows

Updated: 2026-08-25

**TECHNICAL INPUT — NOT LEGAL ADVICE.** Third-party services actually
present in LOOP's runtime dependency tree and configuration, verified by
reading `apps/web/package.json`, `apps/mobile/pubspec.yaml`, and the
Supabase/Vercel/Google integration points already documented in
`docs/CLAUDE_FINAL_COMPLETION_RUN.md` and this session's audits. No
service is listed here that isn't actually wired into the runtime path.

| Service | What reaches it | Why | Optional? | Notes |
| --- | --- | --- | --- | --- |
| **Supabase** (`zqalnvfwxmfrnyjcuehq`, `us-west-2`) | All application data described in `docs/TECHNICAL_DATA_INVENTORY.md` — auth credentials, every table's rows, private Storage file bytes | Database, auth, and file storage — LOOP's entire backend | No — core dependency | Free plan; see `docs/DATABASE_RELEASE_AND_RECOVERY_RUNBOOK.md` for backup posture |
| **Google (OAuth)** | Email address, name, and Google profile identifier for users who choose "Continue with Google"; nothing beyond standard OAuth profile/email scopes as far as this session verified (confirm the exact scopes Supabase's Google provider requests in the Supabase dashboard) | Sign-in convenience | Yes — email/password sign-in is also available | See `docs/GOOGLE_OAUTH_RELEASE_CHECKLIST.md` |
| **Vercel** | Web request traffic, server logs, environment-variable-held secrets (`ANTHROPIC_API_KEY` if configured) | Hosting for `apps/web` (production: `https://loop-teal-rho.vercel.app`) | No — core dependency for the web surface | GitHub-integrated auto-deploy on push to `main`, verified this session |
| **Anthropic** | Ask LOOP prompt content (user's message plus whatever account context the server includes in the request) **only while `ANTHROPIC_API_KEY` is configured** | Live AI responses for Ask LOOP | Yes — the feature fails closed with a truthful "not configured" message when the key is absent, which is its current state | LOOP's own database never stores the conversation (see `docs/TECHNICAL_DATA_INVENTORY.md`); Anthropic's own retention of API request content is governed by Anthropic's terms, not LOOP's code — review those terms before enabling in production, since they're outside this codebase's control |
| **GitHub** | Source code, CI logs, and (once configured) the `QA_TEST_EMAIL`/`QA_TEST_PASSWORD` secrets for Playwright | Version control and CI/CD | No — engineering infrastructure, not a runtime user-data processor (no end-user data flows through GitHub in normal operation) | Repository is currently **public** (`githubRepoVisibility: "public"` per Vercel deployment metadata) — confirm this is intentional; a public repo means the source (not user data, but architecture/comments) is visible to anyone |

## Services NOT present (verified by dependency-tree absence)

No analytics SDK (Firebase Analytics, Mixpanel, Amplitude, etc.), no
crash-reporting SDK (Sentry, Crashlytics, etc.), no advertising SDK, no
push-notification service, no payment processor. If any of these are
added later, this document and `docs/TECHNICAL_DATA_INVENTORY.md` should
be updated in the same change.

## Owner follow-up

- Confirm the GitHub repository visibility (public vs. private) is a
  deliberate choice.
- Decide whether Ask LOOP (and therefore a data flow to Anthropic) ships
  in the first release, or ships disabled until reviewed — this is a
  product decision, not something this session should decide by either
  enabling or permanently disabling the capability.
- Feed this document and `docs/TECHNICAL_DATA_INVENTORY.md` to whoever
  drafts LOOP's actual privacy policy and Play Data Safety declaration.
