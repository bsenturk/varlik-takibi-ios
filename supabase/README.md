# Supabase backend — TEFAS funds

Adds a searchable TEFAS fund catalog and keeps fund prices in `assets_prices`
so the iOS app (a thin client) can list, search and value funds.

```
supabase/
├── migrations/
│   └── 20260607120000_tefas_funds.sql   # tefas_funds table + search_funds() RPC
└── functions/
    ├── _shared/{tefas.ts, cors.ts}      # TEFAS client + helpers
    ├── tefas-sync/index.ts              # daily catalog + price refresh (cron)
    └── tefas-search/index.ts            # on-demand search for the app
```

## Data model

- **`tefas_funds`** — full catalog (one row per fund `code`), refreshed daily by
  `tefas-sync`. Holds the latest `price`, `investor_count` and an `is_popular`
  flag (top-10 by investors).
- **`assets_prices`** — existing prices table. `tefas-sync`/`tefas-search` mirror
  **popular + user-tracked + searched** funds here (`asset_type = 'fund'`,
  `symbol = fund code`, `currency = 'TRY'`), so the app values them like any
  other asset.

> ⚠️ The mirror upserts use `onConflict: "symbol,currency"`. Ensure
> `assets_prices` has a unique constraint on `(symbol, currency)`:
> ```sql
> alter table public.assets_prices
>   add constraint assets_prices_symbol_currency_key unique (symbol, currency);
> ```

## Deploy

```bash
# from the repo root (supabase CLI already installed)
supabase link --project-ref bpiclzhpxkmnqxqvlnmu      # one-time

# 1. Apply the migration (table + search_funds RPC)
supabase db push

# 2. Set the function secrets
supabase secrets set SYNC_SECRET="<a-random-string>"
#   (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are injected automatically)

# 3. Deploy the functions
supabase functions deploy tefas-sync
supabase functions deploy tefas-search --no-verify-jwt   # called by anon app

# 4. Seed the catalog now (first run populates funds + popular flags)
curl -X POST "https://bpiclzhpxkmnqxqvlnmu.functions.supabase.co/tefas-sync" \
     -H "x-sync-secret: <the-SYNC_SECRET>"
```

## Schedule the daily refresh

TEFAS publishes the previous day's prices each evening. Schedule `tefas-sync`
~19:00 Europe/Istanbul using `pg_cron` + `pg_net`:

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'tefas-daily-sync',
  '0 16 * * *',                          -- 16:00 UTC ≈ 19:00 TR
  $$
  select net.http_post(
    url     := 'https://bpiclzhpxkmnqxqvlnmu.functions.supabase.co/tefas-sync',
    headers := jsonb_build_object('x-sync-secret', '<the-SYNC_SECRET>')
  );
  $$
);
```

## How the app uses it

- **Popular 10 (empty search):** `search_funds('')` RPC, or
  `GET /tefas-search?q=`.
- **Search:** `GET /functions/v1/tefas-search?q=<text>` → returns matching funds
  **and** mirrors their prices into `assets_prices`, so a selected fund is
  immediately priceable by `MarketDataManager`.
- Alternatively the app can call the `search_funds(q)` RPC directly via the
  Supabase client for catalog-only results.

> The iOS side currently reads funds from `assets_prices` (the popular 10).
> Wiring the search bar to call `tefas-search` for the long tail is the next
> client-side step.
