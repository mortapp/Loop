import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account/account_context.dart';
import '../../core/account/account_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/user_safe_error.dart';
import '../../core/widgets/account_sheet.dart';
import 'business_repository.dart';

/// The Business tab: account/business switching and membership management.
///
/// Every user has a personal account and may belong to one or more
/// business accounts. This screen lets them see and switch the account
/// they're currently acting as, which scopes everything else in the app
/// (businesses, contacts, items, documents, actions across MAKE, PROTECT,
/// and RECOVER).
class BusinessScreen extends ConsumerStatefulWidget {
  const BusinessScreen({super.key});

  @override
  ConsumerState<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends ConsumerState<BusinessScreen> {
  bool _creatingBusiness = false;

  Future<void> _createBusiness() async {
    if (_creatingBusiness) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateBusinessDialog(),
    );
    if (name == null || !mounted) return;

    setState(() => _creatingBusiness = true);
    try {
      final accountId = await ref.read(businessCreatorProvider)(name);
      ref.invalidate(availableAccountsProvider);
      final accounts = await ref.read(availableAccountsProvider.future);
      if (!mounted) return;
      for (final account in accounts) {
        if (account.id == accountId) {
          ref.read(activeAccountProvider.notifier).select(account);
          break;
        }
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name is ready.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userSafeActionError('create this business'))),
        );
      }
    } finally {
      if (mounted) setState(() => _creatingBusiness = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(availableAccountsProvider);
    final active = ref.watch(activeAccountProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business'),
        actions: const [AccountAvatarButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Acting as', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            accounts.when(
              data: (list) => Column(
                children: list
                    .map(
                      (account) => _AccountTile(
                        account: account,
                        selected: account.id == active.id,
                        onTap: () => ref
                            .read(activeAccountProvider.notifier)
                            .select(account),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(
                'Could not load accounts.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: InkWell(
                key: const Key('create-business-action'),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                onTap: _creatingBusiness ? null : _createBusiness,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      if (_creatingBusiness)
                        const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.add_business_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Create a business',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
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

class _CreateBusinessDialog extends StatefulWidget {
  const _CreateBusinessDialog();

  @override
  State<_CreateBusinessDialog> createState() => _CreateBusinessDialogState();
}

class _CreateBusinessDialogState extends State<_CreateBusinessDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_nameController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a business'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('business-name-field'),
          controller: _nameController,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Business name'),
          validator: (value) {
            final normalized = value?.trim() ?? '';
            if (normalized.isEmpty) return 'Business name is required.';
            if (normalized.length > 100) return 'Use 100 characters or fewer.';
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('create-business-submit'),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
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
