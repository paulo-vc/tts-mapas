"""Gera assets/tabula.png: a textura de madeira da placa de controle.

Uso: python tools/gerar_tabula.py   (precisa de pillow e numpy)
A proporção segue BOARD em Controle.lua (8 x 16.5).
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BOARD_W, BOARD_D = 8, 16.5
W = 1024
H = round(W * BOARD_D / BOARD_W)
FRAME = 56
rng = np.random.default_rng(7)


def smooth_noise(h, w, cells_y, cells_x):
    small = rng.random((cells_y, cells_x)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def wood(h, w, vertical=True, tone=0.0):
    """Veios de madeira: anéis distorcidos por ruído."""
    if not vertical:
        return wood(w, h, True, tone).transpose(1, 0, 2)
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    warp = smooth_noise(h, w, 6, 3) * 60 + smooth_noise(h, w, 40, 6) * 8
    rings = np.sin((x + warp) * 0.11 + smooth_noise(h, w, 3, 2) * 6)
    fine = smooth_noise(h, w, 400, 60) * 0.25
    g = np.clip(0.5 + 0.35 * rings + fine - 0.12, 0, 1)
    dark = np.array([78, 46, 24], np.float32)
    light = np.array([146, 94, 52], np.float32)
    col = dark + (light - dark) * g[..., None]
    return np.clip(col * (1 + tone), 0, 255)


def main():
    img = np.zeros((H, W, 3), np.float32)

    # Tábuas verticais com tons levemente diferentes
    planks = 4
    pw = (W - 2 * FRAME) // planks
    for i in range(planks):
        x0 = FRAME + i * pw
        x1 = W - FRAME if i == planks - 1 else x0 + pw
        img[:, x0:x1] = wood(H, x1 - x0, True, rng.uniform(-0.08, 0.06))
        img[:, x0:x0 + 3] *= 0.45  # junta entre tábuas
        img[:, x0 + 3:x0 + 5] *= 1.12

    # Moldura com veio horizontal (lados com veio vertical)
    img[:FRAME] = wood(FRAME, W, False, -0.22)
    img[-FRAME:] = wood(FRAME, W, False, -0.22)
    img[:, :FRAME] = wood(H, FRAME, True, -0.22)
    img[:, -FRAME:] = wood(H, FRAME, True, -0.22)

    # Chanfro da moldura: luz em cima/esquerda, sombra embaixo/direita
    for d in range(10):
        f = 1.25 - d * 0.02
        s = 0.55 + d * 0.04
        img[d, d:W - d] *= f
        img[d:H - d, d] *= f
        img[H - 1 - d, d:W - d] *= s
        img[d:H - d, W - 1 - d] *= s
        # sombra interna (moldura sobre as tábuas)
        img[FRAME + d, FRAME:W - FRAME] *= s
        img[FRAME:H - FRAME, FRAME + d] *= s
        img[H - FRAME - 1 - d, FRAME:W - FRAME] *= f
        img[FRAME:H - FRAME, W - FRAME - 1 - d] *= f

    # Vinheta
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    v = ((x / W - 0.5) ** 2 + (y / H - 0.5) ** 2 * 0.6)
    img *= (1 - v * 0.55)[..., None]

    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    draw = ImageDraw.Draw(out)

    # Placa do título (o texto "MAPAS" é desenhado pelo script)
    title_y = round((0.5 + 0.3) / BOARD_D * H)
    pw2, ph2 = int(W * 0.56), 74
    box = [W // 2 - pw2 // 2, title_y - ph2 // 2, W // 2 + pw2 // 2, title_y + ph2 // 2]
    draw.rounded_rectangle([box[0] - 6, box[1] - 6, box[2] + 6, box[3] + 6], 16, fill=(150, 112, 44))
    draw.rounded_rectangle([box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2], 13, fill=(92, 66, 22))
    draw.rounded_rectangle(box, 12, fill=(40, 24, 13))

    # Cravos de latão
    def stud(cx, cy, r=13):
        for k in range(r, 0, -1):
            t = k / r
            c = (int(120 + 110 * (1 - t)), int(88 + 90 * (1 - t)), int(30 + 40 * (1 - t)))
            draw.ellipse([cx - k - r * 0.25 * (1 - t), cy - k - r * 0.25 * (1 - t),
                          cx + k - r * 0.25 * (1 - t), cy + k - r * 0.25 * (1 - t)], fill=c)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(60, 40, 12), width=2)

    m = FRAME // 2
    for cy in [m, H - m] + list(np.linspace(m, H - m, 9)[1:-1].astype(int)):
        stud(m, int(cy))
        stud(W - m, int(cy))
    for cx in np.linspace(m, W - m, 5)[1:-1].astype(int):
        stud(int(cx), m)
        stud(int(cx), H - m)
    for bx in (box[0] + 18, box[2] - 18):
        stud(bx, title_y, 9)

    out = out.filter(ImageFilter.SMOOTH)
    dest = Path(__file__).resolve().parent.parent / "assets" / "tabula.png"
    dest.parent.mkdir(exist_ok=True)
    out.save(dest, optimize=True)
    print(dest, out.size)


if __name__ == "__main__":
    main()
