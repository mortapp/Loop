import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_error_view.dart';
import 'models/action_item.dart';
import 'today_providers.dart';

/// The Today tab: a unified action feed spanning every engine — quotes to
/// close (MAKE), returns/warranties needing attention (PROTECT), and
/// resell opportunities (RECOVER) — surfaced as one prioritized list.
///
/// Mirrors `apps/web/src/app/(app)/today/page.tsx`: today this is a plain
/// shared task list backed by `public.actions`; `related_type`/`related_id`
/// are reserved for future auto-generated rows.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsAsync = ref.watch(todayActionsProvider);

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'sign-out') {
                ref.read(supabaseClientProvider).auth.signOut();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(todayActionsProvider.future),
          child: actionsAsync.when(
            data: (actions) => _TodayList(actions: actions),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AsyncErrorView(
              error: error,
              onRetry: () => ref.invalidate(todayActionsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayList extends ConsumerWidget {
  const _TodayList({required this.actions});

  final List<ActionItem> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = actions
        .where(
          (a) =>
              a.status == ActionStatus.open || a.status == ActionStatus.snoozed,
        )
        .toList();
    final done = actions.where((a) => a.status == ActionStatus.done).toList();

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('TODAY', style: theme.textTheme.headlineLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _formatFullDate(DateTime.now()),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xl),
        const _QuickAddForm(),
        const SizedBox(height: AppSpacing.lg),
        if (open.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'Nothing open. Add something above.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          ...open.map((action) => _ActionTile(action: action)),
        if (done.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'RECENTLY DONE',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textStructural,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...done.map((action) => _DoneActionTile(action: action)),
        ],
      ],
    );
  }
}

class _QuickAddForm extends ConsumerStatefulWidget {
  const _QuickAddForm();

  @override
  ConsumerState<_QuickAddForm> createState() => _QuickAddFormState();
}

class _QuickAddFormState extends ConsumerState<_QuickAddForm> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    setState(() => _submitting = true);
    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(todayActionsRepositoryProvider)
          .quickAdd(accountId: accountId, title: title);
      _controller.clear();
      ref.invalidate(todayActionsProvider);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, 'Failed to add: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Add something to do…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

/// A ledger entry, not a card — Today's rows read as lines in a private
/// register (rule line below, no per-row surface/elevation) rather than
/// stacked Trello-style cards. See docs/DESIGN_SYSTEM.md.
class _ActionTile extends ConsumerWidget {
  const _ActionTile({required this.action});

  final ActionItem action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Future<void> setStatus(ActionStatus status) async {
      try {
        await ref
            .read(todayActionsRepositoryProvider)
            .setStatus(id: action.id, status: status);
        ref.invalidate(todayActionsProvider);
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, 'Failed: $e');
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
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
                Text(action.title, style: theme.textTheme.bodyLarge),
                if (action.dueAt != null) _DueLabel(dueAt: action.dueAt!),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setStatus(ActionStatus.done),
            style: TextButton.styleFrom(foregroundColor: AppColors.tyrianText),
            child: const Text('Done'),
          ),
          TextButton(
            onPressed: () => setStatus(ActionStatus.dismissed),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }
}

class _DoneActionTile extends ConsumerWidget {
  const _DoneActionTile({required this.action});

  final ActionItem action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    Future<void> reopen() async {
      try {
        await ref
            .read(todayActionsRepositoryProvider)
            .setStatus(id: action.id, status: ActionStatus.open);
        ref.invalidate(todayActionsProvider);
      } catch (e) {
        if (context.mounted) showErrorSnackBar(context, 'Failed: $e');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          TextButton(onPressed: reopen, child: const Text('Reopen')),
        ],
      ),
    );
  }
}

/// Real overdue detection computed from the actual due date — not a
/// fake urgency indicator (matches the same treatment on
/// apps/web/src/app/(app)/today/page.tsx).
class _DueLabel extends StatelessWidget {
  const _DueLabel({required this.dueAt});

  final DateTime dueAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = dueAt.isBefore(DateTime.now());
    return Text(
      '${overdue ? 'Overdue · ' : 'Due '}${_formatDate(dueAt)}',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: overdue ? AppColors.dangerText : null,
        fontWeight: overdue ? FontWeight.w600 : null,
      ),
    );
  }
}

String _formatFullDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Today';
  }
  return '${months[date.month - 1]} ${date.day}';
}
