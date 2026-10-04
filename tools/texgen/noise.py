"""Tileable procedural noise primitives (numpy)."""
import numpy as np

def _hash2(ix, iy, seed):
    h = (ix * 374761393 + iy * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF) / float(0xFFFFFF)

def value_noise(size, period, seed=0):
    """Tileable value noise on a size x size grid with 'period' cells across."""
    n = size
    ys, xs = np.mgrid[0:n, 0:n]
    fx = xs * period / n; fy = ys * period / n
    ix = np.floor(fx).astype(np.int64); iy = np.floor(fy).astype(np.int64)
    tx = fx - ix; ty = fy - iy
    tx = tx * tx * (3 - 2 * tx); ty = ty * ty * (3 - 2 * ty)
    def h(dx, dy):
        return _hash2((ix + dx) % period, (iy + dy) % period, seed)
    a = h(0, 0); b = h(1, 0); c = h(0, 1); d = h(1, 1)
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty

def grad_noise(size, period, seed=0):
    """Tileable gradient (Perlin-like) noise in [-1,1]."""
    n = size
    ys, xs = np.mgrid[0:n, 0:n]
    fx = xs * period / n; fy = ys * period / n
    ix = np.floor(fx).astype(np.int64); iy = np.floor(fy).astype(np.int64)
    tx = fx - ix; ty = fy - iy
    u = tx * tx * tx * (tx * (tx * 6 - 15) + 10); w = ty * ty * ty * (ty * (ty * 6 - 15) + 10)
    def g(dx, dy):
        ang = _hash2((ix + dx) % period, (iy + dy) % period, seed) * 2 * np.pi
        gx = np.cos(ang); gy = np.sin(ang)
        return gx * (tx - dx) + gy * (ty - dy)
    a = g(0, 0); b = g(1, 0); c = g(0, 1); d = g(1, 1)
    v = (a * (1 - u) + b * u) * (1 - w) + (c * (1 - u) + d * u) * w
    return v * 1.6

def fbm(size, period, octaves=5, seed=0, gain=0.5, lacunarity=2.0, kind="grad"):
    out = np.zeros((size, size)); amp = 1.0; p = period; tot = 0.0
    for o in range(octaves):
        f = grad_noise(size, int(max(1, round(p))), seed + o * 17) if kind == "grad" else (value_noise(size, int(max(1, round(p))), seed + o * 17) * 2 - 1)
        out += amp * f; tot += amp; amp *= gain; p *= lacunarity
    return out / tot

def ridged(size, period, octaves=5, seed=0):
    out = np.zeros((size, size)); amp = 1.0; p = period; tot = 0.0
    for o in range(octaves):
        f = 1.0 - np.abs(grad_noise(size, int(max(1, round(p))), seed + o * 31))
        out += amp * f * f; tot += amp; amp *= 0.5; p *= 2.0
    return out / tot

def worley(size, period, seed=0, jitter=1.0):
    """Tileable Voronoi: returns (F1, F2, cell_id_hash) distances in cell units."""
    n = size
    ys, xs = np.mgrid[0:n, 0:n]
    fx = xs * period / n; fy = ys * period / n
    ix = np.floor(fx).astype(np.int64); iy = np.floor(fy).astype(np.int64)
    f1 = np.full((n, n), 9.0); f2 = np.full((n, n), 9.0); cid = np.zeros((n, n))
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx = (ix + dx); cy = (iy + dy)
            px = cx + 0.5 + (_hash2(cx % period, cy % period, seed) - 0.5) * jitter
            py = cy + 0.5 + (_hash2(cx % period, cy % period, seed + 7) - 0.5) * jitter
            d = np.sqrt((fx - px) ** 2 + (fy - py) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            cid = np.where(closer, _hash2(cx % period, cy % period, seed + 99), cid)
            f1 = np.where(closer, d, f1)
    return f1, f2, cid

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)

def height_to_normal(h, strength=1.0):
    """h in [0,1] tileable -> normal map RGB float [0,1] (OpenGL +Y up)."""
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * strength * h.shape[1]
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * strength * h.shape[0]
    nx = -dx; ny = dy; nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l * 0.5 + 0.5, ny / l * 0.5 + 0.5, nz / l * 0.5 + 0.5], axis=-1)

def blur(a, r=1):
    out = a.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out

def cavity_from_height(h, r=3):
    """Approximate ambient occlusion from height: dark where lower than neighbourhood."""
    b = blur(h, r)
    c = np.clip(1.0 - (b - h) * 3.0, 0.0, 1.0)
    return c

def rgb(r, g, b):
    return np.array([r, g, b], dtype=np.float64)
