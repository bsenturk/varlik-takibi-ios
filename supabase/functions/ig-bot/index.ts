// ig-bot — Instagram paylaşım kuyruğu (ig_queue). İki giriş noktası var:
//
//  1. Telegram webhook (X-Telegram-Bot-Api-Secret-Token): ✅ / 📱 / ❌ butonları
//     taslağın durumunu değiştirir. Yalnızca TG_OWNER_ID'den gelen tıklamalar sayılır.
//  2. Tick (x-sync-secret, pg_cron ile 5 dakikada bir): yeni taslakları Telegram'a
//     onaya yollar, süresi geçenleri düşürür, zamanı gelen onaylıları Instagram'a basar.
//
// Secrets: TG_BOT_TOKEN, TG_OWNER_ID, TG_WEBHOOK_SECRET, IG_TOKEN, IG_USER_ID, SYNC_SECRET.
// İsteğe bağlı: IG_GRAPH_URL (varsayılan Instagram Login API'si).

import { createServiceClient } from "../_shared/prices.ts";
import { errorResponse, jsonResponse } from "../_shared/cors.ts";

const env = (k: string) => Deno.env.get(k) ?? "";
const TG = `https://api.telegram.org/bot${env("TG_BOT_TOKEN")}`;
const IG = env("IG_GRAPH_URL") || "https://graph.instagram.com/v23.0";
const OWNER = env("TG_OWNER_ID");
const STALE_MS = 2 * 3600_000; // publish_at'ten 2 saat sonra yayınlanmaz (eski fiyat paylaşılmasın)
const db = createServiceClient();

interface Row {
  id: number;
  kind: "story" | "reel" | "image";
  media_url: string;
  caption: string | null;
  publish_at: string;
  status: string;
  tg_message_id: number | null;
}

const STATUS_TEXT: Record<string, string> = {
  approved: "✅ Onaylandı, saatinde yayınlanacak",
  manual: "📱 Manuel paylaşacaksın (görseli buradan kaydet)",
  rejected: "❌ Reddedildi",
};

const BUTTONS = (id: number) => ({
  inline_keyboard: [[
    { text: "✅ Onayla", callback_data: `approved:${id}` },
    { text: "📱 Manuel", callback_data: `manual:${id}` },
    { text: "❌ Reddet", callback_data: `rejected:${id}` },
  ]],
});

