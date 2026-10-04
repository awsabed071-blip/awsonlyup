"""Garments and accessories from the MakeHuman helper geometry.
All functions work on the morphed, T-posed mesh (metres) and return primitive dicts."""
import numpy as np
from scipy.spatial import cKDTree
import mh, meshutil

HELPER = {"tights": "helper-tights", "skirt": "helper-skirt", "hair": "helper-hair"}


def vertex_normals_of(mesh_v, faces):
    """Area-weighted normals over polygon faces (original vertex indexing)."""
    n = np.zeros_like(mesh_v)
    for f in faces:
        ids = [vi for vi, _ in f]
        a = mesh_v[ids[0]]
        for k in range(1, len(ids) - 1):
            b = mesh_v[ids[k]]; c = mesh_v[ids[k + 1]]
            fn = np.cross(b - a, c - a)
            for i in ids:
                n[i] += fn
    # weld: vertices that share a position (uv seams of the helpers) get the same normal, so an
    # inflated shell stays watertight instead of cracking along the seams
    key = np.round(mesh_v * 2000.0).astype(np.int64)
    groups = {}
    used = sorted(set(vi for f in faces for vi, _ in f))
    for i in used:
        groups.setdefault(tuple(key[i]), []).append(i)
    for ids in groups.values():
        if len(ids) > 1:
            m = n[ids].sum(axis=0)
            n[ids] = m
    l = np.linalg.norm(n, axis=1); l[l < 1e-12] = 1
    return n / l[:, None]


def body_uv_lookup(base, body_faces):
    """Map body vertex -> list of its uv indices (corners)."""
    vt_of = {}
    for f in body_faces:
        for vi, ti in f:
            vt_of.setdefault(vi, set()).add(ti)
    return {k: sorted(v) for k, v in vt_of.items()}


def transfer_uvs(base, v_m, faces, body_faces, body_tree, body_idx):
    """Give helper faces UVs copied from the nearest body vertices, choosing per face the
    uv candidates that minimise spread (keeps faces from straddling atlas seams)."""
    vt_of = body_uv_lookup(base, body_faces)
    out = []
    for f in faces:
        cands = []
        for vi, ti in f:
            d, j = body_tree.query(v_m[vi])
            bvi = int(body_idx[j])
            cands.append([base.vt[t] for t in vt_of.get(bvi, [])] or [np.array([0.5, 0.5])])
        # greedy: start from the corner with fewest candidates, pick nearest in uv for others
        order = sorted(range(len(f)), key=lambda i: len(cands[i]))
        chosen = [None] * len(f)
        c0 = cands[order[0]][0]; chosen[order[0]] = c0
        ref = c0
        for i in order[1:]:
            best = min(cands[i], key=lambda u: np.linalg.norm(u - ref))
            chosen[i] = best
            ref = (ref + best) * 0.5
        out.append([(f[k][0], chosen[k]) for k in range(len(f))])
    return out  # list of [(vi, uv(2,))...]


def faces_to_prim(v_m, faces_uv, per_v_skin, offsets=None):
    """faces_uv: polygons [(vi, uv array)]. Builds a primitive with explicit uvs."""
    # build a uv table
    uv_table = []; faces = []
    for f in faces_uv:
        poly = []
        for vi, uv in f:
            uv_table.append(uv); poly.append((vi, len(uv_table) - 1))
        faces.append(poly)
    uvs = np.array(uv_table, dtype=np.float64)
    pos = v_m if offsets is None else v_m + offsets
    return meshutil.build_primitive_arrays(pos, uvs, faces, per_v_skin)


def helper_faces(base, name):
    return [base.faces[i] for i in mh.faces_of_group(base, HELPER[name])]


def inflate(v_m, normals, idx, amount):
    off = np.zeros_like(v_m)
    off[idx] = normals[idx] * amount
    return off


def region_split_tights(base, v_m, heads, dominant_bone):
    """Split tights helper vertices into shirt / pants / none by anatomy."""
    tights = mh.group_indices("helper-tights")
    hip_y = heads["Hips"][1]
    shirt = []; pants = []
    wrist_x = abs(heads["LeftHand"][0])
    for vi in tights:
        p = v_m[vi]; b = dominant_bone[vi]
        arm = b in ("LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftShoulder", "RightShoulder", "LeftHand", "RightHand")
        if arm:
            if abs(p[0]) < wrist_x - 0.01:   # stop at the wrist
                shirt.append(vi)
            continue
        if p[1] > hip_y - 0.07:
            shirt.append(vi)
        if p[1] < hip_y + 0.03 and p[1] > heads["LeftFoot"][1] + 0.025:
            pants.append(vi)
    return np.array(shirt), np.array(pants)


def faces_within(faces, allowed):
    allowed = set(int(x) for x in allowed)
    return [f for f in faces if all(vi in allowed for vi, _ in f)]


def dominant_bones(per_v, nverts):
    out = [None] * nverts
    for i in range(nverts):
        lst = per_v[i]
        if lst:
            out[i] = max(lst, key=lambda x: x[1])[0]
    return out
