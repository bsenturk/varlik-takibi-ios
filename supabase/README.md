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

# Push notifications

Broadcasts a push to every device that has notifications enabled (e.g. for
market fluctuation alerts). The app is anonymous, so devices register
themselves by `identifierForVendor`, not by user account.

```
supabase/
├── migrations/
│   └── 20260705120000_device_tokens.sql   # device_tokens table + RLS
└── functions/
    ├── send-push-notification/index.ts    # broadcasts via FCM HTTP v1
    └── market-alert/index.ts              # daily gold/USD/BIST 100 check (cron)
```

## Data model

- **`device_tokens`** — one row per device (`device_id` = `identifierForVendor`),
  holding its current FCM token and `notifications_enabled` (kept in sync by
  the app whenever the user grants/revokes notification permission).

## iOS side

Already wired up: `AppDelegate` registers for remote notifications once
permission is granted, receives the FCM token via `MessagingDelegate`, and
`PushTokenService` upserts it into `device_tokens`.

## One-time setup (Firebase + Apple Developer)

1. **Apple Developer Portal**: on the App ID (`com.xptapps.assetbook`), enable
   the **Push Notifications** capability. (`MyGolds/MyGolds.entitlements`
   already has `aps-environment` on the client, just needs the portal-side
   capability + a re-provisioned profile.)
2. **Firebase Console → Project settings → Cloud Messaging**: upload the APNs
   Auth Key (`.p8`) so FCM can deliver to iOS. This app's Firebase project is
   `varlikdefterim`.
3. **Firebase Console → Project settings → Service accounts**: generate a new
   private key (JSON) for a service account with the "Firebase Cloud
   Messaging API" role — this is `FCM_SERVICE_ACCOUNT_JSON` below.

## Deploy

```bash
supabase link --project-ref bpiclzhpxkmnqxqvlnmu      # if not already linked

# 1. Apply the migration (device_tokens table)
supabase db push

# 2. Set the function secrets
supabase secrets set FCM_PROJECT_ID="varlikdefterim"
supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
supabase secrets set PUSH_SECRET="<a-random-string>"

# 3. Deploy the function
supabase functions deploy send-push-notification

# 4. Deploy the daily market-alert checker (calls send-push-notification internally)
supabase functions deploy market-alert

# 5. Send a one-off broadcast (manual test)
curl -X POST "https://bpiclzhpxkmnqxqvlnmu.functions.supabase.co/send-push-notification" \
     -H "x-push-secret: <the-PUSH_SECRET>" \
     -H "Content-Type: application/json" \
     -d '{"title": "Altın yükselişte 📈", "body": "Son 1 saatte %2 arttı."}'
```

## Daily market-fluctuation alert

`market-alert` checks gold (`GRAM_ALTIN/TRY`), USD/TRY (both from
`assets_prices`) and the BIST 100 index (fetched directly from Yahoo
Finance, since only individual BIST stocks — not the index — live in
`assets_prices`). If any moved **±1.5% or more** that day, it calls
`send-push-notification` with a fixed title (`"Piyasalarda hareketlilik"`)
and body
(`"📈 Piyasalarda hareketlilik var, portföyünüzü kontrol etmeyi unutmayın."`).
If nothing crossed the threshold, it sends nothing.

Reuses the `SYNC_SECRET` guard (same convention as `tefas-sync`) and calls
`send-push-notification` using `PUSH_SECRET` — both must be set (see step 2
above; add `supabase secrets set SYNC_SECRET="<a-random-string>"` if not
already set from the TEFAS setup).

Schedule it once a day, after BIST closes (18:00 Europe/Istanbul):

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'daily-market-alert',
  '30 15 * * *',                          -- 15:30 UTC ≈ 18:30 TR
  $$
  select net.http_post(
    url     := 'https://bpiclzhpxkmnqxqvlnmu.functions.supabase.co/market-alert',
    headers := jsonb_build_object('x-sync-secret', '<the-SYNC_SECRET>')
  );
  $$
);
```
