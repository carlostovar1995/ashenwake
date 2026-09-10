# Spec: Furnace

Target spec (`spec_id` `kindling`, display **Furnace**). Combines retired Fire Mage **Embers** and **Detonation**. Not wired. Follow `.cursor/rules/talent-trees.mdc` and `docs/talents/system.md`.

**50** starting points shared across up to 2 spec slots. WoW-style tiers: 7-row trees unlock at 0 / 3 / 6 / 9 / 12 / 15 / 18 in this spec. Ultimate unlocks at 18. Same-column and same-row spends are legal. Rows mix widths (2–4 talents). Rank cap is 3. Live scales are in `ClassCatalog`.

Talent ids: `kindling_<column>_<slug>` / `kindling_auto_<slug>`. Types: `passive` | `interaction` | `auto` | `ultimate`. Columns **embers** (left) and **detonation** (right). Ultimate `skill_id` **pyre**.

Rarity: one rare (row 5, max 3), one uncommon (row 4, max 2). Kindling and Afterburn are the rares.

Planning numbers vs CombatBalance: bolt 42, missiles 24, ground tick 14, burst 140, nova 130, wall blast 160, meteor 500, player HP 500. Talent extras stay below a full crafted hit unless they are the ultimate. Planning values, not slider ids, until implement.

Folded out: Hotter Coals into Kindling ranks; Impact Heat CDR into Pyre’s crit-refund.

## Identity

- Role: caster DPS
- How they fight: Crafted Fire on QWER to bank Burn and crit. Finish the spec for **Pyre**, which is the only Combust. Mix the other two slots for tank threat or healer pulse; this spec does not own the character.
- Columns: **Embers** (bank Burn, rebuild after the dump) vs **Detonation** (crits into Pyre).
- QWER: Fire Bolt / Missiles / Ray to bank Burn. Burst / Meteor / Nova to crit and to detonate **Singe**. Ground AOE / Aura / Wall to apply **Scorched**. Trees do not occupy QWER. Combust is **not** on QWER, Stormfire, or Meteor. Only **Pyre** spends Burn.
- D/F: Pyre. Auto-fills D then F with other unlocked skills. Swap on the Spellbook.

Live mid interactions (replaced stale % fillers; ids unchanged):

- **Singe** — stack a 6s fire mark (cap 3) with fire hits, then detonate with Burst / Nova / Meteor / Pyre (Bolt / Missiles / Ray at rank 2+).
- **Scorch** — park enemies in fire zones for a snare + extra Burn store; rank 3 pays off on Pyre splash.

Combat foundations (Chill/Freeze, Shatter, Afflict, Combust, Frostfire, Singe, Scorched): `docs/talents/system.md`.

## Auto row

Baseline if this row is skipped: ranged 32, 7.2m, 1.05s, no element. Riders stack with other slotted specs. See system doc.

| Side | Name | Per point | Stance |
| L | Cinder Shot | 1: Fire. Store Burn from the hit (same 50% as fire crafts; Kindling applies). If the target has Burn, copy 25% of remaining Burn, split among enemies in 2.8m (does not consume; copies cannot hop again) | ranged |
| R | Hot Streak Shot | 1: Fire. Store Burn from the hit. Autos +8% crit chance. Auto crits splash 15% of the crit in 1.6m | ranged |

## Rows

Earlier on a path 1+1+1+1+2+3 = 9. Ultimate 1. Total 10.

Left (Embers): one % passive (Emberheart), four interactions. Right (Detonation): two % passives (Hot Hands, Glass Furnace), three interactions.

