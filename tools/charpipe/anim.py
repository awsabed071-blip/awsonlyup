"""Procedural animation authoring for the Mixamo-named skeleton (T-pose rest, feet at y=0).

Poses are expressed as rotations about WORLD axes (in the bind pose), applied hierarchically:
local(b) = rest_local(b) * (Rw(b) expressed in b's rest frame). Rotation convention (right hand):
  +X axis: pitch (flexion forward is NEGATIVE about +X for legs/arms hanging... we use helpers)
Helper semantics (degrees, anatomical, side-aware):
  arm_down(side, deg): lower the arm from T-pose towards the body (about world Z)
  arm_fwd(side, deg): swing arm forward (about world Y when arm is lowered we use X? see impl)
We keep it simple: each helper builds a world rotation from axis/angle, and the author composes.
"""
import numpy as np
from scipy.spatial.transform import Rotation as R

D = np.pi / 180.0


def rx(a): return R.from_rotvec([a * D, 0, 0])
def ry(a): return R.from_rotvec([0, a * D, 0])
def rz(a): return R.from_rotvec([0, 0, a * D])
def ident(): return R.identity()


class Pose:
    """World-axis rotations per bone (scipy Rotation), plus hips translation offset (m)."""
    def __init__(self):
        self.rot = {}
        self.hips_off = np.zeros(3)

    def set(self, bone, rot):
        self.rot[bone] = rot
        return self

    def add(self, bone, rot):
        """compose: new world rotation applied after existing."""
        self.rot[bone] = rot * self.rot[bone] if bone in self.rot else rot
        return self

    def copy(self):
        p = Pose(); p.rot = dict(self.rot); p.hips_off = self.hips_off.copy(); return p


def blend(a: Pose, b: Pose, t: float) -> Pose:
    out = Pose()
    keys = set(a.rot) | set(b.rot)
    for k in keys:
        qa = a.rot.get(k, ident()); qb = b.rot.get(k, ident())
        # slerp via scipy: use Slerp on two keys
        from scipy.spatial.transform import Slerp
        s = Slerp([0.0, 1.0], R.concatenate([qa, qb]))
        out.rot[k] = s([t])[0]
    out.hips_off = a.hips_off * (1 - t) + b.hips_off * t
    return out


# ---------------- anatomical helpers (side = 'Left'/'Right') ----------------
def sgn(side):
    return 1.0 if side == "Left" else -1.0


def arm_down(p, side, deg):
    """Lower the upper arm from the T-pose towards the hip (adduction)."""
    return p.add(f"{side}Arm", rz(-deg * sgn(side)))


def arm_fwd(p, side, deg):
    """Swing the (lowered) arm forward about the shoulder (flexion), world X axis sense."""
    return p.add(f"{side}Arm", ry(deg * sgn(side)))


def arm_out(p, side, deg):
    """Raise the arm sideways (abduction) - inverse of arm_down."""
    return p.add(f"{side}Arm", rz(deg * sgn(side)))


def elbow(p, side, deg):
    """Bend the elbow (flexion) - forearm comes forward/up relative to T-pose (about world Y)."""
    return p.add(f"{side}ForeArm", ry(deg * sgn(side)))


def elbow_up(p, side, deg):
    """Bend the elbow so the forearm rises (about world Z)."""
    return p.add(f"{side}ForeArm", rz(deg * sgn(side)))


def hand_bend(p, side, deg):
    return p.add(f"{side}Hand", ry(deg * sgn(side)))


def fingers(p, side, deg, thumb=None):
    for f in ("Index", "Middle", "Ring", "Pinky"):
        for k in (1, 2, 3):
            p.add(f"{side}Hand{f}{k}", ry(deg * sgn(side) * (0.8 if k == 1 else 1.0)))
    t = deg * 0.5 if thumb is None else thumb
    for k in (1, 2, 3):
        p.add(f"{side}HandThumb{k}", rz(-t * sgn(side) * 0.5) * ry(t * sgn(side) * 0.4))
    return p


def hip(p, side, flex=0.0, abduct=0.0, rot=0.0):
    """Hip flexion (leg forward, +), abduction (+ = leg away from body), internal rotation."""
    r = rx(-flex) * rz(-abduct * sgn(side)) * ry(rot * sgn(side))
    return p.add(f"{side}UpLeg", r)


