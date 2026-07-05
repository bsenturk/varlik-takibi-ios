-- Anon INSERT/UPDATE policies alone aren't enough: Postgres's
-- `INSERT ... ON CONFLICT DO UPDATE` (used by the client's upsert) needs to
-- read the conflicting row too, which requires a SELECT policy under RLS.
-- Rather than let anon SELECT the whole table (leaking every device's FCM
-- token), lock the table down and expose two narrow SECURITY DEFINER RPCs
-- that do the write as the function owner, bypassing RLS.

drop policy if exists "anon can insert device tokens" on public.device_tokens;
drop policy if exists "anon can update device tokens" on public.device_tokens;

create or replace function public.register_device_token(
  p_device_id text,
  p_fcm_token text,
  p_platform text default 'ios',
  p_notifications_enabled boolean default true
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.device_tokens (device_id, fcm_token, platform, notifications_enabled)
  values (p_device_id, p_fcm_token, p_platform, p_notifications_enabled)
  on conflict (device_id) do update
    set fcm_token = excluded.fcm_token,
        platform = excluded.platform,
        notifications_enabled = excluded.notifications_enabled,
        updated_at = now();
$$;

grant execute on function public.register_device_token(text, text, text, boolean) to anon;

create or replace function public.set_device_token_enabled(
  p_device_id text,
  p_enabled boolean
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.device_tokens
  set notifications_enabled = p_enabled, updated_at = now()
  where device_id = p_device_id;
$$;

grant execute on function public.set_device_token_enabled(text, boolean) to anon;
