/// A row from the append-only `public.valuations` history — a running
/// history of estimates for one item.
class ValuationRow {
  const ValuationRow({
    required this.itemId,
    required this.estimatedValueCents,
    required this.valuedAt,
  });

  factory ValuationRow.fromJson(Map<String, dynamic> json) {
    return ValuationRow(
      itemId: json['item_id'] as String,
      estimatedValueCents: (json['estimated_value_cents'] as num).toInt(),
      valuedAt: DateTime.parse(json['valued_at'] as String),
    );
  }

  final String itemId;
  final int estimatedValueCents;
  final DateTime valuedAt;
}
