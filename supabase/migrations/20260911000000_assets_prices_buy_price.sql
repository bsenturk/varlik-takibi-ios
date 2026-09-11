-- Gerçek alış/satış makası. `price` satış fiyatı (Truncgil "Selling"); alış
-- fiyatı şimdiye kadar hiç saklanmıyordu ve istemci iki sütunda da aynı sayıyı
-- gösteriyordu. Yalnızca altın/döviz için doluyor — kripto, BIST, ABD ve
-- fonlarda tek fiyat var, orada NULL kalıyor.
alter table public.assets_prices
  add column if not exists buy_price double precision;

comment on column public.assets_prices.buy_price is
  'Alış fiyatı (varsa). NULL = kaynak tek fiyat yayımlıyor; istemci price alanını kullanır.';
