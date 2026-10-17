#!/usr/bin/env python3
"""Günlük piyasa story'sini assets_prices'tan üretir, isteğe bağlı Instagram kuyruğuna ekler.

Kullanım:
  python3 scripts/ig_story.py altin            # yalnızca görsel → marketing/posts/<tarih>/auto-story-altin.jpg
  python3 scripts/ig_story.py doviz --queue    # görsel + ig-media'ya yükle + ig_queue'ya taslak ekle
  python3 scripts/ig_story.py piyasa --queue   # 18:30 story'si: türü haftanın gününden seçer (ROTATION)
Türler: altin, doviz, bist, abd, fon, etf.
Ortam: SUPABASE_KEY (görsel için anon yeter, --queue için service_role), SUPABASE_URL (varsayılan proje),
       CHROME (Linux'ta google-chrome).
Taslağı Telegram'a `ig-bot` yollar, onaylanınca KINDS'taki saatte yayınlar.
"""
import datetime as dt
import json
import os
import pathlib
import re
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
# ponytail: tatil listesi elle tutuluyor; yıl dönünce Borsa İstanbul tatil takviminden güncelle.
BIST_CLOSED = {"2026-10-29"}
ROTATION = {0: "bist", 1: "abd", 2: "fon", 3: "bist", 4: "etf"}  # 18:30 story'si, Pzt=0
# Uygulamanın varsayılan gösterdiği popüler fonlar. supabase/functions/scrape-tefas POPULAR_CODES ile aynı tut.
FUNDS = ["MAC", "YAS", "TI3", "NNF", "AFT", "AFA", "TCD", "IPB", "GTL", "TTE"]

GOLD = '<i class="coin"></i>'
RING = '<i class="coin ring"></i>'
SILVER = '<i class="coin silver"></i>'
DISCLAIMER = "Yatırım tavsiyesi değildir."
PAST = "Geçmiş performans gelecek için gösterge değildir."


def tk(code):
    return f'<b class="tk">{code}</b>'


