-- Instagram paylaşım kuyruğu. Üretici (GitHub Actions'taki story script'i,
-- ileride video hattı) satırı 'draft' olarak ekler; `ig-bot` her tick'te
-- taslağı Telegram'a onaya yollar, onaylananı publish_at gelince yayınlar.
--
-- draft → (Telegram) → approved | rejected | manual
-- approved → publishing → published | failed
-- approved ama publish_at'ten 2 saat geçti → expired (eski fiyat paylaşılmasın)

create table if not exists public.ig_queue (
  id            bigint generated always as identity primary key,
  kind          text not null check (kind in ('story', 'reel', 'image')),
  media_url     text not null,
  caption       text,
  publish_at    timestamptz not null,
  status        text not null default 'draft'
                check (status in ('draft', 'approved', 'rejected', 'manual',
                                  'publishing', 'published', 'failed', 'expired')),
  tg_message_id bigint,
  ig_media_id   text,
  error         text,
  created_at    timestamptz not null default now()
);

create index if not exists ig_queue_status_publish_at on public.ig_queue (status, publish_at);

alter table public.ig_queue enable row level security;
-- Politika yok: yalnızca service_role (ig-bot, story script'i) erişir.

-- Instagram medyayı herkese açık bir URL'den çekiyor.
insert into storage.buckets (id, name, public)
values ('ig-media', 'ig-media', true)
on conflict (id) do nothing;
