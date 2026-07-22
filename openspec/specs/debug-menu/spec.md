## ADDED Requirements

### Requirement: Debug panel toggle
The system SHALL provide a debug panel toggled with the backtick key (KEY_QUOTELEFT). The panel SHALL appear as a dropdown from the top-left corner of the viewport.

#### Scenario: Toggle panel open
- **WHEN** user presses the backtick key while the debug panel is closed
- **THEN** the debug panel appears at the top-left corner, overlaying the game

#### Scenario: Toggle panel closed
- **WHEN** user presses the backtick key while the debug panel is open
- **THEN** the debug panel disappears and the game continues running

#### Scenario: Panel does not block game input
- **WHEN** user clicks outside the 400px content area of the debug panel while it is open
- **THEN** the click passes through to the game (entity selection, orders, etc.)

#### Scenario: Panel captures its own input
- **WHEN** user clicks inside the 400px content area of the debug panel while it is open
- **THEN** the click is consumed by the panel (toggling checkboxes, adjusting sliders, etc.)

### Requirement: Debug panel layout
The debug panel SHALL be approximately 400px wide, full viewport height, with a dark panel background. The panel SHALL use an accordion layout with 4 collapsible sections in this order: Overlays, Lighting, Cheats, Inspect. A stats label showing entity counts and FPS SHALL be always visible at the top.

#### Scenario: Accordion section toggle
- **WHEN** user clicks a section header in the debug panel
- **THEN** that section's content toggles between visible and hidden

#### Scenario: Multiple sections expanded
- **WHEN** multiple sections are expanded in the debug panel
- **THEN** all expanded sections are visible simultaneously, stacked vertically

### Requirement: Debug overlays
The system SHALL provide 6 toggleable debug overlays, each controlled by a checkbox in the Overlays section of the debug panel. Overlays SHALL redraw every frame when enabled and clean up their visuals when disabled.

#### Scenario: Pathfinding overlay
- **WHEN** the "Pathfinding lines" checkbox is enabled
- **THEN** green/gray lines are drawn showing movement paths for entities with active movement commands

#### Scenario: Spatial hash grid overlay
- **WHEN** the "Spatial hash grid" checkbox is enabled
- **THEN** grid lines are drawn for each spatial hash cell that has entities

#### Scenario: Entity bounds overlay
- **WHEN** the "Entity bounds" checkbox is enabled
- **THEN** selection box outlines are drawn around every entity using FoundationComponent.cell_size for buildings and a default 1x1 for non-buildings

#### Scenario: Health bars overlay
- **WHEN** the "Health bars" checkbox is enabled
- **THEN** the existing SelectionOverlay health bars become visible, showing segmented health bars above selected/hovered entities

#### Scenario: Entity IDs overlay
- **WHEN** the "Entity IDs + Health" checkbox is enabled
- **THEN** a Label is drawn above every entity showing StatsComponent.display_name, StatsComponent.id, and HealthComponent current/max health

#### Scenario: Occupied cells overlay
- **WHEN** the "Occupied cells" checkbox is enabled
- **THEN** colored outlines are drawn for occupied cells: green for building cells, red for blocked cells (idle units)

#### Scenario: Overlay cleanup on disable
- **WHEN** user disables an overlay
- **THEN** all meshes and canvas items created by that overlay are removed from the scene

#### Scenario: Overlay reset on scene change
- **WHEN** the scene changes (new map loaded)
- **THEN** all overlay checkboxes reset to off and all overlay visuals are cleaned up

### Requirement: Lighting controls
The system SHALL provide sliders in the Lighting section of the debug panel for 8 lighting properties plus a color picker. Changes SHALL apply in real-time to the scene's LightPivot and WorldEnvironment nodes. The system SHALL read the scene's initial light pivot rotation to avoid overwriting baked lighting.

#### Scenario: Sun elevation adjustment
- **WHEN** user adjusts the Sun Elevation slider (range: 0-90 degrees)
- **THEN** the LightPivot node's X rotation updates to match the slider value in degrees

#### Scenario: Sun rotation adjustment
- **WHEN** user adjusts the Sun Rotation slider (range: 0-360 degrees)
- **THEN** the LightPivot node's Y rotation updates to match the slider value in degrees

#### Scenario: Sun intensity adjustment
- **WHEN** user adjusts the Sun Intensity slider (range: 0-5)
- **THEN** the DirectionalLight3D's energy property updates to match the slider value

#### Scenario: Sun color adjustment
- **WHEN** user adjusts the Sun Color picker
- **THEN** the DirectionalLight3D's light_color property updates to match the selected color

#### Scenario: Shadow strength adjustment
- **WHEN** user adjusts the Shadow Strength slider (range: 0-1)
- **THEN** the DirectionalLight3D's shadow_opacity and shadow_blur both update to match the slider value directly (no multiplier)

#### Scenario: Ambient light adjustment
- **WHEN** user adjusts the Ambient Light slider (range: 0-2)
- **THEN** the WorldEnvironment's ambient_light_energy property updates to match the slider value

#### Scenario: Fog density adjustment
- **WHEN** user adjusts the Fog Density slider (range: 0-0.01)
- **THEN** the WorldEnvironment's fog_density property updates to match the slider value