async function tg(method: string, body: Record<string, unknown>) {
  const res = await fetch(`${TG}/${method}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!json.ok) throw new Error(`Telegram ${method}: ${json.description}`);
  return json.result;
}

async function ig(path: string, params: Record<string, string>, method = "POST") {
  const qs = new URLSearchParams({ ...params, access_token: env("IG_TOKEN") });
  const res = method === "GET"
    ? await fetch(`${IG}/${path}?${qs}`)
    : await fetch(`${IG}/${path}`, { method, body: qs });
  const json = await res.json();
  if (json.error) throw new Error(`Instagram ${path}: ${json.error.message}`);
  return json;
}

function label(row: Row) {
  const when = new Date(row.publish_at).toLocaleString("tr-TR", {
    timeZone: "Europe/Istanbul", weekday: "short", day: "numeric", month: "short",
    hour: "2-digit", minute: "2-digit",
  });
  const kind = { story: "☀️ Story", reel: "🎬 Reels", image: "🖼️ Gönderi" }[row.kind];
  return `${kind} #${row.id} · ${when}${row.caption ? `\n\n${row.caption}` : ""}`;
}

function containerParams(row: Row): Record<string, string> {
  const video = row.media_url.endsWith(".mp4");
  const p: Record<string, string> = video ? { video_url: row.media_url } : { image_url: row.media_url };
  if (row.kind === "story") p.media_type = "STORIES";
  if (row.kind === "reel") p.media_type = "REELS";
  if (row.caption && row.kind !== "story") p.caption = row.caption;
  return p;
}

// Container hazır olmadan media_publish çağrılırsa Instagram hata veriyor (videoda dakikalar sürebilir).
async function waitReady(container: string) {
  for (let i = 0; i < 20; i++) {
    const { status_code } = await ig(container, { fields: "status_code" }, "GET");
    if (status_code === "FINISHED") return;
    if (status_code === "ERROR" || status_code === "EXPIRED") throw new Error(`container ${status_code}`);
    await new Promise((r) => setTimeout(r, 3000));
  }
  throw new Error("container 60 sn içinde hazır olmadı");
}

async function publish(row: Row) {
  // Atomik sahiplenme: iki tick aynı anda koşarsa yalnızca biri yayınlar.
  const { data: claimed } = await db.from("ig_queue").update({ status: "publishing" })
    .eq("id", row.id).eq("status", "approved").select("id");
  if (!claimed?.length) return;

  try {
    const user = env("IG_USER_ID");
    const { id: container } = await ig(`${user}/media`, containerParams(row));
    await waitReady(container);
    const { id } = await ig(`${user}/media_publish`, { creation_id: container });
    await db.from("ig_queue").update({ status: "published", ig_media_id: id }).eq("id", row.id);
    if (row.tg_message_id) {
      await tg("editMessageCaption", {
        chat_id: OWNER, message_id: row.tg_message_id, caption: `${label(row)}\n\n🚀 Yayınlandı`,
      });
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    await db.from("ig_queue").update({ status: "failed", error: msg }).eq("id", row.id);
    await tg("sendMessage", {
      chat_id: OWNER, text: `⚠️ #${row.id} yayınlanamadı: ${msg}`,
      reply_parameters: row.tg_message_id ? { message_id: row.tg_message_id } : undefined,
    });
  }
}

async function tick() {
  // 1. Yeni taslakları onaya yolla.
  const { data: drafts } = await db.from("ig_queue").select("*")
    .eq("status", "draft").is("tg_message_id", null).order("id");
  for (const row of (drafts ?? []) as Row[]) {
    const video = row.media_url.endsWith(".mp4");
    try {
      const msg = await tg(video ? "sendVideo" : "sendPhoto", {
        chat_id: OWNER, [video ? "video" : "photo"]: row.media_url,
        caption: label(row), reply_markup: BUTTONS(row.id),
      });
      await db.from("ig_queue").update({ tg_message_id: msg.message_id }).eq("id", row.id);
    } catch (err) {
      console.error(`ig-bot notify #${row.id}:`, err); // bir sonraki tick tekrar dener
    }
  }

  // 2. Zamanı çoktan geçmiş taslak/onaylıları düşür.
  const stale = new Date(Date.now() - STALE_MS).toISOString();
  await db.from("ig_queue").update({ status: "expired" })
    .in("status", ["draft", "approved"]).lt("publish_at", stale);

  // 3. Zamanı gelenleri yayınla.
  const { data: due } = await db.from("ig_queue").select("*")
    .eq("status", "approved").lte("publish_at", new Date().toISOString()).order("publish_at");
  for (const row of (due ?? []) as Row[]) await publish(row);

  return { notified: drafts?.length ?? 0, published: due?.length ?? 0 };
}

async function onTelegram(update: Record<string, any>) {
  const cb = update.callback_query;
  if (!cb || String(cb.from?.id) !== OWNER) return;
  const [status, id] = String(cb.data).split(":");
  if (!(status in STATUS_TEXT)) return;

  // Yayınlanana kadar fikir değiştirilebilir; yayınlanan/düşen satıra dokunulmaz.
  const { data } = await db.from("ig_queue").update({ status })
    .eq("id", Number(id)).in("status", ["draft", "approved", "manual", "rejected"]).select("*");
  const row = data?.[0] as Row | undefined;

  await tg("answerCallbackQuery", {
    callback_query_id: cb.id, text: row ? STATUS_TEXT[status] : "Bu taslak artık değiştirilemez",
  });
  if (row) {
    await tg("editMessageCaption", {
      chat_id: OWNER, message_id: cb.message.message_id,
      caption: `${label(row)}\n\n${STATUS_TEXT[status]}`, reply_markup: BUTTONS(row.id),
    });
  }
}

Deno.serve(async (req) => {
  try {
    const tgSecret = req.headers.get("x-telegram-bot-api-secret-token");
    if (tgSecret && tgSecret === env("TG_WEBHOOK_SECRET")) {
      // Hata olsa da 200 dön: Telegram aynı güncellemeyi tekrar tekrar yollamasın.
      await onTelegram(await req.json()).catch((e) => console.error("ig-bot telegram:", e));
      return jsonResponse({ ok: true });
    }
    const syncSecret = req.headers.get("x-sync-secret");
    if (syncSecret && syncSecret === env("SYNC_SECRET")) {
      return jsonResponse(await tick());
    }
    return jsonResponse({ error: "unauthorized" }, 401);
  } catch (err) {
    console.error("ig-bot error:", err);
    return errorResponse(err);
  }
});