def knee(p, side, flex):
    """Knee flexion (+ bends the lower leg backwards)."""
    return p.add(f"{side}Leg", rx(flex))


def ankle(p, side, flex=0.0, tilt=0.0):
    """Ankle: + = plantar flexion (toes down)."""
    return p.add(f"{side}Foot", rx(flex) * rz(tilt * sgn(side)))


def toes(p, side, flex):
    return p.add(f"{side}ToeBase", rx(flex))


def spine(p, pitch=0.0, yaw=0.0, roll=0.0, split=(0.4, 0.35, 0.25)):
    for bone, k in zip(("Spine", "Spine1", "Spine2"), split):
        p.add(bone, rx(-pitch * k) * ry(yaw * k) * rz(roll * k))
    return p


def neck_head(p, pitch=0.0, yaw=0.0, roll=0.0):
    p.add("Neck", rx(-pitch * 0.45) * ry(yaw * 0.4) * rz(roll * 0.4))
    p.add("Head", rx(-pitch * 0.55) * ry(yaw * 0.6) * rz(roll * 0.6))
    return p


def hips(p, pitch=0.0, yaw=0.0, roll=0.0, off=(0, 0, 0)):
    p.add("Hips", rx(-pitch) * ry(yaw) * rz(roll))
    p.hips_off = p.hips_off + np.array(off, dtype=np.float64)
    return p


def shoulder(p, side, up=0.0, fwd=0.0):
    return p.add(f"{side}Shoulder", rz(up * sgn(side)) * ry(fwd * sgn(side)))


# ---------------- baking ----------------
def bake(sk, locals_, node_of, poses, times, name, loop=True, root_motion=None):
    """poses: list of Pose (same length as times). Produces glb animation tracks.
    World-axis rotation for bone b is applied in the bind frame: local = rest_local * (Gw^T Rw Gw)."""
    tracks = []
    rest_g = {n: sk.bones[n].rest_world[:3, :3] for n in sk.order}
    for n in sk.order:
        t0, q0 = locals_[n]
        used = any(n in p.rot for p in poses)
        if not used and n != "Hips":
            continue
        vals = []
        for p in poses:
            rw = p.rot.get(n, ident()).as_matrix()
            Gw = rest_g[n]
            loc = (R.from_quat(q0) * R.from_matrix(Gw.T @ rw @ Gw)).as_quat()
            vals.append(loc)
        vals = np.array(vals)
        # enforce quaternion continuity
        for i in range(1, len(vals)):
            if np.dot(vals[i], vals[i - 1]) < 0:
                vals[i] = -vals[i]
        tracks.append((node_of[n], "rotation", np.array(times), vals))
        if n == "Hips":
            tr = np.array([t0 + p.hips_off for p in poses])
            tracks.append((node_of[n], "translation", np.array(times), tr))
    return (name, tracks)


def sample_cycle(fn, duration, fps=30, loop=True):
    """fn(phase in [0,1)) -> Pose. Returns (poses, times) including the closing frame."""
    nfr = max(2, int(round(duration * fps)))
    times = []; poses = []
    for i in range(nfr + (1 if loop else 0)):
        ph = (i / nfr) % 1.0 if loop else i / max(nfr - 1, 1)
        poses.append(fn(ph)); times.append(i / fps)
    return poses, times


# ---------------- clips ----------------
def _breath(ph, amp=1.0):
    return np.sin(ph * 2 * np.pi) * amp


def pose_idle(ph, t=0.0):
    """Relaxed standing, slight weight on the right leg, arms hanging, soft breathing."""
    p = Pose()
    br = _breath(ph)
    for s in ("Left", "Right"):
        arm_down(p, s, 72 + br * 0.6)
        arm_fwd(p, s, 4)
        elbow(p, s, 12)
        hand_bend(p, s, 4)
        fingers(p, s, 18)
        shoulder(p, s, up=-2 + br * 0.5)
    hip(p, "Left", flex=2, abduct=3, rot=-4)
    hip(p, "Right", flex=1, abduct=-1, rot=2)
    knee(p, "Left", 6); knee(p, "Right", 2)
    hips(p, pitch=2, roll=1.5, off=(0.01, -0.012 - abs(br) * 0.002, 0))
    spine(p, pitch=3 + br * 0.8, roll=-1.5)
    neck_head(p, pitch=-3 + br * 0.4, yaw=np.sin(t * 0.37) * 3)
    return p


