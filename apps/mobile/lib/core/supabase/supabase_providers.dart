import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Initializes Supabase using build-time configuration. Safe to call even
/// when no credentials have been supplied yet (see [SupabaseConfig]) — it
/// will not throw, it just means the client will not be able to reach a
/// backend until real values are provided via `--dart-define`.
Future<void> bootstrapSupabase({
  required String url,
  required String anonKey,
}) async {
  await Supabase.initialize(
    url: url.isEmpty ? 'https://placeholder.supabase.co' : url,
    // supabase_flutter renamed `anonKey` to `publishableKey`; we keep the
    // `anonKey` parameter name on bootstrapSupabase since it maps directly
    // to the SUPABASE_ANON_KEY --dart-define flag documented in the README.
    publishableKey: anonKey.isEmpty ? 'placeholder-anon-key' : anonKey,
    debug: false,
  );
}
