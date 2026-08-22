/// Supabase connection configuration, sourced from `--dart-define` (or
/// `--dart-define-from-file`) values at build/run time so no credentials
/// are ever hardcoded in source.
///
/// Example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// Prefer `--dart-define-from-file=dart_define.json` (see
/// `dart_define.example.json` and the README) so these two values never
/// have to be retyped by hand and can't be silently omitted.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The literal host `bootstrapSupabase` used to silently fall back to
  /// before this validation existed -- a real, previously-shipped
  /// regression (a debug/QA build run without --dart-define reached
  /// Google OAuth against this unreachable host instead of failing
  /// loudly). Named here so `isValidConfig` can reject it explicitly even
  /// if a future edit reintroduces a similar fallback elsewhere.
  static const String placeholderHost = 'placeholder.supabase.co';

  /// Whether real, usable Supabase credentials were provided at build
  /// time. Checked once at startup (`main.dart`) *before* Supabase is
  /// ever initialized and before the sign-in screen can be reached --
  /// a misconfigured build must fail loudly, not silently attempt a
  /// network call to an unreachable placeholder host.
  static bool get isConfigured => isValidConfig(url, anonKey);

  /// Pure validation, factored out of [isConfigured] so it's directly
  /// testable with arbitrary inputs without needing a different
  /// `--dart-define` per test case (see `test/supabase_config_test.dart`).
  static bool isValidConfig(String candidateUrl, String candidateAnonKey) {
    if (candidateUrl.isEmpty || candidateAnonKey.isEmpty) return false;

    final uri = Uri.tryParse(candidateUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host == placeholderHost) return false;

    return true;
  }
}
