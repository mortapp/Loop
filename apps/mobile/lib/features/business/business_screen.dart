import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account/account_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../core/utils/user_safe_error.dart';
import '../../core/widgets/account_sheet.dart';
import '../../core/widgets/ledger_surface.dart';
import 'business_repository.dart';
import 'contacts/contacts_providers.dart';
import 'opportunities/models/opportunity.dart';
import 'opportunities/opportunities_providers.dart';
import 'quotes/models/quote.dart';
import 'quotes/quotes_providers.dart';

/// Presents the existing business engine as People, Work, and Quotes.
/// Account switching stays in the shared account sheet; repositories and
/// server-side lifecycle rules remain unchanged.
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
    final active = ref.watch(activeAccountProvider);
    final contacts = ref.watch(contactsProvider);
    final opportunities = ref.watch(opportunitiesProvider);
    final quotes = ref.watch(quotesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business'),
        actions: [
          IconButton(
            key: const Key('create-business-action'),
            tooltip: 'Create a business',
            onPressed: _creatingBusiness ? null : _createBusiness,
            icon: _creatingBusiness
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_business_outlined),
          ),
          const AccountAvatarButton(),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            ref.refresh(contactsProvider.future),
            ref.refresh(opportunitiesProvider.future),
            ref.refresh(quotesProvider.future),
          ]),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              LedgerPageIntro(
                title: 'Business',
                subtitle: 'People, work, and quotes for ${active.displayName}.',
              ),
              const SizedBox(height: AppSpacing.lg),
              LedgerHero(
                eyebrow: 'Next',
                value: Text(
                  'Turn work into a clear quote.',
                  style: theme.textTheme.headlineMedium,
                ),
                detail:
                    'LOOP calculates the total and keeps its status honest.',
                action: FilledButton.icon(
                  key: const Key('business-create-quote-action'),
                  onPressed: () => context.push('/business/quotes'),
                  icon: const Icon(Icons.add),
                  label: const Text('Create quote'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              LedgerSectionLabel(
                'People',
                trailing: TextButton(
                  onPressed: () => context.push('/business/contacts'),
                  child: const Text('See all'),
                ),
              ),
              contacts.when(
                data: (items) => items.isEmpty
                    ? LedgerRow(
                        title: 'No people yet',
                        subtitle: 'Add a customer before creating a quote.',
                        onTap: () => context.push('/business/contacts'),
                      )
                    : Column(
                        children: [
                          for (final contact in items.take(3))
                            LedgerRow(
                              title: contact.displayName,
                              subtitle: contact.company,
                              onTap: () => context.push('/business/contacts'),
                            ),
                        ],
                      ),
                loading: () => const _SummaryLoading(),
                error: (_, _) => const _SummaryError(label: 'people'),
              ),
              const SizedBox(height: AppSpacing.lg),
              LedgerSectionLabel(
                'Work',
                trailing: TextButton(
                  onPressed: () => context.push('/business/opportunities'),
                  child: const Text('See all'),
                ),
              ),
              opportunities.when(
                data: (items) {
                  final activeWork = items.where(
                    (item) =>
                        item.stage != OpportunityStage.won &&
                        item.stage != OpportunityStage.lost,
                  );
                  if (activeWork.isEmpty) {
                    return LedgerRow(
                      title: 'No active work',
                      subtitle: 'Start with a person or create an opportunity.',
                      onTap: () => context.push('/business/opportunities'),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in activeWork.take(3))
                        LedgerRow(
                          title: item.title,
                          subtitle: [
                            item.contactDisplayName,
                            opportunityStageLabel(item.stage),
                          ].whereType<String>().join(' - '),
                          trailing: item.estimatedValueCents == null
                              ? null
                              : Text(
                                  MoneyUtils.formatCents(
                                    item.estimatedValueCents,
                                  ),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.opportunityText(
                                      theme.brightness,
                                    ),
                                  ),
                                ),
                          onTap: () => context.push('/business/opportunities'),
                        ),
                    ],
                  );
                },
                loading: () => const _SummaryLoading(),
                error: (_, _) => const _SummaryError(label: 'work'),
              ),
              const SizedBox(height: AppSpacing.lg),
              LedgerSectionLabel(
                'Quotes',
                trailing: TextButton(
                  onPressed: () => context.push('/business/quotes'),
                  child: const Text('See all'),
                ),
              ),
              quotes.when(
                data: (items) => items.isEmpty
                    ? LedgerRow(
                        title: 'No quotes yet',
                        subtitle: 'Create one when the work is clear.',
                        onTap: () => context.push('/business/quotes'),
                      )
                    : Column(
                        children: [
                          for (final quote in items.take(3))
                            LedgerRow(
                              title:
                                  quote.contactDisplayName ?? quote.quoteNumber,
                              subtitle:
                                  '${quote.quoteNumber} - ${_quoteStatusLabel(quote.status)}',
                              trailing: Text(
                                MoneyUtils.formatCents(quote.totalCents),
                                style: theme.textTheme.titleMedium,
                              ),
                              onTap: () => context.push('/business/quotes'),
                            ),
                        ],
                      ),
                loading: () => const _SummaryLoading(),
                error: (_, _) => const _SummaryError(label: 'quotes'),
              ),
              const SizedBox(height: AppSpacing.lg),
              LedgerRow(
                title: 'Leads',
                subtitle: 'Early interest that is not active work yet.',
                leading: const Icon(Icons.inbox_outlined, size: 20),
                onTap: () => context.push('/business/leads'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _quoteStatusLabel(QuoteStatus status) {
  final value = status.name;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: LinearProgressIndicator(minHeight: 2),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        'Could not load $label.',
        style: Theme.of(context).textTheme.bodyMedium,
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
