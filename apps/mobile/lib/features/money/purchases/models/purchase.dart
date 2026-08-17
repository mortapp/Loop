/// A single row from `public.purchases`, optionally joined to the item's
/// name (mirrors the `items(id, name)` embed in
/// `apps/web/src/app/(app)/money/purchases/page.tsx`).
class Purchase {
  const Purchase({
    required this.id,
    required this.accountId,
    this.itemId,
    this.itemName,
    this.vendorName,
    this.purchaseDate,
    this.priceCents,
    this.returnWindowExpiresAt,
    this.warrantyExpiresAt,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    final itemsJoin = json['items'] as Map<String, dynamic>?;
    return Purchase(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      itemId: json['item_id'] as String?,
      itemName: itemsJoin?['name'] as String?,
      vendorName: json['vendor_name'] as String?,
      purchaseDate: json['purchase_date'] as String?,
      priceCents: (json['price_cents'] as num?)?.toInt(),
      returnWindowExpiresAt: json['return_window_expires_at'] as String?,
      warrantyExpiresAt: json['warranty_expires_at'] as String?,
    );
  }

  final String id;
  final String accountId;
  final String? itemId;
  final String? itemName;
  final String? vendorName;
  final String? purchaseDate;
  final int? priceCents;
  final String? returnWindowExpiresAt;
  final String? warrantyExpiresAt;
}
