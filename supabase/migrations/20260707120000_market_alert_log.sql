-- One row per day the market-alert push was sent, so the same day never gets
-- a second alert. The cron job (see supabase/README.md) checks this table
-- before invoking the edge function, so once today's alert has gone out the
-- function isn't called again for the rest of the 10:00–14:00 window.

create table if not exists public.market_alert_log (
  alert_date date primary key default current_date,
  created_at timestamptz not null default now()
);

alter table public.market_alert_log enable row level security;
-- No policies: only edge functions (service_role, bypasses RLS) touch this.
