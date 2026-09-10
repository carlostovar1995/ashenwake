# Spec: Crucible

Target spec (`spec_id` `cinderfrost`, display **Crucible**). Combines retired Fire Mage **Frostfire** and **Cinder**. Not wired. Follow `.cursor/rules/talent-trees.mdc` and `docs/talents/system.md`.

**50** starting points shared across up to 2 spec slots. WoW-style tiers: 7-row trees unlock at 0 / 3 / 6 / 9 / 12 / 15 / 18 in this spec. Ultimate unlocks at 18. Same-column and same-row spends are legal. Rows mix widths (2–4 talents). Rank cap is 3.

Talent ids: `cinderfrost_<column>_<slug>` / `cinderfrost_auto_<slug>`. Types: `passive` | `interaction` | `auto` | `ultimate`. Columns **frostfire** (left) and **cinder** (right). Ultimate `skill_id` **ashen_crucible**.

Rarity: one rare (row 5, max 3), one uncommon (row 4, max 2). Glaze and Wraithfire are the rares.

Planning numbers vs CombatBalance: bolt 42, missiles 24, ground tick 14, burst 140, nova 130, wall blast 160, meteor 500, player HP 500. Talent extras stay below a full crafted hit unless they are the ultimate. Planning values, not slider ids, until implement.

Folded out: Tempered into Fumarole (marked amp already lives there); Smother into Wraithfire 3.

Say “enemy that already has Burn,” never “burner.” Freeze is always 50 stacks. Rank only changes ice damage per stack. Frostfire talents key off the **Frostfire** mark, not both DoTs. Shatter stays global (`docs/talents/system.md`). Do not key this spec to Shatter or halve freeze thresholds.

## Identity

- Role: caster DPS
- How they fight: Fire+Ice (**Frostfire**) crafts apply the Frostfire mark. Fire+Shadow paints Afflict. Finish the spec for **Ashen Crucible** (dash absorb + fuse window). Mix other slots for tank or healer hybrids.
- Columns: **Frostfire** (fuse the mark) vs **Cinder** (Fire paints Afflict).
- QWER: Fire+Ice Bolt / Missiles / Ray / Ground / Nova for Kiln. Fire+Shadow and fire ticks to paint Afflict. Trees do not occupy QWER.
- D/F: Ashen Crucible. Wraithfire is a dodge replace, not a D/F bind.

Combat foundations (Chill/Freeze, Shatter, Afflict, Frostfire): `docs/talents/system.md`.

## Auto row

Baseline if this row is skipped: ranged 32, 7.2m, 1.05s, no element. Riders stack with other slotted specs. See system doc.

| Side | Name | Per point | Stance |
| L | Kiln Shot | 1: Fire. Store Burn from the hit. Autos vs Frostfire apply 1 Chill | ranged |
| R | Soot Shot | 1: Fire. Apply 1 Afflict. Autos vs Afflicted deal +10% | ranged |

## Rows

Earlier on a path 1+1+1+1+2+3 = 9. Ultimate 1. Total 10.

Left (Frostfire): two % passives (Alloy; Fumarole’s marked amp is an interaction), four interactions. Right (Cinder): one % passive (Cinderfeed), four interactions.

