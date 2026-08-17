/// Status values for a row in `public.quotes`.
enum QuoteStatus { draft, sent, viewed, accepted, declined, expired }

const quoteStatusOptions = [
  QuoteStatus.draft,
  QuoteStatus.sent,
  QuoteStatus.viewed,
  QuoteStatus.accepted,
  QuoteStatus.declined,
  QuoteStatus.expired,
];

QuoteStatus quoteStatusFromString(String value) {
  return quoteStatusOptions.firstWhere(
    (s) => s.name == value,
    orElse: () => QuoteStatus.draft,
  );
}

/// A single row from `public.quotes`, joined to its contact's display
/// name — mirrors `apps/web/src/app/(app)/business/quotes/page.tsx`.
class Quote {
  const Quote({
    required this.id,
    required this.quoteNumber,
    required this.status,
    required this.totalCents,
    required this.currency,
    this.contactDisplayName,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    final contactsJoin = json['contacts'] as Map<String, dynamic>?;
    return Quote(
      id: json['id'] as String,
      quoteNumber: json['quote_number'] as String,
      status: quoteStatusFromString(json['status'] as String),
      totalCents: (json['total_cents'] as num).toInt(),
      currency: json['currency'] as String? ?? 'USD',
      contactDisplayName: contactsJoin?['display_name'] as String?,
    );
  }

  final String id;
  final String quoteNumber;
  final QuoteStatus status;
  final int totalCents;
  final String currency;
  final String? contactDisplayName;
}

/// One line item on a quote-in-progress (client-side form state, before
/// it's split into `unit_price_cents`/`quantity`/`position` on insert).
class QuoteLineDraft {
  QuoteLineDraft({
    this.description = '',
    this.quantity = '1',
    this.unitPrice = '',
  });

  String description;
  String quantity;
  String unitPrice;
}
