import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'models/purchase.dart';
import 'models/return_record.dart';
import 'models/warranty.dart';

Map<String, dynamic> buildPurchaseRpcParameters({
  required String accountId,
  String? itemId,
  String? vendorName,
  String? purchaseDate,
  int? priceCents,
  String? returnWindowExpiresAt,
  String? warrantyExpiresAt,
}) {
  return {
    'p_account_id': accountId,
    'p_item_id': itemId,
    'p_vendor_name': vendorName,
    'p_purchase_date': purchaseDate,
    'p_price_cents': priceCents,
    'p_return_window_expires_at': returnWindowExpiresAt,
    'p_warranty_expires_at': warrantyExpiresAt,
  };
}

Map<String, dynamic> buildRefundRpcParameters({
  required String accountId,
  required String returnId,
  required String itemId,
  required int refundAmountCents,
}) {
  return {
    'p_account_id': accountId,
    'p_return_id': returnId,
    'p_item_id': itemId,
    'p_refund_amount_cents': refundAmountCents,
  };
}

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

  if (accountId.isEmpty) {
    return const PurchasesPageData(
      purchases: [],
      items: [],
      returns: [],
      warranties: [],
    );
  }

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
        .eq('account_id', accountId)
        .order('created_at', ascending: true),
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
    await _client.rpc(
      'create_purchase_with_money_event',
      params: buildPurchaseRpcParameters(
        accountId: accountId,
        itemId: itemId,
        vendorName: vendorName,
        purchaseDate: purchaseDate,
        priceCents: priceCents,
        returnWindowExpiresAt: returnWindowExpiresAt,
        warrantyExpiresAt: warrantyExpiresAt,
      ),
    );
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
    await _client.rpc(
      'refund_return_with_money_event',
      params: buildRefundRpcParameters(
        accountId: accountId,
        returnId: returnId,
        itemId: itemId,
        refundAmountCents: refundAmountCents,
      ),
    );
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
