## 1. Data Model Additions

- [x] 1.1 Add `build_time: float = 1.0` and `build_limit: int = 0` to EntityData.gd
- [x] 1.2 Update all existing .tres entity files with build_time values (from TS rules.ini)
- [x] 1.3 Add `buildable_queue: String = ""` to EntityData.gd — separates queue routing from factory type
- [x] 1.4 Update ProductionManager.start_production to use `buildable_queue` for queue routing
- [x] 1.5 Update all .tres entity files with correct `buildable_queue` values
- [x] 1.6 Update Sidebar.gd queue lookups to use `buildable_queue`
- [x] 1.7 Update _spawn_unit to use `buildable_queue` for factory lookup

## 2. PrerequisiteSystem

- [x] 2.1 Create `scripts/production/PrerequisiteSystem.gd` autoload with `register_building()`, `unregister_building()`, `can_build()`, `get_build_count()`
- [x] 2.2 Implement OR prerequisite check (EntityData.prerequisite)
- [x] 2.3 Implement AND prerequisite check (EntityData.prerequisite_necessary)
- [x] 2.4 Implement build_limit enforcement
- [x] 2.5 Emit `prerequisites_changed(player_id)` signal on building registration
- [x] 2.6 Register PrerequisiteSystem in project.godot autoloads
- [x] 2.7 Connect BuildingManager.building_placed to PrerequisiteSystem.register_building

## 3. ProductionManager

- [x] 3.1 Create `scripts/production/ProductionQueue.gd` data class (entity_data, progress, is_paused, count)
- [x] 3.2 Create `scripts/production/ProductionManager.gd` autoload with queue storage (`Dict[String, ProductionQueue]`)
- [x] 3.3 Implement `start_production()` — check can_build, deduct cost, add to queue
- [x] 3.4 Implement `cancel_production()` — refund cost, remove/decrement item
- [x] 3.5 Implement `pause_production()` and `resume_production()`
- [x] 3.6 Implement `get_progress()` for current item in queue
- [x] 3.7 Implement `_process(delta)` — tick active timers, detect completion
- [x] 3.8 Implement production speed bonus: `1.0 + (factory_count - 1) * 0.25`
- [x] 3.9 Implement unit spawning — find primary factory, find exit cell, create entity, add to scene
- [x] 3.10 Implement building completion — call BuildingManager.enter_build_mode()
- [x] 3.11 Implement stack queue — increment count for identical consecutive items (max 25)
- [x] 3.12 Register ProductionManager in project.godot autoloads
- [x] 3.13 Add signals: production_started, production_progress, production_completed, production_cancelled

## 4. Angular Progress Shader

- [x] 4.1 Create `shaders/angular_progress.gdshader` — radial wipe from 12 o'clock, clockwise, hard edge
- [x] 4.2 Test shader renders correctly with progress 0.0, 0.5, 1.0

## 5. Sidebar UI Rewrite

- [x] 5.1 Rewrite Sidebar.tscn — CreditsLabel, TabBar (4 buttons), ScrollContainer, GridContainer (5×3), ScrollButtons
- [x] 5.2 Rewrite Sidebar.gd — tab switching, entity filtering by type, active tab visual feedback
- [x] 5.3 Implement cameo button creation from entity data (name, cost tooltip, color)
- [x] 5.4 Implement scroll system — Up/Down buttons scroll by row, middle mouse scroll consumes event
- [x] 5.5 Implement tab hotkeys (F1-F4)
- [x] 5.6 Implement left-click → add to queue via ProductionManager
- [x] 5.7 Implement right-click → pause/cancel via ProductionManager
- [x] 5.8 Implement cameo state updates — connect to PrerequisiteSystem and ProductionManager signals
- [x] 5.9 Implement angular progress overlay on cameos — ColorRect child with shader, update progress per frame
- [x] 5.10 Implement build_limit "dark" state on cameos
- [x] 5.11 Update sidebar height from 300px to ~600px to fit 5 rows + tabs + scroll buttons
- [x] 5.12 Connect EconomyManager.credits_changed to update credits label

## 6. Integration & Edge Cases

- [x] 6.1 Handle no factory available (e.g., try to build infantry without barracks)
- [x] 6.2 Handle queue overflow gracefully (unlimited queue, but ensure UI handles many items)
- [x] 6.3 Handle entity destroyed while in queue (future — for now, no-op)
- [x] 6.4 Run `redot --headless -s test/run_tests.gd` — verify no regressions
- [x] 6.5 Run `gdlint` and `gdformat --check` on all modified files
- [x] 6.6 Block queue advancement until Ready building is physically placed
- [x] 6.7 MouseHandler: sidebar click detection with bounding-box fallback
- [x] 6.8 Fix infantry spawning from wrong building (use buildable_queue for factory lookup)
- [x] 6.9 World-space 2D selection outlines with per-entity-type sizing (infantry 50% width, 75% height)
- [x] 6.10 Health bar segments scale with world-space width (stable across zoom)
- [x] 6.11 Health bar top/bottom brightness split matching original shader behavior
