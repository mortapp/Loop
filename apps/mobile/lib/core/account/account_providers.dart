import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'account_context.dart';

/// The list of accounts (personal + any business memberships) the
/// signed-in user can switch between — real Supabase data, mirroring
/// apps/web's `getActiveAccountSummary` (see active-account.ts). RLS's
/// `accounts_select_accessible` policy already scopes the `accounts` table
/// to rows this user can see, so no explicit filter is needed here: this
/// query IS the full set of accounts the user has access to.
///
/// Re-runs whenever auth state changes (sign-in/out), so switching users
/// never shows a stale account list from the previous session.
final availableAccountsProvider = FutureProvider<List<AccountSummary>>((
  ref,
) async {
  ref.watch(authStateChangesProvider);
  final client = ref.watch(supabaseClientProvider);

  if (client.auth.currentSession == null) {
    return const [];
  }

  final rows = await client
      .from('accounts')
      .select('id, type, businesses(name)');

  return (rows as List).map((row) {
    final type = row['type'] as String;
    final business = row['businesses'] as Map<String, dynamic>?;
    return AccountSummary(
      id: row['id'] as String,
      kind: type == 'business' ? AccountKind.business : AccountKind.personal,
      displayName: type == 'business'
          ? (business?['name'] as String? ?? 'Business')
          : 'Personal',
    );
  }).toList();
});

/// The currently active account the app is operating as. Controls which
/// businesses/contacts/items/documents/actions are in scope across MAKE,
/// PROTECT, and RECOVER.
///
/// Kept synchronous (`AccountSummary`, not `AsyncValue`) since ~20 screens
/// already read `.id`/`.displayName` off this provider directly. While
/// [availableAccountsProvider] is still loading (or the user has no
/// accounts, e.g. mid-sign-out), this returns an empty-id placeholder
/// rather than throwing — downstream `.eq('account_id', id)` queries just
/// return no rows for that brief window instead of crashing, and this
/// provider rebuilds with the real id the moment the accounts list
/// resolves (every dependent provider that watches it refreshes too).
class ActiveAccountNotifier extends Notifier<AccountSummary> {
  static const _loading = AccountSummary(
    id: '',
    kind: AccountKind.personal,
    displayName: 'Personal',
  );

  @override
  AccountSummary build() {
    final accounts = ref.watch(availableAccountsProvider).asData?.value;
    if (accounts == null || accounts.isEmpty) {
      return _loading;
    }
    return accounts.first;
  }

  void select(AccountSummary account) {
    state = account;
  }
}

final activeAccountProvider =
    NotifierProvider<ActiveAccountNotifier, AccountSummary>(
      ActiveAccountNotifier.new,
    );
