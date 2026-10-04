"""Mesh helpers: split per-corner UVs into unique (vertex,uv) pairs, triangulate, normals."""
import numpy as np
from glb import compute_normals


def unique_corners(faces, nverts):
    """faces: list of lists of (vi, ti). Returns (corner_map dict (vi,ti)->new index, list of (vi,ti))."""
    cmap = {}; order = []
    for f in faces:
        for vi, ti in f:
            key = (vi, ti)
            if key not in cmap:
                cmap[key] = len(order); order.append(key)
    return cmap, order


def build_primitive_arrays(pos_m, uvs, faces, per_vertex_skin=None):
    """pos_m: (N,3) positions in metres for original vertex indices; uvs: (M,2) per-corner uv table.
    faces: list of polygons [(vi,ti),...]. per_vertex_skin: list per original vertex of [(bone_index, w)].
    Returns dict with pos, nrm, uv, idx, joints, weights, orig_index."""
    cmap, order = unique_corners(faces, len(pos_m))
    vi_arr = np.array([k[0] for k in order], dtype=np.int64)
    ti_arr = np.array([k[1] for k in order], dtype=np.int64)
    pos = pos_m[vi_arr]
    uv = np.zeros((len(order), 2), dtype=np.float64)
    ok = ti_arr >= 0
    uv[ok] = uvs[ti_arr[ok]]
    uv[:, 1] = 1.0 - uv[:, 1]  # glTF v flips
    tris = []
    for f in faces:
        ids = [cmap[(vi, ti)] for vi, ti in f]
        for k in range(1, len(ids) - 1):
            tris.append((ids[0], ids[k], ids[k + 1]))
    tris = np.array(tris, dtype=np.int64)
    # normals: smooth over original vertex index (so UV seams don't split shading)
    n_orig = compute_normals(pos_m, np.array([[vi_arr[t[0]], vi_arr[t[1]], vi_arr[t[2]]] for t in tris]))
    nrm = n_orig[vi_arr]
    out = {"pos": pos, "nrm": nrm, "uv": uv, "idx": tris, "orig": vi_arr}
    if per_vertex_skin is not None:
        J = np.zeros((len(order), 4), dtype=np.uint16); W = np.zeros((len(order), 4), dtype=np.float32)
        for i, vi in enumerate(vi_arr):
            lst = sorted(per_vertex_skin[vi], key=lambda x: -x[1])[:4]
            s = sum(w for _, w in lst)
            for k, (bi, w) in enumerate(lst):
                J[i, k] = bi; W[i, k] = w / s if s > 0 else 0.0
        out["joints"] = J; out["weights"] = W
    return out
