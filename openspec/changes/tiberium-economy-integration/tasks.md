## 1. Map Editor UI Restructure

- [x] 1.1 Restructure `MapEditor._setup_ui()` to use a top toolbar row (horizontal layout) with minimap in top-right
- [x] 1.2 Add toggleable Paint Height, Paint Tiberium, Place Tree, Erase buttons with radio-button exclusivity
- [x] 1.3 Add Strength HSlider (0–100%) and Radius SpinBox to toolbar
- [x] 1.4 Add `_painted_entities: Dictionary` tracking to MapEditor

## 2. Paint Tiberium & Erase Tools

- [x] 2.1 Implement paint tool: `EntityFactory.create_entity("TIB", overrides)` per cell within radius, stacking amounts on existing pods
- [x] 2.2 Implement erase tool: reduce amount per cell within radius by `strength% * max_amount`, despawn entity at ≤ 0
- [x] 2.3 Support brush radius: all cells within radius affected per click pass
- [x] 2.4 Position entities at cell center (cell size 2×2)
- [x] 2.5 Update entity tracking on paint/erase (add/remove from `_painted_entities`)

## 3. Place Tree Tool

- [x] 3.1 Implement tree placement: single-click creates TiberiumTree entity via EntityFactory at cell center
- [x] 3.2 Implement replace behavior: if cell occupied, remove existing entity before placing tree
- [x] 3.3 Ensure drag does not trigger tree placement (only single-click)

## 4. MapLoader & JSON Persistence

- [x] 4.1 Create `scripts/maps/MapLoader.gd` — reads JSON, calls TerrainSystem + EntityFactory
- [x] 4.2 Bump JSON version to 3 in TerrainSystem.export_to_json()
- [x] 4.3 Add `"entities"` array serialization to export flow
- [x] 4.4 Wire MapLoader into editor save/load and game map load

## 5. FreeUnitComponent

- [x] 5.1 Create `scripts/components/FreeUnitComponent.gd` — spawns free unit on _ready(), then queue_free()
- [x] 5.2 Implement adjacent free cell search (orthogonal → diagonal, up to 5 cells)
- [x] 5.3 Add `_preview` meta guard: skip spawn if parent.get_meta("_preview") is true
- [x] 5.4 Set `_preview` meta on ghost entity in `BuildingManager._create_building_preview()`
- [x] 5.5 Wire FreeUnitComponent in EntityFactory._add_components() (add when data.free_unit is non-empty)
- [x] 5.6 Update gdi_refinery.tres: add `factory = "HarvesterType"`, `free_unit = "HARV"`

## 6. Tiberium Self-Destruct on Depletion

- [x] 6.1 Implement self-destruct in `TiberiumComponent.collect()` when amount ≤ 0 via `queue_free()`

## 7. Tiberium Placeholder Art

- [x] 7.1 Rewrite `TiberiumComponent._ensure_visual_nodes()` with cell-seeded cube generation (3 stages)
- [x] 7.2 Add `@export var placeholder_size: Vector3` to ArtData
- [x] 7.3 Update `ArtComponent._add_placeholder()` to use placeholder_size if non-zero
- [x] 7.4 Create ArtData .tres for TiberiumTree with `placeholder_size = Vector3(0.33, 2.0, 0.33)`

## 8. Spec Sync

- [x] 8.1 Add `openspec/specs/map-editor-tiberium/spec.md`
- [x] 8.2 Add `openspec/specs/map-loader/spec.md`
- [x] 8.3 Add `openspec/specs/free-unit/spec.md`
- [x] 8.4 Add `openspec/specs/tiberium-art-placeholder/spec.md`

## 9. Tiberium Growth System

- [x] 9.1 Create `scripts/core/TiberiumGrowthSystem.gd` autoload with two timers (tree + crystal)
- [x] 9.2 Implement `Engine.is_editor_hint()` guard — MapEditor never triggers growth
- [x] 9.3 Implement tree timer: pick random cell in radius, grow existing or spawn crystal
- [x] 9.4 Implement crystal timer: self-growth + spread to adjacent cells
- [x] 9.5 Implement batched processing (10 trees/tick, 50 crystals/tick)
- [x] 9.6 Implement distance limit: crystal only spreads within `radius_cells + spread_distance_buffer` of tree
- [x] 9.7 Implement spread count limit: max `spread_max` spreads per crystal
- [x] 9.8 Implement full-growth speed bonus: timer interval * `full_growth_speed_bonus` when at max
- [x] 9.9 Add 7 new fields to `GlobalRules.gd` (tree_growth_rate, growth_batch_trees, growth_batch_crystals, spread_amount, spread_distance_buffer, spread_max, full_growth_speed_bonus)
- [x] 9.10 Update `resources/global_rules.tres` with new field values
- [x] 9.11 Add `configure()` method to `TiberiumTreeComponent.gd`, remove `_spawn_crystals`/`_spawn_crystal_at`
- [x] 9.12 Add `spread_count: int = 0` field to `TiberiumComponent.gd`
- [x] 9.13 Register `TiberiumGrowthSystem` autoload in `project.godot`
- [x] 9.14 Add `openspec/specs/tiberium-growth-system/spec.md`
- [x] 9.15 Update `openspec/specs/tiberium-tree/spec.md` with growth system requirements
- [x] 9.16 Update `openspec/specs/global-rules/spec.md` with new growth fields
