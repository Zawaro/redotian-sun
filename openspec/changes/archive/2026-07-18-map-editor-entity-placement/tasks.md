# Tasks: MapEditor Entity Placement with Player Assignment

## Phase 1: Core Infrastructure

- [x] **Task 1.1**: Extend EntityFactory with get_all_by_type() — `scripts/entities/EntityFactory.gd` — Method returns Array[EntityData] filtered by EntityType
- [x] **Task 1.2**: Add PLACE_ENTITY to MapEditor Tool enum — `scripts/editor/MapEditor.gd` — Extend Tool enum, no breaking changes
- [x] **Task 1.3**: Create EntityBrowser script — `scripts/editor/EntityBrowser.gd` (new) — PanelContainer with category tabs, owner dropdown, search bar, entity list populated from EntityFactory, signals: entity_selected, player_changed

## Phase 2: UI Integration

- [x] **Task 2.1**: EntityBrowser always visible — `scripts/editor/EntityBrowser.gd` — Left sidebar panel, always shown when MapEditor loads (no toggle button)
- [x] **Task 2.2**: Integrate EntityBrowser into MapEditor — `scripts/editor/EntityBrowser.gd` — Added to CanvasLayer at Vector2(10, 50), connect signals
- [x] **Task 2.3**: Add entity placement logic — `scripts/editor/EntityPlacer.gd` — Click entity in browser toggles placement mode, click map to place, right-click cancels
- [x] **Task 2.4**: Add preview ghost — `scripts/editor/EntityPlacer.gd` — 50% opacity entity follows cursor, uses _set_preview_transparency() for recursive alpha
- [x] **Task 2.5**: Foundation-aware positioning — `scripts/editor/MapEditor.gd` — _cell_origin_world_pos() accounts for multi-cell building footprints

## Phase 3: Save/Load Integration

- [x] **Task 3.1**: Extend save format with player_id — `scripts/editor/EditorSaveLoad.gd` — Include player_id in JSON, backward compatible
- [x] **Task 3.2**: Extend load format with player_id — `scripts/maps/MapLoader.gd` — Read player_id from JSON, default to 0 if missing

## Phase 4: Polish and Testing

- [x] **Task 4.1**: Add unit tests for EntityBrowser — `test/unit/test_entity_browser.gd` (new) — Test list population, search, selection signals
- [x] **Task 4.2**: Add integration tests for entity placement — `test/integration/test_entity_placement.gd` (new) — Test create, store, save, load, occupied cell blocking
- [x] **Task 4.3**: Manual testing — Verify full workflow in MapEditor

## Phase 5: MapEditor Refactoring

- [x] **Task 5.1**: Create EditorGrid sub-script — `scripts/editor/EditorGrid.gd` (new) — Grid overlay, cell highlight, height label extraction
- [x] **Task 5.2**: Create EntityPlacer sub-script — `scripts/editor/EntityPlacer.gd` (new) — Entity browser integration, preview, placement extraction
- [x] **Task 5.3**: Create ResourcePainter sub-script — `scripts/editor/ResourcePainter.gd` (new) — Tiberium brush painting/erasing extraction
- [x] **Task 5.4**: Create EditorSaveLoad sub-script — `scripts/editor/EditorSaveLoad.gd` (new) — File dialogs, save/load serialization extraction
- [x] **Task 5.5**: Refactor MapEditor.gd — `scripts/editor/MapEditor.gd` — Reduced from 752 to 314 lines, delegates to sub-scripts

## Phase 6: Bug Fixes

- [x] **Task 6.1**: Fix ResourceGrowthSystem in MapEditor — `scripts/core/ResourceGrowthSystem.gd` — Skip growth/spread when MapEditor is active scene
- [x] **Task 6.2**: Fix save/load player_id — `scripts/editor/EditorSaveLoad.gd`, `scripts/maps/MapLoader.gd` — Include player_id in save, read on load
- [x] **Task 6.3**: Fix cell highlight during entity placement — `scripts/editor/EditorGrid.gd` — Hide yellow highlight when PLACE_ENTITY mode active