def pose_walk(ph, speed=1.0):
    """Walk cycle: phase 0 = left heel strike."""
    p = Pose()
    a = ph * 2 * np.pi
    hipL = 24 * np.cos(a) + 2            # left thigh forward at heel strike
    hipR = 24 * np.cos(a + np.pi) + 2
    # knee: bent in swing (second half of each leg's cycle) and slightly at loading
    def knee_curve(x):
        x = x % 1.0
        swing = np.exp(-((x - 0.72) ** 2) / (2 * 0.1 ** 2)) * 62
        load = np.exp(-((x - 0.12) ** 2) / (2 * 0.06 ** 2)) * 14
        return swing + load + 4
    def ankle_curve(x):
        x = x % 1.0
        return -8 * np.exp(-((x - 0.0) ** 2) / (2 * 0.05 ** 2)) + 22 * np.exp(-((x - 0.55) ** 2) / (2 * 0.07 ** 2)) - 6 * np.exp(-((x - 0.8) ** 2) / (2 * 0.08 ** 2))
    hip(p, "Left", flex=hipL, abduct=1); hip(p, "Right", flex=hipR, abduct=1)
    knee(p, "Left", knee_curve(ph)); knee(p, "Right", knee_curve(ph + 0.5))
    ankle(p, "Left", flex=ankle_curve(ph)); ankle(p, "Right", flex=ankle_curve(ph + 0.5))
    toes(p, "Left", 10 * np.exp(-((ph - 0.5) ** 2) / (2 * 0.08 ** 2))); toes(p, "Right", 10 * np.exp(-(((ph + 0.5) % 1.0 - 0.5) ** 2) / (2 * 0.08 ** 2)))
    # pelvis: rotation follows the swinging leg, lateral tilt, vertical bob twice per cycle
    hips(p, yaw=-6 * np.sin(a), roll=3 * np.sin(a), pitch=4, off=(0, -0.02 + 0.018 * np.cos(2 * a), 0))
    spine(p, pitch=2, yaw=7 * np.sin(a), roll=-2 * np.sin(a))
    neck_head(p, pitch=-1, yaw=-3 * np.sin(a))
    # arms counter-swing
    for s, sg in (("Left", 1), ("Right", -1)):
        swing = -sg * 22 * np.cos(a)
        arm_down(p, s, 76); arm_fwd(p, s, 6 + swing); elbow(p, s, 18 + max(0, swing) * 0.5)
        hand_bend(p, s, 3); fingers(p, s, 22)
        shoulder(p, s, fwd=sg * 3 * np.cos(a))
    return p


def pose_run(ph, sprint=False):
    p = Pose()
    a = ph * 2 * np.pi
    amp = 42 if sprint else 34
    hipL = amp * np.cos(a) + 10; hipR = amp * np.cos(a + np.pi) + 10
    def knee_curve(x):
        x = x % 1.0
        return np.exp(-((x - 0.7) ** 2) / (2 * 0.1 ** 2)) * (105 if sprint else 90) + np.exp(-((x - 0.1) ** 2) / (2 * 0.07 ** 2)) * 26 + 8
    def ankle_curve(x):
        x = x % 1.0
        return 30 * np.exp(-((x - 0.42) ** 2) / (2 * 0.08 ** 2)) - 10 * np.exp(-((x - 0.85) ** 2) / (2 * 0.1 ** 2))
    hip(p, "Left", flex=hipL); hip(p, "Right", flex=hipR)
    knee(p, "Left", knee_curve(ph)); knee(p, "Right", knee_curve(ph + 0.5))
    ankle(p, "Left", flex=ankle_curve(ph)); ankle(p, "Right", flex=ankle_curve(ph + 0.5))
    lean = 14 if sprint else 9
    hips(p, yaw=-8 * np.sin(a), roll=3 * np.sin(a), pitch=lean * 0.5, off=(0, -0.03 + 0.035 * np.cos(2 * a), 0))
    spine(p, pitch=lean, yaw=9 * np.sin(a), roll=-2 * np.sin(a))
    neck_head(p, pitch=-lean * 0.8, yaw=-4 * np.sin(a))
    for s, sg in (("Left", 1), ("Right", -1)):
        swing = -sg * (40 if sprint else 32) * np.cos(a)
        arm_down(p, s, 70); arm_fwd(p, s, 12 + swing); elbow(p, s, 80 + max(0, swing) * 0.3); hand_bend(p, s, 6)
        fingers(p, s, 45)
        shoulder(p, s, fwd=sg * 5 * np.cos(a))
    return p


