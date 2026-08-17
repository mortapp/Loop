import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'models/quote.dart';

/// Every quote for the active account, newest first, joined to its
/// contact's name — mirrors
/// `apps/web/src/app/(app)/business/quotes/page.tsx`.
final quotesProvider = FutureProvider.autoDispose<List<Quote>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  final rows = await client
      .from('quotes')
      .select(
        'id, quote_number, status, total_cents, currency, contacts(id, display_name)',
      )
      .eq('account_id', accountId)
      .order('created_at', ascending: false);

  return rows.map(Quote.fromJson).toList();
});

/// A prepared, validated quote line ready to insert — quantity/unit price
/// already parsed out of their form strings.
class PreparedLine {
  const PreparedLine({
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
  });

  final String description;
  final double quantity;
  final int unitPriceCents;

  int get lineTotalCents => (quantity * unitPriceCents).round();
}

/// Generates a quote number like `Q-2026-XXXXX`, mirroring
/// `generateQuoteNumber()` in
/// `apps/web/src/app/(app)/business/quotes/actions.ts`.
String generateQuoteNumber() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final random = Random();
  final suffix = List.generate(
    5,
    (_) => chars[random.nextInt(chars.length)],
  ).join().toUpperCase();
  return 'Q-${DateTime.now().year}-$suffix';
}

class QuotesRepository {
  QuotesRepository(this._client);

  final SupabaseClient _client;

  /// Two-step insert (quote header, then line items) — mirrors
  /// `createQuote` in `apps/web/src/app/(app)/business/quotes/actions.ts`.
  /// Not wrapped in a transaction on purpose: see
  /// docs/KNOWN_ISSUES.md "Quote creation is not transactional". A failure
  /// on the second step is surfaced rather than hidden, leaving a quote
  /// header with no line items exactly as the web app does.
  Future<void> createQuote({
    required String accountId,
    required String contactId,
    String? opportunityId,
    required List<PreparedLine> lines,
  }) async {
    if (lines.isEmpty) {
      throw StateError(
        'Add at least one line item with a description and quantity.',
      );
    }

    final subtotalCents = lines.fold<int>(
      0,
      (sum, line) => sum + line.lineTotalCents,
    );
    final userId = _client.auth.currentUser?.id;

    final quoteRow = await _client
        .from('quotes')
        .insert({
          'account_id': accountId,
          'contact_id': contactId,
          'opportunity_id': opportunityId,
          'quote_number': generateQuoteNumber(),
          'subtotal_cents': subtotalCents,
          'tax_cents': 0,
          'total_cents': subtotalCents,
          'created_by': userId,
        })
        .select('id')
        .single();

    final quoteId = quoteRow['id'] as String;

    try {
      await _client.from('quote_line_items').insert([
        for (var i = 0; i < lines.length; i++)
          {
            'quote_id': quoteId,
            'description': lines[i].description,
            'quantity': lines[i].quantity,
            'unit_price_cents': lines[i].unitPriceCents,
            'position': i,
          },
      ]);
    } on PostgrestException catch (e) {
      // The quote header exists but is missing its lines — not wrapped in
      // a transaction yet (see docs/KNOWN_ISSUES.md). Surface it rather
      // than hiding a half-written quote.
      throw StateError('Quote created but line items failed: ${e.message}');
    }
  }

  Future<void> setStatus({required String id, required QuoteStatus status}) {
    final patch = <String, dynamic>{'status': status.name};
    if (status == QuoteStatus.sent) {
      patch['sent_at'] = DateTime.now().toIso8601String();
    }
    if (status == QuoteStatus.accepted) {
      patch['accepted_at'] = DateTime.now().toIso8601String();
    }
    return _client.from('quotes').update(patch).eq('id', id);
  }
}

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  return QuotesRepository(ref.watch(supabaseClientProvider));
});
