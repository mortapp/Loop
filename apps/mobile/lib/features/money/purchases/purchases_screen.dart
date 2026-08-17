import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_error_view.dart';
import 'models/purchase.dart';
import 'models/return_record.dart';
import 'purchases_providers.dart';
import 'return_controls.dart';

/// PROTECT / ReturnGuard: record what you bought, then start a return or
/// claim a warranty before the window closes.
///
/// Mirrors `apps/web/src/app/(app)/money/purchases/page.tsx`.
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(purchasesPageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchases')),
      body: SafeArea(
        child: pageAsync.when(
          data: (data) => _PurchasesBody(data: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(purchasesPageProvider),
          ),
        ),
      ),
    );
  }
}

class _PurchasesBody extends ConsumerWidget {
  const _PurchasesBody({required this.data});

  final PurchasesPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnByPurchase = data.returnByPurchase;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(purchasesPageProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'PROTECT / ReturnGuard. Record what you bought, then start a '
            'return or claim a warranty before the window closes.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _CreatePurchaseForm(items: data.items),
          const SizedBox(height: AppSpacing.lg),
          if (data.purchases.isEmpty)
            const Text('No purchases yet.')
          else
            for (final purchase in data.purchases)
              _PurchaseTile(
                purchase: purchase,
                existingReturn: returnByPurchase[purchase.id],
              ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.purchase, this.existingReturn});

  final Purchase purchase;
  final ReturnRecord? existingReturn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = purchase.itemName ?? purchase.vendorName ?? 'Purchase';
    final details = <String>[
      purchase.vendorName ?? 'Unknown vendor',
      if (purchase.returnWindowExpiresAt != null)
        'Return by ${purchase.returnWindowExpiresAt}',
      if (purchase.warrantyExpiresAt != null)
        'Warranty until ${purchase.warrantyExpiresAt}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title · ${MoneyUtils.formatCents(purchase.priceCents)}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(details, style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              ReturnControls(
                purchaseId: purchase.id,
                itemId: purchase.itemId,
                existingReturn: existingReturn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatePurchaseForm extends ConsumerStatefulWidget {
  const _CreatePurchaseForm({required this.items});

  final List<ItemRef> items;

  @override
  ConsumerState<_CreatePurchaseForm> createState() =>
      _CreatePurchaseFormState();
}

class _CreatePurchaseFormState extends ConsumerState<_CreatePurchaseForm> {
  String? _itemId;
  final _vendorController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _purchaseDate;
  DateTime? _returnWindowExpiresAt;
  DateTime? _warrantyExpiresAt;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _vendorController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) onPicked(picked);
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final priceText = _priceController.text.trim();
    final priceCents = priceText.isEmpty
        ? null
        : MoneyUtils.dollarsStringToCents(priceText);
    if (priceText.isNotEmpty && priceCents == null) {
      setState(() => _error = 'Price must be a number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(purchasesRepositoryProvider)
          .createPurchase(
            accountId: accountId,
            itemId: _itemId,
            vendorName: _vendorController.text.trim().isEmpty
                ? null
                : _vendorController.text.trim(),
            purchaseDate: _purchaseDate == null
                ? null
                : _isoDate(_purchaseDate!),
            priceCents: priceCents,
            returnWindowExpiresAt: _returnWindowExpiresAt == null
                ? null
                : _isoDate(_returnWindowExpiresAt!),
            warrantyExpiresAt: _warrantyExpiresAt == null
                ? null
                : _isoDate(_warrantyExpiresAt!),
          );

      _vendorController.clear();
      _priceController.clear();
      setState(() {
        _itemId = null;
        _purchaseDate = null;
        _returnWindowExpiresAt = null;
        _warrantyExpiresAt = null;
      });
      ref.invalidate(purchasesPageProvider);
    } catch (e) {
      setState(() => _error = 'Failed to add purchase: $e');
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
            DropdownButtonFormField<String?>(
              initialValue: _itemId,
              decoration: const InputDecoration(
                labelText: 'Item (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not linked to an item'),
                ),
                for (final item in widget.items)
                  DropdownMenuItem<String?>(
                    value: item.id,
                    child: Text(item.name),
                  ),
              ],
              onChanged: (value) => setState(() => _itemId = value),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _vendorController,
              decoration: const InputDecoration(
                labelText: 'Vendor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: r'Price ($ paid)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DatePickerField(
              label: 'Purchase date',
              value: _purchaseDate,
              onTap: () => _pickDate((d) => setState(() => _purchaseDate = d)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DatePickerField(
              label: 'Return window ends',
              value: _returnWindowExpiresAt,
              onTap: () =>
                  _pickDate((d) => setState(() => _returnWindowExpiresAt = d)),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DatePickerField(
              label: 'Warranty ends',
              value: _warrantyExpiresAt,
              onTap: () =>
                  _pickDate((d) => setState(() => _warrantyExpiresAt = d)),
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
                      : const Text('Add purchase'),
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

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(
          value == null
              ? 'Not set'
              : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }
}
