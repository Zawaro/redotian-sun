## 1. GlobalRules & Data Layer

- [x] 1.1 Add `starting_credits`, `tiberium_value`, `harvester_fill_rate` to `scripts/data/GlobalRules.gd`
- [x] 1.2 Update `resources/global_rules.tres` with new field defaults
- [x] 1.3 Add `tiberium_tree`, `spawned_entity_id`, `radius_cells`, `node_count`, `amount_per_node`, `max_amount_per_node` to `scripts/data/EntityData.gd`
- [x] 1.4 Add `tiberium_resource`, `tiberium_amount`, `tiberium_max_amount`, `tiberium_type`, `tiberium_regrowth_rate` to `scripts/data/EntityData.gd`
- [x] 1.5 Add `bib_cells: PackedVector2i` to `scripts/data/EntityData.gd`
- [x] 1.6 Add `dock_position: Vector3` and `dock_rotation: float` to `scripts/data/EntityData.gd`
- [x] 1.7 Create `scripts/data/PlayerData.gd` resource class with `player_id`, `credits`

## 2. EconomyManager Autoload

- [x] 2.1 Create `scripts/economy/EconomyManager.gd` with `credits_changed` and `insufficient_funds` signals
- [x] 2.2 Implement `get_balance(player_id)`, `can_afford(player_id, cost)`, `deduct(player_id, cost, reason)`, `add(player_id, amount, reason)`
- [x] 2.3 Implement `_get_player_data(player_id)` lazy-init creating a new PlayerData if none exists
- [x] 2.4 Register `EconomyManager` autoload in `project.godot`

## 3. FoundationComponent Bib Cells

- [x] 3.1 Add `bib_cells: PackedVector2i` field to `scripts/components/FoundationComponent.gd`
- [x] 3.2 Wire `bib_cells` in `configure(data)` to read from EntityData
- [x] 3.3 Update `BuildingManager.place_building()` to register bib cells in SpatialHash separately from blocked cells
- [x] 3.4 Add bib cell soft-blocking to `SpatialHash.gd` — bib cells are passable for dock-queued harvesters

## 4. DockComponent

- [x] 4.1 Create `scripts/components/DockComponent.gd` with `dock_position`, `dock_rotation`, `allowed_entities`, `unload_rate`, `load_rate` exports
- [x] 4.2 Implement queue system: `queue: Array`, `slot_available` signal, `request_dock()` / `leave_dock()` methods
- [x] 4.3 Implement one-at-a-time processing — next in queue moves up when current leaves

## 5. TiberiumComponent

- [x] 5.1 Create `scripts/components/TiberiumComponent.gd` with `amount`, `max_amount`, `tiberium_type`, `regrowth_rate` exports
- [x] 5.2 Implement `collect(amount) -> int` — depletes crystal, returns collected amount (capped at `amount` remaining)
- [x] 5.3 Implement `is_depleted() -> bool` — returns true when `amount <= 0`
- [x] 5.4 Implement `get_visual_stage() -> int` — returns 0/1/2 based on `amount / max_amount` ratio thresholds (0.33, 0.66)
- [x] 5.5 Wire visual stage updates in `collect()` to swap mesh instances

## 6. TiberiumTreeComponent

- [x] 6.1 Create `scripts/components/TiberiumTreeComponent.gd` with `spawned_entity_id`, `radius_cells`, `tiberium_type`, `node_count`, `amount_per_node`, `max_amount_per_node`, `regrowth_rate` exports
- [x] 6.2 Implement `_spawn_crystals()` — iterate `node_count`, compute scatter positions within radius using jitter, maintain 2-cell minimum distance
- [x] 6.3 For each position: call `EntityFactory.create_entity(spawned_entity_id)` with overrides for amount/type/regrowth parameters
- [x] 6.4 Wire `_spawn_crystals()` in `_ready()` with `call_deferred()` to ensure terrain system is loaded
- [x] 6.5 Ensure tree has no HealthComponent, no SelectComponent, no HitboxComponent (EntityFactory gating on `tiberium_tree`)

## 7. HarvestComponent

