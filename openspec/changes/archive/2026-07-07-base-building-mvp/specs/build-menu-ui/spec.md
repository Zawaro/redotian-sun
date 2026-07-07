## ADDED Requirements

### Requirement: Build menu displays available buildings
A right-side UI panel SHALL display buttons for each available building type. Each button SHALL show the building's cameo texture (or placeholder) and display name. Buttons SHALL be arranged in a 3-column grid layout with 128×96 cameo sizes.

#### Scenario: Build menu is visible during gameplay
- **WHEN** the game is running (not in main menu)
- **THEN** the build menu panel is visible on the right side of the screen

#### Scenario: Build menu shows all GDI buildings
- **WHEN** the build menu loads
- **THEN** it displays buttons for: Construction Yard, Power Plant, Barracks, Refinery, War Factory, Guard Tower

### Requirement: Clicking building button enters build mode
When the player clicks a building button in the build menu, BuildingManager SHALL enter build mode with that building type selected. The cursor SHALL show the placement preview.

#### Scenario: Click button enters build mode
- **WHEN** the player clicks the "Power Plant" button
- **THEN** BuildingManager.is_build_mode becomes true
- **AND** the placement preview appears following the cursor

#### Scenario: Click same button again cancels build mode
- **WHEN** the player is in build mode
- **AND** clicks the same building button again
- **THEN** BuildingManager.is_build_mode becomes false
- **AND** the placement preview disappears

### Requirement: Right-click cancels build mode
When the player right-clicks while in build mode, BuildingManager SHALL exit build mode without placing a building.

#### Scenario: Right-click exits build mode
- **WHEN** the player is in build mode
- **AND** right-clicks anywhere on the map
- **THEN** BuildingManager.is_build_mode becomes false
- **AND** the placement preview disappears

### Requirement: MouseHandler routes input during build mode
MouseHandler._process() SHALL check BuildingManager.is_build_mode. When true, MouseHandler SHALL NOT process selection or movement input, deferring to BuildingManager.

#### Scenario: Selection disabled in build mode
- **WHEN** the player is in build mode
- **AND** left-clicks on the map
- **THEN** no entity selection occurs
- **AND** no movement command is issued

#### Scenario: Selection works normally outside build mode
- **WHEN** the player is NOT in build mode
- **AND** left-clicks on an entity
- **THEN** the entity is selected as normal

### Requirement: MouseHandler ignores clicks on build menu
MouseHandler._process() SHALL detect when the hovered control is inside the BuildMenu panel and skip selection/movement processing. This prevents clicks on build menu buttons from triggering entity selection or movement commands.

#### Scenario: Click on build menu does not trigger selection
- **WHEN** the player clicks on a build menu button
- **THEN** no entity selection occurs
- **AND** no movement command is issued

#### Scenario: Click on game area works normally
- **WHEN** the player clicks on the game area (not on BuildMenu)
- **THEN** selection or movement processing proceeds as normal

### Requirement: Escape key cancels build mode
The Escape key SHALL exit build mode when the player is in build mode.

#### Scenario: Escape exits build mode
- **WHEN** the player is in build mode
- **AND** presses Escape
- **THEN** BuildingManager.is_build_mode becomes false
- **AND** the placement preview disappears
