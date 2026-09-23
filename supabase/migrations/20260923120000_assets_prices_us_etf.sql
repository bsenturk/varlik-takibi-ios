-- ABD ETF'leri (Pro) ayrı bir asset_type ile yazılıyor: 'us_etf'.
--
-- assets_prices'taki kısıt bu türü reddediyordu ("violates check constraint
-- assets_prices_asset_type_check"). Kısıt yeniden kuruluyor; mevcut
-- türlerin listesi 2026-09-23'te tablodaki gerçek değerlerden alındı
-- (bist, fund, us_stock, crypto, currency, gold). Listede olmayan bir satır
-- olsaydı ADD CONSTRAINT başarısız olur ve migration bütünüyle geri alınırdı.

alter table public.assets_prices
  drop constraint if exists assets_prices_asset_type_check;

alter table public.assets_prices
  add constraint assets_prices_asset_type_check
  check (asset_type in ('crypto', 'currency', 'gold', 'bist', 'us_stock', 'us_etf', 'fund'));