| Row | Max | Type | Left | Left per point | Left hook | Right | Right per point | Right hook |
| 1 | 1 | passive | Alloy | 1: +8% damage on crafted spells with both Fire and Ice | fire / ice | Cinderfeed | 1: +10% fire and shadow damage to Afflicted | fire / shadow / afflicted |
| 2 | 1 | interaction | Kiln | 1: Frostfire crafts apply Frostfire 6s, Burn as a fire hit would, and 2 Chill stacks on the same hit. Ticks: 1 Chill and Burn equal to 10% of the tick. Single-school fire/ice do not get this | fire / ice / burn / chilled | Wick | 1: Heal for 8% of Burn damage you deal | burn |
| 3 | 1 | interaction | Quench | 1: The first Frostfire apply on a target deals a steam burst (fire+ice) equal to 20% of remaining Burn. Burn is not consumed | burn / frostfire | Pitch Skin | 1: 20% DR vs fire and shadow while a nearby enemy has Afflict (8m) | afflicted / fire / shadow |
| auto | 1 | auto | Kiln Shot | 1: Fire. Store Burn. Autos vs Frostfire apply 1 Chill | auto | Soot Shot | 1: Fire. Apply 1 Afflict. Autos vs Afflicted +10% | auto |
| 4 | 2 | interaction | Fumarole | 1: Enemies with Frostfire take +8% from you; on death they leave a 1s steam patch (12 fire + 12 ice per 0.5s, 1.6m) / 2: +15%; 2s steam patch | frostfire | Sootbrand | 1: Fire hits apply 1 Afflict stack, including aura, Ground AOE, and wall ticks / 2: 2 stacks. The Afflict tick still does not stack | fire / afflicted |
| 5 | 3 | interaction | Glaze | 1: Frostfire duration 6s → 8s / 2: Frostfire crafts apply 3 Chill (from 2) / 3: Fire-only hits vs Frostfire refresh it 2s and apply 1 Chill; Ice-only hits vs Frostfire refresh it 2s and apply Burn equal to 15% of the hit | fire / ice / frostfire / chilled / burn | Wraithfire | 1: Replaces dodge with an 8m blink; on landing a nova deals 40 fire+shadow in 2.2m / 2: 10m blink, nova 70 in 2.8m, and apply 6 Afflict to enemies hit / 3: Fire spells cost 15% less. Dodge cooldown still applies. Not a D/F skill | fire / shadow / afflicted |
| ult | 1 | ultimate | Ashen Crucible | 1: Aimed dash, max 10m, width 2.6, 32s CD, 80 mana. First dash applies Frostfire and absorbs Afflict along the path (shadow damage equal to stacks removed). 6s fuse window: Fire-only crafts also count as Ice (apply Chill + Frostfire); Ice-only crafts also count as Fire (apply Burn + Frostfire); dual crafts apply Frostfire immediately. Recast: release absorbed Afflict as Burn on units you pass through (1 stack → 1 Burn/tick, 400/target) and detonate Frostfire in 10m for 30 fire + 30 ice + 1s root. Ends the window. No refund if the 6s expires without recast. Does not Freeze. Does not Shatter | fire / ice / frostfire / burn / chilled / afflicted | — | — | — |

During the fuse window you can run a pure Fire or pure Ice bar and still fuse. Outside it, you want Frostfire crafts on QWER. Glaze 3 is the “I dipped ice but my fire bar can keep the mark up” rider. Wraithfire 3 is the Smother fold.

### Ashen Crucible vs sitting on Afflict

There is **no** taken amp. Afflict ticks at `stacks / 4` per second.

- First dash **absorbs all Afflict** on units in the wave path and deals **shadow damage equal to stacks removed** (400 stacks → 400 shadow).
- Recast dash **releases the absorbed pool** as Burn DPS at **1:1** on every unit you pass through, **and** detonates Frostfire. Each target is capped at **400** stacks of conversion (400 → 400 Burn/tick for 10s). Two targets each get the same dump, not a split.
- Sit the full 10s at 400: **1000** from Afflict ticks.
- Window expire or a missed recast wastes the absorbed pool (no steam detonate, no Burn dump).

## Lobby D/F (example)

Skills 50 starting points could unlock, not a required path:

- Ashen Crucible + Pyre (fuse dump then spend Burn)
- Ashen Crucible + Iron Rampage (assassin tank)
- Ashen Crucible + Eye of Tempest (marks into storm)

Wraithfire is a dodge replace, not a D/F bind.

## Implementer notes

- This spec is the target. Do not wire catalog, TalentHooks, or combat until asked.
- Live spends on `fire_mage_frostfire_*`, `fire_mage_obsidian_*`, `fire_mage_cinder_*` do not map. Loadout reset when shipping.
- Keep ultimate `skill_id` **ashen_crucible** (new). Retired `crucible` / `ashen_wake` binds do not exist on this spec.
- When shipping: Frostfire status + HUD icons; Kiln on dual Fire+Ice crafts (all bases, including ticks), not only Ground / Aura / Wall; Wraithfire rank-2 Afflict 6; Wraithfire rank-3 15% fire cost.
- Do not reintroduce Afflict taken amp in baseline copy or `take_damage` unless a later pass asks.
- Do not reintroduce Obsidian Shell.
- Fragile core: `scripts/units/unit.gd`, HUD, walls, compiler, `CombatBalance`. Extract only via `.cursor/rules/cleanup-protocol.mdc`.
- Verify with `scripts/windows/Verify-Ashenwake.ps1`. After a later gameplay ship, OneNote via `scripts/windows/Update-AshenwakeOneNote.ps1`.

## Open questions

- New named status: **Frostfire** (already in system doc).
- Ashen Crucible recast vs letting the 6s expire with no detonate (pool wasted). Spec locks recast detonate + Burn dump, no refund.
- Wraithfire 3 cost reduction is 15% (between old Smother 10/20), one rank only.
