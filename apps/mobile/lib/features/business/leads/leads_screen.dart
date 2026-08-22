import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_error_view.dart';
import '../contacts/contacts_providers.dart';
import '../contacts/models/contact.dart';
import 'leads_providers.dart';
import 'models/lead.dart';

/// The single natural next status — mirrors quotes_screen.dart's and
/// opportunities_screen.dart's identical "one primary action + Other…"
/// pattern (matches `NEXT_STATUS` in
/// apps/web/src/app/(app)/business/leads/page.tsx).
const _nextStatus = <LeadStatus, LeadStatus>{
  LeadStatus.new_: LeadStatus.contacted,
  LeadStatus.contacted: LeadStatus.qualified,
};

Color _statusColor(LeadStatus status) {
  switch (status) {
    case LeadStatus.new_:
      return AppColors.textMuted;
    case LeadStatus.contacted:
      return AppColors.protectAccent;
    case LeadStatus.qualified:
      return AppColors.warning;
    case LeadStatus.disqualified:
      return AppColors.danger;
    case LeadStatus.converted:
      return AppColors.success;
  }
}

/// MAKE / QuoteCloser: track interest before it becomes an opportunity
/// worth quoting. Mirrors
/// `apps/web/src/app/(app)/business/leads/page.tsx`.
class LeadsScreen extends ConsumerWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadsAsync = ref.watch(leadsProvider);
    final contactsAsync = ref.watch(contactRefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leads')),
      body: SafeArea(
        child: leadsAsync.when(
          data: (leads) => contactsAsync.when(
            data: (contacts) => _LeadsBody(leads: leads, contacts: contacts),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AsyncErrorView(error: error),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(leadsProvider),
          ),
        ),
      ),
    );
  }
}

class _LeadsBody extends ConsumerWidget {
  const _LeadsBody({required this.leads, required this.contacts});

  final List<Lead> leads;
  final List<ContactRef> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(leadsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'MAKE / QuoteCloser. Track interest before it becomes an '
            'opportunity worth quoting.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (contacts.isEmpty)
            _NoContactsCard(
              onAddContact: () => context.push('/business/contacts'),
            )
          else
            _CreateLeadForm(contacts: contacts),
          const SizedBox(height: AppSpacing.lg),
          if (leads.isEmpty)
            const Text('No leads yet.')
          else
            for (final lead in leads) _LeadTile(lead: lead),
        ],
      ),
    );
  }
}

class _NoContactsCard extends StatelessWidget {
  const _NoContactsCard({required this.onAddContact});

  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Expanded(
              child: Text('Add a contact first — leads need one.'),
            ),
            TextButton(onPressed: onAddContact, child: const Text('Contacts')),
          ],
        ),
      ),
    );
  }
}

class _LeadTile extends ConsumerWidget {
  const _LeadTile({required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = [
      lead.source,
      lead.notes,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    Future<void> setStatus(LeadStatus status) async {
      try {
        await ref
            .read(leadsRepositoryProvider)
            .setStatus(id: lead.id, status: status);
        ref.invalidate(leadsProvider);
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, 'Failed: $e');
      }
    }

    final next = _nextStatus[lead.status];
    final otherStatuses = leadStatusOptions.where(
      (s) => s != lead.status && s != next,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead.contactDisplayName ?? 'Unknown contact',
                style: theme.textTheme.bodyLarge,
              ),
              Text(
                details.isEmpty ? 'No details' : details,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    label: Text(leadStatusLabel(lead.status)),
                    backgroundColor: _statusColor(
                      lead.status,
                    ).withValues(alpha: 0.12),
                    labelStyle: TextStyle(color: _statusColor(lead.status)),
                    side: BorderSide.none,
                  ),
                  if (next != null)
                    TextButton(
                      onPressed: () => setStatus(next),
                      child: Text('Mark ${leadStatusLabel(next)}'),
                    ),
                  if (otherStatuses.isNotEmpty)
                    PopupMenuButton<LeadStatus>(
                      tooltip: 'Other…',
                      onSelected: setStatus,
                      itemBuilder: (context) => [
                        for (final status in otherStatuses)
                          PopupMenuItem(
                            value: status,
                            child: Text('Mark ${leadStatusLabel(status)}'),
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

class _CreateLeadForm extends ConsumerStatefulWidget {
  const _CreateLeadForm({required this.contacts});

  final List<ContactRef> contacts;

  @override
  ConsumerState<_CreateLeadForm> createState() => _CreateLeadFormState();
}

class _CreateLeadFormState extends ConsumerState<_CreateLeadForm> {
  String? _contactId;
  final _sourceController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final contactId = _contactId;
    if (contactId == null) {
      setState(() => _error = 'Pick a contact first.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(leadsRepositoryProvider)
          .createLead(
            accountId: accountId,
            contactId: contactId,
            source: _sourceController.text.trim().isEmpty
                ? null
                : _sourceController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      _sourceController.clear();
      _notesController.clear();
      setState(() => _contactId = null);
      ref.invalidate(leadsProvider);
    } catch (e) {
      setState(() => _error = 'Failed to add lead: $e');
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
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: 'Source (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
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
                      : const Text('Add lead'),
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
