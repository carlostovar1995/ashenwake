# Agent notes — Ashenwake

Ashenwake is a Godot **4.7.2** GDScript 5vBoss game with League-style controls (`.godot-version`: `4.7.2-stable`). Work in `C:\Users\carlo\OneDrive\Desktop\Projects\Ashenwake`; GitHub is the only daily remote: `https://github.com/carlostovar1995/ashenwake.git`.

## Daily workflow

1. Open this Windows checkout in Cursor and Godot.
2. Before and after substantive work, run the canonical verifier:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\windows\Verify-Ashenwake.ps1
```

1. Playtest in the local Godot editor; Cloud/headless runs are not playtests.
2. End a requested shipping session with `git add -A`, commit, and `git push origin main`, or use **Sync Ashenwake**. Do not commit/push unless the user asks.
3. After shipped gameplay or player-visible design changes, append the matching note to Carlos's OneNote storyboard with `scripts/windows/Update-AshenwakeOneNote.ps1`.



## Acceptance gates

- Combat, targeting, VFX, or HUD hot-path changes require the manual 60-dummy stress gate with overlapping ground AoEs, lightning, walls/projectiles, HUD, and damage numbers active. Behavior must remain unchanged, object counts stable, and frame/script time equal or better.
- Treat `scripts/units/unit.gd`, `scripts/ui/hud.gd`, `scripts/combat/spell_wall.gd`, spell compilation, `CombatBalance`, `ThreatTable`, and the controller order queue as fragile core. Extract only through `.cursor/rules/cleanup-protocol.mdc`.



## Detailed rules

- `.cursor/rules/gdscript-style.mdc` — typed APIs, ownership, diagnostics.
- `.cursor/rules/scene-assets.mdc` — canonical asset roots, staging, UID/import policy.
- `.cursor/rules/cleanup-protocol.mdc` — deletion proof and safe extraction order.
- `.cursor/rules/hot-path-performance.mdc` — bounded, evidence-driven combat/VFX/HUD architecture.
- `.cursor/rules/godot.mdc` — Godot 4.7.2 project conventions.
- `.cursor/rules/windows-origin.mdc` and `.cursor/rules/onenote-notes.mdc` — Windows/GitHub and storyboard workflow.
- `.cursor/rules/talent-trees.mdc` — spec talent-tree protocol (QWER crafted, D/F from trees, 2 spec slots, 50 shared points, WoW-style tiers). Plan with `/plan-class` or “plan a tank spec”; skill in `.cursor/skills/plan-class/`. Locked specs in `docs/specs/`; system in `docs/talents/system.md`.

Never commit `.godot/`, credentials, local exports, or transient staging. Keep text `.tscn`/`.tres`, preserve valid UIDs, and do not bump Godot without updating the pin, project feature family, docs, and verifier together.