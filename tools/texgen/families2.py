"""Procedural PBR surface library v2: real colour albedo per family.
surf_a: RGB = albedo (sRGB), A = roughness
surf_n: RG = tangent normal xy, B = height/AO, A = secondary mask (mortar / chipped paint / soil / lichen)
Families with tint=True are near-grey so the shader multiplies the palette colour in.
"""
import numpy as np, sys, os, time
from PIL import Image
from noise import fbm, ridged, worley, value_noise, smoothstep, height_to_normal, cavity_from_height, blur
from families import bricks, norm01

FAMS = ["smooth", "concrete", "plaster", "ashlar", "brick", "cobble", "asphalt", "wood", "paint_metal", "brushed",
        "corrugated", "rock", "grass", "terracotta", "fabric", "rubber", "tread", "paving", "bark", "leaves"]
TINTED = {"smooth", "paint_metal", "brushed", "fabric", "rubber", "tread", "corrugated"}

def col(r, g, b):
    return np.array([r, g, b]) / 255.0

def lerp(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) == 2 else t
    return a + (b - a) * t

def mono(v):
    return np.stack([v, v, v], axis=-1)

def family(name, n, seed=1):
    s = seed * 100
    if name == "smooth":
        base = 0.5 + fbm(n, 5, 4, s) * 0.03
        alb = mono(base); rough = 0.35 + fbm(n, 5, 3, s + 2) * 0.1; h = 0.5 + fbm(n, 4, 3, s) * 0.02; mask = np.zeros((n, n))
    elif name == "concrete":
        base = fbm(n, 10, 6, s); fine = fbm(n, 80, 3, s + 1)
        pits = (1 - smoothstep(0.05, 0.16, worley(n, 26, s + 9)[0])) * (value_noise(n, 26, s + 8) > 0.68)
        stains = smoothstep(0.45, 0.8, fbm(n, 3, 4, s + 11))
        h = 0.55 + base * 0.1 + fine * 0.03 - pits * 0.25
        c = lerp(col(150, 148, 142), col(118, 116, 112), 0.5 + base * 0.8)
        c = lerp(c, col(92, 90, 86), stains * 0.6)
        c *= (1 + fine * 0.18)[..., None]; c = lerp(c, col(70, 68, 64), pits * 0.8)
        alb = c; rough = 0.88 + fine * 0.05 - stains * 0.08 + pits * 0.05; mask = stains
    elif name == "plaster":
        base = fbm(n, 6, 6, s); fine = fbm(n, 110, 3, s + 1)
        crack = smoothstep(0.84, 0.97, ridged(n, 6, 4, s + 3)) * (fbm(n, 2, 2, s + 4) > 0.05)
        chips = smoothstep(0.6, 0.72, fbm(n, 4, 5, s + 6)); grime = smoothstep(0.3, 0.9, fbm(n, 3, 4, s + 7))
        h = 0.6 + base * 0.07 + fine * 0.03 - crack * 0.2 - chips * 0.12
        c = lerp(col(226, 214, 196), col(196, 182, 160), 0.5 + base * 0.9)
        c = lerp(c, col(150, 138, 118), grime * 0.45) * (1 + fine * 0.1)[..., None]
        c = lerp(c, col(120, 108, 92), crack * 0.8); c = lerp(c, col(160, 150, 136), chips * 0.9)
        alb = c; rough = 0.86 + fine * 0.05 + chips * 0.06; mask = chips
    elif name == "ashlar":
        bh, mortar, cid = bricks(n, 3, 5, mortar=0.045, offset=0.5, seed=s)
        stone = fbm(n, 24, 5, s + 1) * 0.5 + fbm(n, 70, 3, s + 2) * 0.2; veins = smoothstep(0.75, 0.95, ridged(n, 9, 3, s + 4))
        h = 0.3 + 0.55 * bh * (0.85 + stone * 0.15) + stone * 0.05
        c = lerp(col(214, 198, 168), col(176, 158, 128), cid)
        c = c * (1 + stone * 0.35)[..., None]; c = lerp(c, col(236, 228, 210), veins * 0.35)
        c = lerp(c, col(128, 118, 100), mortar * 0.8)
        alb = c; rough = 0.84 + mortar * 0.1 - stone * 0.05 + veins * 0.05; mask = mortar
    elif name == "brick":
        bh, mortar, cid = bricks(n, 6, 16, mortar=0.09, offset=0.5, seed=s)
        grain = fbm(n, 40, 4, s + 1)
        h = 0.35 + 0.5 * bh + grain * 0.06
        c = lerp(col(166, 84, 60), col(120, 62, 48), cid); c = lerp(c, col(190, 120, 90), smoothstep(0.7, 0.9, cid) * 0.5)
        c = c * (1 + grain * 0.25)[..., None]; c = lerp(c, col(170, 160, 146), mortar * 0.9)
        alb = c; rough = 0.9; mask = mortar
    elif name == "cobble":
        f1, f2, cid = worley(n, 8, s, 0.9)
        edge = smoothstep(0.0, 0.18, f2 - f1); dome = np.clip(1.0 - f1 * 1.6, 0, 1); grain = fbm(n, 50, 3, s + 1)
        h = 0.25 + 0.6 * edge * (0.6 + 0.4 * dome) + grain * 0.04
        c = lerp(col(150, 140, 126), col(104, 96, 88), cid); c = lerp(c, col(176, 164, 144), smoothstep(0.6, 1.0, cid) * 0.4)
        c = c * (1 + grain * 0.2)[..., None]; c = lerp(c, col(66, 60, 52), (1 - edge) * 0.85)
        alb = c; rough = 0.75 + (1 - edge) * 0.2; mask = 1 - edge
    elif name == "asphalt":
        grain = fbm(n, 120, 3, s); pebbles = smoothstep(0.75, 0.95, value_noise(n, 90, s + 2)); patch = fbm(n, 3, 4, s + 3)
        h = 0.5 + grain * 0.06 + pebbles * 0.08
        c = lerp(col(54, 54, 56), col(78, 77, 76), 0.5 + patch * 0.8); c = c * (1 + grain * 0.25)[..., None]
        c = lerp(c, col(140, 136, 128), pebbles * 0.7)
        alb = c; rough = 0.85 - pebbles * 0.1; mask = smoothstep(0.5, 0.8, fbm(n, 4, 4, s + 5)) * 0.5
    elif name == "wood":
        ys, xs = np.mgrid[0:n, 0:n] / n
        plank_w = 1.0 / 5.0; pid = np.floor(xs / plank_w); pf = (xs / plank_w) - pid
        off = ((np.sin(pid * 91.7) * 4321.0) % 1.0)
        grain = 0.5 + 0.5 * np.sin((ys * 1.2 + off * 5.0 + fbm(n, 3, 3, s) * 0.12 + (xs / plank_w - pid) * 0.35) * 2 * np.pi * 9.0)
        grain = grain * 0.6 + 0.4 * (0.5 + 0.5 * np.sin((ys * 6.0 + off * 3.0 + fbm(n, 5, 3, s + 4) * 0.25) * 2 * np.pi * 7.0))
        fine = fbm(n, 150, 2, s + 1); gap = 1 - smoothstep(0.0, 0.05, np.minimum(pf, 1 - pf))
        h = 0.55 + grain * 0.05 + fine * 0.03 - gap * 0.3
        c = lerp(col(146, 104, 66), col(96, 66, 40), grain); c = lerp(c, col(172, 128, 86), (off - 0.5) * 0.6 + 0.3)
        c = c * (1 + fine * 0.15)[..., None]; c = lerp(c, col(40, 30, 22), gap * 0.9)
        alb = c; rough = 0.72 + grain * 0.12 + gap * 0.1; mask = smoothstep(0.65, 0.9, fbm(n, 3, 4, s + 7)) * 0.7
    elif name == "paint_metal":
        base = fbm(n, 8, 5, s); chips = smoothstep(0.58, 0.68, fbm(n, 5, 6, s + 3)) * (fbm(n, 2, 3, s + 4) > -0.1)
        rust_bleed = blur(chips, 6); scratches = smoothstep(0.9, 1.0, ridged(n, 30, 2, s + 8)) * 0.6
        h = 0.6 + base * 0.03 - chips * 0.1
        alb = mono(0.5 + base * 0.08 - scratches * 0.3)
        rough = 0.45 + base * 0.1 + chips * 0.45 + rust_bleed * 0.2; mask = np.clip(chips + rust_bleed * 0.5, 0, 1)
    elif name == "brushed":
        streak = value_noise(n, 400, s + 1) * 0.7 + value_noise(n, 180, s + 2) * 0.3
        st = np.zeros_like(streak)
        for k in range(-6, 7):
            st += np.roll(streak, k, axis=1)
        st /= 13.0
        h = 0.5 + st * 0.02; alb = mono(0.5 + (st - 0.5) * 0.25)
        rough = 0.35 + (st - 0.5) * 0.2 + fbm(n, 4, 3, s + 3) * 0.08; mask = smoothstep(0.6, 0.9, fbm(n, 4, 4, s + 6)) * 0.5
    elif name == "corrugated":
        ys, xs = np.mgrid[0:n, 0:n] / n
        wave = 0.5 + 0.5 * np.sin(xs * 2 * np.pi * 12)
        rust = smoothstep(0.55, 0.75, fbm(n, 5, 5, s + 2)) * smoothstep(0.3, 0.7, 1 - ys + fbm(n, 4, 3, s + 3) * 0.5)
        h = 0.3 + wave * 0.5 - rust * 0.08
        alb = mono(0.5 + (wave - 0.5) * 0.1 + fbm(n, 30, 3, s + 1) * 0.08)
        rough = 0.5 + rust * 0.45; mask = rust
    elif name == "rock":
        r = ridged(n, 5, 6, s); f = fbm(n, 12, 5, s + 1)
        strata = 0.5 + 0.5 * np.sin((np.mgrid[0:n, 0:n][0] / n + f * 0.15) * 2 * np.pi * 5)
        h = norm01(r * 0.7 + f * 0.3 + strata * 0.08); fine = fbm(n, 90, 3, s + 2)
        lichen = smoothstep(0.6, 0.85, fbm(n, 4, 4, s + 5))
        c = lerp(col(112, 104, 94), col(160, 150, 134), h); c = lerp(c, col(134, 112, 86), strata * 0.25)
        c = c * (1 + fine * 0.2)[..., None]; c = lerp(c, col(120, 128, 70), lichen * 0.4)
        alb = c; rough = 0.92 - h * 0.08; mask = lichen * 0.6
    elif name == "grass":
        blades = np.zeros((n, n))
        for k in range(3):
            blades += np.abs(fbm(n, 60 * (k + 1), 3, s + k)) * (0.6 - k * 0.15)
        tufts = fbm(n, 8, 4, s + 9); soil = smoothstep(0.4, 0.75, fbm(n, 5, 4, s + 11))
        h = 0.5 + blades * 0.25 + tufts * 0.1
        c = lerp(col(120, 118, 60), col(70, 88, 38), 0.5 + tufts * 0.9); c = c * (0.7 + blades * 0.9)[..., None]
        c = lerp(c, col(110, 82, 58), soil * 0.8)
        alb = c; rough = 0.95; mask = soil
    elif name == "terracotta":
        ys, xs = np.mgrid[0:n, 0:n] / n
        tiles = 0.5 + 0.5 * np.sin(xs * 2 * np.pi * 10); rows = smoothstep(0.85, 1.0, ((ys * 12) % 1.0))
        cid = ((np.floor(xs * 10) * 7.3 + np.floor(ys * 12) * 3.1) % 1.0)
        h = 0.35 + tiles * 0.45 - rows * 0.35 + fbm(n, 40, 3, s) * 0.04
        c = lerp(col(176, 92, 58), col(140, 70, 48), cid); c = c * (1 + fbm(n, 20, 4, s + 1) * 0.25)[..., None]
        c = lerp(c, col(90, 60, 44), rows * 0.7); moss = smoothstep(0.6, 0.85, fbm(n, 5, 4, s + 3))
        c = lerp(c, col(96, 104, 60), moss * 0.5)
        alb = c; rough = 0.85; mask = moss * 0.6
    elif name == "fabric":
        ys, xs = np.mgrid[0:n, 0:n] / n
        weave = 0.5 + 0.25 * np.sin(xs * 2 * np.pi * 160) + 0.25 * np.sin(ys * 2 * np.pi * 160)
        h = 0.5 + (weave - 0.5) * 0.2 + fbm(n, 6, 4, s) * 0.04
        alb = mono(0.5 + (weave - 0.5) * 0.3 + fbm(n, 6, 3, s + 1) * 0.08)
        rough = 0.95; mask = smoothstep(0.6, 0.9, fbm(n, 3, 4, s + 2)) * 0.4
    elif name == "rubber":
        b = fbm(n, 70, 3, s)
        h = 0.5 + b * 0.04; alb = mono(0.5 + b * 0.06); rough = 0.9 + b * 0.05
        mask = smoothstep(0.7, 0.95, fbm(n, 5, 3, s + 1)) * 0.3
    elif name == "tread":
        ys, xs = np.mgrid[0:n, 0:n] / n
        cx = (xs * 8) % 1.0; cy = (ys * 8) % 1.0
        bar = (1 - smoothstep(0.08, 0.14, np.abs((cx + cy) % 1.0 - 0.5))) * (1 - smoothstep(0.25, 0.3, np.abs(cx - 0.5)))
        h = 0.45 + bar * 0.45 + fbm(n, 30, 3, s) * 0.03
        alb = mono(0.5 + bar * 0.15 + fbm(n, 30, 3, s + 1) * 0.1)
        rough = 0.55 + (1 - bar) * 0.15; mask = smoothstep(0.65, 0.9, fbm(n, 4, 4, s + 2)) * 0.5
    elif name == "paving":
        # worn flagstones: staggered rows, thin joints, strong per-stone tone variation, chipped edges
        bh, mortar, cid = bricks(n, 3, 5, mortar=0.022, offset=0.5, seed=s)
        grain = fbm(n, 36, 4, s + 1); wear = fbm(n, 6, 4, s + 3); chips = smoothstep(0.55, 0.9, fbm(n, 90, 2, s + 5)) * smoothstep(0.6, 1.0, mortar + 0.3)
        h = 0.3 + 0.45 * bh + grain * 0.05 - chips * 0.15 + wear * 0.03
        tone = (cid * 1.7) % 1.0
        c = lerp(col(176, 166, 150), col(128, 120, 108), tone); c = c * (1 + grain * 0.18 + wear * 0.12)[..., None]
        c = lerp(c, col(112, 104, 92), mortar * 0.6)
        alb = c; rough = 0.88 + mortar * 0.08 - wear * 0.04; mask = mortar
    elif name == "bark":
        ys, xs = np.mgrid[0:n, 0:n] / n
        r = ridged(n, 4, 5, s)
        fissure = smoothstep(0.55, 0.9, np.abs(np.sin((xs * 6 + fbm(n, 3, 3, s + 1) * 1.2) * np.pi)) * (0.6 + 0.4 * r))
        h = 0.3 + fissure * 0.5 + fbm(n, 40, 3, s + 2) * 0.08
        c = lerp(col(70, 56, 44), col(126, 108, 88), fissure); c = c * (1 + fbm(n, 20, 4, s + 3) * 0.25)[..., None]
        moss = smoothstep(0.5, 0.8, fbm(n, 4, 4, s + 4)); c = lerp(c, col(90, 110, 60), moss * 0.4)
        alb = c; rough = 0.95; mask = moss * 0.5
    elif name == "leaves":
        f1, f2, cid = worley(n, 14, s, 1.0)
        leaf = smoothstep(0.02, 0.2, f2 - f1) * (1 - smoothstep(0.5, 0.8, f1))
        h = 0.4 + leaf * 0.4 + fbm(n, 30, 3, s + 1) * 0.05
        c = lerp(col(78, 96, 52), col(132, 142, 86), cid); c = c * (0.6 + leaf * 0.6)[..., None]
        alb = c; rough = 0.85; mask = 1 - leaf
    else:
        raise ValueError(name)
    cav = cavity_from_height(h, 3)
    alb = np.clip(alb * (0.75 + 0.25 * cav)[..., None], 0, 1)
    return alb, np.clip(rough, 0, 1), np.clip(h, 0, 1), np.clip(mask, 0, 1)

