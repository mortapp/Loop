import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account/account_providers.dart';
import '../../core/supabase/supabase_providers.dart';
import 'models/action_item.dart';

/// The open/snoozed/done actions for the active account, sorted the same
/// way as `apps/web/src/app/(app)/today/page.tsx`: status, then due date
/// (soonest first, nulls last), then most-recently-created first.
///
/// `dismissed` rows are excluded at the query level, matching the web page.
final todayActionsProvider = FutureProvider.autoDispose<List<ActionItem>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  if (accountId.isNotEmpty) {
    // Best-effort: turn due quote/return/warranty deadlines into actions
    // before reading the list. A transient failure here (offline, RLS
    // edge case) should never block showing whatever actions already
    // exist — see supabase/migrations/20260822160000_today_automation.sql.
    try {
      await client.rpc(
        'generate_today_actions',
        params: {'p_account_id': accountId},
      );
    } catch (_) {
      // Ignored — see comment above.
    }
  }

  final rows = await client
      .from('actions')
      .select()
      .eq('account_id', accountId)
      .neq('status', 'dismissed')
      .order('status', ascending: true)
      .order('due_at', ascending: true, nullsFirst: false)
      .order('created_at', ascending: false);

  return rows.map(ActionItem.fromJson).toList();
});

/// Mutations against `public.actions`, kept outside the read provider so
/// screens can invalidate [todayActionsProvider] after a write the same
/// way the web app calls `revalidatePath("/today")` after each action.
class TodayActionsRepository {
  TodayActionsRepository(this._client);

  final SupabaseClient _client;

  Future<void> quickAdd({required String accountId, required String title}) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('actions').insert({
      'account_id': accountId,
      'type': 'manual',
      'title': title,
      'created_by': userId,
    });
  }

  Future<void> setStatus({required String id, required ActionStatus status}) {
    return _client
        .from('actions')
        .update({
          'status': status.name,
          'completed_at': status == ActionStatus.done
              ? DateTime.now().toIso8601String()
              : null,
        })
        .eq('id', id);
  }
}

final todayActionsRepositoryProvider = Provider<TodayActionsRepository>((ref) {
  return TodayActionsRepository(ref.watch(supabaseClientProvider));
});
