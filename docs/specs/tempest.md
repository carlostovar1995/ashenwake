# Spec: Stormpulse

Target spec (`spec_id` `tempest`, display **Stormpulse**). Combines retired Storm Druid **Stormbloom** and **Thunderhead**. Not wired. Follow `.cursor/rules/talent-trees.mdc` and `docs/talents/system.md`.

**50** starting points shared across up to 2 spec slots. WoW-style tiers: 7-row trees unlock at 0 / 3 / 6 / 9 / 12 / 15 / 18 in this spec. Ultimate unlocks at 18. Same-column and same-row spends are legal. Rows mix widths (2–4 talents). Rank cap is 3.

Talent ids: `tempest_<column>_<slug>` / `tempest_auto_<slug>`. Types: `passive` | `interaction` | `auto` | `ultimate`. Columns **stormbloom** (left) and **thunderhead** (right). Ultimate `skill_id` **eye_of_tempest**.

Rarity: one rare (row 5, max 3), one uncommon (row 4, max 2). Atonement and Totem Surge are the rares.

Planning numbers vs CombatBalance: bolt 42, missiles 24, ground tick 14 / 6s, nova 130, meteor 500, lightning totem 200 HP / first hop 40% / 3 hops / 1s, Rejuv 6 HPS × 12 / 6s, Shock 100 / 10s / chain 20% at cap, player HP 500. Talent extras stay below a full crafted hit unless they are the ultimate. Planning values, not slider ids, until implement.

Folded out: Live Current into Galvanic Grove; Conduction into High Voltage.

## Identity

- Role: healer / dps
- How they fight: Lightning+Nature (**Tempestbloom**) crafts hit enemies and already pulse **25%** of dealt as nature heal + Rejuv in 8.5m. Pure Lightning banks Shock and chains. Pre-bond allies, then DPS. During **Eye of Tempest** you heal by shocking inside the cloud. Mix Wildroot for a full healer, or Kindling for a damage tank/healer hybrid.
- Columns: **Stormbloom** (damage that heals) vs **Thunderhead** (full lightning; you are the totem).
- QWER: Lightning+Nature Bolt / Missiles / Ray / Nova. Lightning Bolt / Missiles / Nova / Meteor / Wall totem. Trees do not occupy QWER. Stormbloom does not talent the wall; Thunderhead does (totem).
- D/F: Eye of Tempest.

Combat foundations (Rejuvenation, atonement pulse, Shock, Seeded): `docs/talents/system.md`. Thunderhead column has no Nature talents.

## Auto row

Baseline if this row is skipped: ranged 32, 7.2m, 1.05s, no element. Riders stack with other slotted specs. See system doc.

| Side | Name | Per point | Stance |
| L | Storm Touch | 1: Lightning vs enemies (1 Shock). Allies: 14 nature heal + 1 Rejuvenation | ranged |
| R | High Volt Shot | 1: Lightning vs enemies (1 Shock). +8% lightning on autos. No ally heal | ranged |

## Rows

Earlier on a path 1+1+1+1+2+3 = 9. Ultimate 1. Total 10.

Left (Stormbloom): one % passive (Galvanic Grove; Live Current folded in), four interactions. Right (Thunderhead): two % passives (High Voltage includes Conduction), three interactions.

