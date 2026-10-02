# Regression baseline (recorded 2026-10-01)

Run these before a refactor and again after it. They are the evidence for the
"behavior unchanged, frame/script time equal or better" gate in `AGENTS.md`.
They describe what the build does today, including the problems listed in
[Findings](#findings). Nothing here is a target.

## Commands

| Command | What it does | Needs | Time |
|---|---|---|---|
| `.\tools\baseline-scenario.ps1` | Scripted 5 players + boss, fixed seed, headless. Logs damage/healing, boss threat, status applications and casts. Runs each boss twice and fails if the two digests differ, then compares with `docs/baseline/`. | Godot only | ~40 s |
| `.\tools\baseline-perf.ps1` | 60 chase dummies piled on the champion plus 5 scripted casters cycling every spell with no cooldowns. Logs frame time, draw calls, live particle/projectile/wall counts. | A GPU and a window | ~45 s |
| `.\tools\baseline-shots.ps1` | Replays the scenario in a window at a fixed 60 fps step and saves 8 PNGs per boss to `tools/out/shots/`. | A GPU and a window | ~80 s |

Output goes to `tools/out/` (git-ignored). The reference scenario reports and
the three perf runs recorded below are committed in `docs/baseline/`.

Exit codes: scenario `0` ok, `1` error or non-deterministic, `3` digest differs
from `docs/baseline/`. After an intentional gameplay change, run
`.\tools\baseline-scenario.ps1 -UpdateBaseline` and commit the new reports.
Options are in each script's header (`-Seconds`, `-Seed`, `-Boss`, `-Dummies`, …).
The reference only compares when seed, duration, phase-2 setting and Godot
version match the recorded run.

Godot is found through `$env:GODOT`, then `PATH`, then
`%LOCALAPPDATA%\Programs\Godot`. The version must match `.godot-version`.

## What is measured

**Scenario** (`tools/baseline/scenario.gd`). Boots the real `main.tscn` in raid
mode: the champion plus the four AI raid members, against Colossus or
Dawnwarden. AllyAI is switched off and each player runs a scripted loadout
(`harness.gd`, `LOADOUTS`) so every spell base, all nine infusions and six class
skills are cast in a fixed order. Boss AI stays on, so the boss casts its real
kit: Colossus cone / circle / line; Dawnwarden solar collapse, solar corona,
sunspots, cone, judgment beams and pillar shots. Players and boss have inflated
health so nobody dies and the fight runs the full 60 s; at 55 % of the run the
boss is dropped to 49 % health to force phase 2 and its adds. Seed `1337`.

**Perf** (`tools/baseline/perf.gd`). Training arena, 60 chase dummies (made
immortal so the count stays 60), champion plus 4 helper casters, cooldowns and
mana disabled by the game's own training flags, HUD and damage numbers on, vsync
off. Bulwark's wall is a fire wall here (the protection wall in the scenario is a
long held channel that keeps the caster busy for seconds). 6 s warm-up, then 30 s measured. Live particle, projectile, wall, telegraph
and unit counts are registered as custom Performance monitors
(`ashenwake/*`) and sampled 4 times a second.

**Shots** (`scenario.gd --shots`). Moments are `SHOT_MOMENTS` in
`scenario.gd`: 1, 3, 7, 12, 20, 30, 42 and 55 simulated seconds. The HUD is
visible, so the FPS readout and anything time-of-day will differ between runs.

## Determinism

The scenario digest (SHA-256 of the rounded results) was identical across 3
consecutive runs per boss and is checked on every run. To get there:

- `--fixed-fps 60` makes the simulation step independent of wall time.
- `Harness.silence_audio()` drops `AudioManager`'s SFX pool. One-shot sounds draw
  their pitch from the global RNG only when a pooled player is free, which
  depends on real playback time; left in, crit and arc rolls drifted between
  identical runs (33 496 vs 33 670 total damage).
- The harness overwrites saved talents, loadout, role and session flags before
  the match starts. Your saved loadout does not leak in.

Limits you should know about:

- Headless and windowed runs simulate slightly differently (the `--shots` run
  totals 34 276 damage against 34 502 headless). Compare like with like; the
  shots run writes `scenario_<boss>_shots.json`, never the headless baseline.
- `ThreatTable.taunt` and a few FX throttles use wall-clock time. Taunts are not
  exercised here (AllyAI is off); if a scenario ever casts one, determinism breaks.
- Perf numbers vary run to run and with GPU load. Use the spread below, not one run.

## Recorded numbers

Machine: Windows 11, NVIDIA GeForce RTX 4060 Ti, Forward+, Godot 4.7.2-stable,
1600x900 window, vsync off. Code: `HEAD 18f7291` **plus the uncommitted working
tree** (including changes to `projectile.gd`, `spell_catalog.gd`, `meteor_fx.gd`
and the new VFX scenes).

### Scenario, 60 s, seed 1337

| | Colossus | Dawnwarden |
|---|---|---|
| Damage dealt by the 5 players | 24 112 (incl. 2 651 on adds) | 21 605 |
| Damage taken by boss | 21 461 | 21 605 |
| Boss damage to raid | 10 192 (70 hits) | 6 761 (114 hits) |
| Healing done | 6 858 | 6 761 |
| Final boss threat: Ember / Hex / Bulwark / Vex / Mend | 8 697 / 6 763 / 4 951 / 1 808 / 581 | 9 023 / 6 588 / 6 872 / 2 135 / 599 |
| Aggro holder at every 10 s check | Ember | Ember |
| Boss telegraphs | circle_slam 6, cone_cleave 6, line_breath 5 | sunspot 4, solar_collapse 1, solar_corona 1, cone_cleave 1 |
| Status applications (all units) | 156 | 132 |
| Boss status peaks | shock 100, chill 26, afflict 13 | shock 100, chill 26, afflict 13 |
| Spell slots never cast | 0 | 0 |
| Deaths | 2 phase-2 adds | none |

