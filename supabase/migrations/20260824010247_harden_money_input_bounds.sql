-- Keep every client-controlled money value inside LOOP's documented
-- $1,000,000,000 product bound. Client validation is UX; these constraints
-- are the authority for modified APKs and direct Data API callers.

alter table public.money_events
  add constraint money_events_amount_cents_max
  check (amount_cents <= 100000000000);

alter table public.opportunities
  add constraint opportunities_estimated_value_valid
  check (
    estimated_value_cents is null
    or estimated_value_cents between 0 and 100000000000
  );

create unique index money_events_manual_request_id_idx
  on public.money_events (account_id, source_id)
  where source_type = 'manual' and source_id is not null;
