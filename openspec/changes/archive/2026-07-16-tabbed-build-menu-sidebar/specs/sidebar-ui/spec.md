## ADDED Requirements

### Requirement: Tab bar with four categories
The sidebar SHALL display 4 tab buttons: Buildings, Infantry, Vehicles, Special. Each tab filters entities by entity_type.

#### Scenario: Tab content mapping
- **WHEN** Buildings tab is active
- **THEN** only entities with `entity_type == BUILDING && buildable` are shown
- **WHEN** Infantry tab is active
- **THEN** only entities with `entity_type == INFANTRY && buildable` are shown
- **WHEN** Vehicles tab is active
- **THEN** only entities with `entity_type == VEHICLE && buildable` are shown
- **WHEN** Special tab is active
- **THEN** only entities with `entity_type == AIRCRAFT && buildable` are shown

### Requirement: Scrollable 5×3 cameo grid
The sidebar SHALL display a 5-row × 3-column grid of cameo buttons (15 visible). Scrolling moves entire rows.

#### Scenario: More than 15 entities in tab
- **WHEN** tab has 20 entities
- **AND** scroll offset is 0
- **THEN** first 15 entities are visible
- **AND** scrolling down reveals entities 16-20

#### Scenario: Scroll by row
- **WHEN** user clicks Down button
- **THEN** scroll offset increases by 3 (one row)
- **AND** grid shifts up by one row

### Requirement: Middle mouse scroll on sidebar
The sidebar SHALL consume middle mouse scroll events to scroll the grid, preventing camera zoom.

#### Scenario: Scroll over sidebar
- **WHEN** mouse is over sidebar
- **AND** user scrolls middle mouse wheel
- **THEN** grid scrolls by one row
- **AND** Camera01 does NOT zoom

### Requirement: Tab hotkeys
Each tab SHALL have a keyboard shortcut: F1 (Buildings), F2 (Infantry), F3 (Vehicles), F4 (Special).

#### Scenario: Press F2
- **WHEN** user presses F2
- **THEN** Infantry tab becomes active
- **AND** grid shows infantry entities

### Requirement: Visual feedback for active tab
The active tab button SHALL be visually distinct from inactive tabs.

#### Scenario: Tab selected
- **WHEN** Infantry tab is active
- **THEN** Infantry tab button has distinct styling (highlighted/depressed)
- **AND** other tabs appear normal

### Requirement: Cameo button states
Each cameo button SHALL have visual states: Available (normal), Building (angular progress), Paused (darkened), Dark (build limit reached), Hidden (prerequisites not met).

#### Scenario: Entity available
- **WHEN** entity meets prerequisites and is under build limit
- **THEN** cameo appears in normal state

#### Scenario: Entity in queue building
- **WHEN** entity is currently being produced
- **THEN** cameo shows angular progress overlay

#### Scenario: Entity build limit reached
- **WHEN** entity has reached its build_limit
- **THEN** cameo appears darkened ("ghost" state)

#### Scenario: Entity prerequisites not met
- **WHEN** entity's prerequisites are not met
- **THEN** cameo is hidden (not displayed)

### Requirement: Left-click adds to queue
Left-clicking an available cameo SHALL add the entity to the production queue and deduct its cost.

#### Scenario: Click available entity
- **WHEN** user left-clicks an available cameo
- **THEN** entity is added to queue
- **AND** cost is deducted from credits

### Requirement: Right-click pause/cancel
Right-clicking a queued item SHALL pause it (if building) or cancel/decrement it (if paused).

#### Scenario: Right-click building item
- **WHEN** user right-clicks an actively building item
- **THEN** item is paused

#### Scenario: Right-click paused item
- **WHEN** user right-clicks a paused item
- **THEN** item is cancelled (full refund) or decremented (if count > 1)

### Requirement: Credits display at top
The sidebar SHALL display the player's current credits at the top of the sidebar, updated in real-time.

#### Scenario: Credits shown
- **WHEN** sidebar is visible
- **THEN** credits label shows "$<amount>" at the top
- **AND** updates when credits change

### Requirement: Sidebar dimensions
The sidebar SHALL be 400px wide and ~600px tall, anchored to the right edge of the viewport.

#### Scenario: Sidebar position
- **WHEN** game is running
- **THEN** sidebar is anchored to right edge
- **AND** 400px wide
- **AND** ~600px tall