KINDS = {
    "altin": {
        "title": "☀️ Günün <mark>altın fiyatları</mark>", "publish": (10, 0), "type": "gold",
        "note": f"Satış fiyatları · {DISCLAIMER}",
        "rows": [("GRAM_ALTIN", GOLD, "Gram Altın"), ("CEYREK_ALTIN", GOLD, "Çeyrek Altın"),
                 ("YARIM_ALTIN", GOLD, "Yarım Altın"), ("TAM_ALTIN", GOLD, "Tam Altın"),
                 ("CUMHURIYET_ALTIN", GOLD, "Cumhuriyet Altını"), ("22_AYAR_BILEZIK", RING, "22 Ayar Bilezik"),
                 ("GRAM_GUMUS", SILVER, "Gram Gümüş")],
    },
    "doviz": {
        "title": "💵 Günün <mark>döviz kurları</mark>", "publish": (17, 30), "type": "currency",
        "note": f"Satış fiyatları · {DISCLAIMER}",
        "rows": [("USD", "🇺🇸", "Dolar"), ("EUR", "🇪🇺", "Euro"), ("GBP", "🇬🇧", "Sterlin"),
                 ("CHF", "🇨🇭", "İsviçre Frangı"), ("SAR", "🇸🇦", "Suudi Riyali"),
                 ("AED", "🇦🇪", "BAE Dirhemi"), ("JPY", "🇯🇵", "Japon Yeni")],
    },
    # Borsa/ABD/fon: sabit liste, hiçbirini öne çıkarma (bkz. marketing/iki-haftalik-plan.md).
    "bist": {
        "title": "📊 Günün <mark>BIST hisseleri</mark>", "publish": (18, 30), "type": "bist",
        "note": DISCLAIMER,
        "rows": [(f"{c}.IS", tk(c), n) for c, n in [
            ("AKBNK", "Akbank"), ("ASELS", "Aselsan"), ("BIMAS", "BİM"), ("GARAN", "Garanti BBVA"),
            ("KCHOL", "Koç Holding"), ("THYAO", "Türk Hava Yolları"), ("TUPRS", "Tüpraş")]],
    },
    "abd": {
        "title": "🇺🇸 Günün <mark>ABD hisseleri</mark>", "publish": (18, 30), "type": "us_stock", "usd": True,
        "note": DISCLAIMER,
        "rows": [(c, tk(c), n) for c, n in [
            ("AAPL", "Apple"), ("AMZN", "Amazon"), ("GOOGL", "Alphabet"), ("META", "Meta"),
            ("MSFT", "Microsoft"), ("NVDA", "Nvidia"), ("TSLA", "Tesla")]],
    },
    "etf": {
        "title": "🧺 Günün <mark>ABD ETF'leri</mark>", "publish": (18, 30), "type": "us_etf", "usd": True,
        "note": f"ETF takibi Varlık Takibi Pro'da · {DISCLAIMER} {PAST}",
        "rows": [(c, tk(c), n) for c, n in [
            ("DIA", "Dow Jones"), ("GLD", "Altın"), ("QQQ", "Nasdaq 100"), ("SLV", "Gümüş"),
            ("SPY", "S&amp;P 500"), ("TLT", "ABD 20+ Yıl Tahvil"), ("VTI", "Tüm ABD Borsası")]],
    },
    "fon": {
        "title": "🥧 Popüler <mark>TEFAS fonları</mark>", "publish": (18, 30), "type": "fund", "funds": True,
        "max_age": dt.timedelta(hours=36),  # scrape-tefas günde iki kez (10:00, 15:00) çekiyor
        "sub": "son açıklanan TEFAS fiyatları",
        "note": f"Fon takibi Varlık Takibi Pro'da · {DISCLAIMER} {PAST}",
        "rows": [(c, tk(c), c) for c in FUNDS],
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
.tk{font-size:21px;font-weight:800;color:#7A5410;letter-spacing:-.5px}
.coin{width:48px;height:48px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#FFE9A0,#E8B84B 55%,#B07D16);
  box-shadow:inset 0 0 0 4px rgba(150,100,10,.45)}
.ring{background:none;box-shadow:inset 0 0 0 10px #E0A92E}
.silver{background:radial-gradient(circle at 35% 30%,#FFFFFF,#C9CDD3 55%,#8C939C);box-shadow:inset 0 0 0 4px rgba(90,95,105,.4)}
.nm{flex:1;min-width:0;font-size:40px;font-weight:700}
.nm small{display:block;font-size:28px;color:#8A6A3F;font-weight:500;margin-top:4px;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.px{text-align:right;font-size:44px;font-weight:800;white-space:nowrap}
.ch{display:inline-block;font-size:28px;font-weight:700;border-radius:999px;padding:4px 16px;margin-top:6px}
.up{color:#1E8E3E;background:#E3F5E8}.down{color:#C62828;background:#FDE7E7}.flat{color:#8A6A3F;background:#F3E6CC}
.compact .rows{gap:10px}.compact .row{padding:10px 26px}.compact .ic{width:64px;height:64px}
.compact .nm{font-size:34px}.compact .nm small{font-size:24px}.compact .px{font-size:38px}
.note{font-size:26px;color:#8A6A3F;text-align:center;margin-top:8px;line-height:1.4}
"""


def money(v, cur="₺", decimals=None):
    d = decimals if decimals is not None else (2 if v >= 1 else 4)
    return cur + f"{v:,.{d}f}".translate(str.maketrans(",.", ".,"))


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


def get(path):
    return json.loads(api("GET", path))


def fetch(k):
    q = (f"/rest/v1/assets_prices?select=symbol,name,price,buy_price,change_percent,updated_at"
         f"&asset_type=eq.{k['type']}&symbol=in.({','.join(s for s, _, _ in k['rows'])})")
    return {r["symbol"]: r for r in get(q)}


def html(k, rows, prices, sub, usd_try):
    out = []
    for sym, icon, name in rows:
        r = prices.get(sym)
        if not r:
            continue
        if k.get("funds"):
            extra = r.get("name") or ""  # uzun fon unvanı, CSS ellipsis ile kesilir
        elif usd_try:
            extra = f"≈ {money(r['price'] * usd_try, decimals=0)}"
        else:
            extra = f"Alış {money(r['buy_price'])}" if r.get("buy_price") else ""
        extra = f"<small>{extra}</small>" if extra else ""
        price = money(r["price"], "$" if k.get("usd") else "₺")
        out.append(f'<div class="row"><div class="ic">{icon}</div><div class="nm">{name}{extra}</div>'
                   f'<div class="px">{price}<br>{change(r.get("change_percent"))}</div></div>')
    return f"""<!doctype html><html lang="tr"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@500;600;700;800&display=block" rel="stylesheet">
<style>{CSS}</style></head><body class="{'compact' if len(rows) > 7 else ''}">
<h2>{k["title"]}</h2><p class="sub">{sub}</p>
<div class="store"><img src="{ICON}"><div><b>Varlık Takibi</b><small>App Store &amp; Google Play · Link profilde 👆</small></div></div>
<div class="rows">{''.join(out)}</div>
<div class="note">{k["note"]}</div>
</body></html>"""


def ts(s):
    """PostgREST zaman damgası → datetime. Kesir 2 haneli gelebiliyor, Python <3.11 onu okuyamıyor."""
    return dt.datetime.fromisoformat(re.sub(r"\.\d+", "", s)).astimezone(TR)


def day(d):
    return f"{d.day} {MONTHS[d.month - 1]} {DAYS[d.weekday()]}"


def main():
    now = dt.datetime.now(TR)
    kind = sys.argv[1] if len(sys.argv) > 1 else ""
    if kind == "piyasa":
        kind = ROTATION.get(now.weekday(), "")
        if not kind:
            print("Hafta sonu: 18:30 story'si yok.")
            return
    if kind not in KINDS:
        sys.exit(f"Kullanım: {sys.argv[0]} {'|'.join(KINDS)}|piyasa [--queue]")
    if not KEY:
        sys.exit("SUPABASE_KEY eksik.")
    if kind == "bist" and f"{now:%Y-%m-%d}" in BIST_CLOSED:
        print("Borsa İstanbul bugün kapalı, story üretilmedi.")
        return
    queue, k = "--queue" in sys.argv, KINDS[kind]

    rows, prices = k["rows"], fetch(k)
    if len(prices) < len(rows) // 2:
        sys.exit(f"Fiyatların çoğu eksik: {sorted(prices)}")
    asof = max(ts(r["updated_at"]) for r in prices.values())
    if now - asof > k.get("max_age", MAX_AGE):
        sys.exit(f"Fiyatlar eski ({asof:%d.%m %H:%M}), story üretilmedi.")

    usd_try = None
    if k.get("usd"):
        usd_try = get("/rest/v1/assets_prices?select=price&asset_type=eq.currency&symbol=eq.USD")[0]["price"]
    sub = f"{day(asof)} · {asof:%H:%M} {k.get('sub', 'canlı fiyatlar')}"
    if k.get("funds"):
        sub = f"{day(asof)} · {k['sub']}"

    out = ROOT / "marketing/posts" / f"{now:%Y-%m-%d}" / f"auto-story-{kind}.jpg"
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / "story.html"
        page.write_text(html(k, rows, prices, sub, usd_try))
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
