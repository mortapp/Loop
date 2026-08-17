import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
            const SizedBox(height: AppSpacing.xl),
            Text('MAKE / QuoteCloser', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.6,
              children: [
                _NavCard(
                  title: 'Contacts',
                  description:
                      'Customers, vendors, and anyone else you deal with.',
                  icon: Icons.contacts_outlined,
                  onTap: () => context.push('/business/contacts'),
                ),
                _NavCard(
                  title: 'Leads',
                  description: 'Track interest before it\'s worth quoting.',
                  icon: Icons.leaderboard_outlined,
                  onTap: () => context.push('/business/leads'),
                ),
                _NavCard(
                  title: 'Opportunities',
                  description: 'Qualified interest, tracked to won or lost.',
                  icon: Icons.trending_up,
                  onTap: () => context.push('/business/opportunities'),
                ),
                _NavCard(
                  title: 'Quotes',
                  description: 'Line items, totals, and status — the close.',
                  icon: Icons.request_quote_outlined,
                  onTap: () => context.push('/business/quotes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
