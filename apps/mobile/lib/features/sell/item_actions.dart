import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/account_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/async_error_view.dart';
import '../money/money_providers.dart';
import 'sell_providers.dart';

/// Per-item action row (+ Valuation / + List for sale / + Record sale) —
/// mirrors `apps/web/src/app/(app)/sell/item-actions.tsx`.
class ItemActions extends StatelessWidget {
  const ItemActions({
    super.key,
    required this.itemId,
    required this.isListed,
    this.listingId,
  });

  final String itemId;
  final bool isListed;
  final String? listingId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        _ValuationAction(itemId: itemId),
        if (!isListed) _ListingAction(itemId: itemId),
        _SaleAction(itemId: itemId, listingId: listingId),
      ],
    );
  }
}

class _ValuationAction extends ConsumerStatefulWidget {
  const _ValuationAction({required this.itemId});

  final String itemId;

  @override
  ConsumerState<_ValuationAction> createState() => _ValuationActionState();
}

class _ValuationActionState extends ConsumerState<_ValuationAction> {
  bool _open = false;
  bool _submitting = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cents = MoneyUtils.dollarsStringToCents(_controller.text);
    if (cents == null || cents <= 0) {
      showErrorSnackBar(context, 'Enter a valid estimated value.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(sellRepositoryProvider)
          .addValuation(
            accountId: accountId,
            itemId: widget.itemId,
            estimatedValueCents: cents,
          );
      if (!mounted) return;
      ref.invalidate(sellPageProvider);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('save this valuation'));
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
        child: const Text('+ Valuation'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          child: TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: r'$ est.',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ListingAction extends ConsumerStatefulWidget {
  const _ListingAction({required this.itemId});

  final String itemId;

  @override
  ConsumerState<_ListingAction> createState() => _ListingActionState();
}

class _ListingActionState extends ConsumerState<_ListingAction> {
  bool _open = false;
  bool _submitting = false;
  final _marketplaceController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _marketplaceController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final marketplace = _marketplaceController.text.trim();
    if (marketplace.isEmpty) {
      showErrorSnackBar(context, 'Marketplace is required.');
      return;
    }
    final listPriceCents = MoneyUtils.dollarsStringToCents(
      _priceController.text,
    );
    if (_priceController.text.trim().isNotEmpty &&
        (listPriceCents == null || listPriceCents < 0)) {
      showErrorSnackBar(context, 'Enter a valid listing price.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(sellRepositoryProvider)
          .createListing(
            accountId: accountId,
            itemId: widget.itemId,
            marketplace: marketplace,
            listPriceCents: listPriceCents,
          );
      if (!mounted) return;
      ref.invalidate(sellPageProvider);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('create this listing'));
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
        child: const Text('+ List for sale'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          child: TextField(
            controller: _marketplaceController,
            decoration: const InputDecoration(
              hintText: 'Marketplace',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 90,
          child: TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: r'$ price',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('List'),
        ),
      ],
    );
  }
}

class _SaleAction extends ConsumerStatefulWidget {
  const _SaleAction({required this.itemId, this.listingId});

  final String itemId;
  final String? listingId;

  @override
  ConsumerState<_SaleAction> createState() => _SaleActionState();
}

class _SaleActionState extends ConsumerState<_SaleAction> {
  bool _open = false;
  bool _submitting = false;
  final _priceController = TextEditingController();
  final _feesController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _feesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final salePriceCents = MoneyUtils.dollarsStringToCents(
      _priceController.text,
    );
    if (salePriceCents == null || salePriceCents <= 0) {
      showErrorSnackBar(context, 'Enter a valid sale price.');
      return;
    }
    final feesCents =
        MoneyUtils.dollarsStringToCents(_feesController.text) ?? 0;
    if (feesCents < 0 || feesCents > salePriceCents) {
      showErrorSnackBar(
        context,
        'Fees must be between zero and the sale price.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(sellRepositoryProvider)
          .recordSale(
            accountId: accountId,
            itemId: widget.itemId,
            listingId: widget.listingId,
            salePriceCents: salePriceCents,
            feesCents: feesCents,
          );
      if (!mounted) return;
      ref.invalidate(sellPageProvider);
      ref.invalidate(moneyEventsProvider);
      ref.invalidate(moneyTotalsProvider);
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, userSafeActionError('record this sale'));
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
        child: const Text('+ Record sale'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          child: TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: r'$ sold for',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _feesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: r'$ fees',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
