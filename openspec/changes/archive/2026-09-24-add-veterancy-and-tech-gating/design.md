## Context

Veterancy and tech level both exist as data but dead-end at runtime.

- `StatsComponent` stores `veteran_level`, `sight`, `tech_level`, `trainable` and `armor`.
- `HealthComponent.gd:33`, `CombatComponent.gd:155` and `MovementController.gd:167` already multiply damage/speed/ROF by `GlobalRules` veteran helpers, but nothing ever assigns a rank above `0`.
- `HealthComponent.take_damage(damage, type)` carries no attacker, so no death can be credited.
- `PrerequisiteSystem.can_build(player_id, data)` is the single funnel for `Sidebar.gd:260` and `ProductionManager.gd:84`, but it never compares `tech_level`; the field is only a sidebar sort key (`Sidebar.gd:287`).

The reference implementation is OpenTS (the TS 2.03 reconstruction). The actual engine source was read for this design: `veteran.cpp` (`Made_A_Kill`, rank predicates), `techno.cpp:5335-5342` (kill credit gate), `house.cpp:895-925` (`Can_Build` tech gate), `techtype.cpp:104,620` (`Level` default 255). The OpenTS manual confirms the semantics for `Trainable`, `VeteranRatio`, `TechLevel` and `InitialVeteran`.

## Goals / Non-Goals

**Goals:**
- Make rank reachable through combat: credit the killer, accumulate experience, derive rank, emit promotion.
- Wire the remaining rank consumers (`veteran_sight`, `veteran_rof`) and show rank on the selection overlay.
- Gate the build list on a per-player current tech level sourced from scenario/session.
- Add `StatsComponent` identity helpers and delete the copy-pasted mobile-unit predicate.
- Keep the change backward compatible with existing scenes and `.tres` data.

**Non-Goals:**
- Elite weapon substitution (`Elite=`), veterancy crates, Armory servicing, `TeamType.VeteranLevel`, ability-token gating (`VeteranAbilities`/`EliteAbilities`), self-heal/scatter/etc.
- The building-raises-house-tech-level behavior (ModEnc) — OpenTS does not implement it; house level is fixed per scenario/session.
- The `StatsComponent.get_armor_modifier()` API from issue #37 — armor resistance is a `(warhead × armor)` property and stays on `GlobalRules`/`WarheadData`.
- Price/house multipliers in the XP formula (no such system exists yet).

## Decisions

### 1. Kill attribution lives in a `VeterancySystem` autoload, not in `HealthComponent`
`HealthComponent` gains an optional `source` on `take_damage` and records `last_attacker`; on death it emits a new `killed(killer)` signal (the existing no-arg `health_zero` is untouched, preserving its seven listeners). `VeterancySystem` registers every `HealthComponent` via `get_tree().node_added` — the same registry pattern as `RadarSystem`, and robust to component add order since it keys on the death source rather than on `StatsComponent` — and, on `killed`, resolves the killer's and victim's `StatsComponent` and credits the killer.

Alternative considered: letting `HealthComponent` call `attacker.StatsComponent.add_kill_experience(...)` directly (smaller diff). Rejected because the XP rules (Trainable, ally, ratio, cap) are non-trivial and belong in one testable home; scattering them into `HealthComponent` couples a low-level component to the veterancy economy. The system is the 30th autoload, matching the codebase's existing registry-autoload convention.

### 2. The credit formula follows OpenTS exactly
On a credited kill: `experience += victim_cost / (killer_cost * veteran_ratio)`, then `experience = min(experience, veteran_cap)`. Both figures are the entities' `EntityData.cost` (not `points`), matching `techno.cpp:5341` and the manual. Rank is read off `experience`, not stored independently: `<1` rookie, `[1,2)` veteran, `≥2` elite (`veteran.cpp:125-163`). `veteran_level` remains the stored, derived rank so existing consumers keep reading the same field.

Gates (from `techno.cpp:5341`): the killer's type must be `Trainable`, and the victim's owner must not consider the killer allied. A null killer (capture/sell/sink) credits nobody. No zero guard exists upstream; we add one (`veteran_ratio <= 0` or `killer_cost <= 0` → no credit) to avoid a divide-by-zero crash, documented as a deliberate divergence.

