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
import '../opportunities/opportunities_providers.dart';
import 'models/quote.dart';
import 'quotes_providers.dart';

/// The single natural next step for a quote in this status — this is the
/// one action rendered prominently. Terminal statuses (accepted/declined/
/// expired) have none; every other transition is still reachable via
/// "Other…", just not shown with equal visual weight (matches
/// `NEXT_STATUS` in apps/web/src/app/(app)/business/quotes/page.tsx).
const _nextStatus = <QuoteStatus, (QuoteStatus, String)>{
  QuoteStatus.draft: (QuoteStatus.sent, 'Mark sent'),
  QuoteStatus.sent: (QuoteStatus.viewed, 'Mark viewed'),
  QuoteStatus.viewed: (QuoteStatus.accepted, 'Mark accepted'),
};

Color _statusColor(QuoteStatus status) {
  switch (status) {
    case QuoteStatus.draft:
      return AppColors.textMuted;
    case QuoteStatus.sent:
      return AppColors.protectAccent;
    case QuoteStatus.viewed:
      return AppColors.makeAccent;
    case QuoteStatus.accepted:
      return AppColors.success;
    case QuoteStatus.declined:
      return AppColors.danger;
    case QuoteStatus.expired:
      return AppColors.warning;
  }
}

/// MAKE / QuoteCloser: line items, totals, and status — the close.
/// Mirrors `apps/web/src/app/(app)/business/quotes/page.tsx`.
class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotesAsync = ref.watch(quotesProvider);
    final contactsAsync = ref.watch(contactRefsProvider);
    final opportunitiesAsync = ref.watch(opportunityRefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quotes')),
      body: SafeArea(
        child: quotesAsync.when(
          data: (quotes) => contactsAsync.when(
            data: (contacts) => opportunitiesAsync.when(
              data: (opportunities) => _QuotesBody(
                quotes: quotes,
                contacts: contacts,
                opportunities: opportunities,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AsyncErrorView(error: error),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AsyncErrorView(error: error),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(quotesProvider),
          ),
        ),
      ),
    );
  }
}

class _QuotesBody extends ConsumerWidget {
  const _QuotesBody({
    required this.quotes,
    required this.contacts,
    required this.opportunities,
  });

  final List<Quote> quotes;
  final List<ContactRef> contacts;
  final List<OpportunityRef> opportunities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(quotesProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'MAKE / QuoteCloser. An accepted quote is expected to produce '
            'a money_events row once that wiring exists.',
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
                      child: Text('Add a contact first — quotes need one.'),
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
            _CreateQuoteForm(contacts: contacts, opportunities: opportunities),
          const SizedBox(height: AppSpacing.lg),
          if (quotes.isEmpty)
            const Text('No quotes yet.')
          else
            for (final quote in quotes) _QuoteTile(quote: quote),
        ],
      ),
    );
  }
}

class _QuoteTile extends ConsumerWidget {
  const _QuoteTile({required this.quote});

