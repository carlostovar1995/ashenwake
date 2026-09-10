# Ashenwake VFX authoring

Hand this to a VFX artist. Combat code follows the missile; it does not own leftover smoke. Tag your scene so the game knows what dies on impact and what is allowed to fade.

**Cost / OmniLight / animation one-pager:** [OPTIMAL_DESIGN.md](OPTIMAL_DESIGN.md) (what is cheap vs what drops FPS).

Canonical travel placeholders: Bolt `assets/vfx/projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_01.tscn`, Missiles `.../mprojectile_javelin/mprojectile_javelin_vfx_01.tscn`, Meteor `assets/vfx/elemental/effects/projectile/vfx_fire_projectile_01.tscn`. Persist and impact slots are empty until you drop a scene in.

## Three layers

Every combat spell can use up to three visual layers. You do not need all three on every shot.

1. **Travel body** — the ball, mesh tail, core, and light. These vanish the instant the shot hits or expires.
2. **Travel persist** — world-space particles (smoke, embers, sparks) spawned while the shot flies. On hit they stop spawning and finish their lifetime in place.
3. **Impact** — a one-shot burst at the hit point (explosion, flash). Combat plays this separately; do not parent it under the travel scene.

A magic bolt that is only Head / Trail / Core meshes is body-only. That is valid. Leftover smoke must be persist particles, not a mesh glued to the ball.

## Groups

Select a node in Godot. In the Inspector, open **Node → Groups** and add exactly one of:


| Group        | Meaning                                          |
| ------------ | ------------------------------------------------ |
| `fx_body`    | Hide now on hit (meshes, lights).                |
| `fx_persist` | Stop emitting, keep drawing until particles die. |
| `fx_core`    | Extra tag on a body mesh: kept when this infusion is first in a dual craft. |
| `fx_aura`    | Extra tag on a body mesh: used when this infusion is second in a dual craft. |


Do not put `fx_body` and `fx_persist` on the same node. Do not put either on the scene root; tag the children. `fx_core` / `fx_aura` are extra tags on `fx_body` meshes.

Untagged vendor scenes still work: GPU particles persist, meshes and lights are treated as body. Tagging is required for anything we ship as a travel effect.

## World space (required for persist)

On every `fx_persist` `GPUParticles3D`:

- **Local Coords** = off (`local_coords = false`)
- Lifetime about **0.4–1.5 s** (cap in code is 3 s)
- Author smoke so it drifts in the world, not in the ball’s pocket

If Local Coords is on, leftover smoke teleports into a puff at the last pose instead of leaving a trail.

## Mesh trails vs particle trails

- A cylinder or stretched sphere parented to the shot is **body**. It will pop off on hit. That is correct for magic bolt / javelin tails.
- Smoke, fire wisps, and ember trails that should remain after impact must be **GPUParticles3D** in `fx_persist`.
- Do not try to “linger” a mesh trail. Use particles, or put the leftover look in the impact scene.



## Facing, scale, and lights

- Author along the scene’s forward. Combat may apply `yaw_offset` and `vfx_scale`. Godot travel is **−Z**. If a mesh looks backward, wrap with **180° Y** `(0, 180, 0)` — not 180° X, which also flips the mesh upside down.
- Put **one** `OmniLight3D` on the **travel body** (not persist). Tag it `fx_body`. Set Color, Energy, and Range in the Inspector. Combat copies those into a pooled world light (no shadows, 10-light cap). Range is multiplied by the shot’s `vfx_scale` (bolts are often ~0.55), so author Range at scale 1. Dual infusion: first infusion retints the color; do not add a second Omni for the overlay.
- Keep travel scenes as text `.tscn`. Do not add gameplay scripts (`Projectile`, damage, collision). Preview / color scripts that already ship with the vendor packs are fine.



## What the game does

- Travel VFX is **follow-bound** to the missile. It is not a child of the collision object.
- On hit the missile is freed immediately. Body hides. Persist emitters stop spawning and fade on `FxRoot`.
- If too many persist systems are alive (cap **24**), the oldest is stolen. Damage never depends on whether smoke finished.



## Infusions (per spell base)

A craft is **base + up to two infusions**. Design to the base’s slots. Do not author one flying trail and reuse it on Ground AOE, Aura, Ray, and Wall.

### How they stack

- The **spell base** owns silhouette and delivery (skillshot ball, ground ring, beam, wall).
- **First infusion** owns identity: tint, the travel light, and the **core** mesh when `{base}_body.tscn` exists.
- **Second infusion** is overlay: extra persist / impact, and the **aura** mesh when both infusions have `{base}_body.tscn`. It must not replace the core.
- Tag body meshes `fx_core` and `fx_aura` (in addition to `fx_body`) so a dual craft can keep first-infusion core + second-infusion aura. Both persist scenes still attach.
- Nature, Divine, and Protection use the same slots. They read as heal/ward, not a second enemy missile.

Example: Fire Bolt + Lightning → FireCore + LightningAura, fire persist (trail/sparks) and lightning persist (trail/sparks/arcs), first-infusion light. Lightning Bolt + Fire → LightningCore + FireAura, both persists. Ice Bolt + Fire → ice-tinted bolt body + fire persist (ice has no bolt body yet).

