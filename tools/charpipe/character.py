"""Assemble a complete character (body, eyes, garments, hair, textures) and export GLB."""
import os, sys, json, time
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
import mh, skel, glb, meshutil, garments, uvraster, skin_tex, cloth_tex

PROFILES = {
    "salim": dict(macros=dict(gender=1.0, age=0.5, muscle=0.55, weight=0.47, height=0.52, caucasian=0.7, african=0.15, asian=0.15),
                  skin="young_male", sleeves="long", legs="long", hair=(0.09, 0.07, 0.055), hair_grey=0.0,
                  shirt=(0.16, 0.19, 0.2), pants=(0.19, 0.24, 0.34), shoes=(0.12, 0.12, 0.13),
                  expression=[("expression/units/caucasian/eyebrows-left-inner-up.target", 0.25), ("expression/units/caucasian/eyebrows-right-inner-up.target", 0.25),
                              ("expression/units/caucasian/mouth-depression.target", 0.15)], outfit="street"),
    "grandma": dict(macros=dict(gender=0.0, age=0.84, muscle=0.4, weight=0.62, height=0.3, caucasian=0.7, african=0.15, asian=0.15),
                    skin="old_female", sleeves="long", legs="long", hair=(0.7, 0.68, 0.66), hair_grey=0.0,
                    shirt=(0.08, 0.07, 0.08), pants=(0.08, 0.07, 0.08), shoes=(0.2, 0.14, 0.1),
                    expression=[("expression/units/caucasian/mouth-corner-puller.target", 0.2)], outfit="thobe", thobe_style="embroidered", head="scarf"),
    "child": dict(macros=dict(gender=1.0, age=0.17, muscle=0.5, weight=0.5, height=0.5, caucasian=0.7, african=0.15, asian=0.15),
                  skin="child", sleeves="short", legs="short", hair=(0.11, 0.08, 0.06), hair_grey=0.0,
                  shirt=(0.75, 0.2, 0.18), pants=(0.25, 0.3, 0.42), shoes=(0.9, 0.9, 0.88),
                  expression=[], outfit="street"),
    "musahhir": dict(macros=dict(gender=1.0, age=0.72, muscle=0.5, weight=0.6, height=0.5, caucasian=0.7, african=0.15, asian=0.15),
                     skin="old_male", sleeves="long", legs="long", hair=(0.5, 0.48, 0.46), hair_grey=0.4,
                     shirt=(0.3, 0.27, 0.22), pants=(0.3, 0.27, 0.22), shoes=(0.22, 0.15, 0.1),
                     expression=[], outfit="thobe", thobe_style="plain", thobe_color=(0.3, 0.27, 0.22), head="cap"),
}


def center(v, group):
    return v[mh.group_indices(group)].mean(axis=0)