def pose_jump_air(ph):
    """Rising/apex pose: knees tucked, arms slightly up for balance."""
    p = Pose()
    k = np.sin(min(ph, 1.0) * np.pi)
    for s in ("Left", "Right"):
        arm_down(p, s, 45 - 10 * k); arm_fwd(p, s, -10); elbow(p, s, 35 + 20 * k); fingers(p, s, 25)
    hip(p, "Left", flex=40 * k + 10, abduct=4); hip(p, "Right", flex=25 * k + 5, abduct=2)
    knee(p, "Left", 70 * k + 10); knee(p, "Right", 50 * k + 8)
    ankle(p, "Left", flex=15); ankle(p, "Right", flex=20)
    hips(p, pitch=6, off=(0, -0.02, 0)); spine(p, pitch=8); neck_head(p, pitch=-6)
    return p


def pose_fall(ph):
    """Long fall: legs apart & slightly bent, arms out, head looking down-ish; subtle flail."""
    p = Pose()
    t = ph * 2 * np.pi
    for s, sg in (("Left", 1), ("Right", -1)):
        arm_down(p, s, 25 + 8 * np.sin(t + sg)); arm_fwd(p, s, -15 + 10 * np.sin(t * 1.3)); elbow(p, s, 25 + 15 * np.sin(t * 0.9 + sg * 2)); fingers(p, s, 10)
        hip(p, s, flex=20 + 8 * np.sin(t * 0.8 + sg), abduct=14); knee(p, s, 30 + 10 * np.sin(t + sg * 1.5)); ankle(p, s, flex=20)
    hips(p, pitch=-8, off=(0, 0, 0)); spine(p, pitch=-6 + 3 * np.sin(t * 0.7)); neck_head(p, pitch=-18)
    return p


def pose_land(ph, hard=False):
    """Landing: crouch absorb then recover. ph in [0,1]."""
    p = Pose()
    depth = np.sin(min(ph * 1.25, 1.0) * np.pi)  # 0 -> 1 -> 0
    d = depth * (1.0 if hard else 0.55)
    for s, sg in (("Left", 1), ("Right", -1)):
        arm_down(p, s, 60 - 25 * d); arm_fwd(p, s, 20 * d); elbow(p, s, 20 + 30 * d); fingers(p, s, 20)
        hip(p, s, flex=55 * d + 4, abduct=6 * d); knee(p, s, 95 * d + 6); ankle(p, s, flex=-20 * d)
    leg_drop = 0.42 * d
    hips(p, pitch=18 * d, off=(0, -leg_drop, 0.02 * d)); spine(p, pitch=20 * d); neck_head(p, pitch=-14 * d)
    return p


def pose_crouch_pre_jump(ph):
    p = Pose()
    d = np.sin(min(ph, 1.0) * np.pi) * 0.8
    for s in ("Left", "Right"):
        arm_down(p, s, 70); arm_fwd(p, s, -25 * d); elbow(p, s, 25); fingers(p, s, 20)
        hip(p, s, flex=40 * d + 3); knee(p, s, 70 * d + 5); ankle(p, s, flex=-12 * d)
    hips(p, pitch=10 * d, off=(0, -0.28 * d, 0)); spine(p, pitch=12 * d); neck_head(p, pitch=-8 * d)
    return p


def pose_hang(ph):
    """Hanging from both hands above the head."""
    p = Pose()
    sway = np.sin(ph * 2 * np.pi) * 2
    for s in ("Left", "Right"):
        arm_out(p, s, 72); arm_fwd(p, s, 8); elbow(p, s, 8); hand_bend(p, s, -10); fingers(p, s, 70)
        hip(p, s, flex=12 + sway, abduct=3); knee(p, s, 18); ankle(p, s, flex=25)
    shoulder(p, "Left", up=18); shoulder(p, "Right", up=18)
    hips(p, pitch=-4, off=(0, -0.02, 0)); spine(p, pitch=-6); neck_head(p, pitch=10)
    return p


