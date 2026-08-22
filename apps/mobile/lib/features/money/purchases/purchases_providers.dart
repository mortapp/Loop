import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'models/purchase.dart';
import 'models/return_record.dart';
import 'models/warranty.dart';

/// A minimal item reference for the "link to an item" dropdown on the
/// purchase form.
class ItemRef {
  const ItemRef({required this.id, required this.name});

  factory ItemRef.fromJson(Map<String, dynamic> json) {
    return ItemRef(id: json['id'] as String, name: json['name'] as String);
  }

  final String id;
  final String name;
}

class PurchasesPageData {
  const PurchasesPageData({
    required this.purchases,
    required this.items,
    required this.returns,
    required this.warranties,
  });

  final List<Purchase> purchases;
  final List<ItemRef> items;
  final List<ReturnRecord> returns;
  final List<Warranty> warranties;

  /// The most recent return per purchase, mirroring `returnByPurchase` in
  /// `apps/web/src/app/(app)/money/purchases/page.tsx`.
  Map<String, ReturnRecord> get returnByPurchase {
    final map = <String, ReturnRecord>{};
    for (final r in returns) {
      if (r.purchaseId != null) map[r.purchaseId!] = r;
    }
    return map;
  }

  /// All warranties for a given item, mirroring `warrantiesByItem` in
  /// `apps/web/src/app/(app)/money/purchases/page.tsx`.
  Map<String, List<Warranty>> get warrantiesByItem {
    final map = <String, List<Warranty>>{};
    for (final w in warranties) {
      (map[w.itemId] ??= []).add(w);
    }
    return map;
  }
}

/// Purchases + linkable items + returns for the active account, mirroring
/// the parallel fetch in
/// `apps/web/src/app/(app)/money/purchases/page.tsx`.
final purchasesPageProvider = FutureProvider.autoDispose<PurchasesPageData>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  final results = await Future.wait([
    client
        .from('purchases')
        .select(
          'id, account_id, item_id, vendor_name, purchase_date, price_cents, '
          'return_window_expires_at, warranty_expires_at, items(id, name)',
        )
        .eq('account_id', accountId)
        .order('created_at', ascending: false),
    client
        .from('items')
        .select('id, name')
        .eq('account_id', accountId)
        .order('name', ascending: true),
    client
        .from('returns')
        .select('id, purchase_id, item_id, status')
        .eq('account_id', accountId),
    client
        .from('warranties')
        .select('id, item_id, provider, expires_at, claim_status')
        .eq('account_id', accountId),
  ]);

  final purchases = (results[0]).map(Purchase.fromJson).toList();
  final items = (results[1]).map(ItemRef.fromJson).toList();
  final returns = (results[2]).map(ReturnRecord.fromJson).toList();
  final warranties = (results[3]).map(Warranty.fromJson).toList();

  return PurchasesPageData(
    purchases: purchases,
    items: items,
    returns: returns,
    warranties: warranties,
  );
});

class PurchasesRepository {
  PurchasesRepository(this._client);

  final SupabaseClient _client;

  Future<void> createPurchase({
    required String accountId,
    String? itemId,
    String? vendorName,
    String? purchaseDate,
    int? priceCents,
    String? returnWindowExpiresAt,
    String? warrantyExpiresAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    await _client.from('purchases').insert({
      'account_id': accountId,
      'item_id': itemId,
      'vendor_name': vendorName,
      'purchase_date': purchaseDate,
      'price_cents': priceCents,
      'return_window_expires_at': returnWindowExpiresAt,
      'warranty_expires_at': warrantyExpiresAt,
      'created_by': userId,
    });

    if (priceCents != null) {
      await _client.from('money_events').insert({
        'account_id': accountId,
        'item_id': itemId,
        'kind': 'spend',
        'amount_cents': priceCents,
        'source_type': 'purchase',
        'description': vendorName != null
            ? 'Purchase from $vendorName'
            : 'Purchase',
        'created_by': userId,
      });
    }
  }

  Future<void> startReturn({
    required String accountId,
    required String purchaseId,
    required String itemId,
    String? reason,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('returns').insert({
      'account_id': accountId,
      'item_id': itemId,
      'purchase_id': purchaseId,
      'reason': reason,
      'created_by': userId,
    });
  }

  Future<void> setReturnStatus({
    required String id,
    required ReturnStatus status,
  }) {
    final patch = <String, dynamic>{'status': status.name};
    if (status == ReturnStatus.denied) {
      patch['resolved_at'] = DateTime.now().toIso8601String();
    }
    return _client.from('returns').update(patch).eq('id', id);
  }

  Future<void> refundReturn({
    required String accountId,
    required String returnId,
    required String itemId,
    required int refundAmountCents,
  }) async {
    final userId = _client.auth.currentUser?.id;

    await _client
        .from('returns')
        .update({
          'status': 'refunded',
          'refund_amount_cents': refundAmountCents,
          'resolved_at': DateTime.now().toIso8601String(),
        })
        .eq('id', returnId);

    await _client.from('money_events').insert({
      'account_id': accountId,
      'item_id': itemId,
      'kind': 'refund',
      'amount_cents': refundAmountCents,
      'source_type': 'return',
      'description': 'Return refunded',
      'created_by': userId,
    });

    await _client.from('items').update({'status': 'returned'}).eq('id', itemId);
  }

  Future<void> addWarranty({
    required String accountId,
    required String itemId,
    String? provider,
    String? expiresAt,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('warranties').insert({
      'account_id': accountId,
      'item_id': itemId,
      'provider': provider,
      'expires_at': expiresAt,
      'created_by': userId,
    });
  }

  Future<void> setWarrantyClaimStatus({
    required String id,
    required String claimStatus,
  }) {
    return _client
        .from('warranties')
        .update({'claim_status': claimStatus})
        .eq('id', id);
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>((ref) {
  return PurchasesRepository(ref.watch(supabaseClientProvider));
});
