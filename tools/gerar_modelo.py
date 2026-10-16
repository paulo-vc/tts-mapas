"""Gera o modelo 3D da mesa de controle (assets/atlas.obj) e a textura (assets/atlas.png).

Uso: python tools/gerar_modelo.py   (precisa de pillow e numpy)

O modelo é feito em unidades do TTS, para ser usado em escala 1:
  - tampo de couro ardósia 10 x 15, com o topo em y = 0.30 (onde ficam os botões e as miniaturas)
  - moldura de nogueira escura, cantoneiras de latão, pés
  - plaqueta de latão na borda de cima (-z, que é o topo do painel no TTS)
Os valores precisam bater com BOARD em Atlas.lua.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

INNER_W, INNER_D = 10.0, 15.0
TOP_Y = 0.30
RIM_W, RIM_H = 0.40, 0.14
OUT = Path(__file__).resolve().parent.parent / "assets"
rng = np.random.default_rng(11)

# Regiões da textura (u0, v0, u1, v1)
WOOD = (0.02, 0.02, 0.48, 0.48)
DARK = (0.52, 0.02, 0.98, 0.48)
LEATHER = (0.02, 0.52, 0.48, 0.98)
BRASS = (0.52, 0.52, 0.98, 0.98)


class Mesh:
    def __init__(self):
        self.v, self.vt, self.vn, self.f = [], [], [], []

    def quad(self, p, n, region):
        """p: 4 vértices em ordem anti-horária vista de fora; n: normal."""
        u0, v0, u1, v1 = region
        base_v, base_t = len(self.v), len(self.vt)
        self.v += p
        self.vt += [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        self.vn.append(n)
        ni = len(self.vn)
        a, b, c, d = (base_v + i + 1 for i in range(4))
        ta, tb, tc, td = (base_t + i + 1 for i in range(4))
        self.f.append(((a, ta, ni), (b, tb, ni), (c, tc, ni)))
        self.f.append(((a, ta, ni), (c, tc, ni), (d, td, ni)))

    def box(self, x0, x1, y0, y1, z0, z1, region, top=None):
        top = top or region
        self.quad([(x0, y1, z0), (x0, y1, z1), (x1, y1, z1), (x1, y1, z0)], (0, 1, 0), top)       # cima
        self.quad([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0), region)   # baixo
        self.quad([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1), region)    # frente +z
        self.quad([(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], (0, 0, -1), region)   # trás -z
        self.quad([(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], (1, 0, 0), region)    # +x
        self.quad([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], (-1, 0, 0), region)   # -x

    def cylinder_x(self, x0, x1, cy, cz, r, region, seg=20):
        for i in range(seg):
            a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
            y0, z0 = cy + r * math.cos(a0), cz + r * math.sin(a0)
            y1, z1 = cy + r * math.cos(a1), cz + r * math.sin(a1)
            am = (a0 + a1) / 2
            n = (0, math.cos(am), math.sin(am))
            self.quad([(x0, y0, z0), (x0, y1, z1), (x1, y1, z1), (x1, y0, z0)], n, region)
            # tampas
            self.tri((x1, cy, cz), (x1, y0, z0), (x1, y1, z1), (1, 0, 0), region)
            self.tri((x0, cy, cz), (x0, y1, z1), (x0, y0, z0), (-1, 0, 0), region)

    def tri(self, a, b, c, n, region):
        u0, v0, u1, v1 = region
        bv, bt = len(self.v), len(self.vt)
        self.v += [a, b, c]
        self.vt += [((u0 + u1) / 2, (v0 + v1) / 2), (u0, v0), (u1, v1)]
        self.vn.append(n)
        ni = len(self.vn)
        self.f.append(((bv + 1, bt + 1, ni), (bv + 2, bt + 2, ni), (bv + 3, bt + 3, ni)))

    def save(self, path):
        lines = ["# Atlas do Mestre - mesa de controle (gerado por tools/gerar_modelo.py)"]
        lines += [f"v {x:.4f} {y:.4f} {z:.4f}" for x, y, z in self.v]
        lines += [f"vt {u:.4f} {v:.4f}" for u, v in self.vt]
        lines += [f"vn {x:.4f} {y:.4f} {z:.4f}" for x, y, z in self.vn]
        lines += ["f " + " ".join(f"{a}/{b}/{c}" for a, b, c in face) for face in self.f]
        path.write_text("\n".join(lines) + "\n", encoding="ascii")


def build_mesh():
    m = Mesh()
    hw, hd = INNER_W / 2, INNER_D / 2
    ow, od = hw + RIM_W, hd + RIM_W
    # Corpo: laterais em nogueira escura, topo em couro
    m.box(-ow, ow, 0.0, TOP_Y, -od, od, DARK, top=LEATHER)
    # Moldura
    ry0, ry1 = TOP_Y, TOP_Y + RIM_H
    m.box(-ow, ow, ry0, ry1, hd, od, WOOD)
    m.box(-ow, ow, ry0, ry1, -od, -hd, WOOD)
    m.box(-ow, -hw, ry0, ry1, -hd, hd, WOOD)
    m.box(hw, ow, ry0, ry1, -hd, hd, WOOD)
    # Cantoneiras de latão
    c = 0.62
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (ow - c / 2 + 0.03), sz * (od - c / 2 + 0.03)
            m.box(x - c / 2, x + c / 2, ry1, ry1 + 0.05, z - c / 2, z + c / 2, BRASS)
    # Pés
    f = 0.7
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = sx * (ow - f / 2 - 0.15), sz * (od - f / 2 - 0.15)
            m.box(x - f / 2, x + f / 2, -0.14, 0.0, z - f / 2, z + f / 2, DARK)
    # Plaqueta de latão no meio da borda de cima (-z) e frisos de latão nas laterais
    pw = 3.2
    m.box(-pw / 2, pw / 2, ry1, ry1 + 0.04, -od + 0.06, -hd - 0.06, BRASS)
    for sx in (-1, 1):
        x = sx * (hw + RIM_W / 2)
        m.box(x - 0.05, x + 0.05, ry1, ry1 + 0.02, -hd + 1.0, hd - 1.0, BRASS)
    return m


def smooth_noise(h, w, cy, cx):
    small = (rng.random((cy, cx)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC), np.float32) / 255


def wood(h, w, dark, light):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    warp = smooth_noise(h, w, 5, 3) * 50 + smooth_noise(h, w, 30, 6) * 6
    rings = np.sin((x + warp) * 0.12)
    g = np.clip(0.5 + 0.32 * rings + smooth_noise(h, w, 300, 40) * 0.2 - 0.1, 0, 1)
    d, l = np.array(dark, np.float32), np.array(light, np.float32)
    return d + (l - d) * g[..., None]


def leather(h, w):
    """Couro cor de ardósia: grão fino e manchas suaves, escurecendo um pouco nas bordas."""
    base = np.array([46, 50, 58], np.float32)
    grain = smooth_noise(h, w, 260, 260) * 0.10 + smooth_noise(h, w, 60, 60) * 0.06 + smooth_noise(h, w, 7, 7) * 0.08
    img = base * (0.92 + grain)[..., None]
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum(np.minimum(x, w - 1 - x), np.minimum(y, h - 1 - y)) / (0.5 * min(w, h))
    img *= (0.80 + 0.20 * np.clip(edge * 5, 0, 1))[..., None]
    return img


def brass(h, w):
    base = np.array([184, 134, 43], np.float32)
    n = smooth_noise(h, w, 60, 60) * 0.18 + smooth_noise(h, w, 6, 6) * 0.12
    return base * (0.88 + n)[..., None]


def build_texture(size=1024):
    tex = np.zeros((size, size, 3), np.float32)
    half = size // 2
    # Na imagem, v = 0 fica embaixo: linha = size - v * size
    def put(region, block):
        u0, v0, u1, v1 = region
        r0, r1 = int((1 - v1) * size), int((1 - v0) * size)
        c0, c1 = int(u0 * size), int(u1 * size)
        tex[r0:r1, c0:c1] = block(r1 - r0, c1 - c0)
    tex[:, :] = 90
    put(WOOD, lambda h, w: wood(h, w, (58, 34, 18), (104, 64, 36)))
    put(DARK, lambda h, w: wood(h, w, (32, 19, 10), (62, 38, 20)))
    put(LEATHER, leather)
    put(BRASS, brass)
    img = Image.fromarray(np.clip(tex, 0, 255).astype(np.uint8)).filter(ImageFilter.SMOOTH)
    return img


def main():
    OUT.mkdir(exist_ok=True)
    mesh = build_mesh()
    mesh.save(OUT / "atlas.obj")
    build_texture().save(OUT / "atlas.png", optimize=True)
    print(f"{len(mesh.v)} vértices, {len(mesh.f)} triângulos")


if __name__ == "__main__":
    main()
