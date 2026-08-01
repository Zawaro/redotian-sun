## Why

Cell occupancy and movement feel are hardcoded to entity type. `SpatialHash` counts IDLE `INFANTRY` per cell (capped at 3), `CellReservation` books infantry sub-slots, and `MovementController._is_infantry` (derived from `stats.entity_type == INFANTRY`) gates ~12 behaviors spanning cell-sharing, path shaping, turn behavior, and stance. This is GH #190 — drift from #34, where `shares_cell` was specced on `Locomotor` but never implemented.

The capacity "3" is additionally hardcoded in three places (`CellSubPositions.NUM_SLOTS`, `SpatialHash >= 3`, `CellReservation`) and couples capacity to the sub-position geometry. Whether a unit shares a cell — and how it moves — is a movement-behavior property of its Locomotor, not its species.

## What Changes

- `Locomotor` gains behavior flags `shares_cell`, `stand_upright`, `instant_turn`, `organic_path`. Cell-occupancy participation and infantry-style locomotion derive from the Locomotor, never from `EntityData.EntityType`.
- `MovementController` stops reading `entity_type` entirely: the `_is_infantry` cache and its stats read are deleted; behavior is read from the resolved Locomotor via null-safe accessors.
- `GlobalRules` gains `shared_slots_per_cell: int = 3` — a data knob for cell capacity, replacing the hardcoded constant.
- `CellSubPositions` geometry follows the configured slot count (was the `NUM_SLOTS = 3` const), so changing the knob re-lays-out the sub-position ring.
- `SpatialHash` occupancy counting and `CellReservation` sub-slot booking key off `shares_cell` against `shared_slots_per_cell`; infantry-named accessors are renamed to shared-cell semantics.
- `Foot` and `Jumpjet` set the new flags, preserving current infantry behavior.
- Crush targeting and deploy gating remain entity-type based (gameplay, not movement); `crusher`/`crushable` stay independent per-entity flags any entity may set.
- `SelectionManager` group-move formation splits by `shares_cell` instead of entity type: sharers distribute to cells by combined capacity, non-sharers keep offset-based vehicle formation.

## Capabilities

### New Capabilities
- `cell-occupancy`: shared-cell capacity (`shares_cell`-scoped, `GlobalRules.shared_slots_per_cell` knob), sub-slot positioning following the configured slot count, and sharing repulsion bypass. Supersedes `infantry-occupancy`.

### Modified Capabilities
- `locomotor`: add `shares_cell`, `stand_upright`, `instant_turn`, `organic_path`; MovementController occupancy and infantry-style movement driven by the Locomotor.
- `infantry-occupancy`: superseded by `cell-occupancy` (requirements removed, migrated).
- `cell-reservation`: combined capacity sourced from `CellSubPositions.get_slot_count()`; requirement renamed to shared-cell terminology.
- `spatial-hash`: occupancy counting keyed on `mc.shares_cell()`; accessor renames; capacity from rules; requirement renamed.
- `selection-manager`: group-move formation split keys off `shares_cell` instead of `entity_type`.

## Impact

- **Modified scripts**: `scripts/data/Locomotor.gd`, `scripts/data/GlobalRules.gd`, `scripts/components/MovementController.gd`, `scripts/core/SpatialHash.gd`, `scripts/core/CellReservation.gd`, `scripts/core/CellSubPositions.gd`, `scripts/entities/EntityPlacer.gd`, `scripts/components/FactoryComponent.gd`, `scripts/components/ExitComponent.gd`, `scripts/core/SelectionManager.gd`.
- **Modified resources**: `resources/locomotors/Foot.tres`, `resources/locomotors/Jumpjet.tres`, `resources/global_rules.tres`. No scene changes.
- **Tests**: `test_spatial_hash.gd`, `test_cell_sub_positions.gd`, `test_movement_locomotor_jumpjet.gd`, `test_combat_component_jumpjet.gd`, `test_selection_manager.gd`; new tests for non-infantry `shares_cell`, rules-driven capacity, geometry parameterization, and sharer formation.

## Related

- GH #190 (this issue), GH #34 (origin of the `shares_cell` drift).
