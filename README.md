# طَلْعة · TAL'A 2.0

لعبة تسلّق عمودية بروح *Only Up*: طريق واحد لفوق، بلا نقاط حفظ، وكل سقطة بترجّعك لتحت. سليم بيطلع من سطح دار ستّي، أول ليلة برمضان، ليعلّق فانوسها على الهلال.

A vertical climbing game in the spirit of *Only Up*: one route up, no checkpoints, and every fall takes you back down. Salim climbs from his late grandmother's rooftop on the first night of Ramadan to hang her lantern on the crescent.

## What changed in 2.0

- **Realistic characters.** Salim, his grandmother, Salim as a child and the musahharati are built from the MakeHuman base mesh (CC0) with a Mixamo-style 52-bone skeleton, painted skin (pores, eyebrows, stubble, wrinkles, age spots), cloth with proper collars and hems, hair, headscarf and skull cap. 21 hand-authored animation clips (idle, walk, run, sprint, jump, fall, landings, stun and get-up, hang, mantle, sitting, lying, cheer, pick-up, balance, zip, look-up, grief).
- **Realistic rendering.** Physically based sky (Rayleigh/Mie scattering, moon with phase, stars), a 20-family PBR texture library (albedo, roughness, normal, height, wear masks) shared through texture arrays, triplanar surface shaders, colour grading, and every kit prop rebuilt procedurally inside its original footprint so the route is unchanged.
- **Only Up difficulty by default.** Assists off, checkpoints off, heavier landings (stun scales with the fall, the colour drains from the world), vertigo camera on narrow ledges.
- **نَفَس / Breath.** Hold `F` (gamepad X, or the wave button on touch) to slow the world for two seconds while airborne or moving; the meter refills only on solid ground.
- **Rewritten story.** A grief-centred script in Levantine Arabic: the prologue on the roof, five memories of the grandmother, her unanswered messages found along the way, Salim's own thoughts on the benches, the musahharati, and the ending at the crescent.

## Installing on Android

Download every `Talaa-apk.part*` file and `INSTALL_Android.bat` from `release/`, put them in one folder and run the `.bat` (on Linux or macOS run `join.sh`). It joins the parts into `Talaa.apk`, checks the SHA-256, and you then copy the APK to the phone and tap it.

**Uninstall TAL'A 1.5 first.** Version 2.0 is signed with a new key, so Android will not install it over the old package. It is a new story with a new save; nothing from 1.5 carries over.

## Repository layout

| Path | Contents |
| --- | --- |
| `game/` | Godot 4.7 project (open `project.godot`) |
| `tools/charpipe/` | Character pipeline: MakeHuman mesh + rig → textured, rigged, animated GLB |
| `tools/texgen/` | Procedural PBR texture library generator |
| `release/` | Android build split into parts plus the Windows joiner script |

## Building

Open `game/` in Godot 4.7.2 (Forward+). For Android, the export preset in `game/export_presets.cfg` (ignored by git) needs the Android export templates, a keystore and the SDK tools.

The characters are regenerated with:

```
python3 tools/charpipe/character.py salim /tmp/out --anims
```

which expects the MakeHuman data (`MH_DATA`) and the MPFB2 rig data (`MPFB_DATA`) to be available locally.

## Credits

Base body mesh, targets and eye assets: MakeHuman (CC0). Rig definition and weights: MPFB2 (CC0 data). Everything else, textures, animations, props, shaders and story, is generated or written in this repository.
