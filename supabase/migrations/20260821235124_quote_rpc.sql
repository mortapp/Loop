-- Wraps quote header + line item creation in a single transaction.
--
-- Previously apps/web did this as two sequential inserts from the client
-- (see docs/KNOWN_ISSUES.md "Quote creation is not transactional"): a
-- failure between the two left a quote with no line items. A plpgsql
-- function body is one transaction, so either both rows land or neither
-- does.
--
-- security invoker (the default, made explicit here) is intentional: this
-- must run as the calling `authenticated` role so the existing RLS
-- policies on quotes/quote_line_items are still enforced. This function
-- is a transaction boundary, not a privilege escalation.

create or replace function public.create_quote_with_line_items(
  p_account_id uuid,
  p_contact_id uuid,
  p_opportunity_id uuid,
  p_quote_number text,
  p_subtotal_cents bigint,
  p_tax_cents bigint,
  p_total_cents bigint,
  p_created_by uuid,
  p_line_items jsonb -- array of {"description": text, "quantity": numeric, "unit_price_cents": bigint}
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_quote_id uuid;
begin
  if jsonb_array_length(p_line_items) = 0 then
    raise exception 'create_quote_with_line_items: at least one line item is required';
  end if;

  insert into public.quotes (
    account_id, contact_id, opportunity_id, quote_number,
    subtotal_cents, tax_cents, total_cents, created_by
  )
  values (
    p_account_id, p_contact_id, p_opportunity_id, p_quote_number,
    p_subtotal_cents, p_tax_cents, p_total_cents, p_created_by
  )
  returning id into v_quote_id;

  insert into public.quote_line_items (quote_id, description, quantity, unit_price_cents, position)
  select
    v_quote_id,
    item ->> 'description',
    (item ->> 'quantity')::numeric,
    (item ->> 'unit_price_cents')::bigint,
    (line_ordinality - 1)::int
  from jsonb_array_elements(p_line_items) with ordinality as t(item, line_ordinality);

  return v_quote_id;
end;
$$;

grant execute on function public.create_quote_with_line_items(
  uuid, uuid, uuid, text, bigint, bigint, bigint, uuid, jsonb
) to authenticated;
