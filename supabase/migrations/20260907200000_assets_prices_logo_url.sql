-- assets_prices.logo_url — enstrümanın kendi logosu (mutlak URL).
--
-- Şu ana kadar uygulama kategori ikonu gösteriyordu: her kripto satırında aynı
-- turuncu ₿ duruyor, Bitcoin ile Solana ayırt edilemiyordu.
--
-- NULL, "logo yok" demektir; istemci o durumda mevcut kategori ikonuna düşer.
-- Boş string yerine NULL kullanılıyor ki "henüz bakılmadı" ile "bakıldı, yok"
-- ayrımı ileride ayrı bir kolonla yapılabilsin.
--
-- Fiyat yazan Edge Function'lar (bkz. _shared/prices.ts → upsertPrices) bu
-- kolonu payload'a koymuyor. PostgREST upsert'i ON CONFLICT DO UPDATE'i yalnızca
-- gönderilen kolonlar için üretiyor, dolayısıyla logo_url her fiyat
-- güncellemesinde ezilmez — logolar bir kez yazılır ve kalır.
alter table public.assets_prices
  add column if not exists logo_url text;

comment on column public.assets_prices.logo_url is
  'Enstrüman logosu (mutlak URL). NULL = logo yok; istemci kategori ikonuna düşer.';

-- Logolar üçüncü taraftan hotlink edilmiyor, kendi Storage'ımızdan servis
-- ediliyor. Üç sebep:
--   1. CoinGecko CDN'i Cache-Control göndermiyor (yalnızca ETag), bu yüzden
--      URLCache saklamıyor ve logo her görünümde yeniden iniyor.
--   2. Hotlink, her kullanıcının IP'sini üçüncü tarafa açar.
--   3. O uç yarın kapanırsa uygulamadaki bütün logolar birden kırılır.
-- Storage'a `cacheControl` ile yüklendiği için istemci tarafında düzgün
-- önbelleklenir.
insert into storage.buckets (id, name, public)
values ('asset-logos', 'asset-logos', true)
on conflict (id) do nothing;
