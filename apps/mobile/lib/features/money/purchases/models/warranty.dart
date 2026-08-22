/// A single row from `public.warranties`. Mirrors the `Warranty` type in
/// `apps/web/src/app/(app)/money/purchases/warranty-controls.tsx`.
class Warranty {
  const Warranty({
    required this.id,
    required this.itemId,
    this.provider,
    this.expiresAt,
    this.claimStatus,
  });

  factory Warranty.fromJson(Map<String, dynamic> json) {
    return Warranty(
      id: json['id'] as String,
      itemId: json['item_id'] as String,
      provider: json['provider'] as String?,
      expiresAt: json['expires_at'] as String?,
      claimStatus: json['claim_status'] as String?,
    );
  }

  final String id;
  final String itemId;
  final String? provider;
  final String? expiresAt;
  final String? claimStatus;
}
