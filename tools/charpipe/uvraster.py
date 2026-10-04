"""Rasterize per-triangle attributes into UV space (numpy). Used to paint skin/cloth textures
from 3D rules: we build position/normal maps in texture space, then paint by 3D position."""
import numpy as np


def rasterize(uv_tris, attr_tris, size, bg=0.0, dilate=4):
    """uv_tris: (T,3,2) in [0,1] (v already flipped to image space: row = v*size).
    attr_tris: (T,3,K) per-corner attributes. Returns (size,size,K) float image + coverage mask."""
    K = attr_tris.shape[2]
    img = np.full((size, size, K), bg, dtype=np.float64)
    cov = np.zeros((size, size), dtype=bool)
    px = uv_tris * size
    for t in range(len(px)):
        p = px[t]
        xmin = int(max(np.floor(p[:, 0].min()), 0)); xmax = int(min(np.ceil(p[:, 0].max()), size - 1))
        ymin = int(max(np.floor(p[:, 1].min()), 0)); ymax = int(min(np.ceil(p[:, 1].max()), size - 1))
        if xmax < xmin or ymax < ymin:
            continue
        ys, xs = np.mgrid[ymin:ymax + 1, xmin:xmax + 1]
        xs = xs + 0.5; ys = ys + 0.5
        x0, y0 = p[0]; x1, y1 = p[1]; x2, y2 = p[2]
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-12:
            continue
        l0 = ((y1 - y2) * (xs - x2) + (x2 - x1) * (ys - y2)) / den
        l1 = ((y2 - y0) * (xs - x2) + (x0 - x2) * (ys - y2)) / den
        l2 = 1.0 - l0 - l1
        eps = -0.002
        inside = (l0 >= eps) & (l1 >= eps) & (l2 >= eps)
        if not inside.any():
            continue
        a = attr_tris[t]
        val = l0[..., None] * a[0] + l1[..., None] * a[1] + l2[..., None] * a[2]
        sub = img[ymin:ymax + 1, xmin:xmax + 1]
        sub[inside] = val[inside]
        cov[ymin:ymax + 1, xmin:xmax + 1] |= inside
    if dilate > 0:
        img, cov = dilate_img(img, cov, dilate)
    return img, cov


def dilate_img(img, cov, n):
    """Grow covered pixels outward to avoid seams when sampling with filtering."""
    out = img.copy(); c = cov.copy()
    for _ in range(n):
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(c, (dy, dx), axis=(0, 1))
            shi = np.roll(out, (dy, dx), axis=(0, 1))
            fill = (~c) & sh
            out[fill] = shi[fill]
            c = c | fill
    return out, c


def tri_uv_and_attr(prim, pos_attr, nrm_attr):
    """From a primitive dict (pos,nrm,uv,idx), build arrays for rasterize."""
    idx = prim["idx"]
    uvt = prim["uv"][idx]                              # (T,3,2) with v flipped (image space)
    attrs = np.concatenate([pos_attr[idx], nrm_attr[idx]], axis=2)
    return uvt, attrs
