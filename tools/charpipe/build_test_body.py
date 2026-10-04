"""Step 1 test: morph Salim, build mixamo skeleton, re-pose to T-pose, export body only."""
import numpy as np, json, sys, os
import mh, skel, glb, meshutil
from scipy.spatial.transform import Rotation as R

base = mh.load_base()
v = base.v.copy()
mh.apply_macros(v, gender=1.0, age=0.5, muscle=0.55, weight=0.47, height=0.55, caucasian=0.7, african=0.15, asian=0.15)
rig, weights = mh.load_rig("mixamo")
sk = skel.Skeleton.from_rig(rig, v)
print("bones:", len(sk.order), sk.order[:8])
v_m = v * mh.SCALE
palms = {}
pn = skel.palm_normals(v, rig)
skel.build_rest_frames(sk)
for hand, n in pn.items():
    # express in hand rest frame (columns are axes)
    B = sk.bones[hand].rest_world[:3, :3]
    palms[hand] = B.T @ n
v_t = skel.repose_to_tpose(sk, v_m, weights, palms)
print("T-pose arm dir:", np.round(sk.bone_dir("LeftArm"), 3), "hand:", np.round(sk.bone_dir("LeftHand"), 3), "upleg:", np.round(sk.bone_dir("LeftUpLeg"), 3))
print("height:", v_t[:13380][:, 1].max() - v_t[:13380][:, 1].min(), "min y", v_t[:13380][:, 1].min())
# ground the feet at y=0
floor = v_t[:13380][:, 1].min()
v_t[:, 1] -= floor
for b in sk.bones.values():
    b.head[1] -= floor; b.tail[1] -= floor
skel.build_rest_frames(sk)
# skin lists
per_v = skel.normalize_weights(weights, len(v))
bone_index = {n: i for i, n in enumerate(sk.order)}
per_v_idx = [[(bone_index[n], w) for n, w in lst if n in bone_index] for lst in per_v]
body_faces = [base.faces[i] for i in mh.faces_of_group(base, "body")]
prim = meshutil.build_primitive_arrays(v_t, base.vt, body_faces, per_v_idx)
print("prim verts", len(prim["pos"]), "tris", len(prim["idx"]))
g = glb.GLB()
mat = g.add_material("skin", base_color=(0.78, 0.6, 0.48, 1.0), roughness=0.6)
p = g.add_primitive_data(prim["pos"], prim["nrm"], prim["uv"], prim["idx"], prim["joints"], prim["weights"], mat)
mesh = g.add_mesh("Body", [p])
# joint nodes
locals_ = skel.local_rest(sk)
node_of = {}
for n in sk.order:
    t, q = locals_[n]
    node_of[n] = g.add_node(n, translation=t, rotation=q)
for n in sk.order:
    b = sk.bones[n]
    if b.children:
        g.nodes[node_of[n]]["children"] = [node_of[c] for c in sorted(b.children)]
ibm = [np.linalg.inv(sk.bones[n].rest_world) for n in sk.order]
skin = g.add_skin("Armature", [node_of[n] for n in sk.order], ibm, skeleton_root=node_of[sk.order[0]])
mesh_node = g.add_node("Salim", mesh=mesh, skin=skin)
root = g.add_node("Root", children=[node_of[sk.order[0]], mesh_node])
g.scene_nodes = [root]
# simple test animation: wave left arm + bend knees
times = np.linspace(0, 2.0, 25)
tracks = []
def q_about(axis, ang):
    return R.from_rotvec(np.array(axis) * ang)
for n in ["LeftArm", "RightUpLeg", "LeftUpLeg", "LeftLeg", "RightLeg"]:
    t0, q0 = locals_[n]
    vals = []
    for t in times:
        k = np.sin(t * np.pi)
        if n == "LeftArm":
            extra = q_about([0, 0, 1], 1.2 * k)      # raise/lower arm about world Z in bind frame
        elif n.endswith("UpLeg"):
            extra = q_about([1, 0, 0], -0.8 * k)
        else:
            extra = q_about([1, 0, 0], 1.4 * k)
        Gw = sk.bones[n].rest_world[:3, :3]
        # local = rest_local * (rest^-1 * extra_world * rest)
        loc = (R.from_quat(q0) * R.from_matrix(Gw.T @ extra.as_matrix() @ Gw)).as_quat()
        vals.append(loc)
    tracks.append((node_of[n], "rotation", times, np.array(vals)))
g.add_animation("Test", tracks)
out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/salim_body_test.glb"
g.save(out)
print("saved", out, os.path.getsize(out))
json.dump({n: {"head": sk.bones[n].head.tolist(), "parent": sk.bones[n].parent} for n in sk.order}, open("/tmp/skel_dump.json", "w"), indent=1)
