## MODIFIED Requirements

### Requirement: Entity placement via EntityPlacer
The system SHALL provide a centralized EntityPlacer singleton for all entity placement, including debug mode. EntityPlacer manages inert preview entities (frozen, non-interactive, transparent) and restores original materials on finalize. EntityPlacer SHALL own the free-placement session as a single nullable placing-data field: `start_placing(data)` starts the preview, `stop_placing()` cancels it, `is_placing()` reports session state — there SHALL be no separate mode-flag state machine, no 1-frame input-skip counter, and no session state stored in any UI script. Commit (select_entity) and cancel (deselect_entity / ESC) SHALL be handled event-driven in `EntityPlacer._unhandled_input`; preview repositioning SHALL run in `_process` (mouse-motion events do not fire during camera pans). `EntityPlacer.is_placing()` SHALL be the single source of placement-mode truth for gameplay guards: MouseHandler click routing and the PauseMenu ESC guard SHALL query EntityPlacer, not the Sidebar.

#### Scenario: Preview creation
- **WHEN** user enters placement mode (debug or production)
- **THEN** EntityPlacer creates a preview entity with PROCESS_MODE_DISABLED, zeroed collision, stripped groups, and transparent material_override

#### Scenario: Preview finalization
- **WHEN** user clicks to place the entity
- **THEN** EntityPlacer restores groups, collision layers, process mode, and surface override materials, then emits entity_placed signal

#### Scenario: Material preservation
- **WHEN** a preview entity is finalized
- **THEN** original set_surface_override_material values (set by ArtComponent) are restored, preventing gray/default material loss

#### Scenario: Placing-start click does not commit
- **WHEN** a cameo click starts the placing session (the click is consumed as GUI input)
- **THEN** the same physical click SHALL NOT commit the placement — the placement-start event never reaches `_unhandled_input`

#### Scenario: Commit is event-driven
- **WHEN** the session is placing and a select_entity press reaches `_unhandled_input`
- **THEN** the placement finalizes and is_placing() returns false in the same event, with no skip-frame counter involved

#### Scenario: Cancel is event-driven
- **WHEN** the session is placing and a deselect_entity press or ESC reaches `_unhandled_input`
- **THEN** the preview is cancelled and is_placing() returns false

#### Scenario: Repositioning tracks camera pans
- **WHEN** the camera pans or rotates while the session is placing
- **THEN** the preview repositions to the cursor's terrain position on the next frame

#### Scenario: Commit click does not leak into order resolution
- **WHEN** the commit click finalizes a placement
- **THEN** MouseHandler's subsequent processing observes `EntityPlacer.is_placing() == false` for the *next* frame only — the same physical click SHALL NOT additionally issue a unit order on the freshly placed entity (MouseHandler checks the placing state before its own order resolution)

#### Scenario: Placement-mode truth is centralized
- **WHEN** the PauseMenu ESC guard or MouseHandler click routing needs placement-mode state
- **THEN** it reads `EntityPlacer.is_placing()`; no gameplay script queries the Sidebar for placement state

## ADDED Requirements

### Requirement: Direct deploy fallback
When the "No prerequisites" cheat is enabled and no factory exists for an entity's queue type, clicking that entity's cameo SHALL start placing via EntityPlacer's placement session for it (direct deploy): the entity places at a non-blocked ground cell without factory involvement. This fallback SHALL be a named path (not a reuse of the "place anywhere" start path) so both entry points stay individually observable. The Sidebar SHALL reach this behavior only through one-line delegates; the fallback logic SHALL NOT live in UI code.

#### Scenario: No factory for queue type
- **WHEN** "No prerequisites" is enabled, the queue's factory type is registered, but no matching factory building exists on the map, and the user clicks the entity's cameo
- **THEN** EntityPlacer's session starts a preview for that entity, and clicking a non-blocked ground cell spawns it at full stats

#### Scenario: Factory exists — normal production
- **WHEN** "No prerequisites" is enabled, a matching factory exists, and the user clicks the entity's cameo
- **THEN** production starts normally (the direct deploy fallback does not fire)
