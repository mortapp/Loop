/// Status values for a row in `public.actions`, the unified queue that
/// powers the Today engine across MAKE/PROTECT/RECOVER.
enum ActionStatus { open, snoozed, done, dismissed }

ActionStatus actionStatusFromString(String value) {
  return ActionStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => ActionStatus.open,
  );
}

/// A single row from `public.actions`.
///
/// Mirrors `apps/web/src/app/(app)/today/page.tsx`'s `Action` shape — a
/// plain shared task list today, with `related_type`/`related_id` reserved
/// for future auto-generated rows (expiring returns, quotes to send, ...).
class ActionItem {
  const ActionItem({
    required this.id,
    required this.accountId,
    required this.type,
    required this.title,
    this.description,
    required this.status,
    this.dueAt,
    this.relatedType,
    this.relatedId,
    required this.createdAt,
    this.completedAt,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: actionStatusFromString(json['status'] as String),
      dueAt: json['due_at'] == null
          ? null
          : DateTime.parse(json['due_at'] as String),
      relatedType: json['related_type'] as String?,
      relatedId: json['related_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
    );
  }

  final String id;
  final String accountId;
  final String type;
  final String title;
  final String? description;
  final ActionStatus status;
  final DateTime? dueAt;
  final String? relatedType;
  final String? relatedId;
  final DateTime createdAt;
  final DateTime? completedAt;
}
