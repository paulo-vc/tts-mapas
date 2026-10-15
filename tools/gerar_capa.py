"""Gera assets/capa.jpg: a imagem de capa da Steam Workshop (1024 x 1024).

Uso: python tools/gerar_capa.py [pt|en]   (precisa de pillow, numpy e lupa)
A placa é desenhada a partir do layout real de Atlas.lua (mesmos botões, cores e posições).
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
rng = np.random.default_rng(3)


def font(name, size):
    try:
        return ImageFont.truetype(str(FONTS / name), size)
    except OSError:
        return ImageFont.load_default()


def noise(h, w, cy, cx):
    small = (rng.random((cy, cx)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC), np.float32) / 255


# ---------------------------------------------------------------- placa vista de cima
def board_image(px=80):
    L = lupa.LuaRuntime()
    L.execute('''BTNS = {}
    self = { getScale=function() return {x=1,y=1,z=1} end, getCustomObject=function() return {mesh="m"} end,
      createButton=function(t) t.kind="b"; table.insert(BTNS,t) end,
      createInput=function(t) t.kind="i"; table.insert(BTNS,t) end,
      clearButtons=function() BTNS={} end, clearInputs=function() end }
    function getObjectsWithTag() return {} end
    Global={setVectorLines=function() end}; Grid={}''')
    L.execute((ROOT / "Atlas.lua").read_text(encoding="utf-8"))
    names = {
        "pt": ["Masmorra do Rei Caído", "Taverna do Javali", "Floresta Sombria", "Porto de Valdren",
               "Torre do Arquimago", "Minas de Karak", "Ruínas do Templo"],
        "en": ["Fallen King's Crypt", "Boar's Head Tavern", "Shadow Forest", "Port of Valdren",
               "Archmage's Tower", "Mines of Karak", "Temple Ruins"],
    }[LANG]
    folder = "Ato 1" if LANG == "pt" else "Act 1"
    L.execute(f'''D.lang = "{LANG}"
    D.folders = {{"{folder}"}}
    D.maps = {{ {{name="{names[0]}", url="x", fit="caber", saved={{}}}},
               {{name="{names[1]}", url="x", fit="mesa"}},
               {{name="{names[2]}", url="x", fit="mesa", saved={{}}}},
               {{name="{names[3]}", url="x", fit="mesa"}},
               {{name="{names[4]}", url="x", fit="mesa", saved={{}}}},
               {{name="{names[5]}", url="x", fit="mesa"}},
               {{name="{names[6]}", url="x", fit="mesa"}},
               {{name="x", url="x", fit="mesa", folder="{folder}"}} }}
    D.current = 1; S.tab = "mapas"; build()''')

    inner_w, inner_d, rim = 9.0, 11.8, 0.4
    W, H = int((inner_w + 2 * rim) * px), int((inner_d + 2 * rim) * px)
    tex = Image.open(ROOT / "assets" / "atlas.png").convert("RGB")
    t = tex.width
    wood = tex.crop((int(0.02 * t), int(0.52 * t), int(0.48 * t), int(0.98 * t)))
    parch = tex.crop((int(0.02 * t), int(0.02 * t), int(0.48 * t), int(0.48 * t)))
    brass = tex.crop((int(0.52 * t), int(0.02 * t), int(0.98 * t), int(0.48 * t)))

    img = wood.resize((W, H))
    img.paste(parch.resize((int(inner_w * px), int(inner_d * px))), (int(rim * px), int(rim * px)))
    d = ImageDraw.Draw(img)
    # chanfro da moldura
    r = int(rim * px)
    d.rectangle([r - 4, r - 4, W - r + 3, r - 1], fill=(60, 36, 18))
    d.rectangle([r - 4, r - 4, r - 1, H - r + 3], fill=(60, 36, 18))
    c = int(0.62 * px)
    for x in (0, W - c):
        for y in (0, H - c):
            img.paste(brass.resize((c, c)), (x, y))

    def col(cv):
        return tuple(int(cv[i] * 255) for i in (1, 2, 3))

    for b in L.eval("BTNS").values():
        x, z = b.position[1], -b.position[3]  # place() inverte o z
        cx, cy = (x + inner_w / 2 + rim) * px, (inner_d / 2 + rim - z) * px
        w, h = (b.width or 0) / 450 * px, (b.height or 0) / 450 * px
        fs = max(9, int(b.font_size / 450 * px * 0.92))
        f = font("arialbd.ttf", fs)
        if b.kind == "i":
            d.rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], fill=col(b.color))
            d.text((cx - w / 2 + 10, cy - fs * 0.62), b.label, fill=(150, 128, 98), font=font("arial.ttf", fs))
            continue
        cv = b.color
        if w > 0 and (cv[4] is None or cv[4] > 0):
            d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], 5, fill=col(cv))
        tw = d.textlength(b.label, font=f)
        d.text((cx - tw / 2, cy - fs * 0.62), b.label, fill=col(b.font_color), font=f)
    return img


# ---------------------------------------------------------------- fundo: pano da mesa
def background():
    base = np.array([96, 22, 26], np.float32)
    n = noise(SIZE, SIZE, 300, 300) * 0.22 + noise(SIZE, SIZE, 40, 40) * 0.12 + noise(SIZE, SIZE, 6, 6) * 0.10
    img = base * (0.80 + n)[..., None]
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    vig = 1 - 0.75 * ((x - 0.5) ** 2 + (y - 0.55) ** 2)
    img *= np.clip(vig, 0.35, 1)[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def perspective_coeffs(src, dst):
    """Coeficientes para Image.transform(PERSPECTIVE) levando dst -> src."""
    m = []
    for (x, y), (u, v) in zip(dst, src):
        m.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        m.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    a = np.array(m, np.float64)
    b = np.array(src, np.float64).reshape(8)
    return np.linalg.solve(a, b).tolist()


def main():
    canvas = background()
    board = board_image()
    bw, bh = board.size

    # Placa inclinada, como vista da cadeira do mestre
    dst = [(300, 300), (724, 300), (840, 985), (184, 985)]
    coeffs = perspective_coeffs([(0, 0), (bw, 0), (bw, bh), (0, bh)], dst)
    warped = board.convert("RGBA").transform((SIZE, SIZE), Image.PERSPECTIVE, coeffs, Image.BICUBIC)

    # sombra no pano
    shadow = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(shadow).polygon([(p[0] + 18, p[1] + 24) for p in dst], fill=170)
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas.paste((20, 6, 8), (0, 0), shadow)
    canvas.paste(warped, (0, 0), warped)

    # mapa enrolado na borda de cima da placa
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle([318, 270, 706, 302], 14, fill=(226, 204, 158), outline=(150, 120, 70), width=2)
    for x0 in (296, 704):
        d.rounded_rectangle([x0, 264, x0 + 24, 308], 8, fill=(190, 140, 50), outline=(110, 78, 24), width=2)

    # Título
    title = "Atlas do Mestre" if LANG == "pt" else "Game Master's Atlas"
    sub = "Mapas  ·  Grade  ·  Névoa de guerra" if LANG == "pt" else "Maps  ·  Grid  ·  Fog of war"
    ft = font("georgiab.ttf", 96 if LANG == "pt" else 84)
    fs = font("georgia.ttf", 38)
    tw = d.textlength(title, font=ft)
    d.text(((SIZE - tw) / 2, 58), title, font=ft, fill=(242, 205, 120),
           stroke_width=5, stroke_fill=(40, 12, 10))
    sw = d.textlength(sub, font=fs)
    d.text(((SIZE - sw) / 2, 178), sub, font=fs, fill=(240, 226, 196), stroke_width=3, stroke_fill=(40, 12, 10))

    out = ROOT / "assets" / ("capa.jpg" if LANG == "pt" else "cover_en.jpg")
    canvas.convert("RGB").save(out, quality=90, optimize=True)
    print(out, out.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
