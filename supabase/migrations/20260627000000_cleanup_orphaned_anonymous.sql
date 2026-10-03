-- Migration: Cleanup orphaned anonymous users
-- Description: Removes anonymous auth.users rows inactive for 30+ days
-- plus cascaded data in favorite_buildings, notifications, etc.
-- Called by cleanup-cron Edge Function via supabase.rpc().

create or replace function public.cleanup_orphaned_anonymous_users()
returns table (deleted_count bigint)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count bigint;
begin
  delete from auth.users
  where is_anonymous = true
    and coalesce(last_sign_in_at, created_at) < now() - interval '30 days'
    and id not in (
      select user_id from auth.identities where provider = 'email'
    );

  get diagnostics v_count = row_count;
  return query select v_count;
end;
$$;
