"""Procedural PBR surface library for the world: 20 families packed into two texture arrays.
surf_a: R = albedo detail (0.5 = neutral), G = roughness, B = cavity/AO, A = tint variation
surf_n: R,G = normal xy (0.5 = flat), B = height, A = secondary mask (mortar, chipped paint, soil...)
Layer order must match Surf.FAM in game/scripts/surf.gd.
"""
import numpy as np, sys, os, time
from PIL import Image
from noise import fbm, ridged, worley, value_noise, grad_noise, smoothstep, height_to_normal, cavity_from_height, blur

FAMS = ["smooth", "concrete", "plaster", "ashlar", "brick", "cobble", "asphalt", "wood", "paint_metal", "brushed",
        "corrugated", "rock", "grass", "terracotta", "fabric", "rubber", "tread", "paving", "bark", "leaves"]

def norm01(a):
    lo, hi = np.percentile(a, 0.5), np.percentile(a, 99.5)
    return np.clip((a - lo) / max(hi - lo, 1e-6), 0, 1)

def bricks(n, nx, ny, mortar=0.08, offset=0.5, seed=0, bevel=0.06):
    """Returns (height, mortar_mask, block id noise) for a running-bond pattern."""
    ys, xs = np.mgrid[0:n, 0:n] / n
    row = np.floor(ys * ny); u = xs * nx + (row % 2) * offset
    col = np.floor(u); fx = u - col; fy = ys * ny - row
    dx = np.minimum(fx, 1 - fx); dy = np.minimum(fy, 1 - fy)
    d = np.minimum(dx / (mortar), dy / (mortar * nx / ny))
    h = smoothstep(0.0, 1.0, np.clip(d, 0, 1))
    h = np.minimum(h, smoothstep(0, bevel * 6, np.minimum(dx, dy) + 0.0) * 0.0 + h)
    mortar_mask = 1.0 - smoothstep(0.6, 1.0, d)
    cid = ((np.sin(col * 12.9898 + row * 78.233) * 43758.5453) % 1.0)
    return h, mortar_mask, cid

