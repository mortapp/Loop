/// Non-Supabase runtime configuration, same `--dart-define` pattern as
/// `SupabaseConfig`.
class AppConfig {
  const AppConfig._();

  /// Base URL of the deployed Next.js app — used only by the AI client
  /// today (`apps/mobile/lib/features/ai`), which calls the same
  /// `/api/ai/chat` + `/api/ai/confirm` routes apps/web's own chat UI
  /// calls rather than a parallel mobile AI backend. Defaults to the
  /// real, current production deployment (a public URL, not a secret —
  /// same reasoning as the hardcoded OAuth redirect scheme in
  /// auth_screen.dart) so the app works out of the box; override with
  /// `--dart-define=LOOP_WEB_BASE_URL=...` for a preview/local deploy.
  static const String webBaseUrl = String.fromEnvironment(
    'LOOP_WEB_BASE_URL',
    defaultValue: 'https://loop-teal-rho.vercel.app',
  );
}
