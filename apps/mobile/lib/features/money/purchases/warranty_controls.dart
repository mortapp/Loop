import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_error_view.dart';
import 'models/warranty.dart';
import 'purchases_providers.dart';

/// Warranty controls for one item's purchase — mirrors
/// `apps/web/src/app/(app)/money/purchases/warranty-controls.tsx`: a
/// chip per existing warranty (provider, expiry, claim status) plus a
/// "file claim" action while unfiled, and a "+ Warranty" form to add a
/// new one.
class WarrantyControls extends ConsumerWidget {
  const WarrantyControls({
    super.key,
    required this.itemId,
    required this.warranties,
  });

  final String? itemId;
  final List<Warranty> warranties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = this.itemId;
    if (itemId == null) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final warranty in warranties) _WarrantyChip(warranty: warranty),
        _AddWarrantyControl(itemId: itemId),
      ],
    );
  }
}

class _WarrantyChip extends ConsumerWidget {
  const _WarrantyChip({required this.warranty});

  final Warranty warranty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = [
      warranty.provider ?? 'Warranty',
      if (warranty.expiresAt != null) 'until ${warranty.expiresAt}',
      if (warranty.claimStatus != null) warranty.claimStatus!,
    ].join(' · ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(label),
          backgroundColor: AppColors.protectAccent.withValues(alpha: 0.12),
          labelStyle: const TextStyle(color: AppColors.protectAccent),
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
        if (warranty.claimStatus == null)
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(purchasesRepositoryProvider)
                    .setWarrantyClaimStatus(
                      id: warranty.id,
                      claimStatus: 'filed',
                    );
                if (!context.mounted) return;
                ref.invalidate(purchasesPageProvider);
              } catch (_) {
                if (context.mounted) {
                  showErrorSnackBar(
                    context,
                    userSafeActionError('file this warranty claim'),
                  );
                }
              }
            },
            child: const Text('file claim'),
          ),
      ],
    );
  }
}

class _AddWarrantyControl extends ConsumerStatefulWidget {
  const _AddWarrantyControl({required this.itemId});

  final String itemId;

  @override
  ConsumerState<_AddWarrantyControl> createState() =>
      _AddWarrantyControlState();
}

class _AddWarrantyControlState extends ConsumerState<_AddWarrantyControl> {
  bool _open = false;
  bool _submitting = false;
  final _providerController = TextEditingController();
  DateTime? _expiresAt;

  @override
  void dispose() {
    _providerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(purchasesRepositoryProvider)
          .addWarranty(
            accountId: accountId,
            itemId: widget.itemId,
            provider: _providerController.text.trim().isEmpty
                ? null
                : _providerController.text.trim(),
            expiresAt: _expiresAt == null
                ? null
                : '${_expiresAt!.year.toString().padLeft(4, '0')}-'
                      '${_expiresAt!.month.toString().padLeft(2, '0')}-'
                      '${_expiresAt!.day.toString().padLeft(2, '0')}',
          );
      if (!mounted) return;
      ref.invalidate(purchasesPageProvider);
      setState(() {
        _open = false;
        _providerController.clear();
        _expiresAt = null;
      });
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('add this warranty'));
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
        child: const Text('+ Warranty'),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _providerController,
            decoration: const InputDecoration(
              hintText: 'Provider',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 20),
            );
            if (!mounted) return;
            if (picked != null) setState(() => _expiresAt = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              hintText: 'Expires',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            child: Text(
              _expiresAt == null
                  ? 'Not set'
                  : '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
