#!/bin/sh
# Linux/macOS: join the parts and verify
cat Talaa-apk.part1 Talaa-apk.part2 Talaa-apk.part3 Talaa-apk.part4 Talaa-apk.part5 > Talaa.apk && echo '1c919c1e4486b8bc5bcc9fb9badb4d1635f8e91640b02527e8b645b20d8a5719  Talaa.apk' | sha256sum -c
