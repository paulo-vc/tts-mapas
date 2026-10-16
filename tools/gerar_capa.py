"""Gera as capas da Steam Workshop (1024 x 1024): assets/capa.jpg (pt) e assets/cover_en.jpg (en).

Uso: python tools/gerar_capa.py [pt|en]   (precisa de pillow, numpy e lupa)
A placa é desenhada a partir do layout real de Atlas.lua: mesmos botões, cores, posições e miniaturas.
As imagens de mapa nas miniaturas são exemplos gerados aqui, só para a capa.
"""
import sys
from pathlib import Path

import lupa
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LANG = sys.argv[1] if len(sys.argv) > 1 else "pt"
SIZE = 1024
FONTS = Path("C:/Windows/Fonts")
INNER_W, INNER_D, RIM = 10.0, 15.0, 0.4


def font(name, size):
    try:
        return ImageFont.truetype(str(FONTS / name), size)
    except OSError:
        return ImageFont.load_default()


def noise(rng, h, w, cy, cx):
    small = (rng.random((cy, cx)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC), np.float32) / 255


# ---------------------------------------------------------------- mapas de exemplo
def sample_map(seed, kind, w=360, h=240):
    rng = np.random.default_rng(seed)
    n = noise(rng, h, w, 5, 7) * 0.7 + noise(rng, h, w, 24, 34) * 0.3
    if kind == "dungeon":
        img = np.zeros((h, w, 3), np.float32) + np.array([38, 34, 32], np.float32)
        im = Image.fromarray(img.astype(np.uint8)); d = ImageDraw.Draw(im)
        rooms = [(30, 30, 130, 100), (190, 40, 320, 120), (60, 140, 170, 210), (220, 150, 330, 215)]
        for x0, y0, x1, y1 in rooms:
            d.rectangle([x0, y0, x1, y1], fill=(168, 152, 128))
            for gx in range(x0, x1, 12):
                d.line([gx, y0, gx, y1], fill=(140, 126, 104))
            for gy in range(y0, y1, 12):
                d.line([x0, gy, x1, gy], fill=(140, 126, 104))
        for a, b in [((130, 65), (190, 65)), ((110, 100), (110, 140)), ((260, 120), (260, 150)), ((170, 180), (220, 180))]:
            d.line([a, b], fill=(168, 152, 128), width=16)
        return im
    if kind == "sea":
        land = n > 0.55
        img = np.where(land[..., None], np.array([118, 140, 82]) * (0.8 + 0.4 * n[..., None]),
                       np.array([46, 92, 128]) * (0.8 + 0.4 * n[..., None]))
    elif kind == "forest":
        img = np.array([52, 88, 48]) * (0.6 + 0.7 * n[..., None])
        path = np.abs(np.linspace(-1, 1, w)[None, :] - 0.3 * np.sin(np.linspace(0, 6, h))[:, None]) < 0.06
        img[path] = [150, 124, 86]
    elif kind == "desert":
        img = np.array([196, 160, 104]) * (0.8 + 0.35 * n[..., None])
    elif kind == "snow":
        img = np.array([214, 222, 230]) * (0.8 + 0.25 * n[..., None])
    else:  # taverna / cidade
        img = np.array([132, 98, 66]) * (0.85 + 0.25 * n[..., None])
        im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)); d = ImageDraw.Draw(im)
        for i in range(0, w, 30):
            d.line([i, 0, i, h], fill=(104, 76, 50), width=2)
        for x0, y0 in [(40, 40), (220, 50), (60, 150), (230, 150)]:
            d.ellipse([x0, y0, x0 + 60, y0 + 50], fill=(92, 60, 34), outline=(60, 40, 22), width=3)
        return im
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.SMOOTH)


