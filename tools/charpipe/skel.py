"""Skeleton construction from the MPFB 'mixamo' rig definition, re-posing the MakeHuman
A-pose mesh into a canonical T-pose, linear blend skinning, and canonical bone frames."""
import numpy as np
from scipy.spatial.transform import Rotation as R
import mh

PREFIX = "mixamorig:"


def strip(n):
    return n[len(PREFIX):] if n.startswith(PREFIX) else n


def rot_between(a, b):
    """Minimal rotation (3x3) taking unit vector a to unit vector b."""
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b)
    c = np.dot(a, b)
    if c > 1.0 - 1e-9:
        return np.eye(3)
    if c < -1.0 + 1e-9:
        axis = np.cross(a, [1, 0, 0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, [0, 1, 0])
        axis /= np.linalg.norm(axis)
        return R.from_rotvec(axis * np.pi).as_matrix()
    axis = np.cross(a, b); s = np.linalg.norm(axis)
    axis /= s
    ang = np.arctan2(s, c)
    return R.from_rotvec(axis * ang).as_matrix()


def frame_from_dir(y, ref):
    """Orthonormal basis with +Y along y; +Z as close as possible to ref."""
    y = y / np.linalg.norm(y)
    z = ref - y * np.dot(ref, y)
    if np.linalg.norm(z) < 1e-6:
        ref2 = np.array([0.0, 1.0, 0.0]) if abs(y[1]) < 0.9 else np.array([0.0, 0.0, 1.0])
        z = ref2 - y * np.dot(ref2, y)
    z /= np.linalg.norm(z)
    x = np.cross(y, z)
    return np.stack([x, y, z], axis=1)  # columns = axes


class Bone:
    __slots__ = ("name", "parent", "head", "tail", "children", "world", "rest_world", "rot")
    def __init__(self, name):
        self.name = name; self.parent = None; self.children = []
        self.head = None; self.tail = None; self.world = None; self.rest_world = None; self.rot = np.eye(3)


class Skeleton:
    def __init__(self, bones, order):
        self.bones = bones      # dict name -> Bone
        self.order = order      # parent-first list of names

    @staticmethod
    def from_rig(rig, v):
        bones = {}; 
        for raw, spec in rig["bones"].items():
            b = Bone(strip(raw))
            b.head = mh.rig_point(v, spec["head"]) * mh.SCALE
            b.tail = mh.rig_point(v, spec["tail"]) * mh.SCALE
            b.parent = strip(spec["parent"]) if spec.get("parent") else None
            bones[b.name] = b
        for b in bones.values():
            if b.parent:
                bones[b.parent].children.append(b.name)
        order = []
        def walk(n):
            order.append(n)
            for c in sorted(bones[n].children):
                walk(c)
        roots = [b.name for b in bones.values() if b.parent is None]
        for r in roots:
            walk(r)
        return Skeleton(bones, order)

    def bone_dir(self, name):
        b = self.bones[name]
        # direction towards the first child head if connected, else tail
        if b.children:
            c = self.bones[b.children[0]]
            d = c.head - b.head
            if np.linalg.norm(d) > 1e-4:
                return d / np.linalg.norm(d)
        d = b.tail - b.head
        return d / np.linalg.norm(d)


def canonical_ref(name, d):
    """Reference vector that defines local +Z for a bone with world direction d."""
    if name.endswith("Foot") or name.endswith("ToeBase"):
        return np.array([0.0, 1.0, 0.0])
    if abs(d[2]) > 0.85:
        return np.array([0.0, 1.0, 0.0])
    return np.array([0.0, 0.0, 1.0])


def build_rest_frames(sk):
    """World rest matrices (4x4) with canonical frames, using current heads."""
    for n in sk.order:
        b = sk.bones[n]
        d = sk.bone_dir(n)
        M = np.eye(4)
        M[:3, :3] = frame_from_dir(d, canonical_ref(n, d))
        M[:3, 3] = b.head
        b.rest_world = M


def tpose_targets(sk):
    """Target world directions for the T-pose re-pose; None = keep current."""
    t = {}
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        t[f"{side}Arm"] = np.array([sx, 0.0, 0.0])
        t[f"{side}ForeArm"] = np.array([sx, 0.0, 0.0])
        t[f"{side}Hand"] = np.array([sx, 0.0, 0.0])
        t[f"{side}UpLeg"] = np.array([0.0, -1.0, 0.0])
        t[f"{side}Leg"] = np.array([0.0, -1.0, 0.0])
    return t


def repose_to_tpose(sk, v_m, weights, palm_info):
    """Re-pose the mesh (metres, (N,3)) and skeleton heads into a T-pose.
    weights: dict bone -> list of (vertex, w). Returns new vertex positions."""
    build_rest_frames(sk)
    targets = tpose_targets(sk)
    # keep original world directions of feet so we restore them after leg alignment
    keep = {}
    for n in sk.order:
        if n.endswith("Foot") or n.endswith("ToeBase"):
            keep[n] = sk.bone_dir(n)
    # posed world matrices
    for n in sk.order:
        b = sk.bones[n]
        par = sk.bones[b.parent] if b.parent else None
        if par is None:
            b.world = b.rest_world.copy()
        else:
            L = np.linalg.inv(par.rest_world) @ b.rest_world
            b.world = par.world @ L
        want = targets.get(n)
        if want is None and n in keep:
            want = keep[n]
        if want is not None:
            cur = b.world[:3, 1]
            Rw = rot_between(cur, want)
            b.world[:3, :3] = Rw @ b.world[:3, :3]
        if n.endswith("Hand") and n in palm_info:
            # twist about the bone axis so that the palm faces down (-Y)
            axis = b.world[:3, 1]
            palm = b.world[:3, :3] @ palm_info[n]   # palm normal expressed in current frame -> world
            palm = palm - axis * np.dot(palm, axis)
            if np.linalg.norm(palm) > 1e-6:
                palm /= np.linalg.norm(palm)
                want_p = np.array([0.0, -1.0, 0.0]); want_p = want_p - axis * np.dot(want_p, axis); want_p /= np.linalg.norm(want_p)
                ang = np.arctan2(np.dot(np.cross(palm, want_p), axis), np.dot(palm, want_p))
                Rt = R.from_rotvec(axis * ang).as_matrix()
                b.world[:3, :3] = Rt @ b.world[:3, :3]
    # skinning matrices
    names = list(sk.order)
    S = {n: sk.bones[n].world @ np.linalg.inv(sk.bones[n].rest_world) for n in names}
    out = np.zeros_like(v_m)
    acc = np.zeros(len(v_m))
    for n, lst in weights.items():
        n2 = strip(n)
        if n2 not in S:
            continue
        lst = np.array(lst)
        idx = lst[:, 0].astype(np.int64); w = lst[:, 1]
        M = S[n2]
        p = v_m[idx] @ M[:3, :3].T + M[:3, 3]
        out[idx] += p * w[:, None]
        acc[idx] += w
    missing = acc < 1e-6
    out[missing] = v_m[missing]
    nz = ~missing
    out[nz] /= acc[nz][:, None]
    # new heads = posed heads; rebuild canonical frames at the new positions
    for n in sk.order:
        b = sk.bones[n]
        b.head = b.world[:3, 3]
        Mt = b.world @ np.linalg.inv(b.rest_world)
        b.tail = Mt[:3, :3] @ b.tail + Mt[:3, 3]
    build_rest_frames(sk)
    return out


def palm_normals(v, rig):
    """Palm-out normals (expressed in each hand bone's rest frame later)."""
    out = {}
    for side, sx in (("Left", 1.0), ("Right", -1.0)):
        s = "l" if side == "Left" else "r"
        wrist = mh.joint_cube_center(v, f"joint-{s}-hand") * mh.SCALE
        idx = mh.joint_cube_center(v, f"joint-{s}-finger-2-1") * mh.SCALE
        pin = mh.joint_cube_center(v, f"joint-{s}-finger-5-1") * mh.SCALE
        mid = mh.joint_cube_center(v, f"joint-{s}-finger-3-1") * mh.SCALE
        u = pin - idx; f = mid - wrist
        n = np.cross(u, f) if side == "Left" else np.cross(f, u)
        n /= np.linalg.norm(n)
        out[f"{side}Hand"] = n
    return out


def normalize_weights(weights, nverts, max_inf=4):
    """-> (joints (N,4) int, weights (N,4) float) using bone order index map."""
    per_v = [[] for _ in range(nverts)]
    for n, lst in weights.items():
        for vi, w in lst:
            if w > 1e-5:
                per_v[int(vi)].append((strip(n), float(w)))
    return per_v


def local_rest(sk):
    """Local rest transforms (translation, quaternion xyzw) per bone from world rest frames."""
    out = {}
    for n in sk.order:
        b = sk.bones[n]
        if b.parent:
            L = np.linalg.inv(sk.bones[b.parent].rest_world) @ b.rest_world
        else:
            L = b.rest_world
        q = R.from_matrix(L[:3, :3]).as_quat()
        out[n] = (L[:3, 3].copy(), q)
    return out
