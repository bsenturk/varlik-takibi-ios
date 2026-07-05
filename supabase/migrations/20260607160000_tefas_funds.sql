-- TEFAS funds catalog + fuzzy search
-- ----------------------------------------------------------------------------
-- The app stays a thin client: it searches this catalog (fast, fuzzy) and the
-- selected fund's price is mirrored into `assets_prices` by the edge functions.

create extension if not exists pg_trgm;

-- Full catalog of TEFAS funds (one row per fund code), refreshed daily.
create table if not exists public.tefas_funds (
    code           text primary key,                 -- FONKODU, e.g. "AFA"
    name           text not null default '',          -- FONUNVAN (full title)
    price          double precision,                  -- latest unit price (TRY)
    price_date     timestamptz,                       -- date of `price`
    investor_count bigint  not null default 0,        -- KISISAYISI (popularity signal)
    fund_size      double precision not null default 0,-- PORTBUYUKLUK
    is_popular     boolean not null default false,    -- top-N by investor_count
    updated_at     timestamptz not null default now()
);

-- Trigram index for `ilike '%q%'` / similarity() name search.
create index if not exists idx_tefas_funds_name_trgm
    on public.tefas_funds using gin (name gin_trgm_ops);
create index if not exists idx_tefas_funds_code_trgm
    on public.tefas_funds using gin (code gin_trgm_ops);
create index if not exists idx_tefas_funds_popular
    on public.tefas_funds (investor_count desc) where is_popular;

-- Read-only for the anonymous app. Writes happen only from edge functions using
-- the service-role key (which bypasses RLS).
alter table public.tefas_funds enable row level security;
drop policy if exists "tefas_funds anon read" on public.tefas_funds;
create policy "tefas_funds anon read"
    on public.tefas_funds for select to anon using (true);

-- ----------------------------------------------------------------------------
-- search_funds(q): instant fuzzy search callable from the app via PostgREST RPC.
--   • empty / <2 chars  -> the 10 most popular funds
--   • otherwise         -> name/code matches ranked by relevance then popularity
create or replace function public.search_funds(q text)
returns setof public.tefas_funds
language sql
stable
as $$
    select *
    from public.tefas_funds f
    where
        case
            when q is null or length(trim(q)) < 2 then f.is_popular
            else (f.name ilike '%' || q || '%' or f.code ilike '%' || q || '%')
        end
    order by
        case when q is null or length(trim(q)) < 2 then 0
             else similarity(f.name, q) end desc,
        f.investor_count desc
    limit 25;
$$;

grant execute on function public.search_funds(text) to anon;
