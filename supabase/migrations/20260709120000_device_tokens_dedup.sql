-- Duplicate FCM tokens across device rows caused market alerts to hit the same
-- physical device multiple times. A token identifies one install, so it must
-- live in exactly one row. This: (1) collapses existing duplicates, keeping the
-- most recently updated row per token, and (2) makes register_device_token drop
-- any other rows sharing the token so duplicates can't accumulate again (e.g.
-- when a reinstall changes identifierForVendor but FCM reuses the token).

-- 1. One-time cleanup: keep the newest row per fcm_token, delete the rest.
delete from public.device_tokens a
using public.device_tokens b
where a.fcm_token = b.fcm_token
  and (a.updated_at, a.device_id) < (b.updated_at, b.device_id);

-- 2. Registration now claims the token for the current device_id exclusively.
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
  delete from public.device_tokens
    where fcm_token = p_fcm_token and device_id <> p_device_id;

  insert into public.device_tokens (device_id, fcm_token, platform, notifications_enabled)
  values (p_device_id, p_fcm_token, p_platform, p_notifications_enabled)
  on conflict (device_id) do update
    set fcm_token = excluded.fcm_token,
        platform = excluded.platform,
        notifications_enabled = excluded.notifications_enabled,
        updated_at = now();
$$;
