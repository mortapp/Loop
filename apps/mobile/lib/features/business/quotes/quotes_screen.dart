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

typedef QuoteLinePreparation = ({
  String? error,
  List<PreparedLine> lines,
  int? totalCents,
});

/// Validates and converts editable quote rows without coercing missing or
/// malformed values to zero. An untouched extra row is ignored, while a
/// populated row must be complete. An explicitly entered zero remains a
/// valid unit price.
QuoteLinePreparation prepareQuoteLines(List<QuoteLineDraft> drafts) {
  QuoteLinePreparation invalid(String message) =>
      (error: message, lines: const <PreparedLine>[], totalCents: null);

  final prepared = <PreparedLine>[];
  var totalCents = 0;

  for (var index = 0; index < drafts.length; index++) {
    final draft = drafts[index];
    final description = draft.description.trim();
    final quantityText = draft.quantity.trim();
    final unitPriceText = draft.unitPrice.trim();
    final lineNumber = index + 1;
    final isUntouched =
        description.isEmpty &&
        unitPriceText.isEmpty &&
        (quantityText.isEmpty || quantityText == '1');

    if (isUntouched) continue;
    if (description.isEmpty) {
      return invalid('Line $lineNumber: add a description.');
    }

    final quantity = double.tryParse(quantityText);
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      return invalid(
        'Line $lineNumber: enter a valid quantity greater than zero.',
      );
    }

    if (unitPriceText.isEmpty) {
      return invalid(
        'Line $lineNumber: enter a unit price. Use 0 for a free line item.',
      );
    }

    final unitPrice = double.tryParse(unitPriceText);
    final scaledUnitPrice = unitPrice == null ? null : unitPrice * 100;
    if (unitPrice == null ||
        !unitPrice.isFinite ||
        unitPrice < 0 ||
        scaledUnitPrice == null ||
        !scaledUnitPrice.isFinite) {
      return invalid(
        'Line $lineNumber: enter a valid non-negative unit price. '
        'Use 0 for a free line item.',
      );
    }

    final unitPriceCents = scaledUnitPrice.round();
    final unroundedLineTotal = quantity * unitPriceCents;
    if (!unroundedLineTotal.isFinite) {
      return invalid('Line $lineNumber: the line total is too large.');
    }

    prepared.add(
      PreparedLine(
        description: description,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
      ),
    );
    totalCents += unroundedLineTotal.round();
  }

  if (prepared.isEmpty) {
    return invalid('Add at least one complete line item.');
  }

  return (
    error: null,
    lines: List<PreparedLine>.unmodifiable(prepared),
    totalCents: totalCents,
  );
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
      } catch (_) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Could not update the quote. Try again.');
        }
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

  int? get _totalCents => prepareQuoteLines(_lines).totalCents;

  Future<void> _submit() async {
    final contactId = _contactId;
    if (contactId == null) {
      setState(() => _error = 'Pick a contact first.');
      return;
    }

    final preparation = prepareQuoteLines(_lines);
    if (preparation.error != null) {
      setState(() => _error = preparation.error);
      return;
    }
    final prepared = preparation.lines;

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
      if (!mounted) return;
      setState(() {
        _contactId = null;
        _opportunityId = null;
        _lines
          ..clear()
          ..add(QuoteLineDraft());
      });
      ref.invalidate(quotesProvider);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not create the quote. Check the details and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCents = _totalCents;

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
                  'Total: ${totalCents == null ? '—' : MoneyUtils.formatCents(totalCents)}',
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
              tooltip: 'Remove quote line',
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onRemove,
            ),
        ],
      ),
    );
  }
}
