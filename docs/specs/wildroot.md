# Spec: Lifegrove

Target spec (`spec_id` `wildroot`, display **Lifegrove**). Combines retired Storm Druid **Canopy** and **Grove**. Not wired. Follow `.cursor/rules/talent-trees.mdc` and `docs/talents/system.md`.

**50** starting points shared across up to 2 spec slots. WoW-style tiers: 7-row trees unlock at 0 / 3 / 6 / 9 / 12 / 15 / 18 in this spec. Ultimate unlocks at 18. Same-column and same-row spends are legal. Rows mix widths (2–4 talents). Rank cap is 3.

Talent ids: `wildroot_<column>_<slug>` / `wildroot_auto_<slug>`. Types: `passive` | `interaction` | `auto` | `ultimate`. Columns **canopy** (left) and **grove** (right). Ultimate `skill_id` **worldbloom**.

Rarity: one rare (row 5, max 3), one uncommon (row 4, max 2). Lifebloom and Germinate are the rares.

Planning numbers vs CombatBalance: bolt 42 (Nature heal ~17 after −60%), missiles 24, ground tick 14 / 6s, nova 130, meteor 500, nature wall tick 16 / break 90 / 200 HP / 6s, Rejuv 6 HPS × 12 / 6s, player HP 500. Talent extras stay below a full crafted hit unless they are the ultimate. Planning values, not slider ids, until implement.

Folded out: Overgrowth into Lifebloom 3; Heartwood into Ringward.

## Identity

- Role: healer
- How they fight: Crafted Nature on QWER to stack Rejuvenation and hold space. Finish the spec for **Worldbloom** (plant, pulse, then consume). Mix Tempest or Kindling if you want damage that heals.
- Columns: **Canopy** (stack Rejuvenation, bloom one ally) vs **Grove** (hold the ring, plant the raid).
- QWER: Nature Bolt / Ray / Target / Missiles. Nature Ground AOE / Aura / Wall ring. Trees do not occupy QWER.
- D/F: Worldbloom.

Combat foundations (Rejuvenation, Nature ghosting, atonement pulse): `docs/talents/system.md`. Bank HoTs, press Worldbloom as the save, then rebuild through Drought. Lifebloom is the tank you chose to babysit. Grove play: allies stand in Worldbloom / the ring. You do not kite.

## Auto row

Baseline if this row is skipped: ranged 32, 7.2m, 1.05s, no element. Riders stack with other slotted specs. See system doc.

| Side | Name | Per point | Stance |
| L | Bloom Touch | 1: Ally click 14 nature heal + 1 Rejuvenation. Enemy click is the baseline 32 (no element) | ranged |
| R | Grove Pulse | 1: Enemy click pulses 25% of the hit as nature heal to the lowest ally in 8.5m (does not apply Rejuv). Ally click unchanged from baseline (no ally heal unless another spec’s auto adds it) | ranged |

## Rows

Earlier on a path 1+1+1+1+2+3 = 9. Ultimate 1. Total 10.

Left (Canopy): two % passives (Greenheart, Evergreen), three interactions. Right (Grove): one % passive (Loam), four interactions (Ringward includes the Heartwood fold).

| Row | Max | Type | Left | Left per point | Left hook | Right | Right per point | Right hook |
| 1 | 1 | passive | Greenheart | 1: +10% nature healing | nature | Loam | 1: +10% healing from nature Ground AOE, Aura, and Wall | ground_aoe / aura / wall / nature |
| 2 | 1 | interaction | Deep Roots | 1: Nature Bolt and Ray apply 2 Rejuvenation stacks instead of 1 | bolt / ray / rejuvenation | Thicket | 1: Nature Ground AOE lasts 8s (from 6) and radius +15% | ground_aoe / nature |
| 3 | 1 | passive / interaction | Evergreen | 1: Rejuvenation HPS +10% (6 → 6.6 per stack) | rejuvenation | Ringward | 1: Allies inside your nature Wall ring take 8% less damage and +8% healing received | wall / nature |
| auto | 1 | auto | Bloom Touch | 1: Ally click 14 nature + 1 Rejuvenation. Enemy click baseline 32 | auto | Grove Pulse | 1: Enemy click pulses 25% of the hit as nature heal to the lowest ally in 8.5m (no Rejuv from this pulse) | auto |
| 4 | 2 | interaction | Photosynthesis | 1: Applying Rejuv to an ally who already has it also heals 10 instantly / 2: 18 instantly | rejuvenation | Bramble | 1: Enemies standing on nature wall segments take 12 nature damage per second / 2: 20 per second and are rooted 0.3s every 2s (in addition to the 50% wall slow) | wall / nature |
| 5 | 3 | interaction | Lifebloom | 1: Nature Target on an ally applies Lifebloom (new): 14 HPS, 8s, one ally; a new application replaces the old / 2: 24 HPS / 3: When Lifebloom expires or is consumed, bloom for 90 nature heal. Allies at 12 Rejuv stacks take +12% from your nature crafts | target / nature / rejuvenation | Germinate | 1: The first heal from each nature Ground AOE cast grants a 40 shield for 4s / 2: 70 shield / 3: Also 2 Rejuv stacks | ground_aoe / shield / rejuvenation |
| ult | 1 | ultimate | Worldbloom | 1: Ground, 7m, 6s, 36s CD. You gain Rooted (new): cannot dodge, 70% slow, knockback immune. Pulse 40 nature heal + 1 Rejuv every 1s to allies inside (6 pulses). Recast or expire: consume Rejuvenation on allies inside, heal 22 per stack (12 → 264). If Lifebloom is on someone inside, also bloom them for 90 and they gain 15% DR for 3s. Nature Wall CD resets on cast. Then Drought (new, 3s): your nature crafts do not apply Rejuvenation | ground_aoe / nature / rejuvenation | — | — | — |

Ringward is type `interaction` (DR + received amp in the ring), so Grove still has only Loam as the themed % passive plus four interactions. Lifebloom 3 is the Overgrowth fold.

## Lobby D/F (example)

Skills 50 starting points could unlock, not a required path:

- Worldbloom + Eye of Tempest (plant then storm-heal)
- Worldbloom + Pyre (heal then dump)
- Worldbloom + Hearthguard (raid plant + peel)

## Implementer notes

- This spec is the target. Do not wire catalog, TalentHooks, or combat until asked.
- Live spends on `storm_druid_canopy_*` / `storm_druid_grove_*` do not map. Loadout reset when shipping.
- Keep ultimate `skill_id` **worldbloom** (new). Retired `flourish` / `worldroot` binds do not exist on this spec.
- Dual Lightning+Nature already damages and pulses; that is Tempest’s kit, not Wildroot’s.
- Mixed Lightning+Nature Wall: today style is one shape. Wildroot talents the nature ring; Tempest talents the lightning totem.
- Fragile core: `unit.gd`, HUD, walls, compiler, CombatBalance. Extract only via `.cursor/rules/cleanup-protocol.mdc`.
- Verify with `scripts/windows/Verify-Ashenwake.ps1`. After a gameplay ship, OneNote via `scripts/windows/Update-AshenwakeOneNote.ps1`.

## Open questions

- New named statuses: **Lifebloom**, **Drought**, **Rooted**.
- Worldbloom consume is raid-in-zone (not one ally). Spec locks zone consume.
- Drought is 3s (between Flourish 4s and a full rebuild). Instant nature heals still work; they do not apply Rejuv during Drought.
- Grove Pulse does not apply Rejuv (keeps Bloom Touch as the HoT auto). Spec locks heal-only pulse.
