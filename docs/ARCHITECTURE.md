# Ashenwake Architecture (as of 2026-10-01)

A description of what exists today. It contains no proposals. It was compiled from three read-only audits (combat, HUD/UI, assets/VFX) using grep/glob-level inspection. Figures are approximate, and items marked *(unverified)* were not confirmed by reading code.

## 1. Overview

Godot 4.7.2 GDScript project: a 5-player-vs-boss game with League-style controls. Roughly 124 game `.gd` files (about 46k lines under `scripts/`, excluding `addons/` and `.godot/`) and 102 `.tscn` files. Almost all gameplay is code-driven. The only UI scene is `scenes/ui/hud.tscn`, and the HUD is built mostly in code. Code is overwhelmingly typed. Folders under `scripts/` (and one under `assets/`):

| Folder | Role |
|---|---|
| `scripts/combat` (10) | `ability`, `auto_attack`, `enemy_rank`, `judgment_beam`, `pillar_shot`, `projectile`, `spell_wall`, `spell_wall_layout`, `status_reactions`, `telegraph` |
| `scripts/spells` (11) | `spell_catalog`, `spell_compiler`, `spell_card`, `spell_recipe`, `spell_infusion`, `spell_augment`, `spell_power`, `spell_tags`, `spell_base`, `caster_profile`, `combat_balance` |
| `scripts/units` (10) | `unit`, `unit_controller`, `movement`, `unit_altered*`, `unit_wind*`, `unit_illusion`, `unit_enemy_alter`, `unit_status_snapshots` |
| `scripts/ai` (6) | `add_ai`, `ally_ai`, `boss_ai`, `dawnwarden_ai`, `dummy_chase`, `dummy_shooter` |
| `scripts/talents` (18) | `talent_combat`, `class_catalog`, `talent_hooks`, `talent_spend`, `class_skill_runtime`, … |
| `scripts/autoload` (5) | `game_session`, `arena_state`, `combat_meter`, `threat_table`, `audio_manager` |
| `scripts/ui` (9) | `hud`, `hud_refresh_scheduler`, `spell_workshop`, `status_icons`, `talent_pane`, `enemy_nameplate`, `spell_socket`, `spell_piece_chip`, `spell_hotkey_slot` |
| `scripts/visual` (29 gd, 16 gdshader) | per-spell `*_fx.gd`, `ability_fx`, `character_visual`, `damage_number`, `damage_number_runner`, `world_ui_mesh` |
| `assets/vfx` | 90 tscn, 46 tres, 20 gdshader, 5 gdshaderinc, 9 gd, plus meshes and textures |

There is no `scripts/status` or `scripts/threat` folder. Status logic is split across `status_reactions.gd`, `unit_status_snapshots.gd`, `status_icons.gd` (UI) and `unit.gd`. Threat is the `ThreatTable` autoload.

## 2. Autoloads and global state

`project.godot` registers six autoloads: `GameSession`, `ArenaState`, `CombatMeter`, `ThreatTable`, `AudioManager`, and `MCPRuntime` (MCP addon).

- Global state is read directly by bare name. Nothing is injected.
- `hud.gd` references the first five about 124 times. `spell_workshop.gd` does so 42 times and `talent_pane.gd` 12 times.
- `ThreatTable` is referenced about 25 times across `ai/*`, `arena.gd`, `caster_profile.gd`, `talent_combat.gd` and `enemy_nameplate.gd`.
- 17 scripts in `scripts/visual` reference these autoloads. There is no dedicated VFX autoload.
- `UnitController` holds the order state (`order: Order`, `unit_controller.gd:12`, queued-cast fields `:22-24`, `_clear_cast_queue` `:93`).

## 3. Combat, spells, status, threat

- **Hub:** `unit.gd` (5,957 lines) owns unit state, status, altered/wind/illusion state, cooldowns and abilities. Helpers (`unit_altered*`, `unit_wind*`, `unit_status_snapshots`) were split out, but `unit.gd` remains the largest file in the project.
- **Spell pipeline:** `spell_catalog` (1,257 lines) defines spells. `spell_compiler` (683) and `spell_card` (750) compile and represent them. `combat_balance` (616) holds tuning, and `spell_power`, `spell_tags` and `spell_infusion` modify results.
- **Runtime objects:** `projectile` (853), `spell_wall` (2,118), `telegraph` (989) and `judgment_beam` (454).
- **Threat:** `threat_table.gd` (482) is an autoload that AI, UI and talents read from directly.
- **AI:** all six AI scripts define their own `_physics_process`. Their bodies were not diffed.
- **Talents:** `talent_combat` (1,328), `class_catalog` (484), `talent_hooks` (414), `talent_spend` (413) and `class_skill_runtime` (356).

## 4. HUD, UI, damage numbers

