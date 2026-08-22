import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/account/account_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/account_sheet.dart';
import '../../core/widgets/async_error_view.dart';
import '../../core/widgets/loop_seal.dart';
import 'item_actions.dart';
import 'models/item.dart';
import 'models/listing.dart';
import 'models/valuation.dart';
import 'sell_providers.dart';

Color _statusColor(ItemStatus status) {
  switch (status) {
    case ItemStatus.owned:
      return AppColors.textMuted;
    case ItemStatus.returned:
      return AppColors.warning;
    case ItemStatus.listed:
      return AppColors.protectAccent;
    case ItemStatus.sold:
      return AppColors.success;
    case ItemStatus.disposed:
      return AppColors.textMuted;
  }
}

/// The Sell tab: the RECOVER-facing surface (ResellLens) — valuing items
/// you own, listing them, and tracking resale through to a completed sale,
/// closing the OWN -> RESELL -> EARN AGAIN loop.
///
/// Mirrors `apps/web/src/app/(app)/sell/page.tsx`.
class SellScreen extends ConsumerWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(sellPageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell'),
        actions: const [AccountAvatarButton()],
      ),
      body: SafeArea(
        child: pageAsync.when(
          data: (data) => _SellBody(data: data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(sellPageProvider),
          ),
        ),
      ),
    );
  }
}

class _SellBody extends ConsumerWidget {
  const _SellBody({required this.data});

  final SellPageData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(sellPageProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'RECOVER / ResellLens. Value an item, list it, then record the '
            'sale — a completed sale posts straight to Money as recovered '
            'value.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const _CreateItemForm(),
          const SizedBox(height: AppSpacing.lg),
          if (data.items.isEmpty)
            const Text('No items yet.')
          else
            for (final item in data.items)
              _ItemTile(
                item: item,
                valuation: data.latestValuationByItem[item.id],
                listings: data.listingsByItem[item.id] ?? const [],
                signedUrlByPath: data.signedUrlByPath,
              ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    required this.item,
    required this.valuation,
    required this.listings,
    required this.signedUrlByPath,
  });

  final Item item;
  final ValuationRow? valuation;
  final List<ListingRow> listings;
  final Map<String, String> signedUrlByPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = [
      item.category,
      item.condition,
    ].whereType<String>().join(' · ');
    final heroUrl = item.photos.isNotEmpty
        ? signedUrlByPath[item.photos.first]
        : null;

    // A private collection, not a marketplace listing — an image band
    // (Loop Seal watermark until real photo upload exists) leads every
    // tile, matching apps/web's Sell gallery.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  color: AppColors.murexInk,
                  alignment: Alignment.center,
                  child: heroUrl != null
                      ? Image.network(
                          heroUrl,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const LoopSeal(
                                size: 56,
                                keyPoint: false,
                                opacity: 0.18,
                              ),
                        )
                      : const LoopSeal(
                          size: 56,
                          keyPoint: false,
                          opacity: 0.18,
                        ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Chip(
                    label: Text(item.status.name),
                    backgroundColor: _statusColor(
                      item.status,
                    ).withValues(alpha: 0.16),
                    labelStyle: TextStyle(color: _statusColor(item.status)),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (heroUrl != null && item.status != ItemStatus.sold)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: GestureDetector(
                      onTap: () async {
                        await ref
                            .read(sellRepositoryProvider)
                            .removePhoto(
                              itemId: item.id,
                              objectPath: item.photos.first,
                            );
                        ref.invalidate(sellPageProvider);
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.onAccentFill,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (item.photos.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final path in item.photos.skip(1))
                        if (signedUrlByPath[path] != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.xs,
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                  child: Image.network(
                                    signedUrlByPath[path]!,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (item.status != ItemStatus.sold)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: GestureDetector(
                                      onTap: () async {
                                        await ref
                                            .read(sellRepositoryProvider)
                                            .removePhoto(
                                              itemId: item.id,
                                              objectPath: path,
                                            );
                                        ref.invalidate(sellPageProvider);
                                      },
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          color: AppColors.danger,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.close,
                                          size: 11,
                                          color: AppColors.onAccentFill,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.bodyLarge),
                  Text(
                    details.isNotEmpty ? details : 'No details',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (valuation != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'EST. VALUE',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.textStructural,
                            letterSpacing: 1,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          MoneyUtils.formatCents(
                            valuation!.estimatedValueCents,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.opportunityText(theme.brightness),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (listings.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    for (final listing in listings)
                      Text(
                        'Listed on ${listing.marketplace}'
                        '${listing.listPriceCents != null ? ' for ${MoneyUtils.formatCents(listing.listPriceCents)}' : ''}'
                        ' · ${listing.status.name}',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                  if (item.status != ItemStatus.sold) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final error = await ref
                                .read(sellRepositoryProvider)
                                .pickAndUploadPhoto(
                                  accountId: item.accountId,
                                  itemId: item.id,
                                );
                            if (error != null && context.mounted) {
                              showErrorSnackBar(context, error);
                            } else {
                              ref.invalidate(sellPageProvider);
                            }
                          },
                          child: const Text('+ Photo'),
                        ),
                        ItemActions(
                          itemId: item.id,
                          isListed: item.status == ItemStatus.listed,
                          listingId: listings.isNotEmpty
                              ? listings.first.id
                              : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateItemForm extends ConsumerStatefulWidget {
  const _CreateItemForm();

  @override
  ConsumerState<_CreateItemForm> createState() => _CreateItemFormState();
}

class _CreateItemFormState extends ConsumerState<_CreateItemForm> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _conditionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _conditionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(sellRepositoryProvider)
          .createItem(
            accountId: accountId,
            name: name,
            category: _categoryController.text.trim().isEmpty
                ? null
                : _categoryController.text.trim(),
            condition: _conditionController.text.trim().isEmpty
                ? null
                : _conditionController.text.trim(),
            purchasePriceCents: MoneyUtils.dollarsStringToCents(
              _priceController.text,
            ),
          );
      _nameController.clear();
      _categoryController.clear();
      _conditionController.clear();
      _priceController.clear();
      ref.invalidate(sellPageProvider);
    } catch (e) {
      setState(() => _error = 'Failed to add item: $e');
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _conditionController,
              decoration: const InputDecoration(
                labelText: 'Condition (optional)',
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
                labelText: r'Paid ($, optional)',
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
                      : const Text('Add item'),
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
