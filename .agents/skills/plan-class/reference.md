# Plan-spec node cards

Use from `SKILL.md` when filling a spec. Do not contradict `.cursor/rules/talent-trees.mdc`.

## Per talent

- `id`: `spec_column_slug` (example `aegis_plate_brace`, `kindling_auto_cinder_shot`, `kindling_mid_cinder_focus`)
- `name`: short player-facing label
- `max`: 1 through **3** (how many points can be invested)
- `type`: `passive` | `interaction` | `auto` | `ultimate`
- `per point`: one mechanical line per invested point
- `hook`: spell base, infusion, status, `altered`, `shield`, `threat`, `auto`, or `none`
- `side`: `left` | `right` | `mid` | `shared` (ultimate only)

## Scaling

- **Max 1**: one effect with numbers. Ultimates and auto options are always this (ultimates include damage/heal/shield, radius, duration, cooldown).
- **Max 2–3**: two legal patterns (mix them in a spec):
  - **Number scale**: same effect, larger % or flat (40 shield → 70 shield, +4% / +7% / +10%).
  - **Rider**: keep the earlier effect and add a new one at a later rank (absorb heal → absorb heal + threat pulse).
- You may leave a talent at 1/3 and keep only those ranks. The next **row** unlocks from **points in earlier rows** (`N × 3`), not from maxing this talent.
- Do not put max 2–3 on a talent with identical text at every rank.
- Talents in a row **do not** need the same max. Types may differ.

## Numbers

- Every damage, heal, shield, and % buff must have a number. No `+X%`, “a little,” or “brief.”
- % passives: typically **+5% to +12%** for a max-1. Max-3 fillers about **+3% to +4% per rank**. Number-scale max 3 can step a column passive (example +4% / +8% / +12%).
- Flat hits and ticks should sit near CombatBalance: bolt ~42, missiles ~24, ground tick ~14, burst ~140, nova ~130, wall blast ~160, meteor ~500, nature wall heal tick ~16. Player HP **500**. Talent extras and pulses should usually be **below** a full crafted hit unless they are the ultimate.
- Planning values, not `CombatBalance` slider ids, unless the user asked to implement.

## Per spec

- One tree. **7 rows** is the template (6 play rows + ult). Row `N` unlocks at `N × 3` points in this spec (0/3/6/9/12/15/18). Ultimate unlocks at **18**.
- Row 0 must offer **≥3** ranks. For every later row, earlier max ranks must sum to at least that row’s unlock cost.
- Last talent is always `ultimate` (active skill), always 1 point to unlock, no scale list beyond `1:`, **shared**.
- Exactly one `auto` row, two exclusive options (max 1), optional non-exclusive filler.
- Each column: at least three `interaction` talents and **≥1** themed `%` passive. Fillers may add extra % passives (no cap of 2). Auto options count as neither.
- You may take every talent in a row. Same-column spends are intended.
- Mix row widths. Cap is max 3. At least two max-3 talents. Never two ultimates. Do not bump a max-1 talent to 3.
- Lobby nodes are **one gold style** for every type. Name left, rank right (`0/2`). No T1–T7, no column header bar, no auto/filler/ultimate tints. Do not specify button colors in the spec writeup.

## Live hooks (prefer these)

- Bases: bolt, missiles, ground_aoe, burst, aura, ray, meteor, nova, wall, wave, target
- Infusions: fire, ice, lightning, shadow, nature, divine, protection, wind, illusion
- Statuses: burn, chilled, shocked, afflicted, frozen
- Other: altered, shield, threat, holy blessing, rejuvenation, frostfire, singe, scorch, auto

## Playstyle toys (optional)

Not a quota. When an interaction would otherwise be “more damage,” consider a buff or debuff that changes how the spec is played: a stance, a mark, a short window, a resource, a movement rule. Reuse a live status if it fits. If it does not, propose a **new named status** with duration, stacks/cap, and what it does. Flag it as new under Open questions. Do not add extra combat hotkeys.

## Auto-attack

Not a spec-pick identity. Everyone starts with the **baseline** ranged auto (32 hit, 7.2m, 1.05s CD, 0.2s windup, no element, no rider). Each spec’s auto row adds one of two riders. Riders from different slotted specs **stack**. Melee conversion is unique (at most one in the loadout). Element: fire if any fire auto, else lightning if any lightning auto, else physical if melee, else none.

Retired class autos (do not bake these into a spec slot; they are auto-row options or stacks):

- Old Fire Mage: Fire. Stores Burn. If the target has Burn, copy 25% of remaining Burn, split among enemies in 2.8m.
- Old Bulwark: Melee. 180 physical. +24 extra threat. Each hit restores 10 mana to every living raid member.
- Old Storm Druid: Lightning vs enemies (1 Shock). Allies: 14 nature heal + 1 Rejuvenation.

Do not copy a QWER craft. Do not add a hotkey.

## D/F

Only **skills** (ultimates, and extra actives if the brief adds them) go on D/F. They auto-fill D then F; Spellbook Swap exchanges them. Passives and auto options are never hotkeys. Example pairings are illustrative. The player has up to two spec slots; **50** points typically finish **two** ultimates (~19 each) with a leftover dip.

## Live pool

Do not clone an existing spec’s columns or ultimate. Live / locked specs:

- Furnace, Crucible — `docs/specs/kindling.md`, `docs/specs/cinderfrost.md`
- Ironclad, Holdfast — `docs/specs/aegis.md`, `docs/specs/bastion.md`
- Lifegrove, Stormpulse — `docs/specs/wildroot.md`, `docs/specs/tempest.md`
