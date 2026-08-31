## MODIFIED Requirements

### Requirement: Entity placement via EntityPlacer
The system SHALL provide a centralized EntityPlacer singleton for all entity placement, including debug mode. EntityPlacer manages inert preview entities (frozen, non-interactive, transparent) and restores original materials on finalize. EntityPlacer SHALL own the free-placement session as a single nullable placing-data field: `start_placing(data)` starts the preview, `stop_placing()` cancels it, `is_placing()` reports session state — there SHALL be no separate mode-flag state machine and no session state stored in any UI script. Session input SHALL be poll-based in `EntityPlacer._process` (mouse events do not reach `_unhandled_input` at runtime in this codebase; the same reason MouseHandler and BuildingManager poll), with `_unhandled_input` keeping keyboard/test fallback handling. A one-frame input skip (`_skip_input_frames`) after arming SHALL prevent the arming cameo click — which the Input singleton records even when GUI consumes it — from committing the placement. Building ghosts SHALL commit through BuildingManager (`place_building` at the foundation-snapped origin cell); all other entity types finalize the ghost via `finalize_preview`. `EntityPlacer.is_placing()` SHALL be the single source of placement-mode truth for gameplay guards: MouseHandler click routing and the PauseMenu ESC guard SHALL query EntityPlacer, not the Sidebar.

#### Scenario: Preview creation
- **WHEN** user enters placement mode (debug or production)
- **THEN** EntityPlacer creates a preview entity with PROCESS_MODE_DISABLED, zeroed collision, stripped groups, and transparent material_override

#### Scenario: Preview finalization
- **WHEN** user clicks to place a non-building entity
- **THEN** EntityPlacer restores groups, collision layers, process mode, and surface override materials, then emits entity_placed signal

#### Scenario: Material preservation
- **WHEN** a preview entity is finalized
- **THEN** original set_surface_override_material values (set by ArtComponent) are restored, preventing gray/default material loss

#### Scenario: Placing-start click does not commit
- **WHEN** a cameo click starts the placing session (the click is consumed as GUI input but still registered by the Input singleton)
- **THEN** the session's first input-poll frame is skipped, so the same physical click SHALL NOT commit the placement

#### Scenario: Commit is poll-driven
- **WHEN** the session is placing and `select_entity` registers as just-pressed in `_process`
- **THEN** the placement commits (buildings via `BuildingManager.place_building`, other entities via `finalize_preview`) and `is_placing()` returns false in the same frame

#### Scenario: Cancel is poll-driven
- **WHEN** the session is placing and `deselect_entity` or `ui_cancel` registers as just-pressed in `_process`
- **THEN** the preview is cancelled and `is_placing()` returns false; keyboard events reaching `_unhandled_input` also cancel as fallback

#### Scenario: Building commits route through BuildingManager
- **WHEN** a BUILDING ghost commits
- **THEN** the origin cell snaps to the mouse cell minus half the foundation footprint and the building lands via `BuildingManager.place_building` (cell reservation, terrain leveling, building registry) — not via raw ghost finalization

#### Scenario: Repositioning tracks camera pans
- **WHEN** the camera pans or rotates while the session is placing
- **THEN** the preview repositions to the cursor's terrain position on the next frame (buildings snapped to the foundation grid)

#### Scenario: Refused commit keeps the session armed
- **WHEN** `place_building` refuses the placement (e.g. origin out of map bounds)
- **THEN** the session stays armed with the live ghost so the user can retry

#### Scenario: Commit click does not leak into order resolution
- **WHEN** the commit click finalizes a placement
- **THEN** MouseHandler's subsequent processing observes the commit-click latch for the same physical click — it SHALL NOT additionally issue a unit order on the freshly placed entity

#### Scenario: Placement-mode truth is centralized
- **WHEN** the PauseMenu ESC guard or MouseHandler click routing needs placement-mode state
- **THEN** it reads `EntityPlacer.is_placing()`; no gameplay script queries the Sidebar for placement state

## ADDED Requirements

### Requirement: Direct deploy fallback
When the "No prerequisites" cheat is enabled and no factory exists for an entity's queue type, clicking that entity's cameo SHALL start placing via EntityPlacer's placement session for it (direct deploy): the entity places at a non-blocked ground cell without factory involvement. This fallback SHALL be a named path (`EntityPlacer.start_direct_deploy`, distinct from the place-anywhere start path) routed from ProductionManager so both entry points stay individually observable; the fallback logic SHALL NOT live in UI code.

#### Scenario: No factory for queue type
- **WHEN** "No prerequisites" is enabled, the queue's factory type is registered, but no matching factory building exists on the map, and the user clicks the entity's cameo
- **THEN** EntityPlacer's session starts a preview for that entity, and clicking a non-blocked ground cell spawns it at full stats

#### Scenario: Factory exists — normal production
- **WHEN** "No prerequisites" is enabled, a matching factory exists, and the user clicks the entity's cameo
- **THEN** production starts normally (the direct deploy fallback does not fire)