- [x] 7.1 Create `scripts/components/HarvestComponent.gd` with state machine enum: IDLE, SEEK_NODE, APPROACH_NODE, HARVESTING, FULL, SEEK_REFINERY, APPROACH_REFINERY, DOCKING, UNLOADING
- [x] 7.2 Implement SEEK_NODE state: scan for nearest cell with TiberiumComponent within range via SpatialHash, navigate there via MovementController
- [x] 7.3 Implement HARVESTING state: tick fill rate, deplete crystal, increment cargo. Transition to FULL when cargo reaches capacity or crystal depletes
- [x] 7.4 Implement SEEK_REFINERY state: scan for nearest building with DockComponent where `allowed_entities` contains our dock ID
- [x] 7.5 Implement DOCKING state: navigate to dock_position, orient to dock_rotation. Call `request_dock()` on the DockComponent
- [x] 7.6 Implement UNLOADING state: tick cargo → credits via DockComponent.unload_rate. Call `leave_dock()` when empty
- [x] 7.7 Implement auto-seek: when IDLE with empty cargo, auto-target nearest Tiberium crystal
- [x] 7.8 Support manual target override via public `set_target_node(node)` method (called by right-click selection)

## 8. EntityFactory Wiring

- [x] 8.1 Add `_add_tiberium_tree_component(entity, data)` — attached when `data.tiberium_tree`
- [x] 8.2 Add `_add_tiberium_component(entity, data)` — attached when `data.tiberium_resource`
- [x] 8.3 Add `_add_harvest_component(entity, data)` — references TransportComponent for storage
- [x] 8.4 Add `_add_dock_component(entity, data)` — attached when `dock_position != Vector3.ZERO`
- [x] 8.5 Wire new methods into `_add_components()` with proper gating (no Health/Select for tiberium entities)
- [x] 8.6 Ensure tiberium crystal entities do NOT register as blocked in SpatialHash for unit pathing but DO block in BuildingManager

## 9. BuildingManager — Pseudo-Foundation + Deduction

- [x] 9.1 Add `EconomyManager.deduct()` call in `BuildingManager.place_building()` before `EntityFactory.create_entity()`
- [x] 9.2 Return false from `place_building()` if deduction fails (insufficient funds)
- [x] 9.3 In `can_place()`, check each footprint cell for entities with TiberiumComponent via SpatialHash — reject if found
- [x] 9.4 Ensure `can_place()` does NOT check affordability (placement preview shows valid/invalid independent of credits)

## 10. Credit Display UI

- [x] 10.1 Add `Label` node to `BuildMenu.tscn` above the `GridContainer` with `%CreditsLabel` unique name
- [x] 10.2 Connect `EconomyManager.credits_changed` signal in `BuildMenu._ready()` to update label text with "$" prefix
- [x] 10.3 Implement red color toggle when balance < cheapest buildable item cost
- [x] 10.4 Read initial balance from `EconomyManager.get_balance(0)` in `_ready()`

## 11. Assets & Data Population

- [x] 11.1 Create TiberiumTree entity data .tres (`resources/entities/terrain/tiberium_tree.tres`) with `tiberium_tree = true`, `spawned_entity_id = "TIB"`, `foundation = Vector2i(1,1)`
- [x] 11.2 Create TiberiumTree scene (`scenes/entities/terrain/TiberiumTree.tscn`)
- [x] 11.3 Create Tiberium crystal entity data .tres (`resources/entities/terrain/tiberium_crystal.tres`) with `tiberium_resource = true`, `amount = 500`, `foundation = Vector2i(1,1)`
- [x] 11.4 Create Tiberium crystal scene with 3 cube cluster stages
- [x] 11.5 Create placeholder cube geometry in TiberiumComponent._ensure_visual_nodes() (3D models TBD by artist)
- [x] 11.6 Update refinery EntityData .tres with `dock_position`, `dock_rotation`, `bib_cells`

## 12. Tests

- [x] 12.1 Write unit test for EconomyManager: add, deduct, can_afford, insufficient_funds signal
- [x] 12.2 Write unit test for PlayerData resource creation
- [x] 12.3 Write unit test for TiberiumComponent: collect, deplete, is_depleted, visual stage
- [x] 12.4 Write unit test for TiberiumTreeComponent: spawns correct number of crystals, respects radius and spacing
- [x] 12.5 Write unit test for DockComponent: queue, one-at-a-time, allowed_entities filter
- [x] 12.6 Write unit test for HarvestComponent state machine transitions (simulated)
