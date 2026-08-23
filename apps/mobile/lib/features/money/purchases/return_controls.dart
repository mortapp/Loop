import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_error_view.dart';
import '../money_providers.dart';
import 'models/return_record.dart';
import 'purchases_providers.dart';

Color _statusColor(ReturnStatus status) {
  switch (status) {
    case ReturnStatus.initiated:
      return AppColors.textMuted;
    case ReturnStatus.shipped:
      return AppColors.protectAccent;
    case ReturnStatus.received:
      return AppColors.makeAccent;
    case ReturnStatus.refunded:
      return AppColors.success;
    case ReturnStatus.denied:
      return AppColors.danger;
  }
}

/// Return lifecycle controls for one purchase — mirrors
/// `apps/web/src/app/(app)/money/purchases/return-controls.tsx`:
/// - no return yet -> "Start return" (reason optional)
/// - a return exists and isn't terminal -> cycle status buttons + refund
/// - refunded/denied -> just the status chip, no further actions
class ReturnControls extends ConsumerWidget {
  const ReturnControls({
    super.key,
    required this.purchaseId,
    required this.itemId,
    required this.existingReturn,
  });

  final String purchaseId;
  final String? itemId;
  final ReturnRecord? existingReturn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final existing = existingReturn;
    if (existing == null) {
      return _StartReturnControl(purchaseId: purchaseId, itemId: itemId);
    }

    final theme = Theme.of(context);
    final isTerminal =
        existing.status == ReturnStatus.refunded ||
        existing.status == ReturnStatus.denied;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Chip(
          label: Text('return: ${existing.status.name}'),
          backgroundColor: _statusColor(
            existing.status,
          ).withValues(alpha: 0.12),
          labelStyle: TextStyle(color: _statusColor(existing.status)),
          side: BorderSide.none,
        ),
        if (!isTerminal) ...[
          for (final status in nextReturnStatuses(existing.status))
            TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(purchasesRepositoryProvider)
                      .setReturnStatus(id: existing.id, status: status);
                  if (!context.mounted) return;
                  ref.invalidate(purchasesPageProvider);
                } catch (_) {
                  if (context.mounted) {
                    showErrorSnackBar(
                      context,
                      userSafeActionError('update this return'),
                    );
                  }
                }
              },
              child: Text(
                status.name,
                style: status == ReturnStatus.denied
                    ? TextStyle(color: theme.colorScheme.error)
                    : null,
              ),
            ),
          if (itemId != null)
            _RefundControl(returnId: existing.id, itemId: itemId!),
        ],
      ],
    );
  }
}

class _StartReturnControl extends ConsumerStatefulWidget {
  const _StartReturnControl({required this.purchaseId, required this.itemId});

  final String purchaseId;
  final String? itemId;

  @override
  ConsumerState<_StartReturnControl> createState() =>
      _StartReturnControlState();
}

class _StartReturnControlState extends ConsumerState<_StartReturnControl> {
  bool _open = false;
  bool _submitting = false;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final itemId = widget.itemId;
    if (itemId == null) return;

    setState(() => _submitting = true);
    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(purchasesRepositoryProvider)
          .startReturn(
            accountId: accountId,
            purchaseId: widget.purchaseId,
            itemId: itemId,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(purchasesPageProvider);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('start this return'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemId == null) {
      return const Text("No item linked — can't start a return.");
    }

    if (!_open) {
      return TextButton(
        onPressed: () => setState(() => _open = true),
        child: const Text('+ Start return'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Reason',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Start'),
        ),
      ],
    );
  }
}

class _RefundControl extends ConsumerStatefulWidget {
  const _RefundControl({required this.returnId, required this.itemId});

  final String returnId;
  final String itemId;

  @override
  ConsumerState<_RefundControl> createState() => _RefundControlState();
}

class _RefundControlState extends ConsumerState<_RefundControl> {
  bool _open = false;
  bool _submitting = false;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cents = MoneyUtils.dollarsStringToCents(_amountController.text);
    if (cents == null || cents <= 0) {
      showErrorSnackBar(context, 'Enter a valid refund amount.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(purchasesRepositoryProvider)
          .refundReturn(
            accountId: accountId,
            returnId: widget.returnId,
            itemId: widget.itemId,
            refundAmountCents: cents,
          );
      if (!mounted) return;
      ref.invalidate(purchasesPageProvider);
      ref.invalidate(moneyEventsProvider);
      ref.invalidate(moneyTotalsProvider);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('record this refund'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return TextButton(
        onPressed: () => setState(() => _open = true),
        child: const Text('Refund'),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          child: TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: r'$ refunded',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
