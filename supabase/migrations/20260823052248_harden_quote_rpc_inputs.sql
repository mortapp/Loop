-- Quote integrity: reject malformed lines, recompute totals server-side, and
-- derive the actor from Supabase Auth while preserving the existing RPC shape.

alter table public.quotes
  add constraint quotes_quote_number_length
  check (char_length(btrim(quote_number)) between 1 and 64);

alter table public.quotes
  add constraint quotes_amounts_consistent
  check (
    subtotal_cents >= 0
    and tax_cents >= 0
    and total_cents >= 0
    and total_cents = subtotal_cents + tax_cents
  );

alter table public.quote_line_items
  add constraint quote_line_items_description_valid
  check (
    char_length(btrim(description)) between 1 and 500
  );

alter table public.quote_line_items
  add constraint quote_line_items_quantity_bounds
  check (quantity > 0 and quantity <= 1000000);

alter table public.quote_line_items
  add constraint quote_line_items_unit_price_bounds
  check (unit_price_cents >= 0 and unit_price_cents <= 100000000000);

create or replace function public.create_quote_with_line_items(
  p_account_id uuid,
  p_contact_id uuid,
  p_opportunity_id uuid,
  p_quote_number text,
  p_subtotal_cents bigint,
  p_tax_cents bigint,
  p_total_cents bigint,
  p_created_by uuid,
  p_line_items jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_quote_id uuid;
  v_item jsonb;
  v_description text;
  v_quantity numeric;
  v_unit_price_cents bigint;
  v_calculated_subtotal numeric := 0;
begin
  if auth.uid() is null then
    raise exception using
      errcode = '42501',
      message = 'Authentication is required.';
  end if;

  if not public.has_account_access(p_account_id) then
    raise exception using
      errcode = '42501',
      message = 'The selected account is not available.';
  end if;

  if p_contact_id is null then
    raise exception using
      errcode = '22023',
      message = 'A contact is required.';
  end if;

  if p_quote_number is null
    or char_length(pg_catalog.btrim(p_quote_number)) not between 1 and 64 then
    raise exception using
      errcode = '22023',
      message = 'The quote number is invalid.';
  end if;

  if pg_catalog.jsonb_typeof(p_line_items) is distinct from 'array' then
    raise exception using
      errcode = '22023',
      message = 'Quote lines must be an array.';
  end if;

  if pg_catalog.jsonb_array_length(p_line_items) = 0 then
    raise exception 'create_quote_with_line_items: at least one line item is required';
  end if;

  if pg_catalog.jsonb_array_length(p_line_items) > 100 then
    raise exception using
      errcode = '22023',
      message = 'A quote can contain at most 100 lines.';
  end if;

  for v_item in
    select value from pg_catalog.jsonb_array_elements(p_line_items)
  loop
    begin
      v_description := pg_catalog.btrim(v_item ->> 'description');
      v_quantity := (v_item ->> 'quantity')::numeric;
      v_unit_price_cents := (v_item ->> 'unit_price_cents')::bigint;
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception using
          errcode = '22023',
          message = 'A quote line contains invalid values.';
    end;

    if v_description is null
      or char_length(v_description) not between 1 and 500
      or v_quantity is null
      or v_quantity <= 0
      or v_quantity > 1000000
      or v_unit_price_cents is null
      or v_unit_price_cents < 0
      or v_unit_price_cents > 100000000000 then
      raise exception using
        errcode = '22023',
        message = 'A quote line contains invalid values.';
    end if;

    v_calculated_subtotal := v_calculated_subtotal
      + pg_catalog.round(v_quantity * v_unit_price_cents);
  end loop;

  if v_calculated_subtotal > 9223372036854775807
    or p_subtotal_cents is null
    or p_subtotal_cents::numeric <> v_calculated_subtotal
    or p_tax_cents is null
    or p_tax_cents < 0
    or p_total_cents is null
    or p_total_cents::numeric <> v_calculated_subtotal + p_tax_cents then
    raise exception using
      errcode = '22023',
      message = 'Quote totals do not match the line items.';
  end if;

  insert into public.quotes (
    account_id,
    contact_id,
    opportunity_id,
    quote_number,
    subtotal_cents,
    tax_cents,
    total_cents,
    created_by
  )
  values (
    p_account_id,
    p_contact_id,
    p_opportunity_id,
    pg_catalog.btrim(p_quote_number),
    p_subtotal_cents,
    p_tax_cents,
    p_total_cents,
    auth.uid()
  )
  returning id into v_quote_id;

  insert into public.quote_line_items (
    quote_id,
    description,
    quantity,
    unit_price_cents,
    position
  )
  select
    v_quote_id,
    pg_catalog.btrim(item ->> 'description'),
    (item ->> 'quantity')::numeric,
    (item ->> 'unit_price_cents')::bigint,
    (line_ordinality - 1)::integer
  from pg_catalog.jsonb_array_elements(p_line_items)
    with ordinality as parsed(item, line_ordinality);

  return v_quote_id;
end;
$$;

revoke execute on function public.create_quote_with_line_items(
  uuid, uuid, uuid, text, bigint, bigint, bigint, uuid, jsonb
) from public, anon;
grant execute on function public.create_quote_with_line_items(
  uuid, uuid, uuid, text, bigint, bigint, bigint, uuid, jsonb
) to authenticated;
