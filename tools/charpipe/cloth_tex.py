"""Garment textures painted in the body UV atlas from 3D rules (P = position map, N = normal map)."""
import numpy as np
from noise import fbm, value_noise, smoothstep, height_to_normal, _hash2
from noise_lite import hash_noise


def _twill(size, period=220, angle=1.0):
    ys, xs = np.mgrid[0:size, 0:size] / size
    return 0.5 + 0.5 * np.sin((xs * np.cos(angle) + ys * np.sin(angle)) * 2 * np.pi * period)


def collar_alpha(P, collar_y, size, seed=5):
    """1 below the collar line, 0 above it; the line wobbles slightly so it does not read as a cut."""
    wob = fbm(size, 24, 2, seed + 11) * 0.004
    return smoothstep(collar_y + 0.004 + wob, collar_y - 0.006 + wob, P[..., 1])


def knit(P, N, cov, size, color, seed=5, collar_y=None):
    h = fbm(size, 60, 2, seed + 8) * 0.5 + 0.5
    pill = (hash_noise(size, 300, seed) > 0.99).astype(np.float64)
    big = fbm(size, 5, 4, seed); folds = fbm(size, 11, 3, seed + 3)
    c = np.array(color)[None, None, :] * (0.98 + (h - 0.5) * 0.02 + big * 0.03 + folds * 0.03)[..., None]
    c = c * (1 - pill[..., None] * 0.04)
    rough = 0.94 + big * 0.02
    nrm = height_to_normal(np.clip(0.5 + (h - 0.5) * 0.003 + folds * 0.02, 0, 1), 0.35)
    if collar_y is not None:
        return np.clip(c, 0, 1), nrm, rough, collar_alpha(P, collar_y, size, seed)
    return np.clip(c, 0, 1), nrm, rough


def denim(P, N, cov, size, color, landmarks, seed=6):
    tw = fbm(size, 80, 2, seed + 9) * 0.5 + 0.5
    big = fbm(size, 6, 4, seed); fine = fbm(size, 60, 2, seed + 1); folds = fbm(size, 10, 3, seed + 4)
    c = np.array(color)[None, None, :] * (0.97 + (tw - 0.5) * 0.02 + big * 0.05 + fine * 0.015 + folds * 0.04)[..., None]
    # fading on knees and thighs (front), darker inner legs
    knee_y = landmarks["knee_y"]
    front = np.clip(N[..., 2], 0, 1)
    knee = np.exp(-((P[..., 1] - knee_y) ** 2) / (2 * 0.06 ** 2)) * front
    thigh = np.exp(-((P[..., 1] - (knee_y + 0.22)) ** 2) / (2 * 0.1 ** 2)) * front * 0.5
    fade = np.clip(knee + thigh, 0, 1) * (0.6 + 0.4 * big)
    c = c + (np.array([0.75, 0.78, 0.82]) - c) * (fade * 0.35)[..., None]
    # seams: where the normal points sideways (outer and inner seams)
    seam = smoothstep(0.955, 0.99, np.abs(N[..., 0])) * (P[..., 1] < landmarks["hip_y"] + 0.02)
    c = c * (1 - seam * 0.25)[..., None] + np.array([0.70, 0.55, 0.30])[None, None, :] * (seam * 0.12)[..., None]
    # waistband and belt
    waist = np.exp(-((P[..., 1] - (landmarks["hip_y"] + 0.03)) ** 2) / (2 * 0.012 ** 2))
    c = c * (1 - waist * 0.5)[..., None] + np.array([0.16, 0.11, 0.08])[None, None, :] * (waist * 0.5)[..., None]
    rough = 0.9 - fade * 0.05
    h = (tw - 0.5) * 0.01 + folds * 0.08 - seam * 0.12 + waist * 0.08
    nrm = height_to_normal(np.clip(0.5 + h * 0.15, 0, 1), 0.4)
    return np.clip(c, 0, 1), nrm, np.clip(rough, 0, 1)


