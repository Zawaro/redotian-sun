## 1. Locomotor data model

- [x] 1.1 Add `shares_cell`, `stand_upright`, `instant_turn`, `organic_path` (`bool`, default `false`) to `scripts/data/Locomotor.gd` in the Behavior Flags group
- [x] 1.2 Set all four flags on `resources/locomotors/Foot.tres` and `resources/locomotors/Jumpjet.tres`; confirm Amphibious and all other locomotors stay all-false

## 2. GlobalRules capacity knob

- [x] 2.1 Add `@export_group("Cell Occupancy")` + `shared_slots_per_cell: int = 3` to `scripts/data/GlobalRules.gd`; validate `>= 1`
- [x] 2.2 Set `shared_slots_per_cell = 3` in `resources/global_rules.tres`

## 3. CellSubPositions geometry

- [x] 3.1 Add `static func get_slot_count() -> int` (rules value via `GlobalRules.get_current()`, fallback `NUM_SLOTS`)
- [x] 3.2 Parameterize `get_sub_positions(cell, slot_count := -1)`, `get_sub_position(cell, slot, slot_count := -1)`, `min_slot_dist(slot_count)`; `-1` → `get_slot_count()`
- [x] 3.3 Keep `NUM_SLOTS = 3` and `MARGIN` as static defaults

## 4. SpatialHash

- [x] 4.1 `rebuild()` counts `mc._state == IDLE and mc.shares_cell()`; everything else marks `_blocked_cells` (replaces `stats.entity_type == INFANTRY`)
- [x] 4.2 Rename `_infantry_cell_counts` → `_shared_cell_counts`, `get_infantry_count` → `get_shared_cell_count`, `is_cell_full_for_infantry` → `is_cell_full_for_shared`, `get_full_infantry_cells` → `get_full_shared_cells`, `get_infantry_cells` → `get_shared_cells`
- [x] 4.3 Replace hardcoded `>= 3` caps with `>= CellSubPositions.get_slot_count()`
- [x] 4.4 Leave crush targeting (`get_crusher_blocking_cells`, `get_crushable_enemies_on_cell`) entity-type based

## 5. CellReservation

- [x] 5.1 Source capacity in `is_cell_full`, `_first_free_slot`, `get_available_sub_slot` from `CellSubPositions.get_slot_count()`
- [x] 5.2 Keep static `NUM_SLOTS` const for existing test loops

## 6. MovementController

- [x] 6.1 Delete `_is_infantry` var (L47) and its stats read (L81); MC no longer reads `entity_type`
- [x] 6.2 Add cached bools `_shares_cell`, `_stand_upright`, `_instant_turn`, `_organic_path` set in `_resolve_locomotor()` from `_locomotor_data`; expose public `shares_cell()`
- [x] 6.3 Swap occupancy gates to `_shares_cell`: booking (L204/302/326), landing (L380-381), waypoint offsets (L382-387), stacking pass (L526), idle-occupancy (L801), blocking (L779-782)
- [x] 6.4 Gate feel on cached bools: `stand_upright` (L738), `instant_turn` (L402), `organic_path` (L377 + L625)

## 7. Callers

- [x] 7.1 `FactoryComponent._is_cell_available` and `ExitComponent._is_cell_available` use `is_cell_full_for_shared`
- [x] 7.2 `EntityPlacer.place_entity` gates sub-slot placement on `get_locomotor(entity_data.locomotor).shares_cell`
- [x] 7.3 `SelectionManager.request_move` splits on `mc.shares_cell()` instead of `entity_type == INFANTRY`
- [x] 7.4 Rename `SelectionManager._find_infantry_cell` → `_find_sharer_cell` (capacity check already capacity-aware)

## 8. Tests

- [x] 8.1 Rename SpatialHash accessor references in `test_spatial_hash.gd`
- [x] 8.2 Add `_infantry_like(mc)` helper (sets the four cached bools); replace ~30 `mc._is_infantry = true` writes in `test_movement_locomotor_jumpjet.gd` and `test_combat_component_jumpjet.gd`; set the four flags on injected Locomotors in the `_jumpjet()` / `_make_jumpjet_combat()` helpers
- [x] 8.3 New: non-infantry `shares_cell = true` entity books a sub-slot and counts toward capacity (hypothetical vehicle, not the APC)
- [x] 8.4 New: `get_sub_positions(cell, 4)` returns 4 positions; non-sharing vehicle does NOT book
- [x] 8.5 New: SelectionManager formation splits on `shares_cell`; a non-infantry sharer distributes to a cell by capacity
- [x] 8.6 Run full suite (`redot --headless -s test/run_tests.gd`), then `gdlint` / `gdformat --check` + tab scan on edited files

## 9. Finalization

- [ ] 9.1 Archive the change to update `openspec/specs/`: add `cell-occupancy`, remove `infantry-occupancy`, deltas to `locomotor` / `cell-reservation` / `spatial-hash` / `selection-manager` (incl. requirement renames)
- [ ] 9.2 Commit on `feat/190-locomotor-shares-cell` (Conventional Commits, reference #190)