Casts per player over the run (same in both): Ember 38, Bulwark 38, Mend 43,
Hex 30, Vex 30. The full per-spell, per-status and per-checkpoint tables are in
`docs/baseline/scenario_colossus.json` and `scenario_dawnwarden.json`.

Digests (SHA-256 of the rounded results):

- Colossus: `241c735ee3cd863c41661111fb7822f86567e74a9fbaa72f12b55108cfb56509`
- Dawnwarden: `dfc4ef2f2416b88171bca3909b99151748949068979c2a8741962bebe6bc8d74`

### Perf, 30 s measured, three runs (`docs/baseline/perf_run1-3.json`)

| Metric | Run 1 | Run 2 | Run 3 |
|---|---|---|---|
| Frame time mean (ms) | 23.78 | 22.98 | 23.16 |
| Frame time p50 / p95 / p99 (ms) | 14.8 / 82.2 / 149.3 | 14.5 / 82.3 / 149.8 | 14.6 / 82.4 / 151.5 |
| Frame time max (ms) | 245 | 265 | 237 |
| Average FPS | 42.0 | 43.5 | 43.2 |
| Frames over 16.7 ms / 33.3 ms | 513 / 226 | 483 / 245 | 513 / 242 |
| Render CPU mean / GPU mean (ms) | 1.17 / 3.82 | 1.13 / 3.48 | 1.14 / 3.58 |
| Draw calls mean / p95 / max | 1 155 / 1 544 / 1 878 | 1 179 / 1 569 / 1 928 | 1 166 / 1 548 / 1 814 |
| Primitives mean / max (millions) | 2.43 / 5.37 | 2.44 / 5.85 | 2.48 / 5.17 |
| Script process, worst frame per second, mean / max (ms) | 16.6 / 37.1 | 17.0 / 33.4 | 17.5 / 39.9 |
| Script physics, worst frame per second, mean / max (ms) | 63.5 / 167 | 59.4 / 174 | 64.6 / 165 |

The script-time rows come from `Performance.TIME_PROCESS` and
`TIME_PHYSICS_PROCESS`. The engine refreshes those about once a second and
holds the worst frame of that second, so they are sampled once a second and are
worst-case figures, not averages. Frame time is true wall-clock time between
frames.

Live counts, per run (they were close across runs, so ranges are shown):

| Count | First sample | Last sample | Mean | Peak |
|---|---|---|---|---|
| Units | 71 | 71 | 71 | 71 |
| Nodes | 6 776 | 6 600–6 603 | 6 692–6 696 | 6 892–6 938 |
| Objects | 14 965–14 973 | 15 457–15 525 | 15 323–15 336 | 16 144–16 164 |
| Orphan nodes | 0 | 0 | 0 | 0 |
| Resources | 1 882 | 1 882 | 1 882 | 1 882 |
| Emitting particle systems | 13 | 14–21 | 16–18 | 78–99 |
| Particle budget (sum of `amount` of emitting systems) | 550 | 375–455 | 711–863 | 6 332–6 766 |
| Projectiles | 2 | 1–2 | 2.1–2.4 | 13–14 |
| Live spell walls | 1 | 1 | 1 | 1 (11 spawned) |
| Static memory (MB) | 233 | 244–245 | 243 | 248 |
| Video memory (MB) | 486 | 484 | 486 | 495 |

## Findings

These were found while building the baseline. None were fixed; they are inputs
for the refactor, not part of it.

1. **Object count climbs while node count does not.** Objects rise about 25 per
   second (about 500 over 30 s, in all three runs) while nodes, resources and
   orphans stay flat and static memory grows 0.36 MB/s. Something is creating
   non-node objects that are not released during the run. The cause is not
   identified. The gate says object counts must stay stable, so any change that
   adds to this slope is a regression.
2. **Frame time is far over budget in the worst case.** Mean 23 ms (43 fps), p95
   82 ms, with about 40 % of frames over 16.7 ms and about 18 % over 33.3 ms. GPU time
   is only about 3.6 ms and render CPU about 1.1 ms, so the cost is on the
   script and physics side (physics worst-frame mean about 62 ms per second).
3. **Large hitches.** Every run has 12 or more frames over 100 ms (the log caps at
   12), up to 265 ms. A first, lighter measurement taken before the driver
   fix (below) showed regular 220–340 ms hitches roughly every 6 s, so spell VFX
   spawn cost is a candidate. Not profiled.
4. **Harness bug caught along the way.** An early driver that skipped to any
   castable slot let instant gcd-exempt class skills restart the global cooldown
   forever, so crafted slots 2 and 3 on Mend and Bulwark almost never fired. The
   perf run looked healthy (172 fps) and was under-testing. The driver now
   waits for the GCD instead of skipping ahead, and every slot of every caster
   is exercised; the scenario and perf reports list per-slot cast counts so this
   cannot regress silently.

## Not verified

- I could not open `tools/out/shots/` (the Read tool is denied for that
  directory), so the PNGs were confirmed to exist and have plausible sizes
  (1.5–1.7 MB) but not looked at. Open a few before trusting them.
- Screenshots are not diffed automatically. There is no image comparison tool;
  compare by eye or add one.
- Only `HEAD + working tree` was measured. Rerun on a clean checkout of
  `18f7291` if you want a number free of the uncommitted VFX work.
