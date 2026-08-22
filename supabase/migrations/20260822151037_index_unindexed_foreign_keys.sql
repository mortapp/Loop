-- Performance advisor: covering indexes for every FK the linter flagged.
-- Several of these are on columns actually used in join/embed queries
-- today (contact_id, opportunity_id, purchase_id, listing_id, ...); the
-- created_by/assigned_to/invited_by ones are lower-traffic but still
-- standard practice for any FK (avoids a full table scan on the
-- referenced table's UPDATE/DELETE checks as data grows).

create index if not exists actions_assigned_to_idx on public.actions (assigned_to);
create index if not exists actions_created_by_idx on public.actions (created_by);

create index if not exists business_members_invited_by_idx on public.business_members (invited_by);
create index if not exists business_members_profile_id_idx on public.business_members (profile_id);

create index if not exists businesses_created_by_idx on public.businesses (created_by);

create index if not exists contacts_created_by_idx on public.contacts (created_by);

create index if not exists documents_created_by_idx on public.documents (created_by);

create index if not exists events_actor_profile_id_idx on public.events (actor_profile_id);

create index if not exists items_created_by_idx on public.items (created_by);

create index if not exists leads_contact_id_idx on public.leads (contact_id);
create index if not exists leads_created_by_idx on public.leads (created_by);

create index if not exists listings_created_by_idx on public.listings (created_by);

create index if not exists money_events_created_by_idx on public.money_events (created_by);

create index if not exists opportunities_contact_id_idx on public.opportunities (contact_id);
create index if not exists opportunities_created_by_idx on public.opportunities (created_by);
create index if not exists opportunities_lead_id_idx on public.opportunities (lead_id);

create index if not exists purchases_created_by_idx on public.purchases (created_by);
create index if not exists purchases_receipt_document_id_idx on public.purchases (receipt_document_id);
create index if not exists purchases_vendor_contact_id_idx on public.purchases (vendor_contact_id);

create index if not exists quotes_contact_id_idx on public.quotes (contact_id);
create index if not exists quotes_created_by_idx on public.quotes (created_by);
create index if not exists quotes_opportunity_id_idx on public.quotes (opportunity_id);

create index if not exists returns_created_by_idx on public.returns (created_by);
create index if not exists returns_purchase_id_idx on public.returns (purchase_id);

create index if not exists sales_buyer_contact_id_idx on public.sales (buyer_contact_id);
create index if not exists sales_created_by_idx on public.sales (created_by);
create index if not exists sales_listing_id_idx on public.sales (listing_id);

create index if not exists valuations_created_by_idx on public.valuations (created_by);

create index if not exists warranties_created_by_idx on public.warranties (created_by);
