import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Riverpod provider exposing the app-wide Supabase client.
///
/// `Supabase.initialize` must have already run in `main()` before this
/// provider is read (see `bootstrapSupabase`). Every LOOP engine
/// (MAKE / PROTECT / RECOVER) reads the backend through this single client
/// rather than creating its own, keeping auth/session state unified.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Stream of Supabase auth state changes, exposed for any widget that needs
/// to react to sign-in/sign-out (e.g. gating navigation, the account
/// switcher).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Initializes Supabase using build-time configuration.
///
/// Callers MUST check `SupabaseConfig.isConfigured` first (see
/// `main.dart`) -- this function used to silently substitute a
/// `placeholder.supabase.co` URL when `url`/`anonKey` were empty, which
/// let a build missing `--dart-define` boot normally and reach the
/// sign-in screen, only to fail with a DNS error the moment Google OAuth
/// (or any auth/data call) actually hit the network. That fallback is
/// gone: an invalid config must never reach here at all.
Future<void> bootstrapSupabase({
  required String url,
  required String anonKey,
}) async {
  assert(
    SupabaseConfig.isValidConfig(url, anonKey),
    'bootstrapSupabase called with invalid config -- callers must check '
    'SupabaseConfig.isConfigured first (see main.dart).',
  );
  await Supabase.initialize(
    url: url,
    // supabase_flutter renamed `anonKey` to `publishableKey`; we keep the
    // `anonKey` parameter name on bootstrapSupabase since it maps directly
    // to the SUPABASE_ANON_KEY --dart-define flag documented in the README.
    publishableKey: anonKey,
    debug: false,
  );
}
