/// Status values for a row in `public.items` — the OWN anchor entity that
/// MAKE/PROTECT/RECOVER all hang off of.
enum ItemStatus { owned, returned, listed, sold, disposed }

ItemStatus itemStatusFromString(String value) {
  return ItemStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ItemStatus.owned,
  );
}

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
}
