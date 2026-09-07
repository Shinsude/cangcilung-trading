import json
import urllib.request
import random
from PIL import Image, ImageDraw, ImageFont

API = "https://cangcilung-trading-api.vercel.app/signal/{}"
OUT = r"D:\fajrin\OPENCODE PROJECT\APK CANGCILUNG\previews"

BG = (10, 14, 23)
SURFACE = (17, 24, 39)
SURFACE_ALT = (30, 41, 59)
GREEN = (0, 230, 138)
RED = (255, 77, 106)
AMBER = (255, 176, 32)
BLUE = (59, 130, 246)
PURPLE = (139, 92, 246)
TEXT1 = (248, 250, 252)
TEXT2 = (100, 116, 139)
TEXT3 = (71, 85, 105)

W = 420


def clamp(v, a, b):
    return max(a, min(b, v))


def lerp(a, b, t):
    return tuple(int(clamp(a[i] + (b[i] - a[i]) * t, 0, 255)) for i in range(3))


def get_font(size, bold=False):
    paths = []
    if bold:
        paths = [
            "C:/Windows/Fonts/arialbd.ttf",
            "C:/Windows/Fonts/segoeuib.ttf",
        ]
    else:
        paths = [
            "C:/Windows/Fonts/arial.ttf",
            "C:/Windows/Fonts/segoeui.ttf",
        ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


def rrect(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text(draw, xy, s, font, fill=TEXT1, center_w=None):
    if center_w is not None:
        bb = draw.textbbox((0, 0), s, font=font)
        x = center_w - (bb[2] - bb[0]) / 2
        draw.text((x, xy[1]), s, font=font, fill=fill)
    else:
        draw.text(xy, s, font=font, fill=fill)


def draw_spark(draw, pts, x0, y0, w, h, color, fill=True):
    if len(pts) < 2:
        return
    n = len(pts)
    min_p = min(pts)
    max_p = max(pts)
    span = max_p - min_p or 1
    coords = [
        (x0 + w * i / (n - 1), y0 + h - h * (p - min_p) / span)
        for i, p in enumerate(pts)
    ]
    if fill:
        poly = coords + [(x0 + w, y0 + h), (x0, y0 + h)]
        draw.polygon(poly, fill=color + (35,))
    draw.line(coords, fill=color, width=2)


def fetch(symbol):
    with urllib.request.urlopen(API.format(symbol), timeout=60) as r:
        return json.load(r)


def render(symbol):
    d = fetch(symbol)
    prices = [c["c"] for c in d["candles"]]
    sig = d["signal"]
    pred = d["prediction"]
    ind = d["indicators"]
    sent = d["sentiment"]
    dec = d["decimals"]
    up = d["change_pct"] >= 0
    accent = GREEN if up else RED
    sig_col = GREEN if sig["action"] in ("BUY", "STRONG", "BULLISH", "UP") else RED if sig["action"] in ("SELL", "BEARISH", "DOWN") else AMBER
    dir_col = GREEN if pred["direction"] == "UP" else RED if pred["direction"] == "DOWN" else AMBER
    pct = (pred["next_price"] - d["current_price"]) / d["current_price"] * 100 if d["current_price"] else 0

    y = 0
    img = Image.new("RGBA", (W, 890), BG)
    draw = ImageDraw.Draw(img)

    # ---- top bar ----
    rrect(draw, (14, 12, 46, 44), 22, fill=None, outline=None)
    draw.ellipse((14, 12, 46, 44), fill=(0, 230, 138))
    draw.ellipse((22, 24, 38, 40), fill=(59, 130, 246))
    draw.polygon([(30, 18), (30, 38), (24, 30), (36, 30), (30, 38)], fill=(248, 250, 252))
    text(draw, (56, 14), "Cangcilung", get_font(17, True), TEXT1)
    text(draw, (56, 31), "TRADING AI", get_font(9, True), TEXT2)
    # LIVE badge
    rrect(draw, (330, 14, 406, 42), 20, fill=GREEN + (25,), outline=GREEN + (77,))
    draw.ellipse((344, 25, 352, 33), fill=GREEN)
    text(draw, (360, 18), "LIVE", get_font(10, True), GREEN)

    y = 52
    # ---- symbol bar ----
    syms = ["XAUUSD", "NASDAQ", "AUDUSD"]
    x = 14
    sw = (W - 28 - 16) / 3
    for s in syms:
        active = s == symbol
        fill = BLUE + (38,) if active else SURFACE
        outline = BLUE + (102,) if active else (30, 41, 59)
        rrect(draw, (x, y, x + sw, y + 54), 14, fill=fill, outline=outline)
        text(draw, (x, y + 12), s, get_font(12, True), TEXT1 if active else TEXT2, center_w=x + sw / 2)
        if active:
            draw.ellipse((x + sw / 2 - 2, y + 42, x + sw / 2 + 2, y + 46), fill=BLUE)
        x += sw + 8
    y += 66

    # ---- price hero ----
    rrect(draw, (14, y, W - 14, y + 128), 22, fill=SURFACE, outline=accent + (51,))
    # glow: layered translucent rounded rects
    rrect(draw, (14, y, W - 14, y + 128), 22, fill=accent + (12,))
    rrect(draw, (26, y + 12, 110, y + 32), 10, fill=BLUE + (30,), outline=BLUE + (64,))
    text(draw, (29, y + 15), d["category"].upper(), get_font(9, True), BLUE)
    text(draw, (118, y + 15), d["symbol"], get_font(12, True), TEXT2)
    text(draw, (258, y + 15), d["name"], get_font(11), TEXT3)
    px = f"{d['current_price']:,.{dec}f}"
    text(draw, (26, y + 48), px, get_font(35, True), accent)
    rrect(draw, (26, y + 88, 26 + 30 + 66, y + 112), 10, fill=accent + (30,))
    arr = "+" if up else "-"
    text(draw, (30, y + 90), f"{'▲' if up else '▼'}", get_font(12, True), accent)
    text(draw, (46, y + 90), f"{arr}{abs(d['change_pct']):.2f}%", get_font(13, True), accent)

    y += 142
    # ---- signal hero ----
    rrect(draw, (14, y, W - 14, y + 138), 22, fill=SURFACE, outline=sig_col + (77,))
    rrect(draw, (14, y, W - 14, y + 138), 22, fill=sig_col + (30,))
    text(draw, (26, y + 14), "SINYAL TRADING", get_font(11, True), TEXT2)
    rrect(draw, (W - 96, y + 10, W - 26, y + 28), 8, fill=sig_col + (38,))
    text(draw, (W - 61, y + 12), sig["strength"].upper(), get_font(10, True), sig_col, center_w=W - 61)
    text(draw, (26, y + 42), sig["action"], get_font(34, True), sig_col)
    text(draw, (26, y + 92), "BOLT", get_font(8, True), TEXT3)
    text(draw, (50, y + 88), f"{sig['confidence']*100:.0f}% keyakinan", get_font(12, True), TEXT2)
    text(draw, (W - 190, y + 48), ("▲" if pred["direction"] == "UP" else "▼") + " " + pred["direction"], get_font(14, True), dir_col, center_w=W - 140)
    np = f"{pred['next_price']:,.{dec}f}"
    text(draw, (W - 190, y + 68), np, get_font(14, True), TEXT1, center_w=W - 140)
    text(draw, (W - 190, y + 88), f"{pct:+.2f}% · {pred['horizon']}", get_font(10, True), TEXT2, center_w=W - 140)
    # progress bar
    rrect(draw, (26, y + 114, W - 26, y + 122), 4, fill=SURFACE_ALT)
    bw = int((W - 52) * sig["confidence"])
    if bw > 0:
        rrect(draw, (26, y + 114, 26 + bw, y + 122), 4, fill=sig_col)

    y += 152
    # ---- quick indicators (3 mini tiles) ----
    rsi = ind["rsi"]
    macd = ind["macd"]
    ema = ind["ema"]
    rsi_c = GREEN if rsi["value"] < 30 else RED if rsi["value"] > 70 else AMBER
    macd_c = GREEN if macd["histogram"] >= 0 else RED
    ema_c = GREEN if ema["trend"] == "bullish" else RED
    tls = [
        ("RSI", f"{rsi['value']:.1f}", rsi["region"], rsi_c),
        ("MACD", f"{macd['histogram']:.4f}", macd.get("cross") or "neutral", macd_c),
        ("EMA", ema["trend"], "", ema_c),
    ]
    tw = (W - 28 - 16) / 3
    x = 14
    for label, value, sub, c in tls:
        rrect(draw, (x, y, x + tw, y + 96), 16, fill=SURFACE, outline=c + (51,))
        text(draw, (x + tw / 2, y + 12), label, get_font(10, True), TEXT2, center_w=x + tw / 2)
        text(draw, (x + tw / 2, y + 38), value, get_font(15, True), c, center_w=x + tw / 2)
        if sub:
            text(draw, (x + tw / 2, y + 66), sub, get_font(10), TEXT3, center_w=x + tw / 2)
        x += tw + 8

    y += 108
    # ---- chart card ----
    rrect(draw, (14, y, W - 14, y + 236), 22, fill=SURFACE, outline=(30, 41, 59))
    text(draw, (26, y + 12), "CHART", get_font(12, True), TEXT1)
    rrect(draw, (W - 100, y + 10, W - 26, y + 28), 8, fill=SURFACE_ALT)
    text(draw, (W - 63, y + 12), f"{len(prices)} candles", get_font(9, True), TEXT2, center_w=W - 63)
    cy = y + 40
    ch = 186
    px0, px1 = 20, W - 20
    # grid
    for i in range(5):
        ly = cy + ch * i / 4
        draw.line([(px0, ly), (px1, ly)], fill=(30, 41, 59), width=1)
    # candles
    n = len(prices)
    if n > 0:
        mins = min(min(c["l"] for c in d["candles"]), min(c["o"] for c in d["candles"]))
        maxs = max(max(c["h"] for c in d["candles"]), max(c["c"] for c in d["candles"]))
        span = maxs - mins or 1
        for i, c in enumerate(d["candles"]):
            cx = px0 + (px1 - px0) * i / max(n - 1, 1)
            cw = (px1 - px0) / n * 0.6
            upc = c["c"] >= c["o"]
            col = GREEN if upc else RED
            yh = cy + ch * (maxs - c["h"]) / span
            yl = cy + ch * (maxs - c["l"]) / span
            yo = cy + ch * (maxs - c["o"]) / span
            yc = cy + ch * (maxs - c["c"]) / span
            draw.line([(cx, yh), (cx, yl)], fill=TEXT3, width=2)
            top = min(yo, yc)
            bot = max(yo, yc)
            rrect(draw, (cx - cw / 2, top, cx + cw / 2, max(top + 1, bot)), 2, fill=col)
        # last price tag
        last = d["candles"][-1]
        lc = GREEN if last["c"] >= last["o"] else RED
        lyp = cy + ch * (maxs - last["c"]) / span
        draw.line([(px0, lyp), (px1, lyp)], fill=lc + (90,), width=1)
        tag = f" {last['c']:,.{dec}f} "
        f = get_font(9, True)
        bb = draw.textbbox((0, 0), tag, font=f)
        tw2 = bb[2] - bb[0]
        rrect(draw, (px1 - tw2 - 12, lyp - 10, px1 - 2, lyp + 10), 5, fill=lc)
        text(draw, (px1 - tw2 - 8, lyp - 7), tag, f, (255, 255, 255))
    text(draw, (px0, y + 216), f"{mins:,.{dec}f}", get_font(8, True), TEXT3)

    y += 250
    # ---- sentiment strip ----
    sent_c = GREEN if sent["label"].startswith("BULL") else RED if sent["label"].startswith("BEAR") else AMBER
    rrect(draw, (14, y, W - 14, y + 84), 18, fill=SURFACE, outline=sent_c + (51,))
    text(draw, (26, y + 14), "SENTIMEN", get_font(10, True), TEXT2)
    text(draw, (26, y + 36), sent["label"], get_font(16, True), sent_c)
    text(draw, (W - 120, y + 36), f"{sent['score']:+.2f}", get_font(16, True), sent_c, center_w=W - 80)
    rrect(draw, (26, y + 62, W - 26, y + 68), 3, fill=SURFACE_ALT)
    sw2 = int((W - 52) * clamp((sent["score"] + 1) / 2, 0, 1))
    if sw2 > 0:
        rrect(draw, (26, y + 62, 26 + sw2, y + 68), 3, fill=sent_c)
    # sentiment sparkline
    spark = [float(x) for x in d.get("sentiment_history", [])] or [0.2, 0.5, 0.4, 0.7, 0.6, 0.8]

    y += 96
    # ---- bottom nav ----
    rrect(draw, (0, y, W, y + 64), 0, fill=SURFACE, outline=None)
    draw.line([(0, y), (W, y)], fill=(30, 41, 59), width=1)
    tabs = [("Signal", BLUE, True), ("Chart", TEXT3, False), ("Indikator", TEXT3, False), ("Sentimen", TEXT3, False)]
    tw3 = W / 4
    for i, (label, c, act) in enumerate(tabs):
        tx = i * tw3
        text(draw, (tx, y + 10), label[0], get_font(14, True), c, center_w=tx + tw3 / 2)
        text(draw, (tx, y + 34), label, get_font(9, True), c, center_w=tx + tw3 / 2)

    out = f"{OUT}/preview_{symbol}.png"
    img.save(out)
    return out


if __name__ == "__main__":
    import os
    os.makedirs(OUT, exist_ok=True)
    for s in ["XAUUSD", "NASDAQ", "AUDUSD"]:
        p = render(s)
        print("saved", p)
