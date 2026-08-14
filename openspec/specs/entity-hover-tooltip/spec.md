## Purpose

Show a hover tooltip over world entities, resources, and shrouded cells in the RTS viewport, reusing the existing `SelectionManager` hover state with no additional per-frame raycasts.

## Requirements

### Requirement: Tooltip shown on hover over selectable entities
When the local player hovers the cursor over a selectable world entity (unit or structure) that is revealed to the local player, the game SHALL display a hover tooltip. The tooltip SHALL follow the cursor position while hovering and SHALL disappear when hover clears (mouse leaves the entity) or when the cursor moves over sidebar/debug UI. Hover detection SHALL reuse the existing `SelectionManager` hover state — no additional per-frame raycasts.

#### Scenario: Hover over an entity shows the tooltip
- **WHEN** the cursor hovers over a revealed selectable entity
- **THEN** the tooltip SHALL become visible, positioned at the cursor

#### Scenario: Hover clears
- **WHEN** hover clears (the entity is no longer hovered)
- **THEN** the tooltip SHALL hide

#### Scenario: Cursor over sidebar UI
- **WHEN** the cursor moves over the sidebar or debug UI
- **THEN** the tooltip SHALL hide even if the previous hover target is unchanged

### Requirement: Tooltip appears after a hover delay
The tooltip SHALL appear only after the cursor has hovered the same target continuously for 0.5 seconds. Moving the cursor SHALL reset the delay: a pending tooltip restarts its countdown, and a visible tooltip SHALL hide and stay hidden until the restarted delay lapses. It SHALL hide immediately when hover clears, and a new target SHALL restart the delay. The delay SHALL apply to every tooltip target (entities, resources, shrouded cells). Re-hovering a target after hover cleared SHALL re-arm the delay and show the tooltip again once it lapses.

#### Scenario: Delay before first appearance
- **WHEN** the cursor hovers a target and then stops
- **THEN** the tooltip SHALL NOT be visible before 0.5 seconds have elapsed, and SHALL become visible after the delay lapses

#### Scenario: Cursor movement resets the pending delay
- **WHEN** the cursor moves before the 0.5-second delay lapses
- **THEN** the delay SHALL restart from zero

#### Scenario: Cursor movement hides a visible tooltip until the delay refills
- **WHEN** the tooltip is visible and the cursor moves
- **THEN** the tooltip SHALL hide, the delay SHALL restart, and the tooltip SHALL reappear only after the restarted delay lapses

#### Scenario: Clear cancels the pending tooltip
- **WHEN** hover clears before the 0.5-second delay lapses
- **THEN** the tooltip SHALL remain hidden

#### Scenario: Tooltip reappears on the same target after hover clears
- **WHEN** hover clears (e.g. the cursor passes over the sidebar) and the cursor later hovers the same target again
- **THEN** the tooltip SHALL re-arm the delay and SHALL show the target's label once the delay lapses

### Requirement: Friendly and neutral entities show their real name
For an entity owned by the local player (friendly), the tooltip SHALL display the entity's real `display_name`. For a neutral entity (different player, same team, or ownerless with `player_id == -1`), the tooltip SHALL also display the real `display_name`.

#### Scenario: Friendly unit
- **WHEN** the cursor hovers over a unit owned by the local player
- **THEN** the tooltip SHALL show the unit's `display_name`

#### Scenario: Neutral entity
- **WHEN** the cursor hovers over an entity owned by another player on the local player's team, or by no player (`player_id == -1`)
- **THEN** the tooltip SHALL show the entity's `display_name`

### Requirement: Resource entities show their real name
When the cursor hovers a resource entity (tiberium field or tree) through the interaction-hitbox hover path, the tooltip SHALL show the resource's `display_name`, with the same 1-second delay and immediate-hide behavior as other targets.

#### Scenario: Hover over a tiberium tree
- **WHEN** the cursor hovers a tiberium tree (interaction hitbox, no SelectComponent)
- **THEN** the tooltip SHALL show the tree's `display_name` after the hover delay

### Requirement: Enemy entities show a type label, not a name
For an enemy entity (different team per `PlayerManager.is_enemy`), the tooltip SHALL show a type-only label instead of the real name: `ENEMY INFANTRY` for infantry, `ENEMY UNIT` for vehicles, `ENEMY STRUCTURE` for buildings. An enemy aircraft that is airborne SHALL show `ENEMY AIRCRAFT`; a grounded enemy aircraft SHALL show `ENEMY UNIT`. No real display name SHALL be revealed for enemies.

#### Scenario: Enemy infantry
- **WHEN** the cursor hovers over enemy infantry
- **THEN** the tooltip SHALL show `ENEMY INFANTRY`

#### Scenario: Enemy vehicle
- **WHEN** the cursor hovers over an enemy vehicle
- **THEN** the tooltip SHALL show `ENEMY UNIT`

#### Scenario: Enemy structure
- **WHEN** the cursor hovers over an enemy structure
- **THEN** the tooltip SHALL show `ENEMY STRUCTURE`

#### Scenario: Airborne enemy aircraft
- **WHEN** the cursor hovers over an enemy aircraft that is airborne
- **THEN** the tooltip SHALL show `ENEMY AIRCRAFT`

#### Scenario: Grounded enemy aircraft
- **WHEN** the cursor hovers over an enemy aircraft that is not airborne
- **THEN** the tooltip SHALL show `ENEMY UNIT`

### Requirement: Tooltip is an uppercase black panel with green outline
The tooltip SHALL render as a black panel with a green outline and SHALL display its text in uppercase. The text SHALL be uppercase regardless of the source label's casing.

#### Scenario: Text is uppercased
- **WHEN** the tooltip shows a label containing lowercase characters
- **THEN** the label SHALL be rendered entirely in uppercase

### Requirement: Shrouded cells show UNREVEALED TERRAIN
When no entity is hovered, the cursor is over ground, and the cell under the cursor is not revealed to the local player (shroud or fog), the tooltip SHALL show `UNREVEALED TERRAIN` with the same 1-second delay and immediate-hide behavior. When the cell is revealed, no tooltip SHALL appear for empty ground.

#### Scenario: Hover over shrouded ground
- **WHEN** the cursor hovers shrouded (unrevealed) ground and no entity is hovered, and shroud is enabled
- **THEN** the tooltip SHALL show `UNREVEALED TERRAIN` after the hover delay

#### Scenario: Hover over revealed empty ground
- **WHEN** the cursor hovers revealed empty ground and no entity is hovered
- **THEN** the tooltip SHALL remain hidden