- `hud.gd` (4,319 lines, 202 funcs, all typed) builds nearly everything in code. It has about 91 `.new()` Label/Panel/StyleBox/Control calls. The bar builders are `_make_flat_bar` `:751`, `_make_fill_bar` `:806`, `_make_resource_bar` `:831` and `_make_bar_slot` `:884`.
- It owns boss and player frames, the ability bar, cast bars, status icons, tooltips (5 hover flags at `:192-204`), edit-mode drag, the balance menu, the combat meter and the FPS readout.
- `hud.gd` declares no signals. It has about 36 signal or `.connect(` lines, mostly to `ArenaState`, and it polls autoload state (`ArenaState.boss`, `GameSession.active_unit`) on refresh. `hud_refresh_scheduler.gd` throttles structural refresh work.
- **Damage numbers:** `damage_number.gd` (1,324 lines) uses a static pool and index (`_acquire_number` `:148/:186`, `_pool.pop_back` `:221`). It also builds a `ShaderMaterial` at `:1127`. `damage_number_runner.gd` ticks a Callable at 60 Hz.
- **Other UI:** `spell_workshop` (1,127), `status_icons` (779, 41 static funcs), `talent_pane` (440) and `enemy_nameplate` (313).

## 5. Assets, VFX, shaders

- **Layout:** `assets/vfx/bases/{bolt,meteor,missiles,wave}` has one `.tscn` each. `assets/vfx/infusions/{divine,fire,ice,illusion,lightning,nature,protection,shadow,wind}` has 8 `.tscn` each (4 bases × body/persist) with no scripts. Other folders are `beams`, `common`, `elemental`, `explosion` and `projectiles`. Overall assets include about 582 png, 99 gltf with 99 bin, 21 fbx and 14 ogg.
- **Dispatch:** `ability_fx.gd` (618) is the central VFX dispatcher. It preloads 7 packs by hardcoded path (`:12-18`). `solar_collapse_fx.gd:4` and `spell_ray_fx.gd:8` do the same. Outside `scripts/visual`, `arena_pillar.gd:6-7`, `pillar_shot.gd:8` and `telegraph.gd:6-7` also hardcode VFX asset paths.
- **Wiring:** there is no spell-to-VFX signal bus. Wiring uses `create_timer` and tree signals (`ability_fx.gd:228,311-312,370`, `solar_collapse_fx.gd:51`, `solar_wash_fx.gd:28`, `fx_hero_lights.gd:137`). `character_visual.gd:403` `play_spell_load` takes an `AbilityDef` directly.

## 6. Scripts over 300 lines

| Lines | File |
|---|---|
| 5957 | `scripts/units/unit.gd` |
| 4319 | `scripts/ui/hud.gd` |
| 2118 | `scripts/combat/spell_wall.gd` |
| 1679 | `scripts/arena/arena.gd` |
| 1328 | `scripts/talents/talent_combat.gd` |
| 1324 | `scripts/visual/damage_number.gd` |
| 1257 | `scripts/spells/spell_catalog.gd` |
| 1127 | `scripts/ui/spell_workshop.gd` |
| 1074 | `scripts/units/unit_controller.gd` |
| 1061 | `scripts/player_input.gd` |
| 1031 | `scripts/visual/character_visual.gd` |
| 989 | `scripts/combat/telegraph.gd` |
| 853 | `scripts/combat/projectile.gd` |
| 830 | `scripts/ai/ally_ai.gd` |
| 779 | `scripts/ui/status_icons.gd` |
| 750 / 683 / 618 / 616 | `spell_card`, `spell_compiler`, `ability_fx`, `combat_balance` |
| 567 / 529 / 484 / 482 | `solar_collapse_fx`, `game_session`, `class_catalog`, `threat_table` |
| 454–440 | `judgment_beam`, `audio_manager`, `combat_meter`, `thunder_wave_fx`, `talent_pane` |
| 414–304 | `talent_hooks`, `talent_spend`, `spell_tags`, `spell_wall_layout`, `dawnwarden_ai`, `class_skill_runtime`, `ice_blast_fx`, `spell_power`, `movement`, `enemy_nameplate`, `VFXElementalProjectileBB.gd` |

Less prominent files are listed by basename. `player_input.gd` and `arena.gd` were reported only in passing.

## 7. Signal and coupling hot spots

- **Signal-count outliers** (from grep, so they may include non-declarations): `hud.gd` 107, `ally_ai.gd` 49, `spell_workshop.gd` 42, `arena.gd` 33, `unit.gd` 30, `player_input.gd` 25, `talent_combat.gd` 24 and `spell_wall.gd` 23. `hud.gd` is also reported as declaring 0 signals, so that count most likely reflects connects.
- **Autoload reach-through:** AI, talents, HUD and visuals all call `ThreatTable`, `CombatMeter`, `ArenaState` and `GameSession` directly.
- **Hardcoded asset paths** in combat and arena scripts (see section 5).
- **Hubs:** `unit.gd` for state and `hud.gd` for presentation.

## 8. Duplicated logic

