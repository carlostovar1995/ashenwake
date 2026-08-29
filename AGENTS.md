# Agent notes — Godot game-sync

This repository is a **Godot 4 GDScript** game plus a Cursor Cloud Agent kit. The Windows home PC is the place to playtest in the Godot editor. Cloud Agents, the laptop, and the phone work from this Origin remote.

## Layout

- `project.godot` — Godot project (replace the placeholder with the real game; keep this file at the repo root).
- `scenes/`, `scripts/` — game content.
- `tools/` — headless CI scripts (`ci_check.gd`).
- `.godot-version` — pinned editor tag (default `4.7-stable`). Must match the home PC editor.
- `.cursor/environment.json` — Cloud Agent image + install.
- `scripts/cloud-agent-install.sh` — download Godot Linux editor, symlink `godot`, `godot --headless --import`.
- `scripts/verify-headless.sh` — import + script check. Run this after gameplay edits.

## Commands

```bash
./scripts/cloud-agent-install.sh    # idempotent; safe to re-run
./scripts/verify-headless.sh        # import + tools/ci_check.gd
godot --headless --path . --import  # import only
```

`godot` is on `PATH` after install (`/usr/local/bin/godot` or `~/.local/bin/godot`).

## How to work

1. Edit GDScript and scenes in this checkout.
2. Run `./scripts/verify-headless.sh`. Do not skip import after adding resources.
3. Open a PR. The home PC pulls and playtests in the Godot editor.
4. Do not treat Cloud Agent “run the game” as playtesting: VMs are Linux, usually without a GPU. Headless import and `--check-only` are the verification bar here.

## Do not

- Commit `.godot/`, `export_credentials.cfg`, or local export binaries.
- Rewrite `.uid` files or binary-ize `.tscn` without a reason.
- Assume the Godot editor GUI or a Godot MCP plugin is available in the cloud. Those are home-PC only.
- Bump Godot casually. If you must, change `.godot-version` and `config/features` in `project.godot` in the same change.

## Replacing the placeholder

The shipped `scenes/main.tscn` is a stub so Cloud Agents can import before the real game is copied in. On the home PC, copy the existing Godot project over this tree **without** deleting `.cursor/`, `scripts/cloud-agent-install.sh`, `scripts/verify-headless.sh`, `AGENTS.md`, `.godot-version`, or `tools/ci_check.gd`. Keep `project.godot` at the repository root. Set `.godot-version` to the same tag the home editor uses (for example `4.4.1-stable` or `4.7-stable`).