def family(name, n, seed=1):
    """Returns albedo_detail, rough, cavity, tint, height, mask (all n x n in [0,1])."""
    s = seed * 100
    if name == "smooth":
        h = 0.5 + fbm(n, 4, 3, s) * 0.02
        det = 0.5 + fbm(n, 6, 3, s + 1) * 0.03; rough = 0.35 + fbm(n, 5, 3, s + 2) * 0.08
        cav = np.ones((n, n)); tint = 0.5 + fbm(n, 2, 2, s + 3) * 0.1; mask = np.zeros((n, n))
    elif name == "concrete":
        base = fbm(n, 10, 6, s)
        pores = smoothstep(0.35, 0.6, worley(n, 48, s + 5)[0]) 
        pits = (1 - smoothstep(0.08, 0.2, worley(n, 24, s + 9)[0])) * (value_noise(n, 24, s + 8) > 0.72)
        h = 0.55 + base * 0.12 - pits * 0.25 - (1 - pores) * 0.02
        det = 0.5 + base * 0.2 + fbm(n, 60, 3, s + 2) * 0.06 - pits * 0.12
        rough = 0.9 - base * 0.05 + pits * 0.05
        mask = smoothstep(0.55, 0.8, fbm(n, 3, 4, s + 11)) * 0.6   # damp patches
        tint = 0.5 + fbm(n, 3, 3, s + 4) * 0.25
        cav = cavity_from_height(h, 3)
    elif name == "plaster":
        base = fbm(n, 6, 6, s); fine = fbm(n, 90, 3, s + 1)
        cracks = ridged(n, 6, 4, s + 3); crack = smoothstep(0.86, 0.97, cracks) * (fbm(n, 2, 2, s + 4) > 0.05)
        chips = smoothstep(0.62, 0.72, fbm(n, 4, 5, s + 6))
        h = 0.6 + base * 0.08 + fine * 0.03 - crack * 0.2 - chips * 0.12
        det = 0.5 + base * 0.12 + fine * 0.08 - crack * 0.25
        rough = 0.88 + fine * 0.05
        mask = chips  # exposed stone/under-layer
        tint = 0.5 + fbm(n, 2, 3, s + 7) * 0.2
        cav = cavity_from_height(h, 2)
    elif name == "ashlar":
        bh, mortar, cid = bricks(n, 3, 5, mortar=0.045, offset=0.5, seed=s)
        stone = fbm(n, 24, 5, s + 1) * 0.5 + fbm(n, 70, 3, s + 2) * 0.2
        edgewear = smoothstep(0.3, 0.9, bh)
        h = 0.3 + 0.55 * bh * (0.8 + stone * 0.2) + stone * 0.05
        det = 0.5 + stone * 0.25 + (cid - 0.5) * 0.18 - mortar * 0.12
        rough = 0.86 + mortar * 0.08 - stone * 0.05
        mask = mortar
        tint = cid
        cav = cavity_from_height(h, 3)
    elif name == "brick":
        bh, mortar, cid = bricks(n, 6, 16, mortar=0.09, offset=0.5, seed=s)
        grain = fbm(n, 40, 4, s + 1)
        h = 0.35 + 0.5 * bh + grain * 0.06
        det = 0.5 + (cid - 0.5) * 0.3 + grain * 0.15 - mortar * 0.1
        rough = 0.9; mask = mortar; tint = cid; cav = cavity_from_height(h, 3)
    elif name == "cobble":
        f1, f2, cid = worley(n, 8, s, 0.9)
        edge = smoothstep(0.0, 0.18, f2 - f1)
        dome = np.clip(1.0 - f1 * 1.6, 0, 1)
        grain = fbm(n, 50, 3, s + 1)
        h = 0.25 + 0.6 * edge * (0.6 + 0.4 * dome) + grain * 0.04
        det = 0.5 + (cid - 0.5) * 0.3 + grain * 0.12 - (1 - edge) * 0.15
        rough = 0.75 + (1 - edge) * 0.2
        mask = 1 - edge
        tint = cid; cav = cavity_from_height(h, 3)
    elif name == "asphalt":
        grain = fbm(n, 120, 3, s); pebbles = smoothstep(0.75, 0.95, value_noise(n, 90, s + 2))
        patch = fbm(n, 3, 4, s + 3)
        h = 0.5 + grain * 0.06 + pebbles * 0.08
        det = 0.5 + grain * 0.12 + pebbles * 0.2 + patch * 0.06
        rough = 0.85 - pebbles * 0.1
        mask = smoothstep(0.5, 0.8, fbm(n, 4, 4, s + 5)) * 0.5  # wet/oil patches
        tint = 0.5 + patch * 0.3; cav = cavity_from_height(h, 2)
    elif name == "wood":
        ys, xs = np.mgrid[0:n, 0:n] / n
        plank_w = 1.0 / 5.0
        pid = np.floor(xs / plank_w); pf = (xs / plank_w) - pid
        off = ((np.sin(pid * 91.7) * 4321.0) % 1.0)
        grain = np.sin((ys * 3.0 + off * 5.0 + fbm(n, 6, 4, s) * 0.6 + xs * 0.4) * 2 * np.pi * 7.0)
        rings = 0.5 + 0.5 * grain
        fine = fbm(n, 150, 2, s + 1)
        gap = 1 - smoothstep(0.0, 0.06, np.minimum(pf, 1 - pf))
        h = 0.55 + rings * 0.05 + fine * 0.03 - gap * 0.3
        det = 0.5 + (rings - 0.5) * 0.3 + fine * 0.12 + (off - 0.5) * 0.25 - gap * 0.3
        rough = 0.75 + rings * 0.1 + gap * 0.1
        mask = smoothstep(0.65, 0.9, fbm(n, 3, 4, s + 7)) * 0.7   # weathered grey
        tint = off; cav = cavity_from_height(h, 2)
    elif name == "paint_metal":
        base = fbm(n, 8, 5, s); chips = smoothstep(0.58, 0.68, fbm(n, 5, 6, s + 3)) * (fbm(n, 2, 3, s + 4) > -0.1)
        rust_bleed = blur(chips, 6)
        scratches = smoothstep(0.9, 1.0, ridged(n, 30, 2, s + 8)) * 0.6
        h = 0.6 + base * 0.03 - chips * 0.1
        det = 0.5 + base * 0.08 - scratches * 0.3 - chips * 0.1
        rough = 0.45 + base * 0.1 + chips * 0.45 + rust_bleed * 0.2
        mask = np.clip(chips + rust_bleed * 0.5, 0, 1)
        tint = 0.5 + fbm(n, 3, 3, s + 5) * 0.2; cav = cavity_from_height(h, 2)
    elif name == "brushed":
        ys, xs = np.mgrid[0:n, 0:n] / n
        streak = fbm(n, 3, 2, s) * 0.0 + (value_noise(n, 400, s + 1) * 0.7 + value_noise(n, 180, s + 2) * 0.3)
        # stretch horizontally
        streak = blur(np.roll(streak, 0, 1), 0)
        st = np.zeros_like(streak)
        for k in range(-6, 7):
            st += np.roll(streak, k, axis=1)
        st /= 13.0
        h = 0.5 + st * 0.02
        det = 0.5 + (st - 0.5) * 0.25
        rough = 0.35 + (st - 0.5) * 0.2 + fbm(n, 4, 3, s + 3) * 0.08
        mask = smoothstep(0.6, 0.9, fbm(n, 4, 4, s + 6)) * 0.5
        tint = 0.5 + fbm(n, 2, 2, s + 7) * 0.15; cav = np.ones((n, n))
    elif name == "corrugated":
        ys, xs = np.mgrid[0:n, 0:n] / n
        wave = 0.5 + 0.5 * np.sin(xs * 2 * np.pi * 12)
        rust = smoothstep(0.55, 0.75, fbm(n, 5, 5, s + 2)) * smoothstep(0.3, 0.7, 1 - ys + fbm(n, 4, 3, s + 3) * 0.5)
        h = 0.3 + wave * 0.5 - rust * 0.08
        det = 0.5 + (wave - 0.5) * 0.1 + fbm(n, 30, 3, s + 1) * 0.08 - rust * 0.2
        rough = 0.5 + rust * 0.45
        mask = rust; tint = 0.5 + fbm(n, 3, 3, s + 4) * 0.25; cav = cavity_from_height(h, 2)
    elif name == "rock":
        r = ridged(n, 5, 6, s); f = fbm(n, 12, 5, s + 1)
        strata = 0.5 + 0.5 * np.sin((np.mgrid[0:n, 0:n][0] / n + f * 0.15) * 2 * np.pi * 5)
        h = norm01(r * 0.7 + f * 0.3 + strata * 0.08)
        det = 0.5 + (h - 0.5) * 0.4 + fbm(n, 90, 3, s + 2) * 0.1
        rough = 0.92 - h * 0.08
        mask = smoothstep(0.6, 0.85, fbm(n, 4, 4, s + 5)) * 0.6   # lichen/soil
        tint = 0.5 + fbm(n, 3, 4, s + 6) * 0.3; cav = cavity_from_height(h, 4)
    elif name == "grass":
        blades = np.zeros((n, n))
        for k in range(3):
            blades += np.abs(fbm(n, 60 * (k + 1), 3, s + k)) * (0.6 - k * 0.15)
        tufts = fbm(n, 8, 4, s + 9)
        h = 0.5 + blades * 0.25 + tufts * 0.1
        det = 0.5 + blades * 0.5 + tufts * 0.15 - 0.15
        rough = 0.95
        mask = smoothstep(0.4, 0.75, fbm(n, 5, 4, s + 11))   # bare soil
        tint = 0.5 + fbm(n, 4, 3, s + 12) * 0.35; cav = cavity_from_height(h, 2)
    elif name == "terracotta":
        ys, xs = np.mgrid[0:n, 0:n] / n
        tiles = 0.5 + 0.5 * np.sin(xs * 2 * np.pi * 10)
        rows = 1 - smoothstep(0.0, 0.08, np.abs(((ys * 12) % 1.0) - 0.5) * 2 - 0.9)
        rows = smoothstep(0.85, 1.0, ((ys * 12) % 1.0))
        h = 0.35 + tiles * 0.45 - rows * 0.35 + fbm(n, 40, 3, s) * 0.04
        det = 0.5 + (tiles - 0.5) * 0.1 - rows * 0.3 + fbm(n, 20, 4, s + 1) * 0.12
        rough = 0.85; mask = smoothstep(0.6, 0.85, fbm(n, 5, 4, s + 3)) * 0.6
        tint = ((np.floor(xs * 10) * 7.3 + np.floor(ys * 12) * 3.1) % 1.0); cav = cavity_from_height(h, 2)
    elif name == "fabric":
        ys, xs = np.mgrid[0:n, 0:n] / n
        weave = 0.5 + 0.25 * np.sin(xs * 2 * np.pi * 160) + 0.25 * np.sin(ys * 2 * np.pi * 160)
        h = 0.5 + (weave - 0.5) * 0.2 + fbm(n, 6, 4, s) * 0.04
        det = 0.5 + (weave - 0.5) * 0.3 + fbm(n, 6, 3, s + 1) * 0.08
        rough = 0.95; mask = smoothstep(0.6, 0.9, fbm(n, 3, 4, s + 2)) * 0.4
        tint = 0.5 + fbm(n, 2, 2, s + 3) * 0.1; cav = np.ones((n, n)) * 0.95
    elif name == "rubber":
        b = fbm(n, 70, 3, s)
        h = 0.5 + b * 0.04; det = 0.5 + b * 0.06; rough = 0.9 + b * 0.05
        mask = smoothstep(0.7, 0.95, fbm(n, 5, 3, s + 1)) * 0.3; tint = 0.5 + fbm(n, 2, 2, s + 2) * 0.1
        cav = np.ones((n, n))
    elif name == "tread":
        ys, xs = np.mgrid[0:n, 0:n] / n
        cx = (xs * 8) % 1.0; cy = (ys * 8) % 1.0
        bar = (1 - smoothstep(0.08, 0.14, np.abs((cx + cy) % 1.0 - 0.5))) * (1 - smoothstep(0.25, 0.3, np.abs(cx - 0.5)))
        h = 0.45 + bar * 0.45 + fbm(n, 30, 3, s) * 0.03
        det = 0.5 + bar * 0.15 + fbm(n, 30, 3, s + 1) * 0.1
        rough = 0.55 + (1 - bar) * 0.15; mask = smoothstep(0.65, 0.9, fbm(n, 4, 4, s + 2)) * 0.5
        tint = 0.5 + fbm(n, 2, 2, s + 3) * 0.1; cav = cavity_from_height(h, 2)
    elif name == "paving":
        bh, mortar, cid = bricks(n, 4, 4, mortar=0.05, offset=0.0, seed=s)
        grain = fbm(n, 36, 4, s + 1)
        h = 0.3 + 0.5 * bh + grain * 0.06
        det = 0.5 + (cid - 0.5) * 0.25 + grain * 0.15 - mortar * 0.15
        rough = 0.85 + mortar * 0.1; mask = mortar; tint = cid; cav = cavity_from_height(h, 3)
    elif name == "bark":
        ys, xs = np.mgrid[0:n, 0:n] / n
        r = ridged(n, 4, 5, s)
        fissure = smoothstep(0.55, 0.9, np.abs(np.sin((xs * 6 + fbm(n, 3, 3, s + 1) * 1.2) * np.pi)) * (0.6 + 0.4 * r))
        h = 0.3 + fissure * 0.5 + fbm(n, 40, 3, s + 2) * 0.08
        det = 0.5 + (fissure - 0.5) * 0.3 + fbm(n, 20, 4, s + 3) * 0.12
        rough = 0.95; mask = smoothstep(0.5, 0.8, fbm(n, 4, 4, s + 4)) * 0.5
        tint = 0.5 + fbm(n, 3, 3, s + 5) * 0.2; cav = cavity_from_height(h, 3)
    elif name == "leaves":
        f1, f2, cid = worley(n, 14, s, 1.0)
        leaf = smoothstep(0.02, 0.2, f2 - f1) * (1 - smoothstep(0.5, 0.8, f1))
        h = 0.4 + leaf * 0.4 + fbm(n, 30, 3, s + 1) * 0.05
        det = 0.5 + (cid - 0.5) * 0.35 + leaf * 0.15
        rough = 0.85; mask = 1 - leaf
        tint = cid; cav = cavity_from_height(h, 2)
    else:
        raise ValueError(name)
    return [np.clip(x, 0, 1) for x in (det, rough, cav, tint, h, mask)]