  final Quote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Future<void> setStatus(QuoteStatus status) async {
      try {
        await ref
            .read(quotesRepositoryProvider)
            .setStatus(id: quote.id, status: status);
        ref.invalidate(quotesProvider);
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, 'Failed: $e');
      }
    }

    final next = _nextStatus[quote.status];
    final otherStatuses = quoteStatusOptions.where(
      (s) => s != quote.status && s != next?.$1,
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
                '${quote.quoteNumber} · '
                '${MoneyUtils.formatCents(quote.totalCents, currencySymbol: r'$')}',
                style: theme.textTheme.bodyLarge,
              ),
              Text(
                quote.contactDisplayName ?? 'Unknown contact',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Chip(
                    label: Text(quote.status.name),
                    backgroundColor: _statusColor(
                      quote.status,
                    ).withValues(alpha: 0.12),
                    labelStyle: TextStyle(color: _statusColor(quote.status)),
                    side: BorderSide.none,
                  ),
                  if (next != null)
                    TextButton(
                      onPressed: () => setStatus(next.$1),
                      child: Text(next.$2),
                    ),
                  if (otherStatuses.isNotEmpty)
                    PopupMenuButton<QuoteStatus>(
                      tooltip: 'Other…',
                      onSelected: setStatus,
                      itemBuilder: (context) => [
                        for (final status in otherStatuses)
                          PopupMenuItem(
                            value: status,
                            child: Text('Mark ${status.name}'),
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

class _CreateQuoteForm extends ConsumerStatefulWidget {
  const _CreateQuoteForm({required this.contacts, required this.opportunities});

  final List<ContactRef> contacts;
  final List<OpportunityRef> opportunities;

  @override
  ConsumerState<_CreateQuoteForm> createState() => _CreateQuoteFormState();
}

class _CreateQuoteFormState extends ConsumerState<_CreateQuoteForm> {
  String? _contactId;
  String? _opportunityId;
  final List<QuoteLineDraft> _lines = [QuoteLineDraft()];
  bool _submitting = false;
  String? _error;

  double get _total {
    var total = 0.0;
    for (final line in _lines) {
      final qty = double.tryParse(line.quantity) ?? 0;
      final price = double.tryParse(line.unitPrice) ?? 0;
      total += qty * price;
    }
    return total;
  }

  Future<void> _submit() async {
    final contactId = _contactId;
    if (contactId == null) {
      setState(() => _error = 'Pick a contact first.');
      return;
    }

    final prepared = <PreparedLine>[];
    for (final line in _lines) {
      final description = line.description.trim();
      final quantity = double.tryParse(line.quantity) ?? 0;
      final unitPriceCents =
          MoneyUtils.dollarsStringToCents(line.unitPrice) ?? 0;
      if (description.isNotEmpty && quantity > 0) {
        prepared.add(
          PreparedLine(
            description: description,
            quantity: quantity,
            unitPriceCents: unitPriceCents,
          ),
        );
      }
    }

    if (prepared.isEmpty) {
      setState(
        () => _error =
            'Add at least one line item with a description and quantity.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(quotesRepositoryProvider)
          .createQuote(
            accountId: accountId,
            contactId: contactId,
            opportunityId: _opportunityId,
            lines: prepared,
          );
      setState(() {
        _contactId = null;
        _opportunityId = null;
        _lines
          ..clear()
          ..add(QuoteLineDraft());
      });
      ref.invalidate(quotesProvider);
    } catch (e) {
      setState(() => _error = 'Failed to create quote: $e');
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
            DropdownButtonFormField<String?>(
              initialValue: _opportunityId,
              decoration: const InputDecoration(
                labelText: 'Linked opportunity (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No linked opportunity'),
                ),
                for (final opp in widget.opportunities)
                  DropdownMenuItem<String?>(
                    value: opp.id,
                    child: Text(opp.title),
                  ),
              ],
              onChanged: (value) => setState(() => _opportunityId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Line items', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < _lines.length; i++)
              _LineItemRow(
                key: ObjectKey(_lines[i]),
                line: _lines[i],
                onChanged: () => setState(() {}),
                onRemove: _lines.length > 1
                    ? () => setState(() => _lines.removeAt(i))
                    : null,
              ),
            TextButton(
              onPressed: () => setState(() => _lines.add(QuoteLineDraft())),
              child: const Text('+ Add line'),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${MoneyUtils.formatCents((_total * 100).round())}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create quote'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineItemRow extends StatefulWidget {
  const _LineItemRow({
    super.key,
    required this.line,
    required this.onChanged,
    this.onRemove,
  });

  final QuoteLineDraft line;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final _descriptionController = TextEditingController(
    text: widget.line.description,
  );
  late final _quantityController = TextEditingController(
    text: widget.line.quantity,
  );
  late final _unitPriceController = TextEditingController(
    text: widget.line.unitPrice,
  );

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Description',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                widget.line.description = v;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Qty',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                widget.line.quantity = v;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: _unitPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: r'$/unit',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                widget.line.unitPrice = v;
                widget.onChanged();
              },
            ),
          ),
          if (widget.onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
        ],
      ),
    );
  }
}
