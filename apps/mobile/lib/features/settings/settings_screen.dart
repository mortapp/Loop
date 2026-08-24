import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/ledger_surface.dart';

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

const _links = <_SettingsLink>[
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
  _SettingsLink(
    label: 'Appearance',
    description: 'Use the system, dark, or light theme.',
    route: '/settings/personalization',
  ),
  _SettingsLink(
    label: 'Help',
    description: 'Learn how LOOP works.',
    route: '/help',
  ),
];

/// A real settings hub — only sections with real content behind them
/// (no dead Notifications/Data-Privacy placeholders). Mirrors
/// apps/web/src/app/(app)/settings.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const LedgerPageIntro(
              title: 'Account',
              subtitle: 'Your identity and LOOP preferences.',
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final link in _links)
              LedgerRow(
                title: link.label,
                subtitle: link.description,
                onTap: () {
                  if (link.route == '/business') {
                    context.go(link.route);
                  } else {
                    context.push(link.route);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
