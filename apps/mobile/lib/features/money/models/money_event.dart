/// The kind of a `public.money_events` row — the append-only value ledger
/// every engine writes to (EARN / BUY / RETURN / RESELL).
enum MoneyEventKind { earn, spend, refund, fee, recovered }

MoneyEventKind moneyEventKindFromString(String value) {
  return MoneyEventKind.values.firstWhere(
    (k) => k.name == value,
    orElse: () => MoneyEventKind.earn,
  );
}

/// +1 for value flowing in (earn/recovered/refund), -1 for value flowing
/// out (spend/fee) — mirrors `KIND_SIGN` in
/// `apps/web/src/app/(app)/money/page.tsx`.
int moneyEventKindSign(MoneyEventKind kind) {
  switch (kind) {
    case MoneyEventKind.earn:
    case MoneyEventKind.recovered:
    case MoneyEventKind.refund:
      return 1;
    case MoneyEventKind.spend:
    case MoneyEventKind.fee:
      return -1;
  }
}

/// A single row from the append-only `public.money_events` ledger.
class MoneyEvent {
  const MoneyEvent({
    required this.id,
    required this.accountId,
    this.itemId,
    required this.kind,
    required this.amountCents,
    required this.currency,
    required this.occurredAt,
    this.sourceType,
    this.sourceId,
    this.description,
  });

  factory MoneyEvent.fromJson(Map<String, dynamic> json) {
    return MoneyEvent(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      itemId: json['item_id'] as String?,
      kind: moneyEventKindFromString(json['kind'] as String),
      amountCents: (json['amount_cents'] as num).toInt(),
      currency: json['currency'] as String? ?? 'USD',
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      sourceType: json['source_type'] as String?,
      sourceId: json['source_id'] as String?,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String accountId;
  final String? itemId;
  final MoneyEventKind kind;
  final int amountCents;
  final String currency;
  final DateTime occurredAt;
  final String? sourceType;
  final String? sourceId;
  final String? description;
}
