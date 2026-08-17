import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_providers.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase from build-time configuration. Safe to run with
  // empty credentials — the app still boots, auth/data calls just won't
  // succeed until real values are supplied via --dart-define.
  await bootstrapSupabase(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: LoopApp()));
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

    return MaterialApp.router(
      title: 'LOOP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
