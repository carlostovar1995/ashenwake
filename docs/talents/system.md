# Talent system

Design target for the spec pool, lobby slots, autos, and D/F. Live `ClassCatalog`, `TalentSpend`, `TalentPane`, and `ClassAutoAttack` follow this doc.

Follow `.cursor/rules/talent-trees.mdc` and `.cursor/skills/plan-class/SKILL.md`. Plan a new spec with `/plan-class`; write it to `docs/specs/`.

## What “class” no longer means

There is **no class pick**. The player slots up to **two specs** from a global pool. QWER stay crafted. D and F are spec skills from unlocked ultimates.

Retired four-tree classes (Fire Mage, Bulwark, Storm Druid) are split into the six specs below. Old docs in `docs/classes/` are stubs.

## Spec pool

| Spec | Role | Columns | Ultimate | Doc |
| Furnace | dps | Embers vs Detonation | Pyre | [kindling.md](../specs/kindling.md) |
| Crucible | dps | Frostfire vs Cinder | Ashen Crucible | [cinderfrost.md](../specs/cinderfrost.md) |
| Ironclad | tank | Plate vs Grudge | Iron Rampage | [aegis.md](../specs/aegis.md) |
| Holdfast | tank | Rampart vs Oath | Hearthguard | [bastion.md](../specs/bastion.md) |
| Lifegrove | healer | Canopy vs Grove | Worldbloom | [wildroot.md](../specs/wildroot.md) |
| Stormpulse | healer / dps | Stormbloom vs Thunderhead | Eye of Tempest | [tempest.md](../specs/tempest.md) |

## Lobby

- **2 spec slots.** Any mix of roles. No duplicate spec. Empty slots are legal.
- Changing a spec slot refunds that spec’s points (same idea as today’s class change).
- **50** starting points, shared across slotted specs.
- Each spec is a **WoW-style tree**: mixed row widths, same-column spends legal, next tier at **`N × 3`** points in this spec. Ultimate unlocks at **18** points in that spec (7-row trees).
- Typical spend: two finished ultimates (~19 each) plus a leftover dip, or one ultimate plus a deep second spec.
- No mandated path. Leftover points are not an error.
- **D and F:** unlocked skills auto-fill D then F. Refunding one clears that bind and does not move the other. The Spellbook **Swap** exchanges D and F (and their augments). The Talents tab does not pick binds. Combat does not rebind them. Extra unlocked skills beyond two stay unbound until a slot frees. Passives and auto options are never hotkeys.

### Hybrid examples

- **Damage tank:** Ironclad to Iron Rampage (~19) + Furnace dip. Damage writes threat; Ironclad auto adds extra threat.
- **Damage healer:** Lifegrove to Worldbloom + Stormpulse or Furnace dip.
- **Pure old-role:** Furnace deep + Crucible dip; Ironclad deep + Holdfast dip; Lifegrove deep + Stormpulse dip.

## Tiers (WoW-style)

Each spec is one tree:

- Every earlier row has **2+ talents**. Width can mix (two 1-point autos, four 3-point nodes). Invest in any of them. Same column is legal.
- Row `N` unlocks when this spec has **`N × 3`** points on earlier rows (7-row trees: 0 / 3 / 6 / 9 / 12 / 15 / 18). Refund only if remaining points would still unlock every invested later talent.
- Fillers are extra themed % passives. Columns still need ≥3 interactions and ≥1 % passive.
- Last node is a **shared ultimate**, cost 1, unlocks at 18 points in the spec.

### Lobby tree chrome

- No T1–T7 badges and no left/filler/right header bar.
- Every node uses the **same gold style** (autos, fillers, ultimates included). Do not color-code type or column.
- Button text: **name on the left**, **rank on the right** (`0/2`). Hover tip still lists type and per-point lines.

Talent ids: `spec_column_slug` (example `kindling_embers_live_coals`, `kindling_mid_cinder_focus`, `kindling_auto_cinder_shot`). Types: `passive` | `interaction` | `auto` | `ultimate`. Sides: `left` | `right` | `mid` | `shared`.

