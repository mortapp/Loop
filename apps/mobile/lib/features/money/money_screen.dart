import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/account/account_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/async_error_view.dart';
import 'models/money_event.dart';
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
      return AppColors.danger;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(moneyEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        actions: [
          IconButton(
            tooltip: 'Purchases & returns',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/money/purchases'),
          ),
        ],
      ),
      body: SafeArea(
        child: eventsAsync.when(
          data: (events) => _MoneyBody(events: events),
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
  const _MoneyBody({required this.events});

  final List<MoneyEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final totals = <MoneyEventKind, int>{};
    var net = 0;
    for (final event in events) {
      totals[event.kind] = (totals[event.kind] ?? 0) + event.amountCents;
      net += moneyEventKindSign(event.kind) * event.amountCents;
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(moneyEventsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatCard(
                label: 'Net',
                value: MoneyUtils.formatCents(net),
                color: net >= 0 ? AppColors.success : AppColors.danger,
              ),
              for (final kind in _kinds)
                _StatCard(
                  label: kind.name,
                  value: MoneyUtils.formatCents(totals[kind] ?? 0),
                  color: _kindColor(context, kind),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Log a manual entry', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _LogEventForm(),
          const SizedBox(height: AppSpacing.lg),
          if (events.isEmpty)
            const Text('No money events yet.')
          else
            ...events.map((event) => _MoneyEventTile(event: event)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
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
                style: theme.textTheme.titleMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogEventForm extends ConsumerStatefulWidget {
  const _LogEventForm();

  @override
  ConsumerState<_LogEventForm> createState() => _LogEventFormState();
}

class _LogEventFormState extends ConsumerState<_LogEventForm> {
  MoneyEventKind _kind = MoneyEventKind.earn;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
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
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );
      _amountController.clear();
      _descriptionController.clear();
      ref.invalidate(moneyEventsProvider);
    } catch (e) {
      setState(() => _error = 'Failed to log entry: $e');
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
                        .map(
                          (k) =>
                              DropdownMenuItem(value: k, child: Text(k.name)),
                        )
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
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
