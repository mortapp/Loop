import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import 'models/money_event.dart';
import 'models/money_totals.dart';

const moneyEventsPageSize = 50;

class MoneyEventsPage {
  const MoneyEventsPage({
    required this.events,
    required this.nextOffset,
    required this.hasMore,
  });

  final List<MoneyEvent> events;
  final int nextOffset;
  final bool hasMore;
}

class MoneyEventsPageState {
  const MoneyEventsPageState({
    required this.accountId,
    required this.events,
    required this.nextOffset,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  factory MoneyEventsPageState.fromPage({
    required String accountId,
    required MoneyEventsPage page,
  }) {
    return MoneyEventsPageState(
      accountId: accountId,
      events: List<MoneyEvent>.unmodifiable(page.events),
      nextOffset: page.nextOffset,
      hasMore: page.hasMore,
    );
  }

  factory MoneyEventsPageState.empty(String accountId) {
    return MoneyEventsPageState(
      accountId: accountId,
      events: const [],
      nextOffset: 0,
      hasMore: false,
    );
  }

  final String accountId;
  final List<MoneyEvent> events;
  final int nextOffset;
  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;

  MoneyEventsPageState copyWith({
    List<MoneyEvent>? events,
    int? nextOffset,
    bool? hasMore,
    bool? isLoadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return MoneyEventsPageState(
      accountId: accountId,
      events: events ?? this.events,
      nextOffset: nextOffset ?? this.nextOffset,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

MoneyEventsPage moneyEventsPageFromRows({
  required String accountId,
  required int offset,
  required int pageSize,
  required Iterable<Map<String, dynamic>> rows,
}) {
  if (accountId.isEmpty) {
    throw ArgumentError.value(accountId, 'accountId', 'Cannot be empty');
  }
  if (offset < 0) {
    throw ArgumentError.value(offset, 'offset', 'Cannot be negative');
  }
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive');
  }

  final parsed = rows.map(MoneyEvent.fromJson).toList(growable: false);
  if (parsed.any((event) => event.accountId != accountId)) {
    throw StateError('Money history returned data for another account.');
  }

  final visible = parsed.take(pageSize).toList(growable: false);
  return MoneyEventsPage(
    events: List<MoneyEvent>.unmodifiable(visible),
    nextOffset: offset + visible.length,
    hasMore: parsed.length > pageSize,
  );
}

List<MoneyEvent> mergeMoneyEventPages({
  required String accountId,
  required Iterable<MoneyEvent> existing,
  required Iterable<MoneyEvent> incoming,
}) {
  final byId = <String, MoneyEvent>{};
  for (final event in [...existing, ...incoming]) {
    if (event.accountId != accountId) {
      throw StateError('Money history returned data for another account.');
    }
    byId.putIfAbsent(event.id, () => event);
  }
  return List<MoneyEvent>.unmodifiable(byId.values);
}

abstract interface class MoneyEventsPageLoader {
  Future<MoneyEventsPage> loadPage({
    required String accountId,
    required int offset,
    required int pageSize,
  });
}

class SupabaseMoneyEventsPageLoader implements MoneyEventsPageLoader {
  SupabaseMoneyEventsPageLoader(this._client);

  final SupabaseClient _client;

  @override
  Future<MoneyEventsPage> loadPage({
    required String accountId,
    required int offset,
    required int pageSize,
  }) async {
    final rows = await _client
        .from('money_events')
        .select(
          'id, account_id, item_id, kind, amount_cents, currency, '
          'occurred_at, source_type, source_id, description',
        )
        .eq('account_id', accountId)
        .order('occurred_at', ascending: false)
        .order('id', ascending: false)
        .range(offset, offset + pageSize);

    return moneyEventsPageFromRows(
      accountId: accountId,
      offset: offset,
      pageSize: pageSize,
      rows: rows,
    );
  }
}

final moneyEventsPageLoaderProvider = Provider<MoneyEventsPageLoader>((ref) {
  return SupabaseMoneyEventsPageLoader(ref.watch(supabaseClientProvider));
});

/// Account-scoped, deterministic pages of `money_events`, newest first.
/// The all-row totals remain sourced independently from
/// [moneyTotalsProvider].
class MoneyEventsNotifier extends AsyncNotifier<MoneyEventsPageState> {
  var _generation = 0;

  @override
  Future<MoneyEventsPageState> build() async {
    final accountId = ref.watch(activeAccountProvider).id;
    final loader = ref.watch(moneyEventsPageLoaderProvider);
    _generation++;

    if (accountId.isEmpty) return MoneyEventsPageState.empty(accountId);

    final page = await loader.loadPage(
      accountId: accountId,
      offset: 0,
      pageSize: moneyEventsPageSize,
    );
    return MoneyEventsPageState.fromPage(accountId: accountId, page: page);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final generation = _generation;
    final accountId = current.accountId;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );

    try {
      final page = await ref
          .read(moneyEventsPageLoaderProvider)
          .loadPage(
            accountId: accountId,
            offset: current.nextOffset,
            pageSize: moneyEventsPageSize,
          );
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(activeAccountProvider).id != accountId) {
        return;
      }

      state = AsyncData(
        current.copyWith(
          events: mergeMoneyEventPages(
            accountId: accountId,
            existing: current.events,
            incoming: page.events,
          ),
          nextOffset: page.nextOffset,
          hasMore: page.hasMore,
          isLoadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (error) {
      if (!ref.mounted ||
          generation != _generation ||
          ref.read(activeAccountProvider).id != accountId) {
        return;
      }
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error),
      );
    }
  }
}

final moneyEventsProvider =
    AsyncNotifierProvider.autoDispose<
      MoneyEventsNotifier,
      MoneyEventsPageState
    >(MoneyEventsNotifier.new);

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
    required String requestId,
    String? description,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final payload = {
      'account_id': accountId,
      'kind': kind.name,
      'amount_cents': amountCents,
      'source_type': 'manual',
      'source_id': requestId,
      'description': description,
      'created_by': userId,
    };

    try {
      await _client.from('money_events').insert(payload);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;

      final existing = await _client
          .from('money_events')
          .select('kind, amount_cents, description')
          .eq('account_id', accountId)
          .eq('source_type', 'manual')
          .eq('source_id', requestId)
          .maybeSingle();
      final isSameRequest =
          existing != null &&
          existing['kind'] == kind.name &&
          existing['amount_cents'] == amountCents &&
          existing['description'] == description;
      if (!isSameRequest) rethrow;
    }
  }
}

final moneyEventsRepositoryProvider = Provider<MoneyEventsRepository>((ref) {
  return MoneyEventsRepository(ref.watch(supabaseClientProvider));
});
