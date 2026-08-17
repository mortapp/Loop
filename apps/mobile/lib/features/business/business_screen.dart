import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/account_context.dart';
import '../../core/account/account_providers.dart';
import '../../core/theme/app_spacing.dart';

/// The Business tab: account/business switching and membership management.
///
/// Every user has a personal account and may belong to one or more
/// business accounts. This screen lets them see and switch the account
/// they're currently acting as, which scopes everything else in the app
/// (businesses, contacts, items, documents, actions across MAKE, PROTECT,
/// and RECOVER).
class BusinessScreen extends ConsumerWidget {
  const BusinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(availableAccountsProvider);
    final active = ref.watch(activeAccountProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Acting as', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            ...accounts.map(
              (account) => _AccountTile(
                account: account,
                selected: account.id == active.id,
                onTap: () =>
                    ref.read(activeAccountProvider.notifier).select(account),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_business_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Add or join a business',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Business accounts share your identity but keep their own '
              'businesses, contacts, items, documents, and actions — '
              'separate books, one login.',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final AccountSummary account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(
                    account.isPersonal
                        ? Icons.person_outline
                        : Icons.business_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        account.role ??
                            (account.isPersonal
                                ? 'Personal account'
                                : 'Business'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
