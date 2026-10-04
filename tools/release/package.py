#!/usr/bin/env python3
"""Split a signed APK into parts small enough for a web upload and write the Windows joiner script.

usage: package.py <Talaa.apk> <out_dir> [part_mb]
"""
import hashlib, os, sys

apk = sys.argv[1]
out = sys.argv[2]
part_mb = float(sys.argv[3]) if len(sys.argv) > 3 else 24.0
os.makedirs(out, exist_ok=True)
for f in os.listdir(out):
    if f.startswith("Talaa-apk.part") or f == "INSTALL_Android.bat":
        os.remove(os.path.join(out, f))
data = open(apk, "rb").read()
sha = hashlib.sha256(data).hexdigest()
size = int(part_mb * 1024 * 1024)
n = (len(data) + size - 1) // size
for i in range(n):
    open(os.path.join(out, f"Talaa-apk.part{i + 1}"), "wb").write(data[i * size:(i + 1) * size])
tpl = open(os.path.join(os.path.dirname(__file__), "..", "..", "release", "INSTALL_Android.bat.template"), encoding="utf-8").read()
checks = "\n".join(f"if not exist Talaa-apk.part{i + 1} goto missing" for i in range(n))
join = " + ".join(f"Talaa-apk.part{i + 1}" for i in range(n))
bat = tpl.replace("__NPARTS__", str(n)).replace("__CHECKS__", checks).replace("__JOIN__", join).replace("__SHA__", sha)
# batch files want CRLF
open(os.path.join(out, "INSTALL_Android.bat"), "wb").write(bat.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))
sh = os.path.join(out, "join.sh")
open(sh, "w").write("#!/bin/sh\n# Linux/macOS: join the parts and verify\ncat " + " ".join(f"Talaa-apk.part{i + 1}" for i in range(n)) +
                    f" > Talaa.apk && echo '{sha}  Talaa.apk' | sha256sum -c\n")
os.chmod(sh, 0o755)
print(f"{n} parts, sha256 {sha}, {len(data) / 1e6:.1f} MB")
