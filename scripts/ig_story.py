#!/usr/bin/env python3
"""Günlük piyasa story'sini assets_prices'tan üretir, isteğe bağlı Instagram kuyruğuna ekler.

Kullanım:
  python3 scripts/ig_story.py altin            # yalnızca görsel → marketing/posts/<tarih>/auto-story-altin.jpg
  python3 scripts/ig_story.py doviz --queue    # görsel + ig-media'ya yükle + ig_queue'ya taslak ekle
Ortam: SUPABASE_KEY (görsel için anon yeter, --queue için service_role), SUPABASE_URL (varsayılan proje),
       CHROME (Linux'ta google-chrome).
Taslağı Telegram'a `ig-bot` yollar, onaylanınca KINDS'taki saatte yayınlar.
"""
import datetime as dt
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import urllib.request
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parent.parent
URL = os.environ.get("SUPABASE_URL", "https://bpiclzhpxkmnqxqvlnmu.supabase.co")
KEY = os.environ.get("SUPABASE_KEY", "")
CHROME = os.environ.get("CHROME", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
ICON = (ROOT / "MyGolds/Resources/Assets.xcassets/AppIcon.appiconset/icon-arrowcol-c4-1-1024.png").as_uri()
TR = ZoneInfo("Europe/Istanbul")
MAX_AGE = dt.timedelta(hours=3)  # fiyatlar bundan eskiyse paylaşma (kaynak çökmüş demektir)

GOLD = '<i class="coin"></i>'
RING = '<i class="coin ring"></i>'
SILVER = '<i class="coin silver"></i>'

KINDS = {
    "altin": {
        "title": "☀️ Günün <mark>altın fiyatları</mark>",
        "publish": (10, 0),
        "rows": [("GRAM_ALTIN", GOLD, "Gram Altın"), ("CEYREK_ALTIN", GOLD, "Çeyrek Altın"),
                 ("YARIM_ALTIN", GOLD, "Yarım Altın"), ("TAM_ALTIN", GOLD, "Tam Altın"),
                 ("CUMHURIYET_ALTIN", GOLD, "Cumhuriyet Altını"), ("22_AYAR_BILEZIK", RING, "22 Ayar Bilezik"),
                 ("GRAM_GUMUS", SILVER, "Gram Gümüş")],
    },
    "doviz": {
        "title": "💵 Günün <mark>döviz kurları</mark>",
        "publish": (17, 30),
        "rows": [("USD", "🇺🇸", "Dolar"), ("EUR", "🇪🇺", "Euro"), ("GBP", "🇬🇧", "Sterlin"),
                 ("CHF", "🇨🇭", "İsviçre Frangı"), ("SAR", "🇸🇦", "Suudi Riyali"),
                 ("AED", "🇦🇪", "BAE Dirhemi"), ("JPY", "🇯🇵", "Japon Yeni")],
    },
}
DAYS = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
MONTHS = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

CSS = """
html,body{margin:0;width:1080px;height:1920px;overflow:hidden}
body{background:#FFF5E1;color:#2B1D0E;font-family:Inter,-apple-system,sans-serif;box-sizing:border-box;
  padding:250px 70px 0;display:flex;flex-direction:column;gap:22px}
h2{font-size:76px;line-height:1.1;margin:0;font-weight:800;letter-spacing:-1.5px}
mark{background:none;color:#A8730F}
.sub{font-size:40px;font-weight:500;margin:0 0 6px}
.store{display:flex;align-items:center;gap:22px;background:#fff;border-radius:999px;padding:14px 40px 14px 14px;
  align-self:flex-start;box-shadow:0 12px 36px rgba(40,20,0,.10)}
.store img{width:80px;height:80px;border-radius:20px}
.store b{display:block;font-size:36px}.store small{font-size:28px;color:#8A6A3F;font-weight:600}
.rows{display:flex;flex-direction:column;gap:14px;margin-top:14px}
.row{display:flex;align-items:center;gap:26px;background:#fff;border-radius:34px;padding:18px 30px;
  box-shadow:0 12px 36px rgba(40,20,0,.08)}
.ic{flex:none;width:80px;height:80px;border-radius:22px;background:#FFF1D0;display:grid;place-items:center;font-size:44px}
.coin{width:48px;height:48px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#FFE9A0,#E8B84B 55%,#B07D16);
  box-shadow:inset 0 0 0 4px rgba(150,100,10,.45)}
.ring{background:none;box-shadow:inset 0 0 0 10px #E0A92E}
.silver{background:radial-gradient(circle at 35% 30%,#FFFFFF,#C9CDD3 55%,#8C939C);box-shadow:inset 0 0 0 4px rgba(90,95,105,.4)}
.nm{flex:1;font-size:40px;font-weight:700}.nm small{display:block;font-size:28px;color:#8A6A3F;font-weight:500;margin-top:4px}
.px{text-align:right;font-size:44px;font-weight:800}
.ch{display:inline-block;font-size:28px;font-weight:700;border-radius:999px;padding:4px 16px;margin-top:6px}
.up{color:#1E8E3E;background:#E3F5E8}.down{color:#C62828;background:#FDE7E7}.flat{color:#8A6A3F;background:#F3E6CC}
.note{font-size:26px;color:#8A6A3F;text-align:center;margin-top:8px}
"""


def tl(v):
    return "₺" + f"{v:,.{2 if v >= 1 else 4}f}".translate(str.maketrans(",.", ".,"))


def change(p):
    if p is None:
        return ""
    cls, arrow = ("up", "↑") if p > 0.005 else ("down", "↓") if p < -0.005 else ("flat", "")
    return f'<span class="ch {cls}">{arrow} %{abs(p):.2f}'.replace(".", ",") + "</span>"


def api(method, path, body=None, headers=None):
    req = urllib.request.Request(f"{URL}{path}", data=body, method=method, headers={
        "apikey": KEY, "Authorization": f"Bearer {KEY}", **(headers or {})})
    with urllib.request.urlopen(req) as r:
        return r.read()


def fetch(symbols):
    q = f"/rest/v1/assets_prices?select=symbol,price,buy_price,change_percent,updated_at&currency=eq.TRY&symbol=in.({','.join(symbols)})"
    return {r["symbol"]: r for r in json.loads(api("GET", q))}


def html(kind, prices, asof):
    k = KINDS[kind]
    rows = []
    for sym, icon, name in k["rows"]:
        r = prices.get(sym)
        if not r:
            continue
        buy = f'<small>Alış {tl(r["buy_price"])}</small>' if r.get("buy_price") else ""
        rows.append(f'<div class="row"><div class="ic">{icon}</div><div class="nm">{name}{buy}</div>'
                    f'<div class="px">{tl(r["price"])}<br>{change(r.get("change_percent"))}</div></div>')
    date = f"{asof.day} {MONTHS[asof.month - 1]} {DAYS[asof.weekday()]} · {asof:%H:%M} canlı fiyatlar"
    return f"""<!doctype html><html lang="tr"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700;800&display=block" rel="stylesheet">
<style>{CSS}</style></head><body>
<h2>{k["title"]}</h2><p class="sub">{date}</p>
<div class="store"><img src="{ICON}"><div><b>Varlık Takibi</b><small>App Store &amp; Google Play · Link profilde 👆</small></div></div>
<div class="rows">{''.join(rows)}</div>
<div class="note">Satış fiyatları · Yatırım tavsiyesi değildir.</div>
</body></html>"""


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in KINDS:
        sys.exit(f"Kullanım: {sys.argv[0]} {'|'.join(KINDS)} [--queue]")
    if not KEY:
        sys.exit("SUPABASE_KEY eksik.")
    kind, queue = sys.argv[1], "--queue" in sys.argv
    k = KINDS[kind]

    prices = fetch([s for s, _, _ in k["rows"]])
    if len(prices) < len(k["rows"]) // 2:
        sys.exit(f"Fiyatların çoğu eksik: {sorted(prices)}")
    asof = max(dt.datetime.fromisoformat(r["updated_at"]) for r in prices.values()).astimezone(TR)
    now = dt.datetime.now(TR)
    if now - asof > MAX_AGE:
        sys.exit(f"Fiyatlar eski ({asof:%d.%m %H:%M}), story üretilmedi.")

    out = ROOT / "marketing/posts" / f"{now:%Y-%m-%d}" / f"auto-story-{kind}.jpg"
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / "story.html"
        page.write_text(html(kind, prices, asof))
        subprocess.run([CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1",
                        "--window-size=1080,1920", "--virtual-time-budget=5000", "--allow-file-access-from-files",
                        f"--screenshot={out}", page.as_uri()], check=True, capture_output=True)
    print(out)
    if not queue:
        return

    name = f"stories/{now:%Y-%m-%d}-{kind}.jpg"
    api("POST", f"/storage/v1/object/ig-media/{name}", out.read_bytes(),
        {"Content-Type": "image/jpeg", "x-upsert": "true"})
    publish_at = now.replace(hour=k["publish"][0], minute=k["publish"][1], second=0, microsecond=0)
    row = {"kind": "story", "media_url": f"{URL}/storage/v1/object/public/ig-media/{name}",
           "publish_at": publish_at.isoformat()}
    api("POST", "/rest/v1/ig_queue", json.dumps(row).encode(),
        {"Content-Type": "application/json", "Prefer": "return=minimal"})
    print(f"Kuyruğa eklendi: {row}")


if __name__ == "__main__":
    main()