## Auto-attack

**Baseline (no auto talent):** ranged, **32** hit, **7.2m**, **1.05s** CD, **0.2s** windup, **no element, no rider**. Right-click is never empty. Not a fifth hotkey.

Each spec has **one auto row** (two exclusive `auto` options, max 1, optional filler). You may take **one option per slotted spec** (up to two). They **stack as riders** on the baseline.

- If **any** invested auto option is melee, the attack becomes melee (range, windup, and damage from that option). Other specs’ riders still apply to that melee hit.
- At most **one** melee conversion in the loadout. A second melee option is illegal until the first is refunded.
- Element: fire if any fire auto is taken, else lightning if any lightning auto is taken, else physical if melee, else none.

Example: Ironclad melee + Furnace burn-spread = **180** melee that stores/spreads Burn and still writes threat.

## Combat foundations

Not talent UI. Assumed live when specs are wired. Planning numbers vs CombatBalance: bolt 42, missiles 24, ground tick 14, burst 140, nova 130, wall blast 160, meteor 500, Target 80 / 7s / 12m, Protection shield ~2× base, shield 6s, Holy Blessing cap 10% DR / 8s, dodge 6m / 4.5s, nature heal ~17 after −60%, nature wall tick 16 / break 90 / 200 HP / 6s, lightning totem 200 HP / first hop 40% / 3 hops / 1s, Rejuv 6 HPS × 12 / 6s, Shock 100 / 10s / chain 20% at cap. Player HP **500**. Talent extras stay below a full crafted hit unless they are the ultimate. Planning values, not slider ids, until implement.

### Player HP and threat

- All real player HP is **500**. Do not raise baseline HP for slotting a tank spec. Extra HP, DR, shields, and heals come from talents. NPC raid tank still starts at 500 (Slab → 700) like the player.
- Threat: damage you deal writes threat (`DAMAGE_COEFF` 1.0). Healing splits across engaged enemies (`HEAL_COEFF` 0.5). **Taking damage does not generate threat** unless a talent says so.
- Passive DR from talents such as Spite, Brace, and Bodyguard **adds** (cap **50%**). Ultimate DR (Iron Rampage, Hearthguard) is a separate timed buff on the unit.
- Do not clone Menace 4×, Subtlety, or `shield.resist`.

### Enemy rank

- Values: `normal`, `rare`, `elite`.
- Today: training dummies and little adds = `normal`. Bosses (`is_boss`, Colossus, etc.) = `elite`. `rare` unused until new enemies exist.

### Chill / Freeze

Replaces 0.1% chill per ice damage toward a 100% freeze.

- Stacks **1–50**. Each stack = **1% slow** (50 stacks = 50% slow).
- **Freeze at 50 stacks.** Duration **5s**.
- Ice damage to reach 50 stacks depends on rank: normal **300** (6 per stack), rare **1000** (20 per stack), elite **2000** (40 per stack).
- Freeze DR after a freeze: normal **2.5s**, rare **6s**, elite **12s**.

### Shatter (Fire vs Frozen)

Global, not a Cinderfrost talent. A future frost spec can lean on this.

- Frozen is a 5s stun. Hits still deal **normal** damage (no 3x on the statue).
- A **hidden** Fire-vs-Shadow break bar fills from Fire and Shadow damage (including Burn and Afflict ticks). Ice and Lightning do not fill it. Rank sets the shell: normal **90**, rare **300**, elite **600**.
- First Fire hit does **not** Shatter. When the bar fills, the larger contributor pops it:
  - **Fire Shatter:** explosion is **3x** Fire contrib on the statue (Burn stores 50% of that), plus **40%** Fire splash in Burst radius.
  - **Shadow Shatter:** explosion is **1x** Shadow contrib on the statue, **40%** Ice splash, and **25%** of Afflict stacks copied to neighbors (cap 100). Origin keeps its stacks.
