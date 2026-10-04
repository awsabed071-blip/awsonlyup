"""MakeHuman data loader: base mesh, targets (morphs), joint cubes, MPFB rig definitions,
MakeClothes (.mhclo) proxies. Pure numpy. Units: MakeHuman decimetres -> we convert to metres.
"""
import os, json, re, gzip
import numpy as np

MH_DATA = os.environ.get("MH_DATA", "/tmp/claude-0/-home-user-awsonlyup/33f47551-a852-5b69-bc87-131b6de1abb1/scratchpad/src/mh/makehuman/data")
MPFB_DATA = os.environ.get("MPFB_DATA", "/tmp/claude-0/-home-user-awsonlyup/33f47551-a852-5b69-bc87-131b6de1abb1/scratchpad/src/mpfb2/src/mpfb/data")
SCALE = 0.1  # dm -> m

BODY_VERTS = 13380


class Mesh:
    """Polygon mesh with per-corner UVs (quads/tris), grouped faces."""
    def __init__(self):
        self.v = None            # (N,3) float
        self.vt = None           # (M,2) float
        self.faces = []          # list of list of (vi, ti)
        self.face_group = []     # group name per face

    def copy(self):
        m = Mesh(); m.v = self.v.copy(); m.vt = self.vt.copy(); m.faces = [list(f) for f in self.faces]; m.face_group = list(self.face_group)
        return m


def load_obj(path):
    m = Mesh(); V = []; VT = []; cur = "default"
    with open(path) as fh:
        for line in fh:
            if line.startswith("v "):
                p = line.split(); V.append((float(p[1]), float(p[2]), float(p[3])))
            elif line.startswith("vt "):
                p = line.split(); VT.append((float(p[1]), float(p[2])))
            elif line.startswith("g ") or line.startswith("o "):
                cur = line.split(maxsplit=1)[1].strip()
            elif line.startswith("f "):
                idx = []
                for tok in line.split()[1:]:
                    p = tok.split("/")
                    vi = int(p[0]) - 1
                    ti = int(p[1]) - 1 if len(p) > 1 and p[1] else -1
                    idx.append((vi, ti))
                m.faces.append(idx); m.face_group.append(cur)
    m.v = np.array(V, dtype=np.float64)
    m.vt = np.array(VT, dtype=np.float64) if VT else np.zeros((0, 2))
    return m


_base_cache = None
def load_base():
    global _base_cache
    if _base_cache is None:
        _base_cache = load_obj(os.path.join(MH_DATA, "3dobjs", "base.obj"))
    return _base_cache.copy()


def load_target(path):
    """Returns (indices, deltas) in dm."""
    idx = []; d = []
    with open(path) as fh:
        for line in fh:
            if not line or line[0] == "#":
                continue
            p = line.split()
            if len(p) < 4:
                continue
            idx.append(int(p[0])); d.append((float(p[1]), float(p[2]), float(p[3])))
    if not idx:
        return np.zeros((0,), dtype=np.int64), np.zeros((0, 3), dtype=np.float64)
    return np.array(idx, dtype=np.int64), np.array(d, dtype=np.float64)


def apply_target(v, path, weight):
    if abs(weight) < 1e-6:
        return
    idx, d = load_target(path)
    if len(idx) == 0:
        return
    v[idx] += d * weight


def macro_weights(gender=0.5, age=0.5, muscle=0.5, weight=0.5, height=0.5, proportions=0.5,
                  caucasian=1/3, african=1/3, asian=1/3):
    """Reproduces MakeHuman's macro modifier factor products. Returns {target_rel_path: weight}."""
    def two(x, lo, hi):
        return {lo: 1.0 - x, hi: x}
    g = two(gender, "female", "male")
    # age: 0 -> baby(1y), 0.1875 -> child(11y), 0.5 -> young(25y), 1 -> old(90y)
    if age < 0.1875:
        a = {"baby": 1.0 - age / 0.1875, "child": age / 0.1875}
    elif age < 0.5:
        t = (age - 0.1875) / (0.5 - 0.1875); a = {"child": 1.0 - t, "young": t}
    else:
        t = (age - 0.5) / 0.5; a = {"young": 1.0 - t, "old": t}
    def three(x, lo, mid, hi):
        if x < 0.5:
            return {lo: 1.0 - x * 2.0, mid: x * 2.0}
        return {mid: 2.0 - x * 2.0, hi: x * 2.0 - 1.0}
    m = three(muscle, "minmuscle", "averagemuscle", "maxmuscle")
    w = three(weight, "minweight", "averageweight", "maxweight")
    h = three(height, "minheight", "averageheight", "maxheight")
    p = three(proportions, "uncommonproportions", "regularproportions", "idealproportions")
    eth = {"caucasian": caucasian, "african": african, "asian": asian}
    out = {}
    def add(k, val):
        if val > 1e-5:
            out[k] = out.get(k, 0.0) + val
    for gk, gv in g.items():
        for ak, av in a.items():
            for mk, mv in m.items():
                for wk, wv in w.items():
                    add(f"macrodetails/universal-{gk}-{ak}-{mk}-{wk}.target", gv * av * mv * wv)
                    for hk, hv in h.items():
                        if hk == "averageheight":
                            continue
                        add(f"macrodetails/height/{gk}-{ak}-{mk}-{wk}-{hk}.target", gv * av * mv * wv * hv)
                    for pk, pv in p.items():
                        if pk == "regularproportions":
                            continue
                        add(f"macrodetails/proportions/{gk}-{ak}-{mk}-{wk}-{pk}.target", gv * av * mv * wv * pv)
            for ek, ev in eth.items():
                add(f"macrodetails/{ek}-{gk}-{ak}.target", gv * av * ev)
    return out


