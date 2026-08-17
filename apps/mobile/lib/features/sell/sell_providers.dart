import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import 'models/item.dart';
import 'models/listing.dart';
import 'models/valuation.dart';

class SellPageData {
  const SellPageData({
    required this.items,
    required this.latestValuationByItem,
    required this.listingsByItem,
  });

  final List<Item> items;
  final Map<String, ValuationRow> latestValuationByItem;
  final Map<String, List<ListingRow>> listingsByItem;
}

/// Items + latest valuation per item + open (draft/active) listings per
/// item, for the active account — mirrors the parallel fetch in
/// `apps/web/src/app/(app)/sell/page.tsx`.
final sellPageProvider = FutureProvider.autoDispose<SellPageData>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  final results = await Future.wait([
    client
        .from('items')
        .select()
        .eq('account_id', accountId)
        .order('created_at', ascending: false),
    client
        .from('valuations')
        .select('item_id, estimated_value_cents, valued_at')
        .eq('account_id', accountId)
        .order('valued_at', ascending: false),
    client
        .from('listings')
        .select('id, item_id, marketplace, status, list_price_cents')
        .eq('account_id', accountId)
        .inFilter('status', ['draft', 'active']),
  ]);

  final items = (results[0]).map(Item.fromJson).toList();
  final valuations = (results[1]).map(ValuationRow.fromJson).toList();
  final listings = (results[2]).map(ListingRow.fromJson).toList();

  final latestValuationByItem = <String, ValuationRow>{};
  for (final v in valuations) {
    latestValuationByItem.putIfAbsent(v.itemId, () => v);
  }

  final listingsByItem = <String, List<ListingRow>>{};
  for (final l in listings) {
    (listingsByItem[l.itemId] ??= []).add(l);
  }

  return SellPageData(
    items: items,
    latestValuationByItem: latestValuationByItem,
    listingsByItem: listingsByItem,
  );
});

class SellRepository {
  SellRepository(this._client);

  final SupabaseClient _client;

  Future<void> createItem({
    required String accountId,
    required String name,
    String? category,
    String? condition,
    int? purchasePriceCents,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('items').insert({
      'account_id': accountId,
      'name': name,
      'category': category,
      'condition': condition,
      'purchase_price_cents': purchasePriceCents,
      'created_by': userId,
    });
  }

  Future<void> addValuation({
    required String accountId,
    required String itemId,
    required int estimatedValueCents,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('valuations').insert({
      'account_id': accountId,
      'item_id': itemId,
      'source': 'manual',
      'estimated_value_cents': estimatedValueCents,
      'created_by': userId,
    });
  }

  Future<void> createListing({
    required String accountId,
    required String itemId,
    required String marketplace,
    int? listPriceCents,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('listings').insert({
      'account_id': accountId,
      'item_id': itemId,
      'marketplace': marketplace,
      'status': 'active',
      'list_price_cents': listPriceCents,
      'published_at': DateTime.now().toIso8601String(),
      'created_by': userId,
    });

    await _client.from('items').update({'status': 'listed'}).eq('id', itemId);
  }

  Future<void> recordSale({
    required String accountId,
    required String itemId,
    String? listingId,
    required int salePriceCents,
    int feesCents = 0,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final netAmountCents = salePriceCents - feesCents;

    await _client.from('sales').insert({
      'account_id': accountId,
      'item_id': itemId,
      'listing_id': listingId,
      'sale_price_cents': salePriceCents,
      'fees_cents': feesCents,
      'net_amount_cents': netAmountCents,
      'created_by': userId,
    });

    await _client.from('items').update({'status': 'sold'}).eq('id', itemId);
    if (listingId != null) {
      await _client
          .from('listings')
          .update({'status': 'sold'})
          .eq('id', listingId);
    }

    await _client.from('money_events').insert({
      'account_id': accountId,
      'item_id': itemId,
      'kind': 'recovered',
      'amount_cents': netAmountCents,
      'source_type': 'sale',
      'description': 'Item sold via RECOVER',
      'created_by': userId,
    });
  }
}

final sellRepositoryProvider = Provider<SellRepository>((ref) {
  return SellRepository(ref.watch(supabaseClientProvider));
});
