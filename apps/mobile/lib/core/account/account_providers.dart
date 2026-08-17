import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_context.dart';

/// The list of accounts (personal + any business memberships) the
/// signed-in user can switch between.
///
/// Placeholder implementation: returns a single personal account until the
/// Supabase-backed membership query is wired up. Kept as a provider so the
/// Business tab / account switcher UI can already be built against the
/// real shape.
final availableAccountsProvider = Provider<List<AccountSummary>>((ref) {
  return const [
    AccountSummary(
      id: 'personal',
      kind: AccountKind.personal,
      displayName: 'Personal',
    ),
  ];
});

/// The currently active account the app is operating as. Controls which
/// businesses/contacts/items/documents/actions are in scope across MAKE,
/// PROTECT, and RECOVER.
class ActiveAccountNotifier extends Notifier<AccountSummary> {
  @override
  AccountSummary build() {
    return ref.watch(availableAccountsProvider).first;
  }

  void select(AccountSummary account) {
    state = account;
  }
}

final activeAccountProvider =
    NotifierProvider<ActiveAccountNotifier, AccountSummary>(
      ActiveAccountNotifier.new,
    );
