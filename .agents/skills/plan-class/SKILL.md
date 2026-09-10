---
name: plan-class
description: Plans an Ashenwake spec talent tree from a short brief. Use when the user says plan a class, /plan-class, talent tree, tank/healer/mage kit, D/F skills, spec ultimates, or auto-attack choices. Emits one two-column spec with fillers; does not implement gameplay unless asked.
---

# Plan spec

Read `.cursor/rules/talent-trees.mdc` first. Node-card details: [reference.md](reference.md). Locked specs for a later implementer live in `docs/specs/` (system: `docs/talents/system.md`).

## Brief

Treat the whole user message (or `$ARGUMENTS` on `/plan-class`) as the brief. These are enough:

- `plan a tank spec`
- `/plan-class healer`
- `plan a fire spec, walls and burn, no ice`

Do not ask the user to fill Spec / Fantasy / Columns fields. Optional extra words (name, toys, bans) steer the proposal. If they only name a role, propose the spec name, two column themes, fillers, auto options, and the kit.

Stay in planning. Do not add scripts, scenes, workshop changes, or a lobby picker unless they explicitly asked to implement.

## Steps

1. Lock identity from the brief (role, how they fight). Keep their wording. The spec is **one** tree in the global pool; it does not own the character. Auto is the **auto row**, not a class pick.
2. Propose two named columns with distinct themes (left vs right). They share one combined ultimate. Add **filler passives** (mid) where a row needs padding; rows do not all need 3 talents.
3. Fill **tiers** (rows). Talents in a row do **not** need the same max rank. The player may take several talents in one row and stay in one column. Row `N` unlocks at **`N × 3`** points in this spec (7-row template: 0/3/6/9/12/15/18). Row 0 must offer **≥3** ranks. Last row is the ultimate at cost 1 (unlocks at 18). Include exactly **one auto row** (two exclusive `auto` options, max 1, optional filler). Mix row widths. At least two talents max 3. Cap is max 3; leave max-1 nodes at 1.
4. Every talent with max **2+** lists a payoff at each invested point (larger %/flat and/or a new rider). Leaving a talent unmaxed is a legal dip. The next row unlocks from **points above**, not from maxing a node.
5. Put at least **three interaction** talents in **each column**. Hook live combat toys: bases (bolt, missiles, ground_aoe, burst, aura, ray, meteor, nova, wall, wave, target), infusions (fire, ice, lightning, shadow, nature, divine, protection, wind, illusion), statuses (burn, chilled, shocked, afflicted, frozen, singe, scorch), altered, shields, threat. Make crafted QWER play differently; do not clone workshop augments.
6. Also put **at least 1** themed **% increase** passive in **each column**. Fillers may add more % passives (no cap of 2). Write a real percent. The auto options do not count as a % passive or an interaction.
7. Auto options: two mutually exclusive modifiers (numbers, element/rider, melee conversion if it fits). Assume they **stack** with other slotted specs’ auto rows. At most one melee conversion in a loadout. Optional auto-row filler is not exclusive.
8. While filling rows, **consider** a playstyle-changing buff or debuff (optional). Prefer live statuses first. A new named status is allowed if it changes decisions. Put numbers on it and list it under Open questions as new. Do not require one per column, and do not add a fifth hotkey.
9. Earlier talents are passives/interactions/auto. Only skills (ultimates, plus any extra actives the brief demands) go on D/F.
10. Emit the spec below. **Every damaging, healing, shielding, or % talent includes numbers**. Skills also list cooldown and duration. Tune against live CombatBalance (bolt hit ~42, nova ~130, meteor ~500, wall blast ~160, ground tick ~14, player HP **500**). Mark them as planning values, not locked slider rows. Do not author talent-button colors or row titles; the lobby uses one gold node (name left, rank right).

## Spec shape

```markdown
# Spec: <name>

## Identity
- Role:
- How they fight: <one or two sentences>
- Columns: <left theme> vs <right theme> (fillers sit mid)
- QWER: <what crafted spells are expected to do for this spec>
- D/F: <this spec’s ultimate; auto-fills D then F; Spellbook Swap exchanges them>

## Auto row
| Side | Name | Per point | Stance |
| L | … | 1: … | ranged or melee |
| M | … | 1: … / 2: … | filler, not exclusive |
| R | … | 1: … | ranged or melee |

## Tiers
Unlock = points in this spec on earlier rows. 7-row template: 0 / 3 / 6 / 9 / 12 / 15 / 18.

### Row 1 (unlock 0)
| Side | Name | Max | Type | Per point | Hook |
| L | … | 3 | passive | 1: … / 2: … / 3: … | … |
| M | … | 3 | passive | 1: … / 2: … / 3: … | … |
| R | … | 3 | passive | … | … |

### Row auto (unlock 9)
| Side | Name | Max | Type | Per point | Hook |
| L | … | 1 | auto | 1: … | auto |
| M | … | 3 | passive | … | auto |
| R | … | 1 | auto | 1: … | auto |

### Ultimate (unlock 18)
| Side | Name | Max | Type | Per point | Hook |
| shared | … | 1 | ultimate | 1: <active skill> | … |
```

Repeat a row block for each tier. Sides: `L` left column, `R` right column, `M` filler (or extra column nodes). More than three talents: extra `M` rows in the same table.

## Lobby D/F (example)
Unlocked skills auto-fill D then F. Spellbook Swap exchanges those binds. Talents tab does not pick them. 50 starting points typically finish two ultimates (~19 each) with a leftover dip, or one ultimate plus a deep second spec. Not a required spend path.

## Open questions
```

Types: `passive` | `interaction` | `auto` | `ultimate`. Hook is a base, infusion, status, `auto`, or `none`.
For max 1, `Per point` is a single `1:` line with numbers. For max 2–3, each rank is either a bigger %/flat of the same effect, a new rider, or both.
Each column must include **≥1** `passive` whose effect is a themed percent (example `+8% fire damage`) and **≥3** interactions.
The ultimate row has one skill.

## Fragment (common / uncommon / rare)

Not a real spec; copy the density, not the names. Mix row widths, max 3, auto exclusive, ult at 18.

```markdown
### Holdfast fragment — hold space vs peel
Row 1 unlock 0: Footing (L, passive 3) + Foundation (M, passive 3, +4% Ground AOE/rank) + Vow (R, passive 3).
Row 2 unlock 3: Undertow (L, interaction 2) + Halo (R, interaction 2).
Auto unlock 9: Ward Strike vs Aegis Shot.
Ult unlock 18: Hearthguard (shared, 1).
Left: ≥3 interactions, ≥1 %. Right: same. Fillers do not replace column quotas. Autos exclusive; filler is not.
```