def canvas_shoe(P, N, cov, size, color, landmarks, seed=7):
    sole_h = 0.028
    sole = smoothstep(sole_h + 0.004, sole_h - 0.004, P[..., 1])
    toe_cap = smoothstep(0.05, 0.02, P[..., 1]) * np.clip((P[..., 2] - (landmarks["toe_z"] - 0.05)) / 0.03, 0, 1)
    tw = fbm(size, 70, 2, seed + 5) * 0.5 + 0.5; big = fbm(size, 8, 3, seed)
    c = np.array(color)[None, None, :] * (0.95 + (tw - 0.5) * 0.03 + big * 0.08)[..., None]
    rubber = np.array([0.86, 0.84, 0.78]) * (0.9 + fbm(size, 60, 3, seed + 2) * 0.08)[..., None]
    c = c * (1 - sole[..., None]) + rubber * sole[..., None]
    c = c * (1 - toe_cap[..., None] * 0.7) + rubber * (toe_cap[..., None] * 0.7)
    # laces: stripes across the instep
    lace_zone = np.clip((P[..., 1] - 0.045) / 0.03, 0, 1) * np.clip(1 - np.abs(P[..., 2] - landmarks["toe_z"] + 0.11) / 0.05, 0, 1) * np.clip(N[..., 1], 0, 1)
    laces = ((0.5 + 0.5 * np.sin(P[..., 2] * 2 * np.pi * 90)) > 0.55) * lace_zone
    c = c * (1 - laces[..., None] * 0.9) + np.array([0.9, 0.9, 0.88])[None, None, :] * (laces[..., None] * 0.9)
    rough = 0.9 - sole * 0.25
    nrm = height_to_normal(np.clip(0.5 + (tw - 0.5) * 0.015 + sole * 0.06, 0, 1), 0.5)
    return np.clip(c, 0, 1), nrm, np.clip(rough, 0, 1)


def thobe(P, N, cov, size, landmarks, seed=8, style="embroidered", color=None):
    """Long dress / robe. style 'embroidered': black Palestinian thobe with red chest panel, side bands
    and hem rows; style 'plain': a plain workman's robe with a placket and cuffs (musahhir)."""
    base = np.array(color if color is not None else [0.07, 0.065, 0.08]); red = np.array([0.55, 0.11, 0.13]); gold = np.array([0.66, 0.5, 0.2])
    weave = fbm(size, 70, 2, seed + 7) * 0.5 + 0.5
    big = fbm(size, 5, 3, seed); folds = fbm(size, 10, 3, seed + 3)
    c = base[None, None, :] * (0.97 + (weave - 0.5) * 0.03 + big * 0.05 + folds * 0.05)[..., None]
    chest_y = landmarks["chest_y"]; hip_y = landmarks["hip_y"]
    front = np.clip(N[..., 2] * 1.5, 0, 1)
    stitched = np.zeros(P.shape[:2]); colr = np.broadcast_to(red[None, None, :], P.shape[:2] + (3,)).copy()
    if style == "embroidered":
        # qabbeh: chest panel of 3 cm diamonds, anti-aliased, alternating red / gold rows
        px = P[..., 0] / 0.03; py = (P[..., 1] - chest_y) / 0.03
        dia = np.abs(px % 1.0 - 0.5) + np.abs(py % 1.0 - 0.5)
        motif = smoothstep(0.5, 0.42, dia) * 0.9 + 0.12
        row = (np.floor(py) % 2.0 == 0)
        colr = np.where(row[..., None], red[None, None, :], gold[None, None, :])
        panel = smoothstep(0.09, 0.08, np.abs(P[..., 0])) * smoothstep(chest_y - 0.13, chest_y - 0.11, P[..., 1]) * smoothstep(chest_y + 0.08, chest_y + 0.06, P[..., 1]) * front
        stitched = panel * motif
        # hem: three rows of diamonds
        hy = (P[..., 1] - 0.05) / 0.025
        hem = smoothstep(0.045, 0.05, P[..., 1]) * smoothstep(0.13, 0.125, P[..., 1])
        hdia = np.abs((P[..., 0] / 0.025) % 1.0 - 0.5) + np.abs(hy % 1.0 - 0.5)
        hem_m = hem * (smoothstep(0.5, 0.42, hdia) * 0.9 + 0.1)
        stitched = np.maximum(stitched, hem_m); colr = np.where((hem_m > 0.05)[..., None], np.where((np.floor(hy) % 2.0 == 0)[..., None], red[None, None, :], gold[None, None, :]), colr)
        # cuffs
        cuff = smoothstep(landmarks["wrist_x"] - 0.085, landmarks["wrist_x"] - 0.075, np.abs(P[..., 0])) * smoothstep(landmarks["wrist_x"] - 0.015, landmarks["wrist_x"] - 0.025, np.abs(P[..., 0])) * (P[..., 1] > 1.0)
        stitched = np.maximum(stitched, cuff * 0.9); colr = np.where((cuff > 0.5)[..., None], red[None, None, :], colr)
    else:
        # plain robe: darker placket line down the chest and a slightly lighter collar band
        plk = smoothstep(0.006, 0.003, np.abs(P[..., 0])) * (P[..., 1] > chest_y - 0.25) * (P[..., 1] < chest_y + 0.12) * front
        c = c * (1 - plk * 0.35)[..., None]
        buttons = smoothstep(0.0045, 0.0025, np.sqrt(P[..., 0] ** 2 + (((P[..., 1] - chest_y) / 0.05 % 1.0) - 0.5) ** 2 * 0.05 ** 2)) * (P[..., 1] > chest_y - 0.22) * (P[..., 1] < chest_y + 0.1) * front
        c = c * (1 - buttons)[..., None] + np.array([0.75, 0.7, 0.6])[None, None, :] * buttons[..., None]
        cuff = smoothstep(landmarks["wrist_x"] - 0.07, landmarks["wrist_x"] - 0.06, np.abs(P[..., 0])) * (P[..., 1] > 1.0)
        c = c * (1 - cuff * 0.12)[..., None]
    c = c * (1 - stitched[..., None]) + colr * stitched[..., None] * (0.9 + weave * 0.2)[..., None]
    rough = 0.92 - stitched * 0.08 + big * 0.02
    nrm = height_to_normal(np.clip(0.5 + (weave - 0.5) * 0.01 + folds * 0.02 + stitched * 0.03, 0, 1), 0.4)
    alpha = collar_alpha(P, landmarks["neck_y"] + 0.025, size, seed)
    return np.clip(c, 0, 1), nrm, np.clip(rough, 0, 1), alpha


