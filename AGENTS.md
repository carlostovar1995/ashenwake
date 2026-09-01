# Agent notes — Ashenwake

This repository is **Ashenwake**, a Godot 4.7 GDScript 5vBoss game with League-style controls. The daily working copy lives on Windows. GitHub is the only daily remote. Playtest in the Godot editor on the home PC or laptop.

Home PC path: `C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake`  
GitHub: `https://github.com/carlostovar1995/ashenwake`

## Layout

- `project.godot` — Ashenwake (Godot 4.7, Forward Plus).
- `scenes/`, `scripts/` — arena, units, combat, UI, input.
- `tools/ci_check.gd` — tiny headless sanity print. `tools/smoke_test.gd` — spawn/match smoke test (needs a successful import).
- `.godot-version` — pinned editor tag (default `4.7-stable`). Must match the local editor.
- `.cursor/environment.json` — optional Cloud Agent image + install (unused in the daily loop).
- `scripts/cloud-agent-install.sh` / `scripts/verify-headless.sh` — Linux/headless helpers. Leave them; do not use them for the Windows daily loop.
- `VERSION` — SemVer `MAJOR.MINOR.PATCH`. Git tags are `vMAJOR.MINOR.PATCH`.
- `scripts/windows/Sync-Ashenwake.ps1` — pull, optional commit, push GitHub.
- `scripts/windows/install-desktop-shortcut.ps1` — puts **Sync Ashenwake** on the Windows desktop.

## Commands

On Windows (PowerShell), from the Ashenwake folder:

```powershell
git pull origin main
git add -A
git commit -m "Your message"
git push origin main
```

Or double-click **Sync Ashenwake** on the desktop.

## How to work

1. Open this folder in Cursor and in the Godot editor — not `\\wsl$\...` and not `~/game-sync`.
2. Edit GDScript and scenes here.
3. When the session is done: commit and `git push origin` (GitHub).
4. On the laptop: `git pull` in a local clone of `carlostovar1995/ashenwake`, then open that folder in Cursor/Godot.
5. Do not treat Cloud Agent “run the game” as playtesting.
6. After a shipped gameplay or design change, update Carlos's OneNote storyboard (`Onenote.url`, helper `scripts/windows/Update-AshenwakeOneNote.ps1`).
7. Combat / VFX / HUD changes follow `.cursor/rules/hot-path-performance.mdc`: pool and prune, share materials, spatial queries, batch/time-slice ticks, throttle HUD. The stress bar is 60 dummies + overlapping ground AoEs staying smooth with lightning and damage numbers on.

## Do not

- Commit `.godot/`, `export_credentials.cfg`, or local export binaries.
- Rewrite `.uid` files or binary-ize `.tscn` without a reason.
- Send daily git through WSL or Origin. Those are leftover kit, not the workflow.
- Bump Godot casually. If you must, change `.godot-version` and `config/features` in `project.godot` in the same change.
- Put a second live checkout on Ubuntu and edit both. The Ubuntu `~/game-sync` folder is stale.
- Add per-hit `new()`/`queue_free()`, unique `ShaderMaterial`s, per-instance `_process`, or linear `ArenaState.units` scans on combat/VFX/HUD hot paths. See `.cursor/rules/hot-path-performance.mdc`.
