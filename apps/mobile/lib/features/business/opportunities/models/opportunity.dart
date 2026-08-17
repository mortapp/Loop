/// Stage values for a row in `public.opportunities`.
enum OpportunityStage { new_, qualifying, quoted, negotiating, won, lost }

const opportunityStageOptions = [
  OpportunityStage.new_,
  OpportunityStage.qualifying,
  OpportunityStage.quoted,
  OpportunityStage.negotiating,
  OpportunityStage.won,
  OpportunityStage.lost,
];

String opportunityStageToDbValue(OpportunityStage stage) =>
    stage == OpportunityStage.new_ ? 'new' : stage.name;

String opportunityStageLabel(OpportunityStage stage) =>
    opportunityStageToDbValue(stage);

OpportunityStage opportunityStageFromString(String value) {
  if (value == 'new') return OpportunityStage.new_;
  return opportunityStageOptions.firstWhere(
    (s) => s.name == value,
    orElse: () => OpportunityStage.new_,
  );
}

/// A single row from `public.opportunities`, joined to its contact's
/// display name — mirrors
/// `apps/web/src/app/(app)/business/opportunities/page.tsx`.
class Opportunity {
  const Opportunity({
    required this.id,
    required this.title,
    required this.stage,
    this.estimatedValueCents,
    this.contactDisplayName,
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    final contactsJoin = json['contacts'] as Map<String, dynamic>?;
    return Opportunity(
      id: json['id'] as String,
      title: json['title'] as String,
      stage: opportunityStageFromString(json['stage'] as String),
      estimatedValueCents: (json['estimated_value_cents'] as num?)?.toInt(),
      contactDisplayName: contactsJoin?['display_name'] as String?,
    );
  }

  final String id;
  final String title;
  final OpportunityStage stage;
  final int? estimatedValueCents;
  final String? contactDisplayName;
}
