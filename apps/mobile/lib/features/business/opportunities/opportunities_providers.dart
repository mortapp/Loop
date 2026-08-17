import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'models/opportunity.dart';

/// Every opportunity for the active account, newest first, joined to its
/// contact's name — mirrors
/// `apps/web/src/app/(app)/business/opportunities/page.tsx`.
final opportunitiesProvider = FutureProvider.autoDispose<List<Opportunity>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  final rows = await client
      .from('opportunities')
      .select(
        'id, title, stage, estimated_value_cents, contacts(id, display_name)',
      )
      .eq('account_id', accountId)
      .order('created_at', ascending: false);

  return rows.map(Opportunity.fromJson).toList();
});

/// Minimal `(id, title)` reference list for the quote form's "linked
/// opportunity" picker.
class OpportunityRef {
  const OpportunityRef({required this.id, required this.title});

  factory OpportunityRef.fromJson(Map<String, dynamic> json) {
    return OpportunityRef(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }

  final String id;
  final String title;
}

final opportunityRefsProvider =
    FutureProvider.autoDispose<List<OpportunityRef>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      final accountId = ref.watch(activeAccountProvider).id;

      final rows = await client
          .from('opportunities')
          .select('id, title')
          .eq('account_id', accountId)
          .order('created_at', ascending: false);

      return rows.map(OpportunityRef.fromJson).toList();
    });

class OpportunitiesRepository {
  OpportunitiesRepository(this._client);

  final SupabaseClient _client;

  Future<void> createOpportunity({
    required String accountId,
    required String contactId,
    required String title,
    int? estimatedValueCents,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('opportunities').insert({
      'account_id': accountId,
      'contact_id': contactId,
      'title': title,
      'estimated_value_cents': estimatedValueCents,
      'created_by': userId,
    });
  }

  Future<void> setStage({required String id, required OpportunityStage stage}) {
    return _client
        .from('opportunities')
        .update({'stage': opportunityStageToDbValue(stage)})
        .eq('id', id);
  }
}

final opportunitiesRepositoryProvider = Provider<OpportunitiesRepository>((
  ref,
) {
  return OpportunitiesRepository(ref.watch(supabaseClientProvider));
});
