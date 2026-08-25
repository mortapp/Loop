/// Status values for a row in `public.items` — the OWN anchor entity that
/// MAKE/PROTECT/RECOVER all hang off of.
enum ItemStatus { owned, returned, listed, sold, disposed }

ItemStatus itemStatusFromString(String value) {
  return ItemStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ItemStatus.owned,
  );
}

/// Statuses from which a listing may be created or a sale recorded — must
/// mirror `private.guard_listing_lifecycle`/`private.guard_sale_lifecycle`
/// in supabase/migrations/20260823060632_enforce_atomic_money_lifecycle.sql
/// (`v_item_status not in ('owned', 'listed')` is rejected). A returned or
/// disposed item is server-rejected even though it is not `sold`, so `status
/// != ItemStatus.sold` is not a valid eligibility check on its own.
const _sellableItemStatuses = {ItemStatus.owned, ItemStatus.listed};

bool canPrepareListing(ItemStatus status) =>
    _sellableItemStatuses.contains(status);

bool canRecordSale(ItemStatus status) => _sellableItemStatuses.contains(status);

/// A single row from `public.items`.
class Item {
  const Item({
    required this.id,
    required this.accountId,
    required this.name,
    this.category,
    this.condition,
    this.purchasePriceCents,
    required this.status,
    required this.createdAt,
    this.photos = const [],
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      condition: json['condition'] as String?,
      purchasePriceCents: (json['purchase_price_cents'] as num?)?.toInt(),
      status: itemStatusFromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  final String id;
  final String accountId;
  final String name;
  final String? category;
  final String? condition;
  final int? purchasePriceCents;
  final ItemStatus status;
  final DateTime createdAt;

  /// Object paths in the `item-photos` Storage bucket
  /// (`<accountId>/<itemId>/<uuid>.<ext>`), not URLs — resolved to signed
  /// URLs at read time since the bucket is private. See
  /// `SellPageData.signedPhotoUrl`.
  final List<String> photos;
}
