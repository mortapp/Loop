/// Status values for a row in `public.returns`.
enum ReturnStatus { initiated, shipped, received, refunded, denied }

ReturnStatus returnStatusFromString(String value) {
  return ReturnStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ReturnStatus.initiated,
  );
}

/// Forward-only states that can be selected directly. Refund is an amount-
/// bearing action handled separately, and terminal states have no successors.
List<ReturnStatus> nextReturnStatuses(ReturnStatus current) {
  switch (current) {
    case ReturnStatus.initiated:
      return const [
        ReturnStatus.shipped,
        ReturnStatus.received,
        ReturnStatus.denied,
      ];
    case ReturnStatus.shipped:
      return const [ReturnStatus.received, ReturnStatus.denied];
    case ReturnStatus.received:
      return const [ReturnStatus.denied];
    case ReturnStatus.refunded:
    case ReturnStatus.denied:
      return const [];
  }
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