### Plug-in paths

Combat mixes **one body per base** with **persist + impact per infusion and base**. Drop a finished scene on the convention path and play; the next compile picks it up. No compiler edit.

- Body: `assets/vfx/bases/{base}/body.tscn` (ids: `bolt`, `missiles`, `ground_aoe`, `aoe_explosion`, `aura`, `ray`, `meteor`, `nova`, `wall`, `wave`, `target`)
- First-infusion body (optional): `assets/vfx/infusions/{infusion}/{base}_body.tscn` — replaces the base silhouette when that infusion is first (Fire Bolt uses the fire body, Ice Bolt + Fire keeps the bolt body and only adds fire persist)
- Dual-infusion aura (optional): when the second infusion also has `{base}_body.tscn`, combat keeps `fx_core` from the first body and `fx_aura` from the second (Fire Bolt + Lightning = fire core + lightning aura)
- Persist: `assets/vfx/infusions/{infusion}/{base}_persist.tscn` (ids: `fire`, `ice`, `lightning`, `shadow`, `nature`, `divine`, `protection`, `wind`, `illusion`)
- Impact: `assets/vfx/infusions/{infusion}/{base}_impact.tscn`

Examples: `assets/vfx/infusions/ice/bolt_persist.tscn`, `assets/vfx/infusions/fire/bolt_impact.tscn`, `assets/vfx/infusions/fire/bolt_body.tscn`, `assets/vfx/infusions/shadow/bolt_body.tscn`, `assets/vfx/infusions/wind/bolt_body.tscn`, `assets/vfx/bases/bolt/body.tscn`.

Tag persist children `fx_persist` (Local Coords off). Tag body children `fx_body`. Impact scenes are one-shots played at the hit point; do not parent them under the travel body.

Until a file exists, that slot is skipped. Bolt/Missiles/Meteor keep placeholder bodies. Burst/Nova/Target keep the existing ground-flash placeholder until an impact file is present.

To point at an existing scene without moving it, set `BODY` / `PERSIST` / `IMPACT` in `scripts/visual/spell_vfx_slots.gd`.

### Slots per base

Skip empty slots. Do not fill a missing slot with a bolt mesh.

- **Bolt / Missiles / Wave** — travel body, travel persist, impact at hit. Wave body is the arc mesh (`scripts/visual/wave_fx.gd`); persist is optional wisps, not a mesh tail.
- **Meteor** — falling rock travel (follow-bound) + ground impact. Persist on the rock; impact on land.
- **Burst / Nova** — impact only (flash + ring). No travel persist.
- **Ground AOE** — zone loop for the puddle lifetime. Optional persist mist; impact when placed.
- **Aura** — ring on the caster. Tick pulse, no trail.
- **Ray** — beam body for the channel. Sparks stay on the beam and die with it (local to the beam, not a world trail).
- **Target** — impact on the unit. No travel.
- **Wall** — its own body per infusion (fire line, ice capsule, lightning totem, and so on). Do not reuse bolt trails.

### What each infusion should add

Specify the **read**. Put the scene on the plug-in path when it is ready.

- **Fire** — persist smoke/embers; impact heat flash. Ground AOE and Aura: ember bed in the ring, not a flying tail.
- **Ice** — persist frost wisps; impact shard burst. Zone: mist on the floor.
- **Lightning** — persist sparks (short lifetime); impact crack. Wall totem: small repeating spark, not a javelin mesh.
- **Shadow** — persist dark wisps; impact ink pop. Keep contrast so it still reads on a fire body.
- **Nature** — persist motes; impact heal pulse. Friendly shots: same slots, softer alpha.
- **Divine** — persist gold glow; impact blessing flash.
- **Protection** — persist ward motes; impact shield pop. Wall: curved shield body, not a projectile overlay.
- **Wind** — persist streak wisps; impact gust. Ground AOE: inward pull on the zone, not a second missile.
- **Illusion** — persist magenta wisps; impact shimmer. Extra bolts or meteors reuse the **same** travel scene as the base, tinted. Do not author five unique silhouettes.

## Handoff checklist

- [ ] Children tagged `fx_body` or `fx_persist` (root untagged)
- [ ] One OmniLight on the body (`fx_body`); Energy/Range as you want them in-game. No Omni on persist.
- [ ] Persist particles: Local Coords off, lifetime 0.4–1.5 s
- [ ] Mesh tails marked `fx_body` unless you truly want them to linger (you almost never do)
- [ ] Infusion overlay matches the **base’s slots** (no flying tail on a ground ring or wall)
- [ ] Second infusion is overlay only; it does not replace the body
- [ ] No gameplay scripts on the VFX scene
- [ ] Text `.tscn`, saved on the plug-in path (`assets/vfx/bases/` or `assets/vfx/infusions/{infusion}/`)
- [ ] Playtest: body gone on hit; persist fades only if that slot has a scene; impact plays only if that slot has a scene
- [ ] Dual craft playtest: first infusion still reads as the core; second adds aura (if both bodies exist) plus persist/impact