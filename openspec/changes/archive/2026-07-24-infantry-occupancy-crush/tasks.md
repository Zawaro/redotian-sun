## 1. StatsComponent — Expose Crusher/Crushable

- [x] 1.1 Add `@export var crusher: bool = false` and `@export var crushable: bool = false` to StatsComponent.gd
- [x] 1.2 Copy `crusher` and `crushable` from EntityData in `configure()` method

## 1b. HealthComponent — Add Kill Method

- [x] 1.3 Add `func kill() -> void` to HealthComponent.gd that directly sets `current_health = 0` and emits `health_zero` without firing `damage_taken`

## 2. Data Updates — Crusher/Crushable Flags

- [x] 2.1 Set `crushable = true` on 22 standard infantry .tres files (gdi_light_infantry, nod_light_infantry, gdi_disc_thrower, nod_rocket_infantry, gdi_medic, gdi_engineer, nod_engineer, gdi_umagon, gdi_ghost_stalker, gdi_chem_spray_infantry, nod_slavick, nod_chameleon_spy, nod_oxanna, civ_mutant, civ_mutant_sergeant, civ_mutant_soldier, civ_tratos, civ_tiberian_fiend, civ_technician, civ_civilian_1, civ_civilian_2, civ_civilian_3)
- [x] 2.2 Set `crushable = false` on 4 non-crushable infantry .tres files (nod_cyborg, nod_cyborg_commando, gdi_jumpjet_infantry, nod_mutant_hijacker)
- [x] 2.3 Set `crusher = true` on 18 vehicle .tres files (gdi_titan, gdi_disruptor, gdi_mcv, gdi_mammoth_mk2, gdi_mobile_sensor_array, gdi_harvester_docked, nod_mcv, nod_tick_tank, nod_stealth_tank, nod_subterranean_apc, nod_weed_eater, nod_mobile_repair_vehicle, nod_icbm, nod_devils_tongue, civ_school_bus, civ_locomotive, civ_train_car, civ_cargo_car)
- [x] 2.4 Set `crusher = false` on 3 explicit non-crusher vehicle .tres files (gdi_hover_mlrs, civ_truck, civ_truck_loaded)

## 3. SpatialHash — Infantry-Aware Cell Occupancy

- [x] 3.1 Add `_infantry_cell_counts: Dictionary` field to SpatialHash
- [x] 3.2 Modify `rebuild()` to enrich grid entries with `entity_type` and `player_id`, and track infantry counts in `_infantry_cell_counts`
- [x] 3.3 Add `get_infantry_count(cell) -> int` method
- [x] 3.4 Add `is_cell_full_for_infantry(cell) -> bool` method
- [x] 3.5 Add `get_crushable_enemies_on_cell(cell, player_id) -> Array` method

## 4. CellSubPositions — Sub-Position Utility (NEW)

- [x] 4.1 Create `scripts/core/CellSubPositions.gd` with `_hash_cell()`, `_mulberry32()`, `get_sub_positions()`, `get_sub_position()` static methods
- [x] 4.2 Implement rejection sampling: min 0.3 margin from edges, min 0.4 distance between slots

## 5. MovementController — Infantry Behavior + Crush

- [x] 5.1 Add fields: `_is_infantry`, `_crusher`, `_player_id`, `_assigned_slot`, `_sub_slot_position`, `_has_sub_slot`
- [x] 5.2 Cache entity type and crush flags from StatsComponent in `_ready()`
- [x] 5.3 Modify `set_target_position()`: infantry skip ROTATING, go directly to MOVING
- [x] 5.4 Modify `_is_cell_occupied_by_idle()`: infantry cells only blocked when full (≥3)
- [x] 5.5 Modify `_build_blocked_cells()`: include infantry cells with count ≥ 3 for infantry pathfinders
- [x] 5.6 Add crush logic: track `_last_position`, detect cell transition, query `get_crushable_enemies_on_cell(cell, _player_id)` (filters by player_id — only returns enemy crushable units), call `kill()` on each returned enemy
- [x] 5.7 Add repulsion bypass: skip repulsion when both entities are infantry
- [x] 5.8 Add `_claim_sub_slot()`: on IDLE transition, assign nearest sub-slot position

## 6. SelectionManager — Infantry Group Pre-Assignment

- [x] 6.1 Modify `request_move()`: separate infantry from vehicles using StatsComponent
- [x] 6.2 Add `_find_infantry_cell()` helper: spiral outward from target to find cell with capacity < 3
- [x] 6.3 Assign sub-slot positions to each infantry via `CellSubPositions.get_sub_position()`
- [x] 6.4 Set `_assigned_slot`, `_sub_slot_position`, `_has_sub_slot` on each infantry MovementController

## 7. ProductionManager — Sub-Slot on Spawn

- [x] 7.1 In `_spawn_unit()`: assign sub-slot position to spawned infantry via `CellSubPositions`

## 8. Tests

- [x] 8.1 Create `test/unit/test_cell_sub_positions.gd`: determinism, margin, spacing, slot count
- [x] 8.2 Create `test/unit/test_movement_controller_infantry.gd`: ROTATING skip, crush kills, crush doesn't kill friendly, repulsion bypass
- [x] 8.3 Update `test/unit/test_spatial_hash.gd`: add tests for `get_infantry_count()`, `is_cell_full_for_infantry()`, `get_crushable_enemies_on_cell()`
- [x] 8.4 Update `test/unit/test_selection_manager.gd`: add tests for infantry/vehicle split and `_find_infantry_cell()`