### 3. `trainable` defaults by entity type, overridable only upward
OpenTS defaults `Trainable=yes` for aircraft/infantry/unit and `no` for buildings (`techtype.cpp:175`, `builtype.cpp:372`). We derive it in `StatsComponent.configure`: `trainable = data.trainable or entity_type != BUILDING`. Units are therefore always trainable; a defensive structure opts in with `trainable = true` in its `.tres`. This avoids a 240-file data migration and avoids making every default entity unbuildable-under-a-new-default. A unit type that TS marks `Trainable=no` cannot be represented — an accepted simplification.

### 4. `-1` matches original TS: permanently unbuildable
OpenTS rejects `TechLevel=-1` outright (`house.cpp:906`) and defaults an omitted level to 255 (also effectively unbuildable). We adopt the same semantics: `tech_level == -1` (or omitted, since the field defaults to `-1`) is never buildable, and any positive value requires `player.tech_level >= entity_data.tech_level`. Because `GLOSSARY.md:229` and the `EntityData` field comment previously read `-1 = always available`, those are updated. Of the 73 buildable entities, only `gdi_mcv` and `nod_mcv` sit at `-1`; both are migrated to `tech_level = 1` so they remain buildable. Non-buildable civilians and map-only variants keep `-1`, which now reads as "never in the build list" — consistent with their `buildable = false` flag. A positive level at or below the scenario/session level is effectively "always available", which is how original TS expresses availability.

### 5. Current tech level is per-player and resolved at mission start
`PlayerData` gains `tech_level`. `Mission` gains `tech_level: int = -1` (inherit sentinel, matching `starting_credits`); `GlobalRules` gains a default (`10`, the OpenTS `[MultiplayerDefaults] TechLevel` default). `PlayerManager` resolves mission override → rules default onto each player at `begin_mission`/`_init_defaults`. The gate reads `PlayerManager.get_player_data(player_id).tech_level`. Per-player (not session-wide) is chosen so a future multiplayer lobby can hand each house its own level without a data migration; today all houses get the same value.

### 6. Rank bonuses stay level-based
Our `global-rules` spec applies combat/speed/armor multipliers directly from `veteran_level`. OpenTS instead gates every bonus on ability tokens (`FASTER`, `STRONGER`, `FIREPOWER`, `SIGHT`, `ROF`) carried by `VeteranAbilities`/`EliteAbilities`. Introducing ability lists is a much larger change and the existing spec already committed to the level-based model, so we keep it and add only the two missing multipliers (`veteran_sight`, `veteran_rof`).

### 7. Sight and ROF consumers
`VisionComponent` currently reads `data.sight` once in `configure()`. It connects to `StatsComponent.veterancy_changed` and re-registers its revealer with `sight × veteran_sight multiplier` when the rank changes (the docsheet notes sight is applied inside the reveal routine, so a refresh is required — matches `veterancy.md`). `CombatComponent` divides its reload delay by the veteran ROF multiplier on the existing `60/rof` path.

## Risks / Trade-offs

- **Kill credit across a freed projectile owner** → `VeterancySystem` resolves the killer from the recorded node and guards `is_instance_valid` before awarding; a freed killer credits nobody rather than erroring.
- **`-1` now means unbuildable, changing a long-standing local meaning** → all 73 buildable entities already carry a positive level except the two MCVs, which are migrated in the same change; the field comment and `GLOSSARY.md` are updated so the new meaning is discoverable.
- **Derived `trainable` cannot express `Trainable=no` units** → accepted; noted in the veterancy spec. Upgrading later means a tri-state field, not a breaking data change.
- **`VeterancySystem` as a 30th autoload** → mirrors `RadarSystem`'s tested registry pattern; no polling, event-driven only.
- **Rank display needs insignia art** → `SelectionOverlay` already draws pips; the insignia reuses the pip-drawing path with a distinct marker, so no new art pipeline is required. If art is missing, the requirement is still satisfied by a drawn glyph.
- **Experience credited to the wrong entity when several attackers are involved** → credit is keyed to the source recorded on the fatal `take_damage` call, so only the last damager is credited, matching `techno.cpp`.
