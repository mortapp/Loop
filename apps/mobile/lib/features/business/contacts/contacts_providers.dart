import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'models/contact.dart';

/// Every contact for the active account, newest first — mirrors
/// `apps/web/src/app/(app)/business/contacts/page.tsx`.
final contactsProvider = FutureProvider.autoDispose<List<Contact>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  final rows = await client
      .from('contacts')
      .select()
      .eq('account_id', accountId)
      .order('created_at', ascending: false);

  return rows.map(Contact.fromJson).toList();
});

/// Lightweight `(id, display_name)` contact list for populating pickers on
/// the leads/opportunities/quotes forms — mirrors the same query those
/// web pages run alongside their own domain fetch.
final contactRefsProvider = FutureProvider.autoDispose<List<ContactRef>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final accountId = ref.watch(activeAccountProvider).id;

  final rows = await client
      .from('contacts')
      .select('id, display_name')
      .eq('account_id', accountId)
      .order('display_name', ascending: true);

  return rows.map(ContactRef.fromJson).toList();
});

class ContactsRepository {
  ContactsRepository(this._client);

  final SupabaseClient _client;

  Future<void> createContact({
    required String accountId,
    required String displayName,
    String? email,
    String? phone,
    String? company,
  }) {
    final userId = _client.auth.currentUser?.id;
    return _client.from('contacts').insert({
      'account_id': accountId,
      'display_name': displayName,
      'email': email,
      'phone': phone,
      'company': company,
      'created_by': userId,
    });
  }
}

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.watch(supabaseClientProvider));
});
