-- Supabase-hosted projects include this platform-owned event-trigger helper,
-- but the local CLI image does not. A later immutable migration revokes its
-- client execution privileges. Define an unattached local compatibility shim
-- before migrations so fresh local/CI replay matches the hosted baseline.
do $bootstrap$
begin
  if pg_catalog.to_regprocedure('public.rls_auto_enable()') is null then
    execute $definition$
      create function public.rls_auto_enable()
      returns event_trigger
      language plpgsql
      security definer
      set search_path = ''
      as $function$
      begin
        null;
      end;
      $function$
    $definition$;
  end if;
end
$bootstrap$;
