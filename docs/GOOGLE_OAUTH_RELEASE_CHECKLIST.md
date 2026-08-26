# Google OAuth Release Checklist

Updated: 2026-08-25

## Current architecture (verified this session, do not replace it)

LOOP's Google sign-in is **browser-based Supabase PKCE**, not a native
Android/iOS Google OAuth client SDK:

1. The app calls Supabase's `signInWithOAuth(provider: google)`, which
   opens the system browser to Google's own `accounts.google.com` consent
   screen (physically verified this session — the browser showed
   `accounts.google.com` requesting access to
   `zqalnvfwxmfrnyjcuehq.supabase.co`, never a LOOP-branded page).
2. Google redirects back to Supabase, which completes the exchange and
   redirects again to LOOP's **custom URL scheme**:
   `com.loop.app.loop-mobile://app/login-callback`.
3. That scheme is registered identically in three places — verified
   consistent tonight:
   - `apps/mobile/android/app/src/main/AndroidManifest.xml` (intent-filter
     `android:scheme="com.loop.app.loop-mobile"
     android:host="app" android:path="/login-callback"`)
   - `apps/mobile/ios/Runner/Info.plist` (`CFBundleURLSchemes`)
   - `apps/mobile/lib/core/auth/mobile_auth_contract.dart` (the single
     Dart source of truth both platforms' native code and the Supabase
     redirect URL are built from)
4. Web has its own, separate, standard PKCE callback at
   `apps/web/src/app/auth/callback/route.ts`, which derives its redirect
   target dynamically from the incoming request's own origin — never
   hardcoded to `localhost` or a fixed production URL.

**Do not** replace this with a native Android OAuth client (e.g. Google
Identity Services / Credential Manager) merely because Android is heading
toward a real release. That would be a real architecture change to a
security-sensitive, already-tested, already-physically-verified path, and
is exactly the kind of runtime churn this overnight pass is not authorized
to introduce without a proven defect.

## Owner checklist before/at release

These are dashboard/console actions this session cannot verify or perform
(no OAuth console access, and doing so would require the owner's Google
identity):

- [ ] **Google Cloud Console → OAuth consent screen**: confirm the app is
      in the correct publishing status (Testing vs. In production) for the
      audience you intend — "Testing" mode caps external users at a fixed
      list and shows an "unverified app" warning; moving to production
      may require Google's app verification review if you request
      sensitive/restricted scopes (LOOP's Google sign-in should only need
      basic profile/email scopes, but confirm exactly which scopes
      Supabase's Google provider requests).
- [ ] **Branding**: app name, logo, and support email shown on the Google
      consent screen match LOOP's real identity, not a placeholder.
- [ ] **Authorized redirect URI**: the Google OAuth client's configured
      redirect URI must be Supabase's own callback
      (`https://zqalnvfwxmfrnyjcuehq.supabase.co/auth/v1/callback` —
      confirm the exact value in Supabase Dashboard → Authentication →
      Providers → Google, since that's what Google actually needs to
      allow-list, not LOOP's own custom scheme).
- [ ] **Supabase Dashboard → Authentication → URL Configuration → Redirect
      URLs allow-list**: must contain the exact, byte-for-byte
      `com.loop.app.loop-mobile://app/login-callback` entry (host+path
      shape, not the legacy underscore-scheme variant — see
      `docs/KNOWN_ISSUES.md` for the real regression this was found from).
      If this entry is missing or wrong, Supabase silently falls back to a
      different allow-listed redirect and a mobile user's sign-in lands on
      the **web** callback instead, where it fails — confirmed exact
      failure mode in `apps/web/src/app/auth/callback/route.ts`'s own
      comment.
- [ ] **Supabase Dashboard → Authentication → Providers → Google**:
      provider enabled, client ID/secret populated (never verify this by
      asking the app to print them — check the dashboard field is
      non-empty).
- [ ] **Privacy Policy URL**: Google's OAuth consent screen requires a
      privacy policy URL once you move out of internal/testing mode. LOOP
      does not yet have a published privacy policy — this is a
      product/legal action item (`docs/TECHNICAL_DATA_INVENTORY.md` is
      technical input for writing one, not a substitute for it).
- [ ] **Android package/SHA fingerprint**: only relevant if you later
      configure a *native* Android OAuth client (Credential Manager /
      One Tap) as an addition alongside the existing browser-PKCE flow —
      not required for the current architecture. Don't add one unless a
      specific, deliberate product decision calls for it.

## What NOT to do

- Don't paste a Google client secret into chat, a commit, a doc, or a
  screenshot.
- Don't move the OAuth consent screen to production/verified status as an
  automated step — that's an owner decision with real Google-review
  implications.
- Don't test this checklist by attempting to log in as the owner's real
  Google account autonomously; every physical login test this project has
  done required the owner to tap their own account (see
  `docs/CLAUDE_FINAL_COMPLETION_RUN.md`), and that should stay true.
