-- Device push tokens for broadcast notifications (market alerts etc).
-- The app is anonymous (no Supabase Auth), so devices are identified by
-- their `identifierForVendor` UUID rather than a user id.

create table if not exists public.device_tokens (
  device_id text primary key,
  fcm_token text not null,
  platform text not null default 'ios',
  notifications_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.device_tokens enable row level security;

-- Anonymous clients may register/update their own token. There is no way to
-- scope this to "own row" without auth, matching the rest of this app's
-- anonymous architecture; only SELECT is withheld from anon so devices can't
-- enumerate each other's tokens. Reading the table (to send pushes) is done
-- by edge functions using the service_role key, which bypasses RLS.
create policy "anon can insert device tokens"
  on public.device_tokens for insert
  to anon
  with check (true);

create policy "anon can update device tokens"
  on public.device_tokens for update
  to anon
  using (true)
  with check (true);
