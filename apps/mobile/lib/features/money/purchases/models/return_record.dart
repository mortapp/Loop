/// Status values for a row in `public.returns`.
enum ReturnStatus { initiated, shipped, received, refunded, denied }

ReturnStatus returnStatusFromString(String value) {
  return ReturnStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ReturnStatus.initiated,
  );
}

/// A single row from `public.returns`.
class ReturnRecord {
  const ReturnRecord({
    required this.id,
    this.purchaseId,
    required this.itemId,
    required this.status,
  });

  factory ReturnRecord.fromJson(Map<String, dynamic> json) {
    return ReturnRecord(
      id: json['id'] as String,
      purchaseId: json['purchase_id'] as String?,
      itemId: json['item_id'] as String,
      status: returnStatusFromString(json['status'] as String),
    );
  }

  final String id;
  final String? purchaseId;
  final String itemId;
  final ReturnStatus status;
}
