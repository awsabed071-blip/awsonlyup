"""Minimal GLB writer: skinned meshes with several primitives/materials, PNG textures,
animations (rotation/translation samplers). Pure python + numpy."""
import json, struct, io
import numpy as np
from PIL import Image


class GLB:
    def __init__(self):
        self.buf = bytearray()
        self.views = []; self.accessors = []; self.images = []; self.textures = []; self.samplers = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
        self.materials = []; self.meshes = []; self.nodes = []; self.skins = []; self.animations = []
        self.scene_nodes = []

    def _pad(self, n=4):
        while len(self.buf) % n:
            self.buf.append(0)

    def add_view(self, data: bytes, target=None):
        self._pad(4)
        off = len(self.buf); self.buf.extend(data)
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        self.views.append(v); return len(self.views) - 1

    def add_accessor(self, arr, ctype, atype, target=None, minmax=False):
        arr = np.ascontiguousarray(arr)
        vi = self.add_view(arr.tobytes(), target)
        a = {"bufferView": vi, "componentType": ctype, "count": int(arr.shape[0]), "type": atype}
        if minmax:
            a["min"] = [float(x) for x in np.min(arr, axis=0).ravel()]
            a["max"] = [float(x) for x in np.max(arr, axis=0).ravel()]
        self.accessors.append(a); return len(self.accessors) - 1

    def add_image_png(self, img: Image.Image, name="tex"):
        bio = io.BytesIO(); img.save(bio, format="PNG", optimize=False, compress_level=6)
        vi = self.add_view(bio.getvalue())
        self.images.append({"bufferView": vi, "mimeType": "image/png", "name": name})
        self.textures.append({"source": len(self.images) - 1, "sampler": 0})
        return len(self.textures) - 1

    def add_material(self, name, base_color=(1, 1, 1, 1), base_tex=None, normal_tex=None, mr_tex=None,
                     metallic=0.0, roughness=0.8, alpha_mode=None, double_sided=False, emissive=None, normal_scale=1.0):
        m = {"name": name, "pbrMetallicRoughness": {"baseColorFactor": list(base_color), "metallicFactor": metallic, "roughnessFactor": roughness}}
        if base_tex is not None:
            m["pbrMetallicRoughness"]["baseColorTexture"] = {"index": base_tex}
        if mr_tex is not None:
            m["pbrMetallicRoughness"]["metallicRoughnessTexture"] = {"index": mr_tex}
        if normal_tex is not None:
            m["normalTexture"] = {"index": normal_tex, "scale": normal_scale}
        if alpha_mode:
            m["alphaMode"] = alpha_mode
            if alpha_mode == "MASK":
                m["alphaCutoff"] = 0.5
        if double_sided:
            m["doubleSided"] = True
        if emissive is not None:
            m["emissiveFactor"] = list(emissive)
        self.materials.append(m); return len(self.materials) - 1

    def add_primitive_data(self, pos, nrm, uv, idx, joints=None, weights=None, material=0, uv2=None):
        attrs = {"POSITION": self.add_accessor(pos.astype(np.float32), 5126, "VEC3", 34962, minmax=True),
                 "NORMAL": self.add_accessor(nrm.astype(np.float32), 5126, "VEC3", 34962),
                 "TEXCOORD_0": self.add_accessor(uv.astype(np.float32), 5126, "VEC2", 34962)}
        if uv2 is not None:
            attrs["TEXCOORD_1"] = self.add_accessor(uv2.astype(np.float32), 5126, "VEC2", 34962)
        if joints is not None:
            attrs["JOINTS_0"] = self.add_accessor(joints.astype(np.uint16), 5123, "VEC4", 34962)
            attrs["WEIGHTS_0"] = self.add_accessor(weights.astype(np.float32), 5126, "VEC4", 34962)
        ia = self.add_accessor(idx.astype(np.uint32).reshape(-1), 5125, "SCALAR", 34963)
        return {"attributes": attrs, "indices": ia, "material": material, "mode": 4}

    def add_mesh(self, name, prims):
        self.meshes.append({"name": name, "primitives": prims}); return len(self.meshes) - 1

    def add_node(self, name, translation=None, rotation=None, scale=None, mesh=None, skin=None, children=None):
        n = {"name": name}
        if translation is not None: n["translation"] = [float(x) for x in translation]
        if rotation is not None: n["rotation"] = [float(x) for x in rotation]
        if scale is not None: n["scale"] = [float(x) for x in scale]
        if mesh is not None: n["mesh"] = mesh
        if skin is not None: n["skin"] = skin
        if children: n["children"] = list(children)
        self.nodes.append(n); return len(self.nodes) - 1

    def add_skin(self, name, joint_nodes, inverse_bind, skeleton_root=None):
        ibm = np.array(inverse_bind, dtype=np.float32)  # (J,4,4) row-major numpy -> glTF column-major
        ibm_col = np.ascontiguousarray(np.transpose(ibm, (0, 2, 1))).reshape(len(joint_nodes), 16)
        acc = self.add_accessor(ibm_col.astype(np.float32), 5126, "MAT4")
        s = {"name": name, "joints": list(joint_nodes), "inverseBindMatrices": acc}
        if skeleton_root is not None:
            s["skeleton"] = skeleton_root
        self.skins.append(s); return len(self.skins) - 1

    def add_animation(self, name, tracks):
        """tracks: list of (node_index, path, times(np), values(np))"""
        samplers = []; channels = []
        for node, path, times, values in tracks:
            ti = self.add_accessor(np.asarray(times, dtype=np.float32).reshape(-1), 5126, "SCALAR", minmax=True)
            vals = np.asarray(values, dtype=np.float32)
            vo = self.add_accessor(vals, 5126, "VEC4" if path == "rotation" else "VEC3")
            samplers.append({"input": ti, "output": vo, "interpolation": "LINEAR"})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": path}})
        self.animations.append({"name": name, "samplers": samplers, "channels": channels})

    def save(self, path):
        self._pad(4)
        j = {"asset": {"version": "2.0", "generator": "talaa-charpipe"}, "scene": 0, "scenes": [{"nodes": self.scene_nodes}],
             "nodes": self.nodes, "meshes": self.meshes, "buffers": [{"byteLength": len(self.buf)}], "bufferViews": self.views,
             "accessors": self.accessors}
        if self.materials: j["materials"] = self.materials
        if self.images: j["images"] = self.images; j["textures"] = self.textures; j["samplers"] = self.samplers
        if self.skins: j["skins"] = self.skins
        if self.animations: j["animations"] = self.animations
        js = json.dumps(j, separators=(",", ":")).encode("utf-8")
        while len(js) % 4:
            js += b" "
        total = 12 + 8 + len(js) + 8 + len(self.buf)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
            f.write(struct.pack("<II", len(self.buf), 0x004E4942)); f.write(bytes(self.buf))


def compute_normals(pos, tris):
    n = np.zeros_like(pos)
    a = pos[tris[:, 0]]; b = pos[tris[:, 1]]; c = pos[tris[:, 2]]
    fn = np.cross(b - a, c - a)
    for k in range(3):
        np.add.at(n, tris[:, k], fn)
    l = np.linalg.norm(n, axis=1); l[l < 1e-12] = 1.0
    return n / l[:, None]