- **Tooltips in `hud.gd`:** six `_place_*_tip` functions (ability, passive, player buff, boss status, target status, status) dispatched through an if/elif chain (`:192-204`).
- **Tooltip follow:** near-identical follow-and-clamp-to-viewport `_process` code in `talent_pane.gd:410-425` and `spell_workshop.gd:1107-1127`.
- **HP/label formatting:** boss and player formatting is repeated in `_refresh_combat` (`hud.gd:325+`).
- **AI:** six separate `_physics_process` implementations *(not diffed)*.
- **FX scripts:** the `*_fx.gd` pattern repeats across spells *(not diffed)*.
- **Infusion scenes:** 9 elements share one 8-file template. The files are not byte-identical (`fire/bolt_body.tscn` has 132 lines and `ice/bolt_body.tscn` has 61, with a 181-line diff), so the structure diverges per element.

## 9. Untyped code

- **`scripts/` as a whole:** very low. In combat/spells/units/autoload there are about 36 untyped `var x =` locals against about 2,656 typed or inferred. All 1,304 funcs in that scope have return types. The untyped locals mostly come from Dictionary `.get()` or Array reads (`projectile.gd:77,106,109,112`, `judgment_beam.gd:319`, `ability.gd:142`).
- **`hud.gd`:** 0 untyped vars.
- **`damage_number.gd`:** the main exception, with about 20 untyped `var` and untyped params (`:113,131,136,244,251,313`).
- **`spell_workshop.gd`:** 1 untyped var.
- **`scripts/visual`:** about 31 untyped hits in total.

## 10. Per-frame allocations and node lookups

- **Process hooks:** combat has `projectile.gd:231`, `spell_wall.gd:249`, `telegraph.gd:702`, `judgment_beam.gd:254/260`, `pillar_shot.gd:160`, `unit.gd:560/619`, `arena_state.gd:296` and `combat_meter.gd:21`. There are also 13 in `scripts/visual` (for example `character_visual.gd:318`, `ground_aoe_fx.gd:113`, `thunder_wave_fx.gd:272`).
- **`unit.gd` (about `:556-640`):** loops over cooldowns and abilities, with no `.new()` and no node lookups seen.
- **`hud.gd _process` (`:188`):** `_tick_fps` (`:4104`) builds a `"%d FPS"` string every frame. `_refresh_combat` builds several formatted strings per refresh. Tooltip placement runs per frame. Label text and bars update every frame while the combat panel is visible.
- **`hud.gd` uncached lookups:** `get_node`/`get_node_or_null` at `:2805, 2815, 3043-3057, 4174, 4206, 4214`, in per-icon and per-panel update paths.
- **`scripts/visual`:** `ShaderMaterial.new` at `damage_number.gd:1127`, and `duplicate(true)` of animation resources at `character_visual.gd:142,153,279`. There are 56 node-lookup-style hits (for example `character_visual.gd:116,119,159`). Runtime `load()` appears at `ability_fx.gd:69`, `arena_decor.gd:38`, `character_catalog.gd:60,115` and `character_visual.gd:62`. *(Which of these are per-frame is unverified.)*
- **Groups and `find_child`:** no `get_nodes_in_group` or `find_child` in combat/units/ai/autoload, and none in the HUD `_process`.
- **Not examined:** most other `_process` bodies were not read in full. Allocation inside them is not ruled out.

## 11. Asset duplicates and oversized files

- **Largest files:**
  - Textures under `assets/models/outfits/fantasy`: `T_Peasant_Normal.png` 14.1 MB, `T_Ranger_Normal.png` 12.7 MB, `T_Ranger_ORM.png` 10.8 MB, `T_Peasant_ORM.png` 9.9 MB, `T_Ranger_BaseColor.png` 6.6 MB, `T_Peasant_BaseColor.png` 5.1 MB.
  - `T_Page_Noise.png` 7.5 MB and `T_Trim_Props_Normal.png` 4.4 MB.
  - `assets/anims`: `UAL2_Standard.glb` 8.1 MB and `UAL1_Standard.glb` 7.6 MB.
  - Humanoid boss textures at about 4.3 MB.
- **Hash-identical duplicates:**
  - `FireCore.mtl` ×5 and `FireAura.mtl` ×5 (bolt `Vfx/meshes` plus the fire, lightning, shadow and wind infusions).
  - Bolt `Shards 2/3/4.mtl` and `sm_ring_1.mtl`.
  - `fire_core.obj` and `Standard Bolt Core.obj`.
  - `fireball_mesh.mtl` and `sm_hadouken3.mtl`.
  - `Pillar Pieces_Ground (29).png` and `Pillar Styalized_Ground (29).png`.
  - `UAL1_LICENSE.txt` and `UAL2_LICENSE.txt`.
- **Not run:** a duplicate-basename check across the whole repo. The combat auditor's command was denied.

## 12. Audit limits

- The audits were heuristic: grep counts and sampled reads, not full static analysis.
- Counts differ by scope. The HUD audit's 267 `.gd` and 55 `.tscn` include addons and assets. The combat audit's figures exclude `.godot/` and addons.
