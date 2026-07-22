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
The debug panel SHALL be approximately 400px wide, full viewport height, with a dark semi-transparent background and white/light gray text. The panel SHALL use an accordion layout with 4 collapsible sections in this order: Overlays, Lighting, Cheats, Inspect.

#### Scenario: Accordion section toggle
- **WHEN** user clicks a section header in the debug panel
- **THEN** that section's content toggles between visible and hidden

#### Scenario: Multiple sections expanded
- **WHEN** multiple sections are expanded in the debug panel
- **THEN** all expanded sections are visible simultaneously, stacked vertically

### Requirement: Debug overlays
The system SHALL provide 5 toggleable debug overlays, each controlled by a checkbox in the Overlays section of the debug panel. Overlays SHALL redraw every frame when enabled.

#### Scenario: Pathfinding overlay
- **WHEN** the "Pathfinding lines" checkbox is enabled
- **THEN** green/gray lines are drawn showing movement paths for entities with active movement commands

#### Scenario: Spatial hash grid overlay
- **WHEN** the "Spatial hash grid" checkbox is enabled
- **THEN** grid lines are drawn for each spatial hash cell, with occupancy count labels showing number of entities per cell

#### Scenario: Entity bounds overlay
- **WHEN** the "Entity bounds" checkbox is enabled
- **THEN** selection box outlines are drawn around every entity using FoundationComponent.cell_size for buildings and a default 1x1 for non-buildings

#### Scenario: Health bars overlay
- **WHEN** the "Health bars" checkbox is enabled
- **THEN** a ColorRect bar is drawn above every entity, width proportional to HealthComponent.current_health / HealthComponent.max_health, color: green (>60%), yellow (30-60%), red (<30%)

#### Scenario: Entity IDs overlay
- **WHEN** the "Entity IDs" checkbox is enabled
- **THEN** a Label is drawn above every entity showing StatsComponent.display_name and StatsComponent.id

#### Scenario: Overlay persistence
- **WHEN** user enables an overlay, closes the debug panel, and reopens it
- **THEN** the overlay checkbox remains in its previous state

#### Scenario: Overlay reset on scene change
- **WHEN** the scene changes (new map loaded)
- **THEN** all overlay checkboxes reset to off

### Requirement: Lighting controls
The system SHALL provide sliders in the Lighting section of the debug panel for 9 lighting properties. Changes SHALL apply in real-time to the scene's LightPivot and WorldEnvironment nodes.

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
- **THEN** the DirectionalLight3D's shadow_opacity updates to match the slider value, and shadow_blur updates to slider_value * 10

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
- **THEN** sliders show defaults matching the scene files: sun_elevation=36, sun_rotation=0, sun_intensity=1.0, sun_color=white, shadow_strength=0.9, ambient_light=1.0, fog_density=0.001, sky_rotation=-0.18, glow_intensity=0.1

### Requirement: Cheat toggles
The system SHALL provide 4 independent cheat toggles in the Cheats section: No prerequisites, No build time, No cost, Place anywhere. Each toggle SHALL persist its state across panel open/close cycles.

#### Scenario: No prerequisites toggle
- **WHEN** the "No prerequisites" toggle is enabled
- **THEN** PrerequisiteSystem.can_build() returns true for all entities, bypassing both prerequisite checks and build_limit checks

#### Scenario: No build time toggle
- **WHEN** the "No build time" toggle is enabled
- **THEN** entity build_time is treated as 0, causing ProductionManager to complete production immediately via the existing `if build_time <= 0.0` code path

#### Scenario: No cost toggle
- **WHEN** the "No cost" toggle is enabled
- **THEN** EconomyManager.deduct() is a no-op (returns true without deducting credits)

#### Scenario: Place anywhere toggle
- **WHEN** the "Place anywhere" toggle is enabled
- **THEN** BuildingManager.can_place() returns true for any cell that is not blocked by another entity (skips foundation, terrain, and bib checks)

#### Scenario: Non-building entity placement
- **WHEN** "Place anywhere" is enabled and user clicks a unit/infantry cameo in the build menu
- **THEN** the unit enters placement mode with a preview ghost (same flow as buildings), and clicking a non-blocked ground cell spawns the unit at that location

#### Scenario: Cheat toggle persistence
- **WHEN** user enables a cheat toggle, closes the debug panel, and reopens it
- **THEN** the toggle remains in its previous state

#### Scenario: Cheat reset on scene change
- **WHEN** the scene changes (new map loaded)
- **THEN** all cheat toggles reset to off

### Requirement: Action buttons
The system SHALL provide 2 action buttons in the Cheats section: "Clear All Paths" and "Add 100k Credits".

#### Scenario: Clear all paths
- **WHEN** user clicks the "Clear All Paths" button
- **THEN** DebugVisualizer.clear_all() is called and all pathfinding debug lines are removed

#### Scenario: Add credits
- **WHEN** user clicks the "Add 100k Credits" button
- **THEN** 100,000 credits are added to the local player's balance via EconomyManager.add(player_id, 100000, "debug_menu")

### Requirement: Entity inspection
The system SHALL allow clicking any entity when the debug panel is open to inspect its data. The Inspect section SHALL expand and display all component data for the clicked entity dynamically using Godot's property system.

#### Scenario: Click entity to inspect
- **WHEN** user clicks an entity while the debug panel is open
- **THEN** the Inspect section expands and displays all exported properties from all attached components, grouped by component name, using get_property_list() and get() for dynamic field discovery

#### Scenario: Click empty space to clear inspection
- **WHEN** user clicks empty space while the debug panel is open and an entity is being inspected
- **THEN** the Inspect section clears and collapses

#### Scenario: Click different entity
- **WHEN** user clicks a different entity while one is already being inspected
- **THEN** the Inspect section updates to show the newly clicked entity's data

#### Scenario: Entity inspection integration
- **WHEN** an entity is clicked while the debug panel is open
- **THEN** MouseHandler notifies DebugMenu via inspect_entity(entity) method, and DebugMenu populates the Inspect section

### Requirement: Game state display
The system SHALL display a compact debug stats label in the Cheats section showing: entity count by EntityType enum (INFANTRY=0, VEHICLE=1, BUILDING=2, AIRCRAFT=3, TERRAIN=4, OVERLAY=5), FPS, and spatial hash occupancy (occupied cells / total cells as percentage).

#### Scenario: Debug stats display
- **WHEN** user views the Cheats section
- **THEN** a label shows entity counts per EntityType, current FPS, and spatial hash occupancy percentage

#### Scenario: Stats update frequency
- **WHEN** the debug panel is open
- **THEN** the debug stats label updates every frame

### Requirement: Entity spawning via build menu
When cheat mode is active, the existing build menu SHALL show all buildable entities regardless of prerequisites, production SHALL be instant (build_time = 0), and non-building entities SHALL be placeable via the same flow as buildings.

#### Scenario: Build menu shows all entities
- **WHEN** "No prerequisites" is enabled and user opens a build tab
- **THEN** all entities of that type are shown in the sidebar regardless of prerequisite requirements

#### Scenario: Instant production
- **WHEN** "No build time" is enabled and user starts production
- **THEN** the entity completes immediately and enters placement mode (for buildings) or spawns (for units)