| Row | Max | Type | Left | Left per point | Left hook | Right | Right per point | Right hook |
| 1 | 1 | passive | Galvanic Grove | 1: +8% lightning damage on crafts that also have Nature. +10% healing from the nature atonement pulse | lightning / nature | High Voltage | 1: +10% lightning damage. +8% lightning damage to enemies with 50+ Shock | lightning / shocked |
| 2 | 1 | interaction | Stormbond | 1: A nature heal on an ally applies Stormbond (new) 8s, max 2 allies. The nature pulse heals Stormbonded allies only (split). If none are bonded, the pulse still hits lowest-HP in range and applies Stormbond | nature / rejuvenation | Arc | 1: Shock chain hops 4 (from 3) and bounce range 7 → 9m | lightning / shocked |
| 3 | 1 | interaction | Feedback | 1: Shock chain hops also trigger the nature pulse (live chains are storm-only and do not) | shocked / lightning / nature | Static | 1: Enemies that die with 50+ Shock explode for 45 lightning in Burst radius (does not apply Shock, does not chain) | shocked / burst |
| auto | 1 | auto | Storm Touch | 1: Lightning vs enemies (1 Shock). Allies: 14 nature + 1 Rejuvenation | auto | High Volt Shot | 1: Lightning vs enemies (1 Shock). +8% lightning on autos. No ally heal | auto |
| 4 | 2 | interaction | Seedstorm | 1: Lightning+Nature enemy hits apply 1 Seeded stack without Alteration / 2: 2 stacks. Bloom still at 8. Fire is not required to spend seeds | lightning / nature / altered | Charge Coil | 1: Lightning hits apply 2 Shock (from 1) / 2: 3 Shock | lightning / shocked |
| 5 | 3 | interaction | Atonement | 1: Nature pulse 25% → 35% of dealt / 2: 45% / 3: 55% and pulse range 8.5 → 12m | nature / lightning | Totem Surge | 1: Lightning Wall first hop 40% of totem HP → 50% / 2: 60% / 3: 70% and each totem tick applies 2 Shock | wall / lightning / shocked |
| ult | 1 | ultimate | Eye of Tempest | 1: Instant self, 8s, 34s CD. A storm cloud (new, 6m) attaches to you. Enemies inside: +1 Shock every 0.5s and 16 lightning per 0.5s. Lightning crafts from inside the cloud count as Nature for the pulse at 40% of dealt (does not stack with Atonement ranks; uses 40%), 0 bounce falloff, and +1 hop. Recast: detach the cloud at your feet for the remaining duration. Recast again: jump to the cloud (10m). Stormbond cap 2 → 3. You cannot apply Rejuvenation while the cloud exists except via the pulse | lightning / nature / shocked | — | — | — |

Dual Lightning+Nature already damages and pulses; Stormbond **redirects** that pulse, it does not add a second 25%. Charge Coil must not apply Shock on chain hops (live rule stays unless a talent says so). Feedback only adds the heal pulse. Seedstorm is an exception to “Seeded requires Alteration.” Seedstorm bloom numbers stay live (18 splash / 90 bloom) unless playtest says otherwise.

## Lobby D/F (example)

Skills 50 starting points could unlock, not a required path:

- Eye of Tempest + Worldbloom (storm into plant)
- Eye of Tempest + Pyre (full DPS)
- Eye of Tempest + Iron Rampage (storm tank)

## Implementer notes

- This spec is the target. Live Storm Druid is still four trees in `ClassCatalog`. Do not wire this spec until asked.
- Live spends on `storm_druid_stormbloom_*` / `storm_druid_thunderhead_*` do not map. Loadout reset when shipping.
- Keep ultimate `skill_id` **eye_of_tempest** (new). Retired `tempest_bloom` / `eye_of_the_storm` binds do not exist on this spec.
- Mixed Lightning+Nature Wall: today style is one shape. Stormbloom does not talent the wall; Thunderhead uses the totem; Wildroot uses the ring.
- Fragile core: `unit.gd`, HUD, walls, compiler, CombatBalance. Extract only via `.cursor/rules/cleanup-protocol.mdc`.
- Verify with `scripts/windows/Verify-Ashenwake.ps1`. After a gameplay ship, OneNote via `scripts/windows/Update-AshenwakeOneNote.ps1`.

## Open questions

- New named statuses: **Stormbond**, **storm cloud** (Eye of Tempest). Drought is Wildroot’s, not this spec’s (Eye of Tempest has no Drought).
- Eye of Tempest jump: 10m vs dodge-replace. Spec locks recast jump, dodge unchanged.
- Eye of Tempest pulse at 40% vs stacking with Atonement ranks (spec locks 40%, no stack). Between retired Tempest Bloom 50% and baseline 25%.
- Stormbond cap during the window is 3 (between 2 and retired Tempest Bloom 4).