#### Scenario: Sky rotation adjustment
- **WHEN** user adjusts the Sky Rotation slider (range: -1 to 1)
- **THEN** the WorldEnvironment's sky_rotation Y component updates to match the slider value, X and Z components remain at 0

#### Scenario: Glow intensity adjustment
- **WHEN** user adjusts the Glow Intensity slider (range: 0-2)
- **THEN** the WorldEnvironment's glow_intensity property updates to match the slider value

#### Scenario: Lighting default values
- **WHEN** the debug panel opens and no lighting adjustments have been made
- **THEN** sliders show values derived from the scene's actual light pivot rotation and environment settings

### Requirement: Cheat toggles
The system SHALL provide 4 independent cheat toggles in the Cheats section: No prerequisites, No build time, No cost, Place anywhere. Each toggle SHALL persist its state across panel open/close cycles. Cheat flags are stored on the DebugMenu node and read by other systems via group reference.

#### Scenario: No prerequisites toggle
- **WHEN** the "No prerequisites" toggle is enabled
- **THEN** PrerequisiteSystem.can_build() returns true for all entities, bypassing both prerequisite checks and build_limit checks
- **AND** the Sidebar build menu refreshes to show all entities

#### Scenario: No build time toggle
- **WHEN** the "No build time" toggle is enabled
- **THEN** entity build_time is treated as 0, causing ProductionManager to complete production immediately

#### Scenario: No cost toggle
- **WHEN** the "No cost" toggle is enabled
- **THEN** EconomyManager.deduct() is a no-op (returns true without deducting credits)

#### Scenario: Place anywhere toggle
- **WHEN** the "Place anywhere" toggle is enabled
- **THEN** BuildingManager.can_place() returns true for any cell (skips foundation, terrain, and bib checks)
- **AND** Sidebar enters debug place mode for non-building entities

#### Scenario: Non-building entity placement
- **WHEN** "Place anywhere" is enabled and user clicks a unit/infantry cameo in the build menu
- **THEN** the unit enters placement mode with a preview ghost via EntityPlacer, and clicking a non-blocked ground cell spawns the unit

#### Scenario: Cheat reset on scene change
- **WHEN** the scene changes (new map loaded)
- **THEN** all cheat toggles reset to off and debug place mode is exited

### Requirement: Action buttons
The system SHALL provide 2 action buttons in the Cheats section: "Clear All Paths" and "Add 100k Credits".

#### Scenario: Clear all paths
- **WHEN** user clicks the "Clear All Paths" button
- **THEN** DebugVisualizer.clear_all() is called and all debug overlays are cleaned up

#### Scenario: Add credits
- **WHEN** user clicks the "Add 100k Credits" button
- **THEN** 100,000 credits are added to the local player's balance via EconomyManager.add()

### Requirement: Entity inspection
The system SHALL display component data for the currently selected entity in the Inspect section. Inspection is driven by SelectionManager.selection_changed — no separate click handler needed.

#### Scenario: Entity selected with panel open
- **WHEN** user selects an entity while the debug panel is open
- **THEN** the Inspect section expands and displays a health summary (current/max) followed by all exported properties from all attached components, grouped by component name

#### Scenario: Entity deselected
- **WHEN** user deselects all entities (clicks empty space)
- **THEN** the Inspect section clears and collapses

#### Scenario: Different entity selected
- **WHEN** user selects a different entity while one is already being inspected
- **THEN** the Inspect section updates to show the newly selected entity's data

#### Scenario: Panel opens with entity already selected
- **WHEN** user opens the debug panel while an entity is already selected
- **THEN** the Inspect section immediately shows the selected entity's data

### Requirement: Game state display
The system SHALL display a compact debug stats label at the top of the panel (always visible when panel is open) showing entity count by EntityType enum and FPS.

#### Scenario: Debug stats display
- **WHEN** user views the debug panel
- **THEN** a label shows entity counts per EntityType (INF, VEH, BLD, ARC, TER, OVR) and current FPS

#### Scenario: Stats update frequency
- **WHEN** the debug panel is open
- **THEN** the debug stats label updates every frame

### Requirement: Entity placement via EntityPlacer
The system SHALL provide a centralized EntityPlacer singleton for all entity placement, including debug mode. EntityPlacer manages inert preview entities (frozen, non-interactive, transparent) and restores original materials on finalize.

#### Scenario: Preview creation
- **WHEN** user enters placement mode (debug or production)
- **THEN** EntityPlacer creates a preview entity with PROCESS_MODE_DISABLED, zeroed collision, stripped groups, and transparent material_override

#### Scenario: Preview finalization
- **WHEN** user clicks to place the entity
- **THEN** EntityPlacer restores groups, collision layers, process mode, and surface override materials, then emits entity_placed signal

#### Scenario: Material preservation
- **WHEN** a preview entity is finalized
- **THEN** original set_surface_override_material values (set by ArtComponent) are restored, preventing gray/default material loss

### Requirement: Scene change reset
The system SHALL reset all debug state when a new map is loaded, detected via the node_added signal watching for nodes starting with "Map".

#### Scenario: New map loaded
- **WHEN** a node with name starting with "Map" is added to the scene tree
- **THEN** all cheat toggles reset, debug place mode exits, EntityPlacer cancels preview, overlay checkboxes reset, and inspection clears