def pose_mantle(ph):
    """Climbing onto a ledge: hands high and pressing down, one leg up. ph in [0,1]."""
    p = Pose()
    k = ph
    up = 1 - abs(k - 0.4) / 0.4 if k < 0.8 else 0.0
    up = max(0.0, up)
    for s in ("Left", "Right"):
        arm_out(p, s, 70 - 110 * k if k < 0.6 else 4); arm_fwd(p, s, 20 + 10 * k); elbow(p, s, 20 + 40 * (1 - k)); hand_bend(p, s, -15 * (1 - k)); fingers(p, s, 30)
    hip(p, "Right", flex=90 * up + 10 * (1 - k), abduct=18 * up); knee(p, "Right", 100 * up + 10)
    hip(p, "Left", flex=20 * (1 - k)); knee(p, "Left", 30 * (1 - k) + 6); ankle(p, "Left", flex=20 * (1 - k))
    hips(p, pitch=35 * (1 - k) + 10 * up, off=(0, -0.1 * up, 0.0)); spine(p, pitch=25 * (1 - k)); neck_head(p, pitch=-10)
    return p


def pose_sit_chair(ph):
    p = Pose()
    br = _breath(ph)
    for s, sg in (("Left", 1), ("Right", -1)):
        arm_down(p, s, 68); arm_fwd(p, s, 28); elbow(p, s, 70 + 4 * br); hand_bend(p, s, 10); fingers(p, s, 30)
        hip(p, s, flex=88, abduct=8); knee(p, s, 85); ankle(p, s, flex=-5)
    hips(p, pitch=-4, off=(0, -0.42, 0.0)); spine(p, pitch=10 + br); neck_head(p, pitch=-4)
    return p


def pose_sit_floor(ph):
    p = Pose()
    br = _breath(ph)
    for s, sg in (("Left", 1), ("Right", -1)):
        arm_down(p, s, 62); arm_fwd(p, s, 30); elbow(p, s, 60 + 3 * br); fingers(p, s, 30)
        hip(p, s, flex=85, abduct=48, rot=20); knee(p, s, 120); ankle(p, s, flex=30)
    hips(p, pitch=-2, off=(0, -0.78, 0.0)); spine(p, pitch=14 + br); neck_head(p, pitch=-6)
    return p


def pose_stun_getup(ph):
    """Lying on the front after a hard fall, then pushing up to kneel and stand. ph [0,1]."""
    p = Pose()
    if ph < 0.35:
        k = ph / 0.35
        d = 1.0
    else:
        k = 1.0; d = 1.0 - (ph - 0.35) / 0.65
    d = max(0.0, min(1.0, d))
    for s in ("Left", "Right"):
        arm_down(p, s, 30 * d + 68 * (1 - d)); arm_fwd(p, s, 60 * d + 5 * (1 - d)); elbow(p, s, 90 * d + 12 * (1 - d)); fingers(p, s, 20)
        hip(p, s, flex=95 * d + 3 * (1 - d), abduct=8 * d); knee(p, s, 110 * d + 5 * (1 - d)); ankle(p, s, flex=-10 * d)
    hips(p, pitch=70 * d, off=(0, -0.72 * d, 0.0)); spine(p, pitch=30 * d); neck_head(p, pitch=-25 * d + 5)
    return p


def pose_cheer(ph):
    """Quiet relief: hands on the head, then arms open to the sky."""
    p = Pose()
    k = np.sin(ph * np.pi)
    for s in ("Left", "Right"):
        arm_out(p, s, 30 + 40 * k); arm_fwd(p, s, 40 - 20 * k); elbow(p, s, 90 - 60 * k); fingers(p, s, 15)
    hips(p, pitch=-3); spine(p, pitch=-8 * k); neck_head(p, pitch=20 * k)
    return p


def pose_pickup(ph):
    p = Pose()
    k = np.sin(min(ph, 1.0) * np.pi)
    arm_down(p, "Right", 30 + 20 * k); arm_fwd(p, "Right", 70 * k); elbow(p, "Right", 20); fingers(p, "Right", 30 + 30 * k)
    arm_down(p, "Left", 70); arm_fwd(p, "Left", 10 * k); elbow(p, "Left", 25); fingers(p, "Left", 20)
    for s in ("Left", "Right"):
        hip(p, s, flex=35 * k); knee(p, s, 55 * k); ankle(p, s, flex=-10 * k)
    hips(p, pitch=45 * k, off=(0, -0.22 * k, 0.03 * k)); spine(p, pitch=15 * k); neck_head(p, pitch=-15 * k)
    return p


