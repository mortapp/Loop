import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_preference.dart';

const _options = <(ThemePreference, String, String)>[
  (ThemePreference.system, 'System', "Follows your device's setting."),
  (ThemePreference.dark, 'Dark', 'Murex Noir, always.'),
  (ThemePreference.light, 'Light', 'Royal Bone, always.'),
];

/// Real System/Dark/Light theme control — mirrors
/// apps/web/src/app/(app)/settings/personalization.
class PersonalizationScreen extends ConsumerWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themePreferenceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Personalization')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              'THEME',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textStructural,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (value, label, description) in _options)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => setThemePreference(ref, value),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: value == current
                            ? AppColors.tyrianAccent
                            : AppColors.platinum.withValues(alpha: 0.16),
                      ),
                      color: AppColors.murexInk,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: theme.textTheme.bodyLarge),
                              Text(
                                description,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (value == current)
                          const Icon(
                            Icons.check,
                            color: AppColors.tyrianText,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
