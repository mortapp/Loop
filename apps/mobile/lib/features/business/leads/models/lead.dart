/// Status values for a row in `public.leads`.
enum LeadStatus { new_, contacted, qualified, disqualified, converted }

const leadStatusOptions = [
  LeadStatus.new_,
  LeadStatus.contacted,
  LeadStatus.qualified,
  LeadStatus.disqualified,
  LeadStatus.converted,
];

String leadStatusToDbValue(LeadStatus status) =>
    status == LeadStatus.new_ ? 'new' : status.name;

LeadStatus leadStatusFromString(String value) {
  if (value == 'new') return LeadStatus.new_;
  return leadStatusOptions.firstWhere(
    (s) => s.name == value,
    orElse: () => LeadStatus.new_,
  );
}

/// Display label for a status — undoes the `new_` -> `new` Dart keyword
/// dodge from [leadStatusToDbValue].
String leadStatusLabel(LeadStatus status) =>
    status == LeadStatus.new_ ? 'new' : status.name;

/// A single row from `public.leads`, joined to its contact's display name
/// (mirrors the `contacts(id, display_name)` embed in
/// `apps/web/src/app/(app)/business/leads/page.tsx`).
class Lead {
  const Lead({
    required this.id,
    required this.status,
    this.source,
    this.notes,
    this.contactDisplayName,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    final contactsJoin = json['contacts'] as Map<String, dynamic>?;
    return Lead(
      id: json['id'] as String,
      status: leadStatusFromString(json['status'] as String),
      source: json['source'] as String?,
      notes: json['notes'] as String?,
      contactDisplayName: contactsJoin?['display_name'] as String?,
    );
  }

  final String id;
  final LeadStatus status;
  final String? source;
  final String? notes;
  final String? contactDisplayName;
}
