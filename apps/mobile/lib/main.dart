import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/configuration_error_app.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_preference.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A build run without real --dart-define values (or with a stale/
  // placeholder one) must fail loudly here, before the sign-in screen
  // -- let alone Google OAuth -- is ever reachable. This used to boot
  // normally into a Supabase client pointed at an unreachable
  // placeholder.supabase.co; see docs/KNOWN_ISSUES.md for the real
  // regression that caused.
  if (!SupabaseConfig.isConfigured) {
    if (kDebugMode) {
      // Never prints the anon key -- only whether config looks present.
      debugPrint(
        'SupabaseConfig.isConfigured == false '
        '(url ${SupabaseConfig.url.isEmpty ? "empty" : "set"}, '
        'anonKey ${SupabaseConfig.anonKey.isEmpty ? "empty" : "set"}). '
        'Rebuild with --dart-define-from-file=dart_define.json.',
      );
    }
    runApp(const ConfigurationErrorApp());
    return;
  }

  await bootstrapSupabase(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Read the persisted theme preference before the first frame, same
  // bootstrap-before-runApp pattern as Supabase config, so there's no
  // flash of the wrong theme.
  final initialTheme = await loadThemePreference();

  runApp(
    ProviderScope(
      overrides: [themePreferenceProvider.overrideWith((ref) => initialTheme)],
      child: const LoopApp(),
    ),
  );
}

/// Root widget for the LOOP mobile app.
///
/// LOOP is one unified value operating system, not three separate apps —
/// this widget wires up the single shared theme, router, and Riverpod
/// scope that every engine (MAKE, PROTECT, RECOVER) and every shared
/// surface (Today, Money, Sell, Business, AI) runs within.
class LoopApp extends ConsumerWidget {
  const LoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themePreference = ref.watch(themePreferenceProvider);

    return MaterialApp.router(
      title: 'LOOP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeModeFor(themePreference),
      routerConfig: router,
    );
  }
}