- Bar is not shown on the HUD. Freeze duration ending with the bar unfilled does not explode.

### Afflict (baseline)

- **1 damage per 4 stacks** each second. Shadow hits add 1 stack (the Afflict tick does not). **400** stacks max. Duration 10s.
- At 400 stacks that is **100** damage per second from Afflict.
- **No damage-taken amp at cap.** `CombatBalance` id `afflict.taken` exists at **0** and is **not applied** in `Unit.take_damage`.

### Combust

Not in combat. Only Furnace’s ultimate **Pyre** spends remaining Burn (see that spec). Do not put Combust on Fire+Lightning hits, Meteor, Burst, or other skills.

### Singe (Furnace)

Stacking fire mark from **Singe**. Fire hits (not ticks or autos) apply 1 stack, cap **3**, duration **6s**, refresh.

- At 3 stacks, Burst / Nova / Meteor / Pyre consumes the mark for **18 / 28 / 36** fire in **2.2m** (Singe 1 / 2 / 3). Rank 2 also lets Bolt / Missiles / Ray consume.
- Rank 3 copies **20%** remaining Burn to neighbors in **2.8m** (does not hop again). Does not consume Burn.

### Scorched (Furnace)

Zone snare from **Scorch**. Fire Ground AOE / Aura / Wall ticks apply **Scorched** **5s**.

- Snare **12% / 18% / 24%**. Fire hits vs Scorched store **+8% / +12% / +16%** extra of the hit as Burn.
- Rank 3: Pyre leftover splash **40% → 55%** and consumes Scorched.

### Frostfire (status)

Fusion mark. Talents key off this flag, not `has_burn && has_chill`.

- Flag, duration **6s** (Glaze 1: **8s**), refresh on application.
- Applied by Fire+Ice crafts (Kiln), by Ashen Crucible, and by Glaze 3 single-school hits vs a marked target.
- Does not Freeze. Does not Shatter. Burn still ticks; Chill still slows.
- Elite-safe: no 2000-ice freeze race.

### Rejuvenation

- **+6 HPS** per stack, max **12**, duration **6s**.
- New nature heals add a stack and refresh the duration.
- Nature does not damage enemies. Skillshots and missiles pass through enemies until they hit an ally or reach max range.

### Nature atonement pulse

- A damaging hit that carries Nature heals allies in **8.5m** for **25%** of dealt (`rejuvenation.pulse`) and applies Rejuvenation.
- Lightning+Nature mixed crafts deal enemy damage (they do not ghost) and already trigger this.
- Compound name **Tempestbloom** is already in the compiler for lightning|nature.

### Shock

- **1** stack per lightning hit, cap **100**, duration **10s**.
- Hits chain (up to **20%** of the hit at 100 stacks). Chain does not apply Shock. **20%** less damage each bounce.
- Lightning Wall: small totem, **200 HP**, chains to the nearest enemy every **1s** (**3** hops). First hop deals **40%** of the totem's current HP.

### Seeded

- Nature+Alteration on enemies: **5%** snare per seed, cap **8**. Fire spends a seed for an **18** splash. The **8th** seed blooms for **90** nature.
- Tempest **Seedstorm** applies Seeded without the Alteration augment. Fire is not required to spend seeds.

Do not clone workshop augments (Echo, Aftershock, Pierce) or retired Obsidian Shell.

## Implement notes

Talent ids are `kindling_*` / `cinderfrost_*` / `aegis_*` / `bastion_*` / `wildroot_*` / `tempest_*`. Mid fillers use `spec_mid_slug`.

Fragile core: `unit.gd`, HUD, walls, compiler, `CombatBalance`, `ThreatTable`. Extract via `.cursor/rules/cleanup-protocol.mdc`. Verify with `scripts/windows/Verify-Ashenwake.ps1`. After a gameplay ship, OneNote via `scripts/windows/Update-AshenwakeOneNote.ps1`.
