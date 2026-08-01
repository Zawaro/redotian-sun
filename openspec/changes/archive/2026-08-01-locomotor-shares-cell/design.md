## Context

`MovementController._is_infantry` is set once in `_ready()` from `stats.entity_type == EntityData.EntityType.INFANTRY` (`scripts/components/MovementController.gd` L81) and gates 12 sites: booking (L204/302/326), exact sub-slot landing (L380-381), per-waypoint offsets (L382-387), stacking pass (L526), idle-occupancy (L801), blocking (L779-782), smooth path (L377), MOVING-vs-ROTATING (L402), spline easing (L625), and facing (L738). `SpatialHash.rebuild()` (`scripts/core/SpatialHash.gd` L72) counts IDLE infantry and marks every other entity's cell blocked; the cap `3` is duplicated in `CellSubPositions.NUM_SLOTS`, `SpatialHash.is_cell_full_for_infantry >= 3`, and `CellReservation.is_cell_full`. `SelectionManager.request_move` (L163) splits group moves by `entity_type == INFANTRY`. `shares_cell` has zero hits in the codebase (confirmed drift). Jumpjet infantry is an INFANTRY-type entity with its own `Jumpjet` locomotor and must keep booking sub-slots when walking. Amphibious is passability-only vehicle locomotion (`water` in `terrain_speeds`); it must not share cells.

## Goals / Non-Goals

**Goals:**
- Cell-occupancy participation and infantry-style movement feel live on the Locomotor; `MovementController` no longer reads `entity_type`.
- Cell capacity (`3`) becomes a GlobalRules data knob; sub-position geometry derives from it (moddability-first engine).
- Existing infantry behavior preserved (Foot + Jumpjet set the flags).
- Non-infantry `shares_cell = true` entities (future) share a cell, book slots, and form up like sharers.
- `crusher`/`crushable` remain independent per-entity flags; any entity may set both.

**Non-Goals:**
- Crush targeting (`get_crusher_blocking_cells`, `get_crushable_enemies_on_cell`) stays entity-type based — selecting which units can be crushed is gameplay, not movement.
- DeployComponent gating stays entity-type based — it filters movers from buildings, not movement feel.
- Per-locomotor cell capacity (e.g. Foot=3, hypothetical sharer=4). One global capacity knob; all sharers pool into the same ring.
- Sidebar/EntityBrowser UI stays entity-type based.

## Decisions

### D1. Locomotor owns movement behavior — four mix-and-match flags

`Locomotor.gd` gains `shares_cell`, `stand_upright`, `instant_turn`, `organic_path` (all `bool`, default `false`, in the existing Behavior Flags group). `shares_cell` is occupancy participation; the other three are infantry-style movement feel: `stand_upright` = facing normal is `Vector3.UP` (L738), `instant_turn` = skip ROTATING and enter MOVING directly (L402), `organic_path` = `smooth_path` (L377) + spline easing (L625). `Foot` and `Jumpjet` set all four; Amphibious and every other locomotor stay all-false.

The split is deliberate: future entities may need subsets — e.g. a vehicle that turns instantly (`instant_turn`) but still banks with the slope normal (`stand_upright = false`). A single `is_infantry` bundle would hardcode that combination and prevent mix-and-match.

### D2. `shares_cell` drives occupancy

Replace occupancy gates with the `_shares_cell` cache: booking (L204/302/326), exact landing (L380-381), waypoint offsets (L382-387), stacking pass (L526 → `_shares_cell and mc._shares_cell`), idle-occupancy (L801 → self plus entry MC), and blocking (L779-782 → `not _shares_cell and _crusher` / `not _shares_cell`). `SpatialHash.rebuild()` counts `mc._state == IDLE and mc.shares_cell()` and blocks everything else. `EntityPlacer.place_entity` gates sub-slot placement on `get_locomotor(entity_data.locomotor).shares_cell`.

`crusher` and `crushable` (StatsComponent/EntityData) are independent per-entity flags; any entity may set both. Crush targeting remains entity-type based — a crusher selects infantry-type crushable units; blocking logic keys off `shares_cell`. The two keys are intentionally different (movement occupancy vs crush gameplay) and documented as such.

### D3. Capacity knob in GlobalRules, single accessor

`GlobalRules.shared_slots_per_cell: int = 3` (new `@export_group("Cell Occupancy")`, validated `>= 1`). `CellSubPositions.get_slot_count()` is the single accessor: reads the rules value when `GlobalRules.get_current()` is loaded, else falls back to `NUM_SLOTS = 3`. The fallback keeps existing tests green (tests run without autoloads). `SpatialHash` and `CellReservation` read capacity through it.

Data-driven capacity is a deliberate engine goal: a moddable, rules-driven remake should not hardcode occupancy constants in code.

### D4. Geometry follows the slot count

`CellSubPositions` geometry parameterizes on slot count: `get_sub_positions(cell, slot_count := -1)`, `get_sub_position(cell, slot, slot_count := -1)`, `min_slot_dist(slot_count)`; `-1` resolves to `get_slot_count()`. The ring already emits `base_angle + i * TAU / count` positions, so any count produces valid, margin-respecting geometry. `NUM_SLOTS = 3` remains the static default.

### D5. Cached behavior bools, set in `_resolve_locomotor()`

