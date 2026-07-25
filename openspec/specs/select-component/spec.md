## ADDED Requirements

### Requirement: SelectComponent manages selection visuals
`SelectComponent` SHALL be an `Area3D`-based component that manages selection visual feedback: selection box, health bar, hover/select visibility toggling, and rally line drawing.

#### Scenario: Component attached to entity
- **WHEN** EntityFactory creates an entity with `entity_type != TERRAIN`
- **THEN** a SelectComponent child node is added with `SelectionHitbox` and `SelectOutline` collision shapes

### Requirement: Select box types
SelectComponent SHALL support three visual modes via `select_box_type`: Infantry, Vehicle, and Structure. Each mode determines the visual style of the selection indicator.

#### Scenario: Structure select box
- **WHEN** `select_box_type == SelectBoxType.Structure`
- **THEN** a 3D selection box is rendered using ImmediateMesh L-shaped corner lines (12 bottom corners + 6 top corners)

#### Scenario: Vehicle/Infantry select box
- **WHEN** `select_box_type` is Infantry or Vehicle
- **THEN** the entity registers in "selectable", "entities", and "drag_selectable" groups

### Requirement: Health bar for structures
When a Structure entity has a HealthComponent, SelectComponent SHALL render a segmented health bar at the top of the selection box using BoxMesh with a grid overlay.

#### Scenario: Health bar visibility
- **WHEN** entity is selected or hovered AND has HealthComponent
- **THEN** health bar and grid are visible

#### Scenario: Health bar hidden when not selected
- **WHEN** entity is neither selected nor hovered
- **THEN** health bar and grid are hidden

#### Scenario: Health bar updates on damage
- **WHEN** HealthComponent emits `health_changed`
- **THEN** `update_health_bar()` resizes the bar proportionally and updates color

### Requirement: Health color thresholds
SelectComponent SHALL color the health bar based on health percentage:
- Green: health > 50%
- Yellow: health > 25% and ≤ 50%
- Red: health > 0% and ≤ 25%
- Dark red (0.5, 0.0, 0.0): health = 0 (dead)

#### Scenario: Full health is green
- **WHEN** health percentage is 100%
- **THEN** health bar color is green

#### Scenario: Half health is yellow
- **WHEN** health percentage is 40%
- **THEN** health bar color is yellow

#### Scenario: Critical health is red
- **WHEN** health percentage is 10%
- **THEN** health bar color is red

#### Scenario: Dead unit is dark red
- **WHEN** health percentage is 0%
- **THEN** health bar color is dark red

### Requirement: Hover and select visibility
SelectComponent SHALL toggle visibility of all child meshes based on hover and selection state. The building select box is only visible when selected (not on hover). Rally line is only visible when selected AND a rally point is set.

#### Scenario: Hover shows outline
- **WHEN** `is_hovering = true` and `is_selected = false`
- **THEN** selection outline and health bar are visible, building select box is hidden

#### Scenario: Select shows everything
- **WHEN** `is_selected = true`
- **THEN** all selection visuals are visible

#### Scenario: Neither hover nor select hides all
- **WHEN** `is_hovering = false` and `is_selected = false`
- **THEN** all selection visuals are hidden

### Requirement: Rally line drawing
When a building has a RallyPointComponent, SelectComponent SHALL draw a green line from the building center to the rally point cell with a diamond marker at the endpoint.

#### Scenario: Rally line visible when selected with rally point
- **WHEN** entity is selected AND RallyPointComponent has a set rally point
- **THEN** a green line extends from building center to rally point with a diamond marker

#### Scenario: Rally line hidden when no rally point
- **WHEN** entity is selected but RallyPointComponent has no rally point
- **THEN** rally line is hidden

#### Scenario: Rally line updates on change
- **WHEN** RallyPointComponent emits `rally_point_changed`
- **THEN** rally line is redrawn to the new position

### Requirement: Group registration
SelectComponent SHALL register its parent entity in scene tree groups based on its type and selectability flags:
- "selectable": if `is_selectable == true`
- "drag_selectable": if `is_drag_selectable == true`
- "entities": always (for iteration by core systems)

#### Scenario: Selectable unit registered
- **WHEN** a Vehicle entity with `is_selectable = true` enters the scene tree
- **THEN** parent is in "selectable", "drag_selectable", and "entities" groups

#### Scenario: Structure not in drag_selectable
- **WHEN** a Structure entity enters the scene tree
- **THEN** parent is NOT in "drag_selectable" group (structures can't be box-selected)
