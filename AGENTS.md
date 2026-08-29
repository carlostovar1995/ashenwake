# Agent notes — Boss Fighter (game-sync)

This repository is **Boss Fighter**, a Godot 4.7 GDScript 5vBoss game with League-style controls, plus a Cursor Cloud Agent kit. Playtest in the Godot editor on the Windows home PC. Cloud Agents, the laptop, and the phone work from this Origin remote.

## Layout

- `project.godot` — Boss Fighter (Godot 4.7, Forward Plus).
- `scenes/`, `scripts/` — arena, units, combat, UI, input.
- `tools/ci_check.gd` — tiny headless sanity print. `tools/smoke_test.gd` — spawn/match smoke test (needs a successful import).
- `.godot-version` — pinned editor tag (default `4.7-stable`). Must match the home PC editor.
- `.cursor/environment.json` — Cloud Agent image + install.
- `scripts/cloud-agent-install.sh` — download Godot Linux editor, symlink `godot`, `godot --headless --import`.
- `scripts/verify-headless.sh` — import + script check. Run this after gameplay edits.
- `scripts/setup-origin.sh` / `scripts/ensure-origin-path.sh` — WSL Origin CLI + PATH. `scripts/setup-windows.ps1` jumps from PowerShell into WSL.
- `scripts/import-local-godot.sh` — copy a Windows/WSL Godot project into this repo without dropping the kit. Use `--push` to commit and push.

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
- On Windows, never pipe Origin `install.sh` to `sh` in PowerShell. Use WSL or `scripts/setup-windows.ps1`. After install, put `~/.local/bin` on PATH (`scripts/ensure-origin-path.sh`).

## Replacing the local Windows copy

The Origin repo is the source of truth. On the home PC, open `~/game-sync` (or `\\wsl$\Ubuntu\home\carlo\game-sync`) in Godot — not only the old OneDrive `Boss Game` folder — so edits can be pulled and pushed. Keep `.cursor/`, the `scripts/*.sh` kit, `AGENTS.md`, `.godot-version`, and `tools/ci_check.gd`.
