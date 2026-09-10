# Spec: Ironclad

Target spec (`spec_id` `aegis`, display **Ironclad**). Combines retired Bulwark **Plate** and **Grudge**. Not wired. Follow `.cursor/rules/talent-trees.mdc` and `docs/talents/system.md`.

**50** starting points shared across up to 2 spec slots. WoW-style tiers: 7-row trees unlock at 0 / 3 / 6 / 9 / 12 / 15 / 18 in this spec. Ultimate unlocks at 18. Same-column and same-row spends are legal. Rows mix widths (2–4 talents). Rank cap is 3.

Talent ids: `aegis_<column>_<slug>` / `aegis_auto_<slug>`. Types: `passive` | `interaction` | `auto` | `ultimate`. Columns **plate** (left) and **grudge** (right). Ultimate `skill_id` **iron_rampage**.

Rarity: one rare (row 5, max 3), one uncommon (row 4, max 2). Brace and Ire are the rares.

Planning numbers vs CombatBalance: bolt 42, Target 80 / 7s / 12m, nova 130, ground tick 14 / 18s CD, wall 160 blast / 800 HP / 35s CD, Protection shield ~2× base, shield 6s, Holy Blessing cap 10% DR / 8s, dodge 6m / 4.5s, player HP 500. Do not clone Menace 4×, Subtlety, or `shield.resist`. Planning values, not slider ids, until implement.

Folded out: Hard Ward into Second Skin 2 (shield amount); Live Wire dropped (lightning-specific); Lunge into the melee auto option; Peal into Ire 3.

## Identity

- Role: tank
- How they fight: Crafted Protection / Divine on QWER to live. Damaging infusions plus threat on QWER to keep packs. Target-base crafts taunt if you take Goad. Finish the spec for **Iron Rampage**. Mix Kindling or Tempest for a tank that deals damage to generate threat.
- Columns: **Plate** (live through hits) vs **Grudge** (keep aggro).
- QWER: Protection Bolt / Aura / Ray / Ground for shields; Divine for Holy Blessing; Target on enemies for taunt (Goad). Trees do not occupy QWER.
- D/F: Iron Rampage. Goad is a Target-base interaction, not a D/F bind.

Combat foundations (HP 500, threat coeffs, DR cap): `docs/talents/system.md`. Slab at +40% on 500 HP → **700**. Passive DR from Spite and Brace **adds** (cap 50%). Iron Rampage DR is a separate timed buff.

### Aggro

- **Plate — Anointed:** each hit you take generates 40 threat on that attacker (while Holy Blessing).
- **Grudge — Goad + Claim:** Target-base on an enemy taunts; Claim is extra threat on damaging crafts. Ire 3 also makes Nova and Burst generate 2.5× threat.

## Auto row

Baseline if this row is skipped: ranged 32, 7.2m, 1.05s, no element. Riders stack with other slotted specs. Melee conversion is unique in the loadout. See system doc.

| Side | Name | Per point | Stance |
| L | Iron Fist | 1: Melee 180 physical, 2.4m, 0.85s, 0.22s windup. +24 extra threat. Each hit restores 10 mana to every living raid member. Dodge 8m (from 6), dodge CD 3.6s (from 4.5) | melee |
| R | Goading Shot | 1: Stay ranged. Autos generate 40 extra threat and restore 8 raid mana | ranged |

## Rows

Earlier on a path 1+1+1+1+2+3 = 9. Ultimate 1. Total 10.

Left (Plate): one % passive (Slab), four interactions (Second Skin 2 also scales shield heal; Hard Ward folded into Second Skin 2). Right (Grudge): two % passives (Spite, Marked Prey), three interactions.

| Row | Max | Type | Left | Left per point | Left hook | Right | Right per point | Right hook |
| 1 | 1 | passive | Slab | 1: +40% max health (500 → 700) | none | Spite | 1: +10% damage and 12% DR | none |
| 2 | 1 | interaction | Shared Plate | 1: Protection shield on an ally also gives you 80 shield for 6s (once per cast) | protection / shield | Goad | 1: Crafted Target on an enemy taunts 3s. Ally Target does not. After Goad: +20% move for 2s | target / threat |
| 3 | 1 | interaction / passive | Anointed | 1: While Holy Blessing: each hit generates 40 threat on that attacker. Divine-heal 40, 1s internal cooldown | divine / threat | Marked Prey | 1: Enemies you hold aggro on take +10% damage from you only. Whole pack. Allies do not deal extra | threat |
| auto | 1 | auto | Iron Fist | 1: Melee 180 physical, 2.4m, 0.85s. +24 extra threat. 10 raid mana per hit. Dodge 8m (from 6), dodge CD 3.6s (from 4.5) | auto | Goading Shot | 1: Stay ranged. Autos +40 threat and 8 raid mana | auto |
| 4 | 2 | interaction | Second Skin | 1: Shield absorb Protection-heals 50 / 2: 90, and +20% shield amount. 1s internal cooldown | protection / shield | Claim | 1: Damaging crafts +20% threat / 2: +35% | threat |
| 5 | 3 | interaction | Brace | 1: While shielded, 10% DR / 2: 16% DR / 3: 22% DR. Also divine-heal 40 every 1s while shielded | shield / divine | Ire | 1: Shield = 25% of threat that hit generated, 6s, cap 80 per hit / 2: cap 120 per hit / 3: Also Nova and Burst generate 2.5× threat | threat / shield / nova / burst |
| ult | 1 | ultimate | Iron Rampage | 1: Instant self, 7s, 22s CD. 40% DR, +20% damage, +40% threat from damaging crafts, +10% move. Each hit taken grants 60 shield for 6s | threat / shield | — | — | — |

Goad’s post-taunt move is the Lunge fold that is not dodge (dodge lives on Iron Fist). Marked Prey is a source-filtered taken amp on mobs the tank holds, not a raid damage-taken buff.

## Lobby D/F (example)

Skills 50 starting points could unlock, not a required path:

- Iron Rampage + Pyre (damage tank)
- Iron Rampage + Hearthguard (full tank)
- Iron Rampage + Worldbloom (off-tank healer)

Goad is a Target-base interaction, not a D/F bind.

## Implementer notes

- This spec is the target. Do not wire catalog, TalentHooks, or combat until asked.
- Live spends on `bulwark_plate_*` / `bulwark_grudge_*` do not map. Loadout reset when shipping.
- Keep ultimate `skill_id` **iron_rampage** (new). Retired `ironhide` / `rampage` binds do not exist on this spec.
- Iron Fist is the unique melee conversion for this spec. Bastion’s melee option cannot be invested while Iron Fist is invested.
- Fragile core: `unit.gd`, HUD, walls, compiler, `CombatBalance`, `ThreatTable`. Extract via `.cursor/rules/cleanup-protocol.mdc`.
- Verify with `scripts/windows/Verify-Ashenwake.ps1`. After a later gameplay ship, OneNote via `scripts/windows/Update-AshenwakeOneNote.ps1`.

## Open questions

- Ire 2 is a cap scale (80 → 120) so the max-3 is not identical text; Peal is the rank-3 rider.
- Live Wire (Shocked bonus threat) is dropped, not folded. A later lightning-tank mix uses Tempest autos + Claim.