def apply_macros(v, **kw):
    missing = []
    for rel, wgt in macro_weights(**kw).items():
        path = os.path.join(MH_DATA, "targets", rel)
        if os.path.exists(path):
            apply_target(v, path, wgt)
        else:
            missing.append(rel)
    return missing


def apply_named(v, pairs):
    """pairs: list of (relative target path under targets/, weight)"""
    for rel, wgt in pairs:
        path = os.path.join(MH_DATA, "targets", rel)
        if os.path.exists(path):
            apply_target(v, path, wgt)
        else:
            print("missing target", rel)


_vg_cache = None
def vertex_groups():
    global _vg_cache
    if _vg_cache is None:
        _vg_cache = json.load(open(os.path.join(MPFB_DATA, "mesh_metadata", "basemesh_vertex_groups.json")))
    return _vg_cache


def group_indices(name):
    out = []
    for a, b in vertex_groups()[name]:
        out.extend(range(a, b + 1))
    return np.array(out, dtype=np.int64)


def joint_cube_center(v, cube_name):
    return v[group_indices(cube_name)].mean(axis=0)


def load_rig(name="mixamo"):
    r = json.load(open(os.path.join(MPFB_DATA, "rigs", "standard", f"rig.{name}.json")))
    w = json.load(open(os.path.join(MPFB_DATA, "rigs", "standard", f"weights.{name}.json")))
    return r, w["weights"]


def rig_point(v, spec):
    st = spec.get("strategy", "CUBE")
    if st == "CUBE":
        return joint_cube_center(v, spec["cube_name"])
    if st == "MEAN":
        return v[np.array(spec["vertex_indices"], dtype=np.int64)].mean(axis=0)
    if st == "VERTEX":
        return v[int(spec["vertex_index"])]
    return np.array(spec["default_position"], dtype=np.float64) / SCALE


def load_mhclo(path):
    """Parse a MakeClothes proxy file. Returns dict with obj path, mapping arrays."""
    d = {"verts": [], "x_scale": None, "y_scale": None, "z_scale": None, "obj": None, "material": None, "delete": []}
    base = os.path.dirname(path)
    with open(path) as fh:
        mode = None
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            p = s.split()
            if p[0] == "obj_file":
                d["obj"] = os.path.join(base, p[1]); mode = None
            elif p[0] == "material":
                d["material"] = os.path.join(base, p[1]); mode = None
            elif p[0] in ("x_scale", "y_scale", "z_scale"):
                d[p[0]] = (int(p[1]), int(p[2]), float(p[3])); mode = None
            elif p[0] == "verts":
                mode = "verts"
            elif p[0] == "delete_verts":
                mode = "delete"
            elif mode == "verts":
                if len(p) == 1:
                    d["verts"].append((int(p[0]), int(p[0]), int(p[0]), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0))
                elif len(p) >= 9:
                    d["verts"].append((int(p[0]), int(p[1]), int(p[2]), float(p[3]), float(p[4]), float(p[5]), float(p[6]), float(p[7]), float(p[8])))
            elif mode == "delete":
                d["delete"].append(s)
    return d


def fit_mhclo(d, body_v):
    """Compute proxy vertex positions (dm) from the fitted body."""
    def scale_of(key):
        if d[key] is None:
            return 1.0
        a, b, ref = d[key]
        return abs(body_v[a][ "xyz".index(key[0]) ] - body_v[b][ "xyz".index(key[0]) ]) / ref
    sx, sy, sz = scale_of("x_scale"), scale_of("y_scale"), scale_of("z_scale")
    out = np.zeros((len(d["verts"]), 3))
    for i, (a, b, c, wa, wb, wc, dx, dy, dz) in enumerate(d["verts"]):
        out[i] = body_v[a] * wa + body_v[b] * wb + body_v[c] * wc + np.array([dx * sx, dy * sy, dz * sz])
    return out


def faces_of_group(mesh, name):
    return [i for i, g in enumerate(mesh.face_group) if g == name]


def triangulate(faces):
    tris = []
    for f in faces:
        for k in range(1, len(f) - 1):
            tris.append((f[0], f[k], f[k + 1]))
    return tris
