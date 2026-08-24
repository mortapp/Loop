import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account/account_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../core/utils/request_id.dart';
import '../../core/widgets/account_sheet.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/ledger_surface.dart';
import 'models/money_event.dart';
import 'models/money_totals.dart';
import 'money_providers.dart';

const _kinds = [
  MoneyEventKind.earn,
  MoneyEventKind.recovered,
  MoneyEventKind.refund,
  MoneyEventKind.spend,
  MoneyEventKind.fee,
];

Color _kindColor(BuildContext context, MoneyEventKind kind) {
  switch (kind) {
    case MoneyEventKind.earn:
    case MoneyEventKind.recovered:
      return AppColors.success;
    case MoneyEventKind.refund:
      return AppColors.protectAccent;
    case MoneyEventKind.spend:
    case MoneyEventKind.fee:
      return AppColors.dangerText;
  }
}

/// The Money tab: a unified view of value moving through LOOP — the
/// append-only `public.money_events` ledger every engine writes to.
///
/// Mirrors `apps/web/src/app/(app)/money/page.tsx`: totals by kind, net,
/// a manual log-entry form, and the full event list. Purchases & returns
/// (PROTECT) live one level down at `/money/purchases`.
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  void _showAddEntry(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add entry',
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _LogEventForm(onSaved: () => Navigator.of(sheetContext).pop()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(moneyEventsProvider);
    final totalsAsync = ref.watch(moneyTotalsProvider);
    final activeAccountId = ref.watch(activeAccountProvider).id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        actions: const [AccountAvatarButton()],
      ),
      body: SafeArea(
        child: eventsAsync.when(
          data: (history) {
            if (history.accountId != activeAccountId) {
              return const Center(child: CircularProgressIndicator());
            }
            return totalsAsync.when(
              data: (totals) => _MoneyBody(
                history: history,
                totals: totals,
                onAdd: () => _showAddEntry(context),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AsyncErrorView(
                error: error,
                onRetry: () => ref.invalidate(moneyTotalsProvider),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(moneyEventsProvider),
          ),
        ),
      ),
    );
  }
}

class _MoneyBody extends ConsumerWidget {
  const _MoneyBody({
    required this.history,
    required this.totals,
    required this.onAdd,
  });

  final MoneyEventsPageState history;
  final MoneyTotals totals;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final net = totals.netCents;
    final events = history.events;

    // One dominant Net figure, not six equally-weighted boxes — Net is
    // what answers "how am I doing," everything else is supporting
    // detail (matches the same hierarchy fix on apps/web's Money page).
    // Totals come from the one canonical formula (public.account_money_
    // totals) rather than being reduced from `events` here — see
    // money_providers.dart's moneyTotalsProvider.
    return RefreshIndicator(
      onRefresh: () => Future.wait([
        ref.refresh(moneyEventsProvider.future),
        ref.refresh(moneyTotalsProvider.future),
      ]),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const LedgerPageIntro(
            title: 'Money',
            subtitle: 'Everything you made, protected, and recovered.',
          ),
          const SizedBox(height: AppSpacing.lg),
          LedgerHero(
            eyebrow: 'Current value',
            value: Text(
              MoneyUtils.formatCents(net),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 44,
                color: net >= 0 ? AppColors.success : AppColors.dangerText,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            action: FilledButton.icon(
              key: const Key('money-add-entry-action'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add entry'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _KindTotal(
                  label: 'Made',
                  value: MoneyUtils.formatCents(totals.madeCents),
                ),
              ),
              Expanded(
                child: _KindTotal(
                  label: 'Protected',
                  value: MoneyUtils.formatCents(totals.protectedCents),
                ),
              ),
              Expanded(
                child: _KindTotal(
                  label: 'Recovered',
                  value: MoneyUtils.formatCents(totals.recoveredCents),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          LedgerRow(
            key: const Key('money-protect-row'),
            title: 'Purchases, returns & warranties',
            subtitle: 'Keep what you bought protected.',
            leading: const Icon(Icons.shield_outlined, size: 20),
            onTap: () => context.push('/money/purchases'),
          ),
          const SizedBox(height: AppSpacing.lg),
          const LedgerSectionLabel('Ledger'),
          const SizedBox(height: AppSpacing.xs),
          if (events.isEmpty)
            const LedgerEmptyState(
              title: 'No entries yet.',
              detail: 'Your value history will appear here.',
            )
          else ...[
            ...events.map((event) => _MoneyEventTile(event: event)),
            const SizedBox(height: AppSpacing.sm),
            _MoneyHistoryFooter(history: history),
          ],
        ],
      ),
    );
  }
}

class _MoneyHistoryFooter extends ConsumerWidget {
  const _MoneyHistoryFooter({required this.history});

  final MoneyEventsPageState history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (history.isLoadingMore) {
      return Semantics(
        liveRegion: true,
        label: 'Loading more money history',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppSpacing.sm),
              Text('Loading more history…'),
            ],
          ),
        ),
      );
    }

    if (history.loadMoreError != null) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              Text(
                'Could not load more history. Check your connection and '
                'try again.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () =>
                    ref.read(moneyEventsProvider.notifier).loadMore(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (history.hasMore) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: () => ref.read(moneyEventsProvider.notifier).loadMore(),
          icon: const Icon(Icons.expand_more),
          label: const Text('Load more'),
        ),
      );
    }

    return Text(
      'All history loaded.',
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }
}

class _KindTotal extends StatelessWidget {
  const _KindTotal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 10,
            letterSpacing: 0.8,
            color: AppColors.textStructural,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MoneyEventTile extends StatelessWidget {
  const _MoneyEventTile({required this.event});

  final MoneyEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sign = moneyEventKindSign(event.kind);
    final color = _kindColor(context, event.kind);

    // A ledger row, not a card — see docs/DESIGN_SYSTEM.md; matches
    // Today's transaction-row treatment.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.platinum.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description?.isNotEmpty == true
                      ? event.description!
                      : event.kind.name,
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  '${event.occurredAt.toLocal()} · ${event.sourceType ?? "manual"}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            '${sign > 0 ? '+' : '-'}${MoneyUtils.formatCents(event.amountCents)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogEventForm extends ConsumerStatefulWidget {
  const _LogEventForm({this.onSaved});

  final VoidCallback? onSaved;

  @override
  ConsumerState<_LogEventForm> createState() => _LogEventFormState();
}

class _LogEventFormState extends ConsumerState<_LogEventForm> {
  MoneyEventKind _kind = MoneyEventKind.earn;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _requestId = newRequestId();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountCents = MoneyUtils.dollarsStringToCents(_amountController.text);
    if (amountCents == null || amountCents <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(moneyEventsRepositoryProvider)
          .logManualEvent(
            accountId: accountId,
            kind: _kind,
            amountCents: amountCents,
            requestId: _requestId,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );
      if (!mounted) return;
      _amountController.clear();
      _descriptionController.clear();
      _requestId = newRequestId();
      ref.invalidate(moneyEventsProvider);
      ref.invalidate(moneyTotalsProvider);
      widget.onSaved?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _error = userSafeActionError('log this entry'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<MoneyEventKind>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Kind',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _kinds
                    .map((k) => DropdownMenuItem(value: k, child: Text(k.name)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: r'Amount ($)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
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
                  : const Text('Log entry'),
            ),
            if (_error != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