def pose_balance(ph):
    """Arms out on a narrow beam, slight sway."""
    p = Pose()
    t = ph * 2 * np.pi
    for s, sg in (("Left", 1), ("Right", -1)):
        arm_down(p, s, 10 + 6 * np.sin(t + sg)); arm_fwd(p, s, 5); elbow(p, s, 10); fingers(p, s, 10)
        hip(p, s, flex=8); knee(p, s, 14); 
    hips(p, pitch=3, roll=3 * np.sin(t), off=(0, -0.03, 0)); spine(p, roll=-4 * np.sin(t)); neck_head(p, pitch=-15)
    return p


def pose_lie_idle(ph):
    """Child lying on the back (bed)."""
    p = Pose()
    br = _breath(ph)
    for s in ("Left", "Right"):
        arm_down(p, s, 60); elbow(p, s, 70 + 3 * br); fingers(p, s, 25)
        hip(p, s, flex=10, abduct=4); knee(p, s, 15)
    hips(p, pitch=-88, off=(0, -0.8, 0.0)); spine(p, pitch=0); neck_head(p, pitch=12)
    return p


def pose_zip(ph):
    p = Pose()
    sway = np.sin(ph * 2 * np.pi) * 4
    for s in ("Left", "Right"):
        arm_out(p, s, 70); arm_fwd(p, s, 12); elbow(p, s, 30); hand_bend(p, s, -10); fingers(p, s, 70)
        hip(p, s, flex=30 + sway, abduct=4); knee(p, s, 45); ankle(p, s, flex=25)
    hips(p, pitch=-6, off=(0, -0.03, 0)); spine(p, pitch=-4); neck_head(p, pitch=8)
    return p


def pose_look_up(ph):
    """Standing, looking up at the sky with a hand shading the eyes (cutscene)."""
    p = pose_idle(ph)
    neck_head(p, pitch=28)
    spine(p, pitch=-6)
    return p


def pose_grief(ph):
    """Head down, shoulders in: the quiet moment."""
    p = Pose()
    br = _breath(ph)
    for s in ("Left", "Right"):
        arm_down(p, s, 76); arm_fwd(p, s, 10); elbow(p, s, 22); fingers(p, s, 30)
        shoulder(p, s, up=-5, fwd=8)
        hip(p, s, flex=3); knee(p, s, 5)
    hips(p, pitch=4, off=(0, -0.02, 0)); spine(p, pitch=14 + br); neck_head(p, pitch=-30)
    return p


CLIPS = {
    # name: (fn(ph) , duration, loop)
    "Idle": (lambda ph: pose_idle(ph, ph * 6.0), 6.0, True),
    "Walk": (pose_walk, 1.05, True),
    "Run": (lambda ph: pose_run(ph, False), 0.68, True),
    "Sprint": (lambda ph: pose_run(ph, True), 0.56, True),
    "Jump_Start": (pose_crouch_pre_jump, 0.32, False),
    "Jump_Air": (pose_jump_air, 0.9, True),
    "Fall": (pose_fall, 1.6, True),
    "Land": (lambda ph: pose_land(ph, False), 0.5, False),
    "Land_Hard": (lambda ph: pose_land(ph, True), 0.8, False),
    "Stun_GetUp": (pose_stun_getup, 1.6, False),
    "Hang": (pose_hang, 2.0, True),
    "Mantle": (pose_mantle, 0.7, False),
    "Sit_Chair": (pose_sit_chair, 5.0, True),
    "Sit_Floor": (pose_sit_floor, 5.0, True),
    "Lie": (pose_lie_idle, 5.0, True),
    "Cheer": (pose_cheer, 3.0, False),
    "PickUp": (pose_pickup, 1.4, False),
    "Balance": (pose_balance, 2.4, True),
    "Zip": (pose_zip, 2.0, True),
    "LookUp": (pose_look_up, 5.0, True),
    "Grief": (pose_grief, 6.0, True),
}


def all_clips(sk, node_of, locals_, names=None):
    out = []
    for name, (fn, dur, loop) in CLIPS.items():
        if names and name not in names:
            continue
        poses, times = sample_cycle(fn, dur, 30, loop)
        out.append(bake(sk, locals_, node_of, poses, times, name, loop))
    return out
