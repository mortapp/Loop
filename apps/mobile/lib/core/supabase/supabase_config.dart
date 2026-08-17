/// Supabase connection configuration, sourced from `--dart-define` values at
/// build/run time so no credentials are ever hardcoded in source.
///
/// Example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// When these are left unset (empty string defaults), the app still boots —
/// Supabase is initialized with empty values and any auth/data call will
/// simply fail until real credentials are supplied. This lets the UI
/// scaffold run standalone before a live project exists.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');

  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether real Supabase credentials were provided at build time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