def build(n, out_dir, strength_scale=1.0):
    A = np.zeros((n, n * len(FAMS), 4), dtype=np.uint8)
    N = np.zeros((n, n * len(FAMS), 4), dtype=np.uint8)
    for i, name in enumerate(FAMS):
        t = time.time()
        det, rough, cav, tint, h, mask = family(name, n, seed=i + 1)
        nm = height_to_normal(h, 0.9 * strength_scale * (512.0 / n))
        A[:, i * n:(i + 1) * n, 0] = (det * 255).astype(np.uint8)
        A[:, i * n:(i + 1) * n, 1] = (rough * 255).astype(np.uint8)
        A[:, i * n:(i + 1) * n, 2] = (cav * 255).astype(np.uint8)
        A[:, i * n:(i + 1) * n, 3] = (tint * 255).astype(np.uint8)
        N[:, i * n:(i + 1) * n, 0] = (nm[..., 0] * 255).astype(np.uint8)
        N[:, i * n:(i + 1) * n, 1] = (nm[..., 1] * 255).astype(np.uint8)
        N[:, i * n:(i + 1) * n, 2] = (h * 255).astype(np.uint8)
        N[:, i * n:(i + 1) * n, 3] = (mask * 255).astype(np.uint8)
        print(f"{name:12s} {n} done in {time.time() - t:.1f}s", flush=True)
    Image.fromarray(A, "RGBA").save(os.path.join(out_dir, f"surf_a_{n}.png"))
    Image.fromarray(N, "RGBA").save(os.path.join(out_dir, f"surf_n_{n}.png"))

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 512
    out = sys.argv[2] if len(sys.argv) > 2 else "/tmp"
    build(n, out)