`MovementController` caches the four behaviors as private bools (`_shares_cell`, `_stand_upright`, `_instant_turn`, `_organic_path`), assigned in `_resolve_locomotor()` from `_locomotor_data` — mirroring the existing `_is_hover` / `_is_jumpjet` / `_is_subterranean` pattern. Public `shares_cell()` exposes occupancy for SpatialHash and SelectionManager. Tests inject `_locomotor_data` without calling `_resolve_locomotor()` (no rules in tests), so they set the caches directly; a `_infantry_like(mc)` test helper replaces the ~30 `mc._is_infantry = true` writes.

*Alternative considered:* null-safe accessors reading `_locomotor_data` live. Rejected — inconsistent with the class's cached-flag idiom, adds a null window before `_resolve_locomotor()` runs, and per-call derefs in hot paths for no test benefit.

### D6. Rename cascade — code and specs

SpatialHash accessors rename: `_infantry_cell_counts` → `_shared_cell_counts`, `get_infantry_count` → `get_shared_cell_count`, `is_cell_full_for_infantry` → `is_cell_full_for_shared`, `get_full_infantry_cells` → `get_full_shared_cells`, `get_infantry_cells` → `get_shared_cells`. Consumers: FactoryComponent L110, ExitComponent L141, MovementController L782. Rename is required — the accessors count any `shares_cell` unit and would lie with infantry names.

The specs follow the code: the `infantry-occupancy` capability is renamed to `cell-occupancy` (its requirements REMOVED with migration, the generalized requirements ADDED under the new capability); requirement headers that both rename and change content use paired RENAMED + MODIFIED delta ops (e.g. `cell-reservation` "Combined infantry-scoped capacity" → "Combined sharing-scoped capacity", `spatial-hash` "Infantry cell capacity" → "Shared cell capacity").

### D7. SelectionManager formation keys off `shares_cell`

`request_move` (L163) splits the selection by `stats.entity_type == INFANTRY`. It becomes `mc.shares_cell()`: sharers distribute to cells by combined capacity (`_find_infantry_cell` → `_find_sharer_cell`, which already queries `CellReservation.is_cell_full` and becomes capacity-aware), non-sharers keep the offset-based vehicle formation. `_find_sharer_cell`'s capacity check now uses the rules knob automatically.

## Risks / Trade-offs

- **Jumpjet trap**: if `Jumpjet.tres` lacks `shares_cell`, jumpjet infantry silently stops booking sub-slots when walking (`test_jumpjet_walk_books_sub_slot` guards it). → Mitigation: both Foot and Jumpjet set the flags; the test stays green.
- **Test injection**: jumpjet/combat tests inject `_locomotor_data` and force `_is_infantry = true`. After the change the injected Locomotors must set the new flags, and the caches must be set. → Mitigation: `_infantry_like(mc)` helper centralizes cache writes in the affected test files.
- **Capacity vs geometry**: a knob that did not re-lay-out positions would clamp slots onto existing ones. → Mitigation: D4 parameterizes geometry; covered by a `get_sub_positions(cell, 4)` regression test.
- **`get_slot_count()` per-frame cost**: reads rules via `GlobalRules.get_current()` (scene-tree lookup). → Mitigation: callers resolve once per rebuild/move; the fallback path is a constant. Acceptable hot-path cost.
- **Future shares_cell vehicles** (test-only today): repulsion/pathing/formation feel is untested against a real unit. → Mitigation: covered by the acceptance tests; the APC is deliberately not flipped.
- **Spec capability rename** touches the archive merge (REMOVED + ADDED across capabilities). → Mitigation: migration notes on every REMOVED requirement; validate the change before archiving.

## Migration Plan

1. Add the four flags to `Locomotor.gd`; set them in `Foot.tres` + `Jumpjet.tres`.
2. Add `shared_slots_per_cell` to `GlobalRules.gd` + `resources/global_rules.tres`.
3. Parameterize `CellSubPositions` (D4) and add `get_slot_count()`.
4. Rewrite `SpatialHash.rebuild()` counting on `mc.shares_cell()`; rename accessors (D6).
5. Source `CellReservation` capacity from `get_slot_count()`.
6. `MovementController`: delete `_is_infantry`; add cached bools (D5); swap gates per D1/D2.
7. Update callers: FactoryComponent, ExitComponent, EntityPlacer.
8. `SelectionManager`: split on `mc.shares_cell()`; rename `_find_infantry_cell` → `_find_sharer_cell` (D7).
9. Tests: rename references, `_infantry_like` helper, new coverage (sharing, capacity, geometry, formation).
10. Land on `feat/190-locomotor-shares-cell`, archive the change (capability rename + requirement renames).

Rollback: revert flag/tres/GlobalRules additions and gate swaps; existing behavior is preserved by Foot+Jumpjet flags and the `get_slot_count()` fallback.

## Open Questions

- Mixed sharers (infantry + future vehicle) pool into one shared ring — acceptable?
- Jumpjet `shares_cell` is mode-blind: it shares when grounded, but the boolean cannot express "shares only on the ground." No regression today; revisit when a second hybrid locomotor exists.
- Should `organic_path` eventually fold `smooth_path` out (it is a cosmetic walk curve; currently stays with the flag that also eases spline ends)?