| Row | Max | Type | Left | Left per point | Left hook | Right | Right per point | Right hook |
| 1 | 1 | passive | Emberheart | 1: +10% Burn damage | burn | Hot Hands | 1: Fire spells +6% crit chance | fire |
| 2 | 1 | interaction | Live Coals | 1: Dying enemies with Burn explode for 30% of remaining Burn in 3.6m | burn / burst | Critical Mass | 1: Fire crits splash 20% of the crit in 1.6m | fire |
| 3 | 1 | interaction | Cinder Spark | 1: Applying Burn to a target that already has Burn deals 10% of the new layer instantly | burn | Flashover | 1: Fire crits store an extra 25% of the hit as Burn | fire / burn |
| auto | 1 | auto | Cinder Shot | 1: Fire. Store Burn. If the target has Burn, copy 25% of remaining Burn, split among enemies in 2.8m (does not consume; copies cannot hop again) | auto | Hot Streak Shot | 1: Fire. Store Burn. Autos +8% crit. Auto crits splash 15% of the crit in 1.6m | auto |
| 4 | 2 | interaction / passive | Searing Marks | 1: Fire hits refresh Burn layers by 0.5s / 2: by 1.0s, and Ground AOE / Aura / Wall ticks also refresh | fire / burn | Glass Furnace | 1: Fire crit damage 230% (from 200%) / 2: 260% | fire |
| 5 | 3 | interaction | Kindling | 1: Burn stores +8% of the hit (50% becomes 58%) / 2: +15% of the hit (50% becomes 65%) / 3: +22% of the hit (50% becomes 72%); Fire Bolt, Missiles, and Ray vs Burned store an extra 25% of the hit as Burn (on top of that store; not a damage amp); Heating (new, 6s) after Pyre: fire hits store 100% of the hit as Burn | burn / fire / bolt / missiles / ray | Afterburn | 1: After a fire crit, next fire spell is 15% faster to cast for 4s / 2: 30% faster / 3: 45% faster and Hot Streak (new): 2 fire crits within 8s make your next Pyre instant (0s cast). Consumed on that Pyre | fire |
| ult | 1 | ultimate | Pyre | 1: 1.8s unit-target, 36s CD, 90 mana. Consume remaining Burn: deal 150% of it as fire on the target, plus a 400 fire hit that always crits if any Burn was consumed. Nearby take 40% of leftover Burn in 2.8m (raw; does not apply Burn or Combust). Each Fire crit you land reduces remaining CD by 0.5s. Only Combust in this spec | fire / burn | — | — | — |

Kindling 3 is the Hotter Coals fold plus Heating after **Pyre** (not the retired Combustion). Afterburn 3 Hot Streak is consumed on **Pyre** (not Pyroblast). Pyre’s 0.5s crit refund is the Impact Heat fold (any Fire crit, not only Burst / Nova / Meteor).

## Lobby D/F (example)

Skills 50 starting points could unlock, not a required path:

- Pyre + Iron Rampage (damage tank)
- Pyre + Ashen Crucible ( dual fire specs)
- Pyre + Worldbloom or Eye of Tempest (healer hybrid)

## Implementer notes

- Live catalog, TalentHooks, and combat are wired. Talent ids stay `kindling_mid_singe` / `kindling_mid_scorch` so existing spends still load.
- Keep ultimate `skill_id` **pyre** (new; retired `combustion` / `pyroblast` do not exist on this spec).
- Singe and Scorched show on target/boss frames. Heating and Hot Streak from Kindling 3 / Afterburn 3 are still pending HUD if those ranks ship later.
- Do not put Combust on Fire+Lightning hits, Meteor, Burst, or any skill except Pyre.
- Fragile core: `scripts/units/unit.gd`, HUD, walls, compiler, `CombatBalance`. Extract only via `.cursor/rules/cleanup-protocol.mdc`.
- Verify with `scripts/windows/Verify-Ashenwake.ps1`. After a later gameplay ship, OneNote via `scripts/windows/Update-AshenwakeOneNote.ps1`.

## Open questions

- New named statuses: **Singe**, **Scorched** (shipped). **Heating**, **Hot Streak** still planned on Kindling 3 / Afterburn 3.
- Pyre always-crit requires any Burn consumed (including a tiny layer), not a Burn threshold.
- Pyre splash is leftover Burn after the 150% spend, same “raw, no Burn apply” rule as retired Combustion. Scorch 3 raises that splash to 55% and consumes Scorched.
