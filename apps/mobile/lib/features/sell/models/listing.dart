/// Status values for a row in `public.listings`.
enum ListingStatus { draft, active, sold, removed }

ListingStatus listingStatusFromString(String value) {
  return ListingStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ListingStatus.draft,
  );
}

/// A single row from `public.listings`.
class ListingRow {
  const ListingRow({
    required this.id,
    required this.itemId,
    required this.marketplace,
    required this.status,
    this.listPriceCents,
  });

  factory ListingRow.fromJson(Map<String, dynamic> json) {
    return ListingRow(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      marketplace: json['marketplace'] as String,
      status: listingStatusFromString(json['status'] as String),
      listPriceCents: (json['list_price_cents'] as num?)?.toInt(),
    );
  }

  final String id;
  final String itemId;
  final String marketplace;
  final ListingStatus status;
  final int? listPriceCents;
}
