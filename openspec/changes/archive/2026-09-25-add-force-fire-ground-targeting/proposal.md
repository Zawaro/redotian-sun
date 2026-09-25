## Why

The Ctrl modifier (`OrderResult.MOD_FORCE_ATTACK`) is carried from `MouseHandler.build_modifiers()` all the way down to `CombatComponent.get_order_for_target()`, but nothing in the ground path ever reads it: `UnitOrderGenerator.get_orders()` emits a MOVE whenever `target == null` before any component sees the modifier, `CombatComponent` early-returns `null` for a null target and gates behind `stats.player_id >= 0`, and `CombatComponent` has no way to engage a *position* at all. So Ctrl+click on empty ground, an ally, a neutral, or a bridge silently becomes a move. `openspec/specs/order-system/spec.md` already carries a `Force-fire into shroud gated` scenario for a feature that does not exist, and `stop-command`'s `Stop during combat` scenario is unimplemented.

## What Changes

- Ctrl+Left-click issues an **ATTACK** order against a ground cell, an ally/own entity, a neutral entity, or terrain — instead of a move. Without Ctrl the ground branch is byte-for-byte unchanged.
- `CombatComponent` gains a **ground engagement**: `_target_pos` becomes the source of truth and `_target` becomes optional. The engagement repeats on cooldown until a player move, the Stop command, or the shooter's death.
- **Force-fire ground targeting is blocked only by shroud.** Fog (explored, not currently visible) stays targetable; an unexplored cell degrades the order to a plain move. This **amends** the existing `order-system` fog requirement, whose ground clause currently keys on visibility.
- Guard auto-acquisition requires the candidate cell to be **visible to the owning player** (#446 first half). Once acquired, the engagement is **retained** even if the target later moves under shroud — no visibility drop gate. Player-ordered attacks are unaffected.
- Shots with no entity target resolve the **occupant of the impact cell**: the closest `HealthComponent` entity at that cell, excluding the shooter only — **allies take damage**.
- Cell overlays in the target cell take warhead damage in a second, disjoint pass: bridge and ice under `can_damage_walls`, tiberium under `can_damage_tiberium`. Both flags are currently dead data and get their first readers; **no new fields and no new `.tres`**.
- The Stop command clears the engagement, reverting the unit to idle while leaving guard free to re-acquire. Fixes the already-spec'd `stop-command` scenario for entity attacks too.
- **BREAKING** (behavior): Stop now cancels an in-progress attack, and guard no longer acquires an invisible enemy. Both were already written down as requirements.

## Capabilities

### New Capabilities

_(none — every requirement lands in an existing capability)_

### Modified Capabilities

- `order-system`: force-fire ground order generation and cursor; the ground clause of the fog requirement moves from a visibility test to a shroud (explored) test
- `combat-firing`: ground (position) engagement lifecycle, cell-occupant damage resolution, warhead-gated cell-overlay damage
- `guard-auto-engage`: visibility gate on acquisition; guard blocked by *engagement* rather than by an entity target
- `bridges`: warhead damageability of a LOW normal span, gated on `can_damage_walls`, honoring the existing destructibility split
- `ice-drowning`: warhead damageability of ice, gated on `can_damage_walls` and the `breakable_ice` feature

## Impact

**Scripts**
- `scripts/components/CombatComponent.gd` — position-first engagement (`_target_pos`, `set_ground_target()`, `is_engaged()`), order generation for null/neutral/ally targets, hitscan occupant resolution
- `scripts/components/GuardComponent.gd` — `_is_blocked()` keyed on `is_engaged()`; visibility gate in `_find_nearest_enemy()`
- `scripts/components/ProjectileController.gd` — seed `_last_known_target_pos` from an ordered position; null-victim detonation; impact FX when nothing takes damage
- `scripts/core/SpatialHash.gd` — `resolve_cell_victim()` (precedent: `get_crushable_enemies_on_cell()`)
- `scripts/core/OrderSystem.gd` — ground shroud gate beside `_fog_filter_target()`
- `scripts/orders/UnitOrderGenerator.gd` — ground branch consults `MOD_FORCE_ATTACK` for both `get_orders()` and `get_cursor()`
- `scripts/hud/MouseHandler.gd` — `apply_selection_hotkey(is_stop)` clears the engagement

**No changes** to packed scenes (`.tscn`), `EntityData`/`WarheadData`/`WeaponData` schemas, or any `.tres`. `MouseHandler`'s targeting paths are untouched — bridges are reached by occupant resolution at impact, not by the raycast.

**Data readers gained:** `WarheadData.can_damage_walls`, `WarheadData.can_damage_tiberium`.

**Related issues:** #264 (force-fire section), #446 (folded in and closed), #250 (LOW-span bridge destruction becomes reachable — its strength tuning and repair hut stay open).

**Docs:** `GLOSSARY.md` gains `force fire`, `ground engagement`, and `legal target`; the existing `fog-gated targeting` row is corrected for the fog/shroud split.
