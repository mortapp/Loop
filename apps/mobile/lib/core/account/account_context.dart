/// The kind of account a user is currently acting as.
///
/// Every LOOP user has exactly one personal account and may additionally
/// belong to zero or more business accounts. The app always operates in
/// the context of one selected account at a time (the "active" account),
/// which scopes what businesses/contacts/items/documents/actions are
/// visible across MAKE, PROTECT, and RECOVER.
enum AccountKind { personal, business }

/// A single account a signed-in user can act as — either their own
/// personal account, or a business account they hold membership in.
///
/// This is a placeholder/interface shape for the account-switcher: no
/// live Supabase data is wired up yet, but the navigation shell and
/// Business tab are built against this model so the real data layer can
/// slot in later without reshaping the UI.
class AccountSummary {
  const AccountSummary({
    required this.id,
    required this.kind,
    required this.displayName,
    this.role,
  });

  /// Stable identifier for the account (personal account id, or business
  /// account id).
  final String id;

  final AccountKind kind;

  /// Human-readable name shown in the account switcher (e.g. a person's
  /// name for personal accounts, or a business name).
  final String displayName;

  /// The signed-in user's role within this account, when it's a business
  /// account (e.g. "Owner", "Member"). Null for personal accounts.
  final String? role;

  bool get isPersonal => kind == AccountKind.personal;
  bool get isBusiness => kind == AccountKind.business;
}
