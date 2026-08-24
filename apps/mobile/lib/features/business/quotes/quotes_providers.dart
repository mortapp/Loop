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

Map<String, Object?> buildCreateQuoteRpcParameters({
  required String accountId,
  required String contactId,
  required String? opportunityId,
  required String userId,
  required String quoteNumber,
  required List<PreparedLine> lines,
}) {
  if (lines.isEmpty) {
    throw StateError(
      'Add at least one line item with a description and quantity.',
    );
  }

  for (final line in lines) {
    if (line.description.trim().isEmpty ||
        !line.quantity.isFinite ||
        line.quantity <= 0 ||
        line.unitPriceCents < 0) {
      throw StateError('Every quote line must contain valid values.');
    }
  }

  final subtotalCents = lines.fold<int>(
    0,
    (sum, line) => sum + line.lineTotalCents,
  );

  return {
    'p_account_id': accountId,
    'p_contact_id': contactId,
    'p_opportunity_id': opportunityId,
    'p_quote_number': quoteNumber,
    'p_subtotal_cents': subtotalCents,
    'p_tax_cents': 0,
    'p_total_cents': subtotalCents,
    'p_created_by': userId,
    'p_line_items': [
      for (final line in lines)
        {
          'description': line.description.trim(),
          'quantity': line.quantity,
          'unit_price_cents': line.unitPriceCents,
        },
    ],
  };
}

Map<String, Object?> buildSetQuoteStatusRpcParameters({
  required String quoteId,
  required QuoteStatus status,
}) {
  return {'p_quote_id': quoteId, 'p_status': status.name};
}

class QuotesRepository {
  QuotesRepository(this._client);

  final SupabaseClient _client;

  /// Creates the quote header and all lines in one database transaction.
  Future<void> createQuote({
    required String accountId,
    required String contactId,
    String? opportunityId,
    required List<PreparedLine> lines,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in again before creating a quote.');
    }

    await _client.rpc(
      'create_quote_with_line_items',
      params: buildCreateQuoteRpcParameters(
        accountId: accountId,
        contactId: contactId,
        opportunityId: opportunityId,
        userId: userId,
        quoteNumber: generateQuoteNumber(),
        lines: lines,
      ),
    );
  }

  Future<void> setStatus({
    required String id,
    required QuoteStatus status,
  }) async {
    await _client.rpc(
      'set_quote_status_with_money_event',
      params: buildSetQuoteStatusRpcParameters(quoteId: id, status: status),
    );
  }
}

final quotesRepositoryProvider = Provider<QuotesRepository>((ref) {
  return QuotesRepository(ref.watch(supabaseClientProvider));
});
