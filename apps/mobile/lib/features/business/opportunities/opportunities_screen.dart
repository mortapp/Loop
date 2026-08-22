import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_error_view.dart';
import '../contacts/contacts_providers.dart';
import '../contacts/models/contact.dart';
import 'models/opportunity.dart';
import 'opportunities_providers.dart';

/// The single natural next stage — the one action rendered prominently.
/// Terminal stages (won/lost) have none; every other transition is still
/// reachable via "Other…" (matches `NEXT_STAGE` in
/// apps/web/src/app/(app)/business/opportunities/page.tsx and mirrors
/// quotes_screen.dart's identical pattern).
const _nextStage = <OpportunityStage, OpportunityStage>{
  OpportunityStage.new_: OpportunityStage.qualifying,
  OpportunityStage.qualifying: OpportunityStage.quoted,
  OpportunityStage.quoted: OpportunityStage.negotiating,
};

Color _stageColor(OpportunityStage stage) {
  switch (stage) {
    case OpportunityStage.new_:
      return AppColors.textMuted;
    case OpportunityStage.qualifying:
      return AppColors.protectAccent;
    case OpportunityStage.quoted:
      return AppColors.warning;
    case OpportunityStage.negotiating:
      return AppColors.makeAccent;
    case OpportunityStage.won:
      return AppColors.success;
    case OpportunityStage.lost:
      return AppColors.danger;
  }
}

/// MAKE / QuoteCloser: qualified interest, tracked through to won or lost.
/// Mirrors `apps/web/src/app/(app)/business/opportunities/page.tsx`.
class OpportunitiesScreen extends ConsumerWidget {
  const OpportunitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunitiesAsync = ref.watch(opportunitiesProvider);
    final contactsAsync = ref.watch(contactRefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Opportunities')),
      body: SafeArea(
        child: opportunitiesAsync.when(
          data: (opportunities) => contactsAsync.when(
            data: (contacts) => _OpportunitiesBody(
              opportunities: opportunities,
              contacts: contacts,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AsyncErrorView(error: error),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(opportunitiesProvider),
          ),
        ),
      ),
    );
  }
}

class _OpportunitiesBody extends ConsumerWidget {
  const _OpportunitiesBody({
    required this.opportunities,
    required this.contacts,
  });

  final List<Opportunity> opportunities;
  final List<ContactRef> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(opportunitiesProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'MAKE / QuoteCloser. Once qualified, an opportunity is worth '
            'writing a quote for.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (contacts.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add a contact first — opportunities need one.',
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/business/contacts'),
                      child: const Text('Contacts'),
                    ),
                  ],
                ),
              ),
            )
          else
            _CreateOpportunityForm(contacts: contacts),
          const SizedBox(height: AppSpacing.lg),
          if (opportunities.isEmpty)
            const Text('No opportunities yet.')
          else
            for (final opp in opportunities) _OpportunityTile(opportunity: opp),
        ],
      ),
    );
  }
}

class _OpportunityTile extends ConsumerWidget {
  const _OpportunityTile({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Future<void> setStage(OpportunityStage stage) async {
      try {
        await ref
            .read(opportunitiesRepositoryProvider)
            .setStage(id: opportunity.id, stage: stage);
        ref.invalidate(opportunitiesProvider);
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, 'Failed: $e');
      }
    }

    final next = _nextStage[opportunity.stage];
    final otherStages = opportunityStageOptions.where(
      (s) => s != opportunity.stage && s != next,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(opportunity.title, style: theme.textTheme.bodyLarge),
              Text(
                '${opportunity.contactDisplayName ?? "Unknown contact"} · '
                '${MoneyUtils.formatCents(opportunity.estimatedValueCents)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    label: Text(opportunityStageLabel(opportunity.stage)),
                    backgroundColor: _stageColor(
                      opportunity.stage,
                    ).withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      color: _stageColor(opportunity.stage),
                    ),
                    side: BorderSide.none,
                  ),
                  if (next != null)
                    TextButton(
                      onPressed: () => setStage(next),
                      child: Text('Mark ${opportunityStageLabel(next)}'),
                    ),
                  if (otherStages.isNotEmpty)
                    PopupMenuButton<OpportunityStage>(
                      tooltip: 'Other…',
                      onSelected: setStage,
                      itemBuilder: (context) => [
                        for (final stage in otherStages)
                          PopupMenuItem(
                            value: stage,
                            child: Text('Mark ${opportunityStageLabel(stage)}'),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          'Other…',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateOpportunityForm extends ConsumerStatefulWidget {
  const _CreateOpportunityForm({required this.contacts});

  final List<ContactRef> contacts;

  @override
  ConsumerState<_CreateOpportunityForm> createState() =>
      _CreateOpportunityFormState();
}

class _CreateOpportunityFormState
    extends ConsumerState<_CreateOpportunityForm> {
  String? _contactId;
  final _titleController = TextEditingController();
  final _valueController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final contactId = _contactId;
    final title = _titleController.text.trim();
    if (contactId == null) {
      setState(() => _error = 'Pick a contact first.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(opportunitiesRepositoryProvider)
          .createOpportunity(
            accountId: accountId,
            contactId: contactId,
            title: title,
            estimatedValueCents: MoneyUtils.dollarsStringToCents(
              _valueController.text,
            ),
          );
      _titleController.clear();
      _valueController.clear();
      setState(() => _contactId = null);
      ref.invalidate(opportunitiesProvider);
    } catch (e) {
      setState(() => _error = 'Failed to add opportunity: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _contactId,
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final contact in widget.contacts)
                  DropdownMenuItem(
                    value: contact.id,
                    child: Text(contact.displayName),
                  ),
              ],
              onChanged: (value) => setState(() => _contactId = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: r'Est. value ($, optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add opportunity'),
                ),
                if (_error != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
