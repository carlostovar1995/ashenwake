# Spec: Holdfast

Target spec (`spec_id` `bastion`, display **Holdfast**). Combines retired Bulwark **Rampart** and **Oath**. Not wired. Follow `.cursor/rules/talent-trees.mdc` and `docs/talents/system.md`.

**50** starting points shared across up to 2 spec slots. WoW-style tiers: 7-row trees unlock at 0 / 3 / 6 / 9 / 12 / 15 / 18 in this spec. Ultimate unlocks at 18. Same-column and same-row spends are legal. Rows mix widths (2–4 talents). Rank cap is 3.

Talent ids: `bastion_<column>_<slug>` / `bastion_auto_<slug>`. Types: `passive` | `interaction` | `auto` | `ultimate`. Columns **rampart** (left) and **oath** (right). Ultimate `skill_id` **hearthguard**.

Rarity: one rare (row 5, max 3), one uncommon (row 4, max 2). Battlement and Bodyguard are the rares.

Planning numbers vs CombatBalance: bolt 42, nova 130, ground tick 14 / 18s CD, wall 160 blast / 800 HP / 35s CD, Protection shield ~2× base, shield 6s, Holy Blessing cap 10% DR / 8s (Halo raises cap to 20%), dodge 6m / 4.5s, player HP 500. Planning values, not slider ids, until implement.

Folded out: Pavise and Mortar into Battlement 3; Mercy into Vow.

## Identity

- Role: tank
- How they fight: Crafted Protection / Divine / Nature on QWER to live. Wind Ground for pulls. Protection Wall as the hold. Finish the spec for **Hearthguard** (ground pulse that also peels). Mix Aegis for a full tank, or a DPS spec if you only need space and peel.
- Columns: **Rampart** (hold space) vs **Oath** (peel allies).
- QWER: Protection Wall as the 4s hold; Wind Ground for pulls (Undertow); Divine for Holy Blessing; Protection shields on allies. Trees do not occupy QWER.
- D/F: Hearthguard.

Combat foundations (HP 500, threat coeffs, DR cap): `docs/talents/system.md`. Passive DR from Bodyguard **adds** (cap 50%). Hearthguard DR is a separate timed buff.

### Aggro

- **Rampart — Battlement + Hearthguard:** normal mobs taunt onto the wall; Hearthguard pulses 24 threat/s.
- **Oath — Redirect:** 8% / 18% of threat from damage allies deal within 8m is moved to you.

## Auto row

Baseline if this row is skipped: ranged 32, 7.2m, 1.05s, no element. Riders stack with other slotted specs. Melee conversion is unique in the loadout (cannot stack with Aegis Iron Fist). See system doc.

| Side | Name | Per point | Stance |
| L | Ward Strike | 1: Melee 140 physical, 2.4m, 0.85s. +16 extra threat. Nearest ally 20 shield for 4s | melee |
| R | Aegis Shot | 1: Stay ranged. Autos grant you 25 shield for 4s | ranged |

## Rows

Earlier on a path 1+1+1+1+2+3 = 9. Ultimate 1. Total 10.

Left (Rampart): two % passives (Footing, Masonry), three interactions. Right (Oath): one % passive (Vow; Mercy folded in), four interactions.

| Row | Max | Type | Left | Left per point | Left hook | Right | Right per point | Right hook |
| 1 | 1 | passive | Footing | 1: +10% Ground AOE damage, healing, and shielding | ground_aoe | Vow | 1: +18% shield amount on allies (not you). +12% healing dealt and +12% healing received | shield |
| 2 | 1 | interaction | Undertow | 1: Wind Ground AOE: 2 charges, 20% faster recharge (14.4s from 18s base). Each pull: 50 threat per yanked enemy | wind / ground_aoe / threat | Halo | 1: Divine Blessing at 150% rate. Cap 20% DR (from 10%), 8s | divine |
| 3 | 1 | passive / interaction | Masonry | 1: +30% wall HP and 20% wall CDR (35s → 28s) | wall | Cover | 1: Ally Protection shields last +3s (6s → 9s) | protection / shield |
| auto | 1 | auto | Ward Strike | 1: Melee 140 physical, 2.4m, 0.85s. +16 extra threat. Nearest ally 20 shield for 4s | auto | Aegis Shot | 1: Stay ranged. Autos grant you 25 shield for 4s | auto |
| 4 | 2 | interaction | Palisade | 1: Wall length +20% / 2: +35% length and walls last +1.5s | wall | Redirect | 1: 8% of threat from damage allies deal within 8m is moved to you / 2: 18% | threat |
| 5 | 3 | interaction | Battlement | 1: Normal mobs taunt onto the wall until it dies or expires / 2: +2.5m leash. No rare/elite / 3: Protection Wall channel 5s (from 4), 35% slow while holding (from 50%); heal 35% of damage the wall absorbs as that wall's infusion (Protection / Divine / Nature) | wall / threat | Bodyguard | 1: Allies within 6m take 8% less / 2: 12% / 3: 25% of prevented damage becomes a 6s shield on you | shield |
| ult | 1 | ultimate | Hearthguard | 1: Ground, 4.5 radius, 5s, 22s CD. Pulse 60 shield to allies and 24 threat to enemies every 1s. You: 30% DR for 5s. Knockback immune inside. Lowest-HP ally in the zone: 30% of their damage redirects to you for 4s and they gain 200 extra shield on cast | ground_aoe / shield / threat | — | — | — |

Undertow charges are Wind Ground AOE only. Cover is type `interaction` (duration rider), not a second % passive on the Oath column.

## Lobby D/F (example)

Skills 50 starting points could unlock, not a required path:

- Hearthguard + Iron Rampage (full tank)
- Hearthguard + Worldbloom (plant + peel)
- Hearthguard + Pyre (peel tank who dumps Burn)

## Implementer notes

- This spec is the target. Do not wire catalog, TalentHooks, or combat until asked.
- Live spends on `bulwark_rampart_*` / `bulwark_oath_*` do not map. Loadout reset when shipping.
- Keep ultimate `skill_id` **hearthguard** (new). Retired `sanctuary` / `intercede` binds do not exist on this spec.
- Ward Strike is a melee conversion. Illegal while Aegis Iron Fist is invested, and the reverse.
- Fragile core: `unit.gd`, HUD, walls, compiler, `CombatBalance`, `ThreatTable`. Extract via `.cursor/rules/cleanup-protocol.mdc`.
- Verify with `scripts/windows/Verify-Ashenwake.ps1`. After a later gameplay ship, OneNote via `scripts/windows/Update-AshenwakeOneNote.ps1`.

## Open questions

- Hearthguard redirect targets the lowest-HP ally in the zone at cast (not a later dip). Spec locks on-cast snapshot.
- Vow healing is 12% / 12% (compressed from Mercy 18% / 18%) so the % passive is not a full second Mercy.
- Cover sits on row 3 opposite Masonry (passive vs interaction). Oath still has Halo, Cover, Redirect, Bodyguard as four interactions; Masonry keeps Rampart at two % passives.
