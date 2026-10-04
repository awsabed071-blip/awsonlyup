"""Procedural skin textures painted in the MakeHuman UV atlas from 3D rules."""
import os, numpy as np
from PIL import Image
import mh, uvraster
from noise_lite import fbm2d, hash_noise

MASK_DIR = os.path.join(mh.MPFB_DATA, "textures")


def load_mask(name, size):
    im = Image.open(os.path.join(MASK_DIR, f"mpfb_{name}.jpg")).convert("L")
    if im.size[0] != size:
        im = im.resize((size, size), Image.BILINEAR)
    return np.asarray(im, dtype=np.float64) / 255.0


def sd_segment(p, a, b):
    """Distance from points p (...,3) to segment ab."""
    ab = b - a; t = np.clip(np.einsum("...k,k->...", p - a, ab) / max(np.dot(ab, ab), 1e-9), 0, 1)
    return np.linalg.norm(p - (a + t[..., None] * ab), axis=-1)


def sd_polyline(p, pts):
    d = np.full(p.shape[:-1], 1e9)
    for i in range(len(pts) - 1):
        d = np.minimum(d, sd_segment(p, pts[i], pts[i + 1]))
    return d


def paint_skin(prim, landmarks, size=2048, profile="young_male", seed=3):
    """prim: body primitive dict (pos (metres, T-pose, feet at 0), nrm, uv(image space), idx).
    landmarks: dict with eye_l, eye_r, mouth, head, nose, chin, brow_y, ear_l, ear_r (3D).
    Returns albedo (size,size,3) float, normal (size,size,3), roughness (size,size)."""
    uvt, attrs = uvraster.tri_uv_and_attr(prim, prim["pos"], prim["nrm"])
    img, cov = uvraster.rasterize(uvt, attrs, size, bg=0.0, dilate=6)
    P = img[..., :3]; N = img[..., 3:6]
    face_m = load_mask("face", size); lips_m = load_mask("lips", size); lids_m = load_mask("eyelids", size)
    ears_m = load_mask("ears", size); nails_m = np.maximum(load_mask("fingernails", size), load_mask("toenails", size))
    rng = np.random.default_rng(seed)
    head = landmarks["head"]; eye_l = landmarks["eye_l"]; eye_r = landmarks["eye_r"]; mouth = landmarks["mouth"]
    nose = landmarks["nose"]; chin = landmarks["chin"]
    # ---------- base tone ----------
    prof = {
        "young_male": dict(tone=(0.70, 0.52, 0.40), red=(0.74, 0.44, 0.36), stubble=0.55, wrinkle=0.0, spots=0.0, hair=(0.10, 0.075, 0.055), lips=(0.62, 0.38, 0.35), rough=0.55),
        "old_female": dict(tone=(0.76, 0.62, 0.53), red=(0.74, 0.50, 0.44), stubble=0.0, wrinkle=1.0, spots=1.0, hair=(0.75, 0.72, 0.68), lips=(0.60, 0.40, 0.38), rough=0.62),
        "child": dict(tone=(0.78, 0.60, 0.48), red=(0.82, 0.52, 0.44), stubble=0.0, wrinkle=0.0, spots=0.0, hair=(0.12, 0.085, 0.06), lips=(0.70, 0.42, 0.40), rough=0.50),
        "old_male": dict(tone=(0.66, 0.50, 0.40), red=(0.70, 0.42, 0.36), stubble=0.35, wrinkle=0.8, spots=0.6, hair=(0.45, 0.43, 0.42), lips=(0.58, 0.36, 0.34), rough=0.6),
    }[profile]
    tone = np.array(prof["tone"]); red = np.array(prof["red"])
    slow = fbm2d(size, 6, 4, seed) * 0.5 + 0.5
    mid = fbm2d(size, 18, 3, seed + 1)
    pores = fbm2d(size, 220, 2, seed + 2)
    alb = tone[None, None, :] * (0.93 + slow * 0.12)[..., None]
    alb = alb * (1.0 + mid * 0.02)[..., None]
    # mottling: subtle red/yellow variation
    alb[..., 0] *= 1.0 + fbm2d(size, 20, 3, seed + 3) * 0.04
    alb[..., 2] *= 1.0 - fbm2d(size, 25, 3, seed + 4) * 0.05
    # ---------- face regions ----------
    # cheeks & nose & ears redder
    cheek = np.exp(-((P[..., 1] - (eye_l[1] - 0.045)) ** 2) / (2 * 0.03 ** 2)) * np.clip((np.abs(P[..., 0]) - 0.025) / 0.03, 0, 1)
    cheek *= face_m
    nosed = np.exp(-np.sum((P - nose) ** 2, axis=-1) / (2 * 0.012 ** 2))
    alb = alb * (1 - (cheek * 0.35 + nosed * 0.25)[..., None]) + red[None, None, :] * (cheek * 0.35 + nosed * 0.25)[..., None]
    alb = alb * (1 - (ears_m * 0.3)[..., None]) + red[None, None, :] * (ears_m * 0.3)[..., None]
    # forehead slightly yellower / darker
    fore = np.clip((P[..., 1] - (eye_l[1] + 0.02)) / 0.05, 0, 1) * face_m
    alb[..., 2] *= 1.0 - fore * 0.08
    # lips
    lipc = np.array(prof["lips"])
    alb = alb * (1 - lips_m[..., None] * 0.85) + lipc[None, None, :] * (lips_m[..., None] * 0.85)
    # eyelids: darker/pinker, lash line at the lid border
    lid_dark = lids_m * 0.18
    alb *= (1 - lid_dark)[..., None]
    alb[..., 0] *= 1.0 + lids_m * 0.06
    lid_edge = np.clip(lids_m - np.roll(lids_m, 3, axis=0), 0, 1)
    alb *= (1 - lid_edge * 0.6)[..., None]
    # eye socket shading (ambient occlusion around eyes)
    for e in (eye_l, eye_r):
        de = np.linalg.norm(P - e, axis=-1)
        sock = np.clip(1 - de / 0.028, 0, 1) ** 1.5
        alb *= (1 - sock * 0.22)[..., None]
    # nails
    alb = alb * (1 - nails_m[..., None] * 0.7) + np.array([0.86, 0.70, 0.66])[None, None, :] * (nails_m[..., None] * 0.7)
    # knuckles / joints darkening on hands via high-freq noise where hands are (x beyond wrist)
    hands = (np.abs(P[..., 0]) > landmarks["wrist_x"] - 0.01) & (P[..., 1] > 1.0) & cov
    alb *= (1 - hands * 0.04)[..., None]
    # ---------- eyebrows ----------
    hair = np.array(prof["hair"])
    brow_y = landmarks["brow_y"]
    for e, sx in ((eye_l, 1.0), (eye_r, -1.0)):
        pts = np.array([[e[0] - sx * 0.006, brow_y - 0.004, e[2] + 0.004],
                        [e[0] + sx * 0.008, brow_y + 0.003, e[2] + 0.009],
                        [e[0] + sx * 0.024, brow_y + 0.004, e[2] + 0.006],
                        [e[0] + sx * 0.040, brow_y - 0.002, e[2] - 0.004]])
        P2 = P.copy(); P2[..., 2] = 0.0; pts2 = pts.copy(); pts2[:, 2] = 0.0
        d = sd_polyline(P2, pts2) + (P[..., 2] < e[2] - 0.005) * 1.0 + (N[..., 2] < 0.15) * 1.0
        thick = 0.0036 + 0.0018 * np.clip((P[..., 0] * sx - (e[0] * sx)) / 0.04, 0, 1)
        strands = 0.55 + 0.45 * (hash_noise(size, 900, seed + 7) > 0.35)
        bm = np.clip(1 - d / thick, 0, 1) ** 0.6 * strands * (0.9 if profile != "old_female" else 0.7)
        alb = alb * (1 - bm[..., None]) + hair[None, None, :] * bm[..., None]
    # ---------- stubble ----------
    if prof["stubble"] > 0:
        below = np.clip((mouth[1] + 0.012 - P[..., 1]) / 0.02, 0, 1)
        side = np.clip((np.abs(P[..., 0]) - 0.022) / 0.02, 0, 1) * np.clip((P[..., 1] - (mouth[1] - 0.01)) / 0.03, 0, 1) * np.clip((P[..., 1] < eye_l[1] - 0.03), 0, 1)
        mustache = np.clip(1 - np.abs(P[..., 1] - (mouth[1] + 0.012)) / 0.012, 0, 1) * np.clip(1 - np.abs(P[..., 0]) / 0.03, 0, 1) * (1 - lips_m)
        beard = np.clip(below + side + mustache * 0.8, 0, 1) * face_m * (1 - lips_m)
        beard *= np.clip((P[..., 2] - (head[2] - 0.02)) / 0.03, 0, 1)  # front of the face only
        grain = 0.6 + 0.4 * (hash_noise(size, 1100, seed + 9) > 0.45)
        k = beard * (0.75 + 0.25 * grain) * prof["stubble"] * 0.5
        beard_col = np.minimum(hair * 1.3, tone * 0.75)
        alb = alb * (1 - k[..., None]) + beard_col[None, None, :] * k[..., None]
    # ---------- scalp (under the hair cap) ----------
    scalp = ((P[..., 1] > brow_y + 0.035) | ((P[..., 2] < head[2] - 0.035) & (P[..., 1] > eye_l[1]))) & (P[..., 1] > 1.2) & cov
    scalp = scalp & ~(face_m > 0.5)
    scalp_f = scalp.astype(np.float64)
    # soften the hairline
    hl = np.clip((P[..., 1] - (brow_y + 0.03)) / 0.012, 0, 1)
    hl_full = np.maximum(hl, np.clip((head[2] - 0.035 - P[..., 2]) / 0.01, 0, 1) * (P[..., 1] > eye_l[1]))
    scalp_f = np.minimum(scalp_f + hl_full * (P[..., 1] > brow_y + 0.015) * (P[..., 1] > 1.2), 1.0) * cov
    sc_col = hair if profile != "old_female" else tone * 0.9
    alb = alb * (1 - scalp_f[..., None] * 0.92) + sc_col[None, None, :] * (scalp_f[..., None] * 0.92)
    # ---------- wrinkles & age ----------
    height = mid * 0.05
    if prof["wrinkle"] > 0:
        w = prof["wrinkle"]
        lines = np.zeros((size, size))
        # forehead lines
        for k in range(3):
            y = brow_y + 0.022 + k * 0.011
            curve = np.array([[-0.045, y - 0.006, head[2] + 0.055], [-0.02, y, head[2] + 0.068], [0.0, y + 0.002, head[2] + 0.07], [0.02, y, head[2] + 0.068], [0.045, y - 0.006, head[2] + 0.055]])
            d = sd_polyline(P, curve); lines += np.clip(1 - d / 0.0012, 0, 1) * (0.7 + 0.3 * mid)
        # crow's feet
        for e, sx in ((eye_l, 1.0), (eye_r, -1.0)):
            for a in (-0.35, -0.1, 0.15, 0.4):
                p0 = np.array([e[0] + sx * 0.032, e[1], e[2] - 0.01])
                p1 = p0 + np.array([sx * 0.02 * np.cos(a), 0.02 * np.sin(a), -0.012])
                d = sd_segment(P, p0, p1); lines += np.clip(1 - d / 0.0009, 0, 1) * 0.8
        # nasolabial folds and mouth corners
        for sx in (1.0, -1.0):
            p0 = np.array([nose[0] + sx * 0.016, nose[1] - 0.004, nose[2] - 0.012])
            p1 = np.array([mouth[0] + sx * 0.03, mouth[1] - 0.012, mouth[2] - 0.016])
            d = sd_segment(P, p0, p1); lines += np.clip(1 - d / 0.0022, 0, 1) * 0.9
            p2 = np.array([mouth[0] + sx * 0.024, mouth[1] - 0.004, mouth[2] - 0.004]); p3 = p2 + np.array([sx * 0.004, -0.02, -0.004])
            d = sd_segment(P, p2, p3); lines += np.clip(1 - d / 0.0012, 0, 1) * 0.7
        # fine crinkles everywhere on the face / hands
        crinkle = np.abs(fbm2d(size, 500, 2, seed + 12)) * (face_m + hands * 0.6)
        lines = np.clip(lines + crinkle * 0.5, 0, 1) * w
        alb *= (1 - lines * 0.22)[..., None]
        height -= lines * 0.9
        # sagging shade under eyes and cheeks
        for e in (eye_l, eye_r):
            d = np.linalg.norm(P - (e + np.array([0, -0.018, 0.0])), axis=-1)
            alb *= (1 - np.clip(1 - d / 0.016, 0, 1) * 0.12)[..., None]
    if prof["spots"] > 0:
        sp = (hash_noise(size, 140, seed + 20) > 0.93).astype(np.float64)
        sp = np.maximum(sp, np.roll(sp, 1, 0)); sp = np.maximum(sp, np.roll(sp, 1, 1))
        spots = sp * (face_m * 0.5 + hands * 0.8) * prof["spots"]
        alb = alb * (1 - spots[..., None] * 0.35) + np.array([0.45, 0.32, 0.24])[None, None, :] * (spots[..., None] * 0.35)
    # ---------- roughness ----------
    rough = np.full((size, size), prof["rough"]) + mid * 0.03
    tzone = (np.clip(1 - np.abs(P[..., 0]) / 0.02, 0, 1) * face_m * (P[..., 1] > mouth[1]))
    rough -= tzone * 0.1
    rough = rough * (1 - lips_m) + 0.42 * lips_m
    rough = rough * (1 - nails_m) + 0.3 * nails_m
    rough += scalp_f * 0.25
    # ---------- normal ----------
    from noise import height_to_normal
    nrm = height_to_normal(np.clip(0.5 + height * 0.08, 0, 1), 0.5)
    return np.clip(alb, 0, 1), nrm, np.clip(rough, 0.05, 1.0), cov
