-- Bind each approved AI tool call to one domain row. Provider retries may
-- repeat the confirmation request, but they must not repeat the write.

create unique index actions_ai_confirmation_idempotency_idx
  on public.actions (account_id, related_id)
  where related_type = 'ai_confirmation' and related_id is not null;

create unique index money_events_ai_confirmation_idempotency_idx
  on public.money_events (account_id, source_id)
  where source_type = 'ai' and source_id is not null;
