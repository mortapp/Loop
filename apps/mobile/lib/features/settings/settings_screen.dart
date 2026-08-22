import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class _SettingsLink {
  const _SettingsLink({
    required this.label,
    required this.description,
    required this.route,
  });

  final String label;
  final String description;
  final String route;
}

const _sections = <(String, List<_SettingsLink>)>[
  (
    'ACCOUNT',
    [
      _SettingsLink(
        label: 'Profile',
        description: 'Name, email, and account memberships.',
        route: '/profile',
      ),
      _SettingsLink(
        label: 'Accounts & businesses',
        description: 'Switch account, or start a business.',
        route: '/business',
      ),
    ],
  ),
  (
    'APPEARANCE',
    [
      _SettingsLink(
        label: 'Personalization',
        description: 'Theme — system, dark, or light.',
        route: '/settings/personalization',
      ),
    ],
  ),
  (
    'ABOUT',
    [
      _SettingsLink(
        label: 'Help & Support',
        description: 'How to use LOOP.',
        route: '/help',
      ),
    ],
  ),
];

/// A real settings hub — only sections with real content behind them
/// (no dead Notifications/Data-Privacy placeholders). Mirrors
/// apps/web/src/app/(app)/settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            for (final (title, links) in _sections) ...[
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.textStructural,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final link in links)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Card(
                    child: ListTile(
                      title: Text(link.label, style: theme.textTheme.bodyLarge),
                      subtitle: Text(link.description),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (link.route == '/business') {
                          context.go(link.route);
                        } else {
                          context.push(link.route);
                        }
                      },
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
