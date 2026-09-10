# Ashenwake

Godot **4.7.2** arena fighter (5vBoss, League-style controls). Daily work is a **local Windows or laptop clone**. GitHub is the only remote you need.

Repo: [https://github.com/carlostovar1995/ashenwake](https://github.com/carlostovar1995/ashenwake)

Home PC folder: `C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake`

## What you need

- Git for Windows and a GitHub login (`gh auth login` or Git Credential Manager).
- Godot **4.7.2** (same as `.godot-version`).
- Cursor on the machine you are editing on.

## Home PC

1. Open `C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake` in Cursor and in Godot.
2. Verify, edit, and playtest here.
3. When you are done:

```powershell
cd C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake
git add -A
git commit -m "Describe the session"
git push origin main
```

Or double-click **Sync Ashenwake** on the desktop (pull, commit if dirty, push).

Install or refresh that icon from PowerShell:

```powershell
cd C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\install-desktop-shortcut.ps1
```

## Verification

Godot **4.7.2** is the exact project version (`.godot-version`: `4.7.2-stable`). From PowerShell, use the Windows verifier as the canonical automated check before and after substantive changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Verify-Ashenwake.ps1
```

It is the single entry point for version consistency, import, script/resource validation, CI sanity, and smoke coverage. A successful headless run does not replace a local editor playtest.

Combat, targeting, VFX, and HUD hot-path changes also require the manual 60-dummy stress scenario with overlapping ground AoEs, lightning, walls/projectiles, HUD, and damage numbers active. Require unchanged behavior, stable object counts, and equal-or-better frame/script time; optimize from profiler evidence, not suspicion.

## Project conventions

- Runtime assets belong in `assets/` type roots: `ui/`, `audio/sfx/`, `textures/arena/`, `anims/`, `models/`, and `vfx/`. Do not add vendor-named roots.
- Keep only Godot-ready runtime formats for characters and outfits. Current model roots are `models/characters/humanoid_boss/`, `models/outfits/fantasy/`, `models/props/fantasy/` (decorative meshes), and `models/props/collision/` (StaticBody cover/colliders). Reusable decorative props are retained even when they are not placed yet. Each destination under `scenes/arena/layouts/` is a standalone room.
- Keep VFX source resources only when they are reachable from a runtime effect. Vendor demo scenes, alternate export formats, and unused effect variants do not belong in the runtime tree.
- `_incoming/` is non-runtime staging. Promote selected files into a canonical root and update references; remove promoted duplicates. Keep `_incoming/audio/` only as conversion source for `tools/convert_sfx.py`, and do not ignore or delete that source tree wholesale.
- Fragile-core extractions must preserve behavior and proceed one typed boundary at a time. See `AGENTS.md` and the scoped rules in `.cursor/rules/` before changing `Unit`, HUD, `SpellWall`, spell compilation, combat balance/threat, or the order queue.

## Laptop

```powershell
git clone https://github.com/carlostovar1995/ashenwake.git
```

Open the cloned folder in Cursor and Godot. `git pull` / `git push` against the same GitHub repo.

## Do not

- Commit `.godot/` or export binaries.

## License

Private project. All rights reserved unless you add a license.
