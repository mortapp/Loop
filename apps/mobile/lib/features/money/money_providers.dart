import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import 'models/money_event.dart';
import 'models/money_totals.dart';

/// Every `money_events` row for the active account, newest first — mirrors
/// `apps/web/src/app/(app)/money/page.tsx`.
final moneyEventsProvider = FutureProvider.autoDispose<List<MoneyEvent>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  if (accountId.isEmpty) return const [];

  final rows = await client
      .from('money_events')
      .select()
      .eq('account_id', accountId)
      .order('occurred_at', ascending: false)
      .limit(200);

  return rows.map(MoneyEvent.fromJson).toList();
});

/// MADE/PROTECTED/RECOVERED/SPENT/FEES/NET, sourced from the one canonical
/// formula (public.account_money_totals — see
/// supabase/migrations/20260822165605_money_integrity.sql) instead of
/// being re-derived client-side. Web reads the same RPC.
final moneyTotalsProvider = FutureProvider.autoDispose<MoneyTotals>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  if (accountId.isEmpty) return MoneyTotals.zero;

  final rows = await client.rpc(
    'account_money_totals',
    params: {'p_account_id': accountId},
  );
  final row = (rows as List).isEmpty
      ? null
      : rows.first as Map<String, dynamic>;
  return row == null ? MoneyTotals.zero : MoneyTotals.fromJson(row);
});

class MoneyEventsRepository {
  MoneyEventsRepository(this._client);

  final SupabaseClient _client;

  Future<void> logManualEvent({
    required String accountId,
    required MoneyEventKind kind,
    required int amountCents,
    String? description,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('money_events').insert({
      'account_id': accountId,
      'kind': kind.name,
      'amount_cents': amountCents,
      'source_type': 'manual',
      'description': description,
      'created_by': userId,
    });
  }
}

final moneyEventsRepositoryProvider = Provider<MoneyEventsRepository>((ref) {
  return MoneyEventsRepository(ref.watch(supabaseClientProvider));
});