def build(name, out_dir, tex_size=2048, anims=None, verbose=True):
    t0 = time.time()
    prof = PROFILES[name]
    base = mh.load_base()
    v = base.v.copy()
    mh.apply_macros(v, **prof["macros"])
    mh.apply_named(v, prof["expression"])
    rig, weights = mh.load_rig("mixamo")
    sk = skel.Skeleton.from_rig(rig, v)
    v_m = v * mh.SCALE
    skel.build_rest_frames(sk)
    pn = skel.palm_normals(v, rig)
    palms = {h: sk.bones[h].rest_world[:3, :3].T @ n for h, n in pn.items()}
    v_t = skel.repose_to_tpose(sk, v_m, weights, palms)
    floor = v_t[:mh.BODY_VERTS][:, 1].min()
    v_t[:, 1] -= floor
    for b in sk.bones.values():
        b.head[1] -= floor; b.tail[1] -= floor
    skel.build_rest_frames(sk)
    heads = {n: sk.bones[n].head for n in sk.order}
    per_v = skel.normalize_weights(weights, len(v))
    bone_index = {n: i for i, n in enumerate(sk.order)}
    per_v_idx = [[(bone_index[n], w) for n, w in lst if n in bone_index] for lst in per_v]
    # fallback: vertices without weights borrow the nearest weighted body vertex
    body_w = [i for i in range(mh.BODY_VERTS) if per_v_idx[i]]
    wtree = cKDTree(v_t[body_w])
    nfix = 0
    for i in range(len(v)):
        if not per_v_idx[i]:
            _, j = wtree.query(v_t[i]); per_v_idx[i] = list(per_v_idx[body_w[j]]); per_v[i] = list(per_v[body_w[j]]); nfix += 1
    # helper shells (tights, skirt, hair hood) follow the body: copy the weights of the nearest body
    # vertex, so a garment never tears along a face edge when the head or spine turns
    for i in range(mh.BODY_VERTS, len(v)):
        _, j = wtree.query(v_t[i]); per_v_idx[i] = list(per_v_idx[body_w[j]]); per_v[i] = list(per_v[body_w[j]])
    if verbose and nfix:
        print(f"[{name}] weight fallback for {nfix} vertices")
    dom = garments.dominant_bones(per_v, len(v))
    # ---- landmarks (metres, T-pose) ----
    eye_l = center(v_t, "joint-l-eye"); eye_r = center(v_t, "joint-r-eye")
    head = center(v_t, "joint-head"); mouth = center(v_t, "joint-mouth")
    body_idx = np.arange(mh.BODY_VERTS)
    headreg = body_idx[(v_t[:mh.BODY_VERTS, 1] > eye_l[1] - 0.06) & (v_t[:mh.BODY_VERTS, 1] < eye_l[1] + 0.01)]
    nose = v_t[headreg[np.argmax(v_t[headreg, 2])]]
    lm = dict(eye_l=eye_l, eye_r=eye_r, eye_y=eye_l[1], head=head, mouth=mouth, nose=nose, chin=mouth - np.array([0, 0.04, 0.0]),
              brow_y=eye_l[1] + 0.018, wrist_x=abs(heads["LeftHand"][0]), hip_y=heads["Hips"][1], knee_y=heads["LeftLeg"][1],
              chest_y=heads["Spine2"][1] + 0.08, toe_z=heads["LeftToeBase"][2], ankle_y=heads["LeftFoot"][1], neck_y=heads["Neck"][1],
              shoulder_y=heads["LeftArm"][1])
    if verbose:
        print(f"[{name}] morph+repose {time.time() - t0:.1f}s height {v_t[:mh.BODY_VERTS, 1].max():.2f}")
    body_faces = [base.faces[i] for i in mh.faces_of_group(base, "body")]
    nrm_all = garments.vertex_normals_of(v_t, body_faces + garments.helper_faces(base, "tights") + garments.helper_faces(base, "skirt") + garments.helper_faces(base, "hair"))
    # ---- which body vertices are covered by clothes ----
    yv = v_t[:, 1]; xv = np.abs(v_t[:, 0])
    arm_bones = {"LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftShoulder", "RightShoulder"}
    leg_bones = {"LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"}
    covered = np.zeros(len(v), dtype=bool)
    sleeve_end = lm["wrist_x"] - 0.02 if prof["sleeves"] == "long" else abs(heads["LeftForeArm"][0]) - 0.07
    leg_end = lm["ankle_y"] + 0.04 if prof["legs"] == "long" else lm["knee_y"] + 0.03
    for i in range(mh.BODY_VERTS):
        b = dom[i]
        if b in arm_bones and xv[i] < sleeve_end:
            covered[i] = True
        elif b in ("Spine", "Spine1", "Spine2", "Hips") and yv[i] > lm["hip_y"] - 0.12 and yv[i] < lm["neck_y"] - 0.015:
            covered[i] = True
        elif b in leg_bones and yv[i] > leg_end and yv[i] < lm["hip_y"] + 0.05:
            covered[i] = True
        elif b in ("Hips",) and yv[i] < lm["hip_y"] + 0.05 and yv[i] > leg_end:
            covered[i] = True
    if prof["outfit"] == "thobe":
        for i in range(mh.BODY_VERTS):
            if dom[i] in leg_bones or dom[i] == "Hips":
                if yv[i] > 0.06:
                    covered[i] = True
    foot_set = set(int(i) for i in body_idx if dom[i] in ("LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase") and yv[i] < lm["ankle_y"] + 0.05)
    body_vis_faces = [f for f in body_faces if not all(covered[vi] or vi in foot_set for vi, _ in f)]
    # ---- skin textures ----
    body_prim_full = meshutil.build_primitive_arrays(v_t, base.vt, body_faces, per_v_idx)
    alb, nrm, rough, cov = skin_tex.paint_skin(body_prim_full, lm, size=tex_size, profile=prof["skin"])
    if verbose:
        print(f"[{name}] skin painted {time.time() - t0:.1f}s")
    body_prim = meshutil.build_primitive_arrays(v_t, base.vt, body_vis_faces, per_v_idx)
    g = glb.GLB()
    dbg = os.path.join(out_dir, "debug"); os.makedirs(dbg, exist_ok=True)
    _dbg_n = [0]
    def tex(img_f, size=None):
        _dbg_n[0] += 1
        Image.fromarray((np.clip(img_f, 0, 1) * 255).astype(np.uint8)).resize((512, 512)).save(os.path.join(dbg, f"{name}_tex{_dbg_n[0]}.png"))
        im = Image.fromarray((np.clip(img_f, 0, 1) * 255).astype(np.uint8))
        if size and im.size[0] != size:
            im = im.resize((size, size), Image.LANCZOS)
        return g.add_image_png(im)
    def mr_tex(rough_map, size):
        mr = np.stack([np.ones_like(rough_map), rough_map, np.zeros_like(rough_map)], axis=-1)
        return tex(mr, size)
    skin_mat = g.add_material("skin", base_tex=tex(alb), normal_tex=tex(nrm, 1024), mr_tex=mr_tex(rough, 1024), roughness=1.0, normal_scale=0.6)
    prims = [g.add_primitive_data(body_prim["pos"], body_prim["nrm"], body_prim["uv"], body_prim["idx"], body_prim["joints"], body_prim["weights"], skin_mat)]
    # ---- eyes ----
    eye = mh.load_mhclo(os.path.join(mh.MH_DATA, "eyes", "low-poly", "low-poly.mhclo"))
    eye_mesh = mh.load_obj(eye["obj"])
    eye_src = np.array([t[0] for t in eye["verts"]], dtype=np.int64)   # body helper vertex per eye vertex
    eye_pos = v_t[eye_src]
    eye_skin = [per_v_idx[i] for i in eye_src]
    eye_prim = meshutil.build_primitive_arrays(eye_pos, eye_mesh.vt, eye_mesh.faces, eye_skin)
    eye_img = Image.open(os.path.join(mh.MH_DATA, "eyes", "materials", "brown_eye.png")).convert("RGBA")
    ea = np.asarray(eye_img).astype(np.float64) / 255.0
    dark = np.clip((0.55 - ea[..., :3].mean(-1)) / 0.25, 0, 1)[..., None]
    ea[..., :3] = ea[..., :3] * (1 - dark) + ea[..., :3] * np.array([0.42, 0.55, 0.7])[None, None, :] * dark
    eye_img = Image.fromarray((np.clip(ea, 0, 1) * 255).astype(np.uint8))
    eye_mat = g.add_material("eyes", base_tex=g.add_image_png(eye_img), roughness=0.15, metallic=0.0)
    prims.append(g.add_primitive_data(eye_prim["pos"], eye_prim["nrm"], eye_prim["uv"], eye_prim["idx"], eye_prim["joints"], eye_prim["weights"], eye_mat))
    # ---- garments from the tights helper ----
    body_tree = cKDTree(v_t[:mh.BODY_VERTS]); 
    tights_faces = garments.helper_faces(base, "tights")
    shirt_v, pants_v = garments.region_split_tights(base, v_t, heads, dom)
    # the collar line is painted (alpha) rather than cut from the mesh, so it stays smooth
    neck_cut = lm["neck_y"] - 0.012 if prof["outfit"] == "street" else lm["neck_y"] + 0.025
    if prof["sleeves"] == "short":
        shirt_v = np.array([i for i in shirt_v if not (dom[i] in arm_bones and xv[i] > abs(heads["LeftForeArm"][0]) - 0.07)])
    if prof["legs"] == "short":
        pants_v = np.array([i for i in pants_v if yv[i] > lm["knee_y"] + 0.03])
    # position/normal maps for cloth painting use the body atlas; garments get transferred uvs
    def garment(faces_sel, inflate_amt, label, uv_mode="body"):
        idx = sorted(set(vi for f in faces_sel for vi, _ in f))
        if uv_mode == "head":
            # hood-derived pieces (hair, cap, scarf) get a cylindrical map around the head: the body
            # atlas has seams across the scalp that smear a transferred texture
            fuv = []
            for f in faces_sel:
                us = []; vs = []
                for vi, _ in f:
                    q = v_t[vi]
                    d = q - head; dn = d / max(np.linalg.norm(d), 1e-6)
                    u = 0.5 + np.arctan2(dn[0], -dn[2]) / (2 * np.pi)
                    us.append(u); vs.append(np.clip(np.arccos(np.clip(dn[1], -1, 1)) / np.pi, 0, 1))
                if max(us) - min(us) > 0.5:
                    us = [u + 1.0 if u < 0.5 else u for u in us]
                fuv.append([(vi, (us[k], vs[k])) for k, (vi, _) in enumerate(f)])
        else:
            fuv = garments.transfer_uvs(base, v_t, faces_sel, body_faces, body_tree, np.arange(mh.BODY_VERTS))
        off = garments.inflate(v_t, nrm_all, np.array(idx), inflate_amt)
        return garments.faces_to_prim(v_t, fuv, per_v_idx, off)
    def own_maps(prim, size=1024):
        uvt, attrs = uvraster.tri_uv_and_attr(prim, prim["pos"], prim["nrm"])
        img, cv = uvraster.rasterize(uvt, attrs, size, bg=0.0, dilate=8)
        return img[..., :3], img[..., 3:6], cv
    # textures for garments are painted using the *body* position map (same atlas)
    P = None
    uvt, attrs = uvraster.tri_uv_and_attr(body_prim_full, body_prim_full["pos"], body_prim_full["nrm"])
    img, pcov = uvraster.rasterize(uvt, attrs, 1024, bg=0.0, dilate=6)
    P = img[..., :3]; Nmap = img[..., 3:6]
    if prof["outfit"] == "street":
        shirt_faces = garments.faces_within(tights_faces, shirt_v)
        pants_faces = garments.faces_within(tights_faces, pants_v)
        sp = garment(shirt_faces, 0.012, "shirt")
        pp = garment(pants_faces, 0.009, "pants")
        c, n, r, a = cloth_tex.knit(P, Nmap, pcov, 1024, prof["shirt"], collar_y=neck_cut)
        shirt_mat = g.add_material("shirt", base_tex=tex(np.concatenate([c, a[..., None]], axis=-1)), normal_tex=tex(n), mr_tex=mr_tex(r, 1024), roughness=1.0, alpha_mode="MASK", double_sided=True)
        c, n, r = cloth_tex.denim(P, Nmap, pcov, 1024, prof["pants"], lm)
        pants_mat = g.add_material("pants", base_tex=tex(c), normal_tex=tex(n), mr_tex=mr_tex(r, 1024), roughness=1.0)
        prims.append(g.add_primitive_data(sp["pos"], sp["nrm"], sp["uv"], sp["idx"], sp["joints"], sp["weights"], shirt_mat))
        prims.append(g.add_primitive_data(pp["pos"], pp["nrm"], pp["uv"], pp["idx"], pp["joints"], pp["weights"], pants_mat))
    else:
        # thobe: shirt region of tights + skirt helper, one material
        shirt_faces = garments.faces_within(tights_faces, shirt_v)
        skirt_faces = garments.helper_faces(base, "skirt")
        sp = garment(shirt_faces, 0.014, "thobe_top")
        skp = garment(skirt_faces, 0.004, "thobe_skirt")
        c, n, r, a = cloth_tex.thobe(P, Nmap, pcov, 1024, lm, style=prof.get("thobe_style", "embroidered"), color=prof.get("thobe_color"))
        thobe_mat = g.add_material("thobe", base_tex=tex(np.concatenate([c, a[..., None]], axis=-1)), normal_tex=tex(n), mr_tex=mr_tex(r, 1024), roughness=1.0, alpha_mode="MASK", double_sided=True)
        prims.append(g.add_primitive_data(sp["pos"], sp["nrm"], sp["uv"], sp["idx"], sp["joints"], sp["weights"], thobe_mat))
        prims.append(g.add_primitive_data(skp["pos"], skp["nrm"], skp["uv"], skp["idx"], skp["joints"], skp["weights"], thobe_mat))
    if prof.get("head") == "scarf":
        # headscarf: hair helper (a hood that also covers the face) with the face window cut out, plus a neck/shoulder shell
        def in_window(vi):
            q = v_t[vi]
            face = q[2] > head[2] + 0.04 and q[1] < lm["brow_y"] + 0.03 and abs(q[0] - head[0]) < 0.07
            below = q[2] > head[2] + 0.0 and q[1] < lm["chin"][1] + 0.01
            return face or below
        def scarf_ok(vi):
            q = v_t[vi]
            return np.linalg.norm(q - head) < 0.2 and q[1] > lm["chin"][1] - 0.06 and not in_window(vi)
        hair_faces = [f for f in body_faces if all(scarf_ok(vi) for vi, _ in f)]
        neck_v = np.array([i for i in mh.group_indices("helper-tights") if yv[i] > lm["shoulder_y"] - 0.05 and (dom[i] in ("Neck", "Spine2", "LeftShoulder", "RightShoulder", "Head") or yv[i] > lm["shoulder_y"] - 0.02)])
        neck_faces = garments.faces_within(tights_faces, neck_v)
        hp = garment(hair_faces, 0.012, "scarf_top", uv_mode="head"); npm = garment(neck_faces, 0.016, "scarf_neck")
        c, n, r = cloth_tex.scarf(P, Nmap, pcov, 1024)
        scarf_mat = g.add_material("scarf", base_tex=tex(c), normal_tex=tex(n), mr_tex=mr_tex(r, 1024), roughness=1.0, double_sided=True)
        Ph, Nh, ch = own_maps(hp)
        c2, n2, r2 = cloth_tex.scarf(Ph, Nh, ch, 1024, seed=19)
        scarf_mat2 = g.add_material("scarf_head", base_tex=tex(c2), mr_tex=mr_tex(r2, 1024), roughness=1.0, double_sided=True)
        prims.append(g.add_primitive_data(hp["pos"], hp["nrm"], hp["uv"], hp["idx"], hp["joints"], hp["weights"], scarf_mat2))
        prims.append(g.add_primitive_data(npm["pos"], npm["nrm"], npm["uv"], npm["idx"], npm["joints"], npm["weights"], scarf_mat))
    # ---- shoes: inflated feet ----
    foot_faces = [f for f in body_faces if all(vi in foot_set for vi, _ in f)]
    shoe_off = garments.inflate(v_t, nrm_all, np.array(sorted(foot_set)), 0.007)
    # thicker sole: push downward-facing foot vertices down
    for i in foot_set:
        if nrm_all[i][1] < -0.4:
            shoe_off[i][1] -= 0.012
    shoe_prim = meshutil.build_primitive_arrays(v_t + shoe_off, base.vt, foot_faces, per_v_idx)
    c, n, r = cloth_tex.canvas_shoe(P, Nmap, pcov, 1024, prof["shoes"], lm)
    shoe_mat = g.add_material("shoes", base_tex=tex(c), normal_tex=tex(n), mr_tex=mr_tex(r, 1024), roughness=1.0)
    prims.append(g.add_primitive_data(shoe_prim["pos"], shoe_prim["nrm"], shoe_prim["uv"], shoe_prim["idx"], shoe_prim["joints"], shoe_prim["weights"], shoe_mat))
    # ---- hair cap ----
    if prof.get("head") != "scarf":
        # the hair helper is a hood reaching the chest; keep the scalp and the nape, drop the rows over the ears and face
        def hair_ok(vi):
            q = v_t[vi]
            ear = abs(q[0] - head[0]) > 0.062 and q[1] < eye_l[1] + 0.065 and q[2] > head[2] - 0.045
            return np.linalg.norm(q - head) < 0.175 and not ear and (q[1] > eye_l[1] + 0.035 or (q[2] < head[2] - 0.03 and q[1] > eye_l[1] - 0.02))
        hair_faces = [f for f in body_faces if all(hair_ok(vi) for vi, _ in f)]
        hpr = garment(hair_faces, 0.006, "hair", uv_mode="head")
        Ph, Nh, ch = own_maps(hpr)
        c, n, r, a = cloth_tex.hair_cap(Ph, Nh, ch, 1024, prof["hair"], lm, grey=prof["hair_grey"])
        rgba = np.concatenate([c, a[..., None]], axis=-1)
        hair_mat = g.add_material("hair", base_tex=tex(rgba), mr_tex=mr_tex(r, 1024), roughness=1.0, alpha_mode="MASK", double_sided=True)
        prims.append(g.add_primitive_data(hpr["pos"], hpr["nrm"], hpr["uv"], hpr["idx"], hpr["joints"], hpr["weights"], hair_mat))
    if prof.get("head") == "cap":
        # white crocheted skull cap sitting on the hair
        cap_faces = [f for f in body_faces if all(hair_ok(vi) and v_t[vi][1] > eye_l[1] + 0.05 for vi, _ in f)]
        cpr = garment(cap_faces, 0.012, "cap", uv_mode="head")
        Ph, Nh, ch = own_maps(cpr)
        c, n, r = cloth_tex.taqiyah(Ph, Nh, ch, 1024)
        cap_mat = g.add_material("cap", base_tex=tex(c), mr_tex=mr_tex(r, 1024), roughness=1.0, double_sided=True)
        prims.append(g.add_primitive_data(cpr["pos"], cpr["nrm"], cpr["uv"], cpr["idx"], cpr["joints"], cpr["weights"], cap_mat))
    mesh = g.add_mesh(name.capitalize(), prims)
    # ---- skeleton nodes ----
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
    mesh_node = g.add_node(name.capitalize() + "Mesh", mesh=mesh, skin=skin)
    root = g.add_node("Root", children=[node_of[sk.order[0]], mesh_node])
    g.scene_nodes = [root]
    if anims:
        for aname, tracks in anims(sk, node_of, locals_):
            g.add_animation(aname, tracks)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f"{name}.glb")
    g.save(out)
    json.dump({"heads": {n: heads[n].tolist() for n in sk.order}, "order": sk.order, "landmarks": {k: (v.tolist() if hasattr(v, "tolist") else v) for k, v in lm.items()}},
              open(os.path.join(out_dir, f"{name}_skel.json"), "w"))
    if verbose:
        print(f"[{name}] saved {out} {os.path.getsize(out) / 1e6:.1f} MB in {time.time() - t0:.1f}s")
    return out, sk, locals_


if __name__ == "__main__":
    name = sys.argv[1] if len(sys.argv) > 1 else "salim"
    out_dir = sys.argv[2] if len(sys.argv) > 2 else "/tmp/chars"
    with_anims = "--anims" in sys.argv
    if with_anims:
        import anim
        build(name, out_dir, anims=lambda sk, node_of, locals_: anim.all_clips(sk, node_of, locals_))
    else:
        build(name, out_dir)
