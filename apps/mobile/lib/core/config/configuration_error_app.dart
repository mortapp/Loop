import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/loop_seal.dart';

/// Shown instead of the real app when `SupabaseConfig.isConfigured` is
/// false at startup -- a build run without real `--dart-define` values
/// (see `main.dart`). Deliberately not a crash and not a silent boot into
/// a broken sign-in screen: this is the loud, clear failure the old
/// `placeholder.supabase.co` fallback should always have been. Polished
/// and non-technical, since a QA tester or reviewer (not just a
/// developer) may be the one who sees it.
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.murexNoir,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.murexNoir,
          onSurface: AppColors.textPrimary,
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LoopSeal(size: 40, keyPoint: false, opacity: 0.7),
                  const SizedBox(height: 24),
                  Text(
                    "LOOP can't start",
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This build is missing its backend configuration. '
                    "If you're testing a debug/QA build, rebuild with the "
                    'real Supabase values (see the README). This is not a '
                    'sign-in problem -- nothing has been attempted yet.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
