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
  final userId = client.auth.currentUser?.id;

  if (client.auth.currentSession == null || userId == null) {
    return const [];
  }

  final results = await Future.wait([
    client.from('accounts').select('id, type, business_id, businesses(name)'),
    client
        .from('business_members')
        .select('business_id, role')
        .eq('profile_id', userId)
        .eq('status', 'active'),
  ]);

  final roleByBusinessId = <String, String>{
    for (final row in results[1])
      row['business_id'] as String: row['role'] as String,
  };

  final accounts = results[0].map((row) {
    final type = row['type'] as String;
    final business = row['businesses'] as Map<String, dynamic>?;
    final businessId = row['business_id'] as String?;
    return AccountSummary(
      id: row['id'] as String,
      kind: type == 'business' ? AccountKind.business : AccountKind.personal,
      displayName: type == 'business'
          ? (business?['name'] as String? ?? 'Business')
          : 'Personal',
      role: businessId == null ? null : roleByBusinessId[businessId],
    );
  }).toList();

  accounts.sort((left, right) {
    if (left.kind != right.kind) return left.isPersonal ? -1 : 1;
    return left.displayName.toLowerCase().compareTo(
      right.displayName.toLowerCase(),
    );
  });
  return accounts;
});

/// Keeps a selected account when it remains accessible, otherwise falls back
/// deterministically to the first account. Extracted for regression testing.
AccountSummary? resolveActiveAccount(
  List<AccountSummary> accounts,
  String? selectedAccountId,
) {
  if (accounts.isEmpty) return null;
  if (selectedAccountId != null) {
    for (final account in accounts) {
      if (account.id == selectedAccountId) return account;
    }
  }
  return accounts.first;
}

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

  String? _selectedAccountId;

  @override
  AccountSummary build() {
    final accounts = ref.watch(availableAccountsProvider).asData?.value;
    if (accounts == null || accounts.isEmpty) {
      return _loading;
    }
    final selected = resolveActiveAccount(accounts, _selectedAccountId)!;
    _selectedAccountId = selected.id;
    return selected;
  }

  void select(AccountSummary account) {
    final accessible = ref.read(availableAccountsProvider).asData?.value;
    final selected = accessible == null
        ? null
        : resolveActiveAccount(
            accessible
                .where((candidate) => candidate.id == account.id)
                .toList(),
            account.id,
          );
    if (selected == null) {
      throw ArgumentError.value(
        account.id,
        'account',
        'Account is not accessible',
      );
    }
    _selectedAccountId = selected.id;
    state = selected;
  }
}

final activeAccountProvider =
    NotifierProvider<ActiveAccountNotifier, AccountSummary>(
      ActiveAccountNotifier.new,
    );
