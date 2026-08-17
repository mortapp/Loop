import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'models/lead.dart';

/// Every lead for the active account, newest first, joined to its
/// contact's name — mirrors
/// `apps/web/src/app/(app)/business/leads/page.tsx`.
final leadsProvider = FutureProvider.autoDispose<List<Lead>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  final rows = await client
      .from('leads')
      .select('id, status, source, notes, contacts(id, display_name)')
      .eq('account_id', accountId)
      .order('created_at', ascending: false);

  return rows.map(Lead.fromJson).toList();
});

class LeadsRepository {
  LeadsRepository(this._client);

  final SupabaseClient _client;

  Future<void> createLead({
    required String accountId,
    required String contactId,
    String? source,
    String? notes,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('leads').insert({
      'account_id': accountId,
      'contact_id': contactId,
      'source': source,
      'notes': notes,
      'created_by': userId,
    });
  }

  Future<void> setStatus({required String id, required LeadStatus status}) {
    return _client
        .from('leads')
        .update({'status': leadStatusToDbValue(status)})
        .eq('id', id);
  }
}

final leadsRepositoryProvider = Provider<LeadsRepository>((ref) {
  return LeadsRepository(ref.watch(supabaseClientProvider));
});