# ---------------------------------------------------------------- placa a partir do layout real
def board_image(px=80):
    L = lupa.LuaRuntime()
    L.execute('''BTNS = {}; DECALS = {}
    self = { getScale=function() return {x=1,y=1,z=1} end, getCustomObject=function() return {mesh="m"} end,
      createButton=function(t) table.insert(BTNS,t) end, clearButtons=function() BTNS={} end,
      setDecals=function(d) DECALS=d end }
    function getObjectsWithTag() return {} end
    Global={setVectorLines=function() end}; Grid={}''')
    L.execute((ROOT / "Atlas.lua").read_text(encoding="utf-8"))
    names = {
        "pt": ["Cripta do Rei", "Taverna do Javali", "Floresta Sombria", "Porto de Valdren", "Dunas de Sal", "Pico Gelado"],
        "en": ["King's Crypt", "Boar's Head Tavern", "Shadow Forest", "Port of Valdren", "Salt Dunes", "Frozen Peak"],
    }[LANG]
    maps = ",".join(f'{{name="{n}", url="u{i}", fit="mesa"{", saved={}" if i in (0, 3) else ""}}}'
                    for i, n in enumerate(names))
    L.execute(f'D.lang = "{LANG}"; D.maps = {{ {maps} }}; D.current = 1; S.sel = 3; S.tab = "mapas"; build()')

    tex = Image.open(ROOT / "assets" / "atlas.png").convert("RGB")
    t = tex.width
    leather = tex.crop((int(0.02 * t), int(0.02 * t), int(0.48 * t), int(0.48 * t)))
    wood = tex.crop((int(0.02 * t), int(0.52 * t), int(0.48 * t), int(0.98 * t)))
    brass = tex.crop((int(0.52 * t), int(0.02 * t), int(0.98 * t), int(0.48 * t)))
    W, H = int((INNER_W + 2 * RIM) * px), int((INNER_D + 2 * RIM) * px)
    img = wood.resize((W, H))
    img.paste(leather.resize((int(INNER_W * px), int(INNER_D * px))), (int(RIM * px), int(RIM * px)))
    c = int(0.62 * px)
    for x in (0, W - c):
        for y in (0, H - c):
            img.paste(brass.resize((c, c)), (x, y))
    img.paste(brass.resize((int(3.2 * px), int(0.3 * px))), (W // 2 - int(1.6 * px), int(0.05 * px)))
    d = ImageDraw.Draw(img)

    def to_px(x, z_local):  # o script inverte o z (topo do painel = -z local)
        return (x + INNER_W / 2 + RIM) * px, (INNER_D / 2 + RIM + z_local) * px

    def col(cv):
        return tuple(int(cv[i] * 255) for i in (1, 2, 3))

    kinds = ["dungeon", "tavern", "forest", "sea", "desert", "snow"]
    for k, dc in enumerate(L.eval("DECALS").values()):
        x, zl = -dc.position[1], dc.position[3]  # decals têm o x espelhado
        w, h = dc.scale[1] * px, dc.scale[2] * px
        cx, cy = to_px(x, zl)
        img.paste(sample_map(k + 3, kinds[k % len(kinds)]).resize((int(w), int(h))), (int(cx - w / 2), int(cy - h / 2)))

    for b in L.eval("BTNS").values():
        x, zl = b.position[1], b.position[3]
        cx, cy = to_px(x, zl)
        w, h = (b.width or 0) / 450 * px, (b.height or 0) / 450 * px
        cv = b.color
        if w > 0 and (cv[4] is None or cv[4] > 0.05) and b.label:
            d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], 5, fill=col(cv))
        if b.label:
            fs = max(9, int(b.font_size / 450 * px * 0.92))
            f = font("arialbd.ttf", fs)
            tw = d.textlength(b.label, font=f)
            d.text((cx - tw / 2, cy - fs * 0.62), b.label, fill=col(b.font_color), font=f)
    return img


# ---------------------------------------------------------------- fundo e composição
def background():
    rng = np.random.default_rng(3)
    base = np.array([92, 24, 28], np.float32)
    n = noise(rng, SIZE, SIZE, 300, 300) * 0.22 + noise(rng, SIZE, SIZE, 40, 40) * 0.12 + noise(rng, SIZE, SIZE, 6, 6) * 0.1
    img = base * (0.82 + n)[..., None]
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    img *= np.clip(1 - 0.8 * ((x - 0.5) ** 2 + (y - 0.58) ** 2), 0.35, 1)[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def perspective_coeffs(src, dst):
    m = []
    for (x, y), (u, v) in zip(dst, src):
        m.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        m.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    return np.linalg.solve(np.array(m, np.float64), np.array(src, np.float64).reshape(8)).tolist()


def main():
    canvas = background()
    board = board_image()
    bw, bh = board.size
    dst = [(318, 262), (706, 262), (842, 1000), (182, 1000)]
    coeffs = perspective_coeffs([(0, 0), (bw, 0), (bw, bh), (0, bh)], dst)
    warped = board.convert("RGBA").transform((SIZE, SIZE), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    shadow = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(shadow).polygon([(p[0] + 16, p[1] + 22) for p in dst], fill=180)
    canvas.paste((18, 6, 8), (0, 0), shadow.filter(ImageFilter.GaussianBlur(22)))
    canvas.paste(warped, (0, 0), warped)

    d = ImageDraw.Draw(canvas)
    title = "Atlas do Mestre" if LANG == "pt" else "Game Master's Atlas"
    sub = "Mapas  ·  Miniaturas  ·  Grade" if LANG == "pt" else "Maps  ·  Thumbnails  ·  Grid"
    ft = font("georgiab.ttf", 96 if LANG == "pt" else 84)
    fs = font("georgia.ttf", 38)
    tw = d.textlength(title, font=ft)
    d.text(((SIZE - tw) / 2, 50), title, font=ft, fill=(242, 205, 120), stroke_width=5, stroke_fill=(36, 12, 10))
    sw = d.textlength(sub, font=fs)
    d.text(((SIZE - sw) / 2, 168), sub, font=fs, fill=(240, 226, 196), stroke_width=3, stroke_fill=(36, 12, 10))

    out = ROOT / "assets" / ("capa.jpg" if LANG == "pt" else "cover_en.jpg")
    canvas.convert("RGB").save(out, quality=90, optimize=True)
    print(out, out.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