def scarf(P, N, cov, size, color=(0.93, 0.91, 0.86), seed=9):
    weave = fbm(size, 80, 2, seed + 7) * 0.5 + 0.5
    big = fbm(size, 5, 3, seed); folds = fbm(size, 11, 3, seed + 3)
    c = np.array(color)[None, None, :] * (0.97 + (weave - 0.5) * 0.02 + big * 0.04 + folds * 0.05)[..., None]
    # thin embroidered edge near the face opening: rows of small red dots at y ~ brow line are added on the mesh side via hairline alpha; here a faint lace pattern
    lace = ((hash_noise(size, 90, seed + 2) > 0.9) & (np.abs(fbm(size, 20, 2, seed + 3)) < 0.1)).astype(np.float64) * 0.0
    rough = 0.92 + big * 0.02
    nrm = height_to_normal(np.clip(0.5 + (weave - 0.5) * 0.01 + folds * 0.02, 0, 1), 0.4)
    return np.clip(c, 0, 1), nrm, np.clip(rough, 0, 1)


def hair_cap(P, N, cov, size, color, landmarks, seed=10, grey=0.0):
    strands = fbm(size, 120, 2, seed)
    flow = fbm(size, 30, 3, seed + 1)
    c = np.array(color)[None, None, :] * (0.8 + 0.4 * (strands * 0.5 + 0.5) + flow * 0.1)[..., None]
    if grey > 0:
        g = (hash_noise(size, 500, seed + 4) < grey).astype(np.float64)
        c = c * (1 - g[..., None]) + np.array([0.7, 0.68, 0.66])[None, None, :] * g[..., None]
    # alpha: fade at the hairline (front edge) using distance above the brow
    brow = landmarks["brow_y"]; head = landmarks["head"]
    ax = np.abs(P[..., 0] - head[0])
    h0 = brow + 0.03 + 0.022 * smoothstep(0.03, 0.065, ax) + fbm(size, 40, 2, seed + 6) * 0.006
    front_fade = smoothstep(h0, h0 + 0.022, P[..., 1])
    side_fade = smoothstep(landmarks["eye_y"] + 0.025, landmarks["eye_y"] + 0.05, P[..., 1])
    back = smoothstep(head[2] - 0.015, head[2] - 0.045, P[..., 2])
    alpha = np.maximum(front_fade, side_fade * back)
    alpha = np.clip(alpha + (strands > 0.3) * 0.08 - (strands < -0.35) * 0.08, 0, 1) * cov
    rough = 0.6 + strands * 0.08
    nrm = height_to_normal(np.clip(0.5 + strands * 0.03 + flow * 0.02, 0, 1), 0.6)
    return np.clip(c, 0, 1), nrm, np.clip(rough, 0, 1), alpha


def taqiyah(P, N, cov, size, color=(0.93, 0.92, 0.88), seed=12):
    """Crocheted white skull cap: fine open-work pattern at 1 cm, soft folds."""
    w = fbm(size, 90, 2, seed) * 0.5 + 0.5; big = fbm(size, 6, 3, seed + 1)
    c = np.array(color)[None, None, :] * (0.95 + (w - 0.5) * 0.06 + big * 0.04)[..., None]
    rough = 0.95 + big * 0.02
    nrm = height_to_normal(np.clip(0.5 + (w - 0.5) * 0.015, 0, 1), 0.4)
    return np.clip(c, 0, 1), nrm, np.clip(rough, 0, 1)