def build(n, out_dir):
    A = np.zeros((n, n * len(FAMS), 4), dtype=np.uint8); N = np.zeros((n, n * len(FAMS), 4), dtype=np.uint8)
    for i, name in enumerate(FAMS):
        t = time.time()
        alb, rough, h, mask = family(name, n, seed=i + 1)
        nm = height_to_normal(h, 1.1 * (512.0 / n))
        A[:, i * n:(i + 1) * n, :3] = (alb * 255).astype(np.uint8); A[:, i * n:(i + 1) * n, 3] = (rough * 255).astype(np.uint8)
        N[:, i * n:(i + 1) * n, 0] = (nm[..., 0] * 255).astype(np.uint8); N[:, i * n:(i + 1) * n, 1] = (nm[..., 1] * 255).astype(np.uint8)
        N[:, i * n:(i + 1) * n, 2] = (h * 255).astype(np.uint8); N[:, i * n:(i + 1) * n, 3] = (mask * 255).astype(np.uint8)
        print(f"{name:12s} {n} {time.time() - t:.1f}s", flush=True)
    Image.fromarray(A, "RGBA").save(os.path.join(out_dir, f"surf_a_{n}.png"))
    Image.fromarray(N, "RGBA").save(os.path.join(out_dir, f"surf_n_{n}.png"))
    # preview sheet
    sheet = np.concatenate([np.concatenate([A[:, i * n:(i + 1) * n, :3] for i in range(r * 5, r * 5 + 5)], 1) for r in range(4)], 0)
    Image.fromarray(sheet).resize((sheet.shape[1] // 2, sheet.shape[0] // 2)).save(os.path.join(out_dir, f"sheet_{n}.png"))

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 512
    build(n, sys.argv[2] if len(sys.argv) > 2 else "/tmp")
