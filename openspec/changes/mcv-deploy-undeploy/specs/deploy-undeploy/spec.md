## ADDED Requirements

### Requirement: DeployComponent bidirectional configuration
The system SHALL provide a `DeployComponent` node class that configures both deploy (vehicle→building) and undeploy (building→vehicle) transformations. The component SHALL include `deploys_into: String` (target entity id for deploy), `undeploys_into: String` (target entity id for undeploy), `deploy_time: float` (seconds, 0=instant), `deploy_rotation: float` (degrees), `undeploy_rotation: float` (degrees), `deploy_cell: Vector2i` (local offset for spawn point, default [0,0]), and `transfer_health_ratio: bool` (default true).

#### Scenario: MCV DeployComponent
- **WHEN** a DeployComponent is configured with `deploys_into = "GACNST"`, `undeploys_into = ""`, `deploy_rotation = 0.0`, `deploy_cell = Vector2i(0,0)`
- **THEN** the component configures the entity for deploy-only transformation to "GACNST"

#### Scenario: ConYard DeployComponent
- **WHEN** a DeployComponent is configured with `deploys_into = ""`, `undeploys_into = "MCV"`, `undeploy_rotation = 0.0`, `deploy_cell = Vector2i(0,0)`
- **THEN** the component configures the entity for undeploy-only transformation to "MCV"

### Requirement: Deploy via Ctrl+D hotkey
The system SHALL trigger MCV deployment when the player presses Ctrl+D while an MCV is selected. The MCV SHALL be idle (not moving) to deploy. The system SHALL validate that all foundation cells of the target building are free before deploying. The system SHALL deselect the MCV before removing it from the world.

#### Scenario: Successful deploy
- **WHEN** player selects an MCV and presses Ctrl+D
- **AND** MCV is idle
- **AND** all foundation cells of the target building are free
- **THEN** MCV is deselected
- **AND** MCV is removed from the world
- **AND** target building is created at the calculated origin cell with `deploy_rotation` applied
- **AND** building cells are registered in SpatialHash
- **AND** PrerequisiteSystem.register_building() is called
- **AND** health is transferred by ratio

#### Scenario: Deploy blocked by moving MCV
- **WHEN** player selects an MCV that is currently moving and presses Ctrl+D
- **THEN** deploy is aborted with no action

#### Scenario: Deploy blocked by occupied cells
- **WHEN** player selects an MCV and presses Ctrl+D
- **AND** one or more foundation cells of the target building are occupied by enemy units or buildings
- **THEN** deploy is aborted with a warning

### Requirement: Auto-scatter on deploy
The system SHALL automatically scatter allied units that block foundation cells when deploying. The scatter SHALL push units to adjacent free cells. After scatter, the system SHALL re-validate foundation cells. If cells are still blocked after scatter, deploy SHALL abort with a warning.

#### Scenario: Scatter clears foundation
- **WHEN** player deploys MCV
- **AND** foundation cells have allied idle units
- **THEN** allied units are scattered to adjacent free cells
- **AND** deploy proceeds after scatter completes

#### Scenario: Scatter fails to clear foundation
- **WHEN** player deploys MCV
- **AND** foundation cells have allied idle units
- **AND** scatter cannot find free adjacent cells for all units
- **THEN** deploy is aborted with a warning

### Requirement: Undeploy via move command
The system SHALL trigger building undeploy when the player left-clicks on ground (move command) with one or more buildings selected. All selected buildings with a DeployComponent that has `undeploys_into` set SHALL undeploy simultaneously. The system SHALL NOT attempt to move the buildings (buildings cannot move). The system SHALL deselect each building before removing it from the world.

#### Scenario: Successful undeploy
- **WHEN** player selects a building with DeployComponent and left-clicks on ground
- **AND** `undeploys_into` is set
- **THEN** building is deselected
- **AND** building cells are unregistered from SpatialHash
- **AND** PrerequisiteSystem.unregister_building() is called
- **AND** building is removed from the world
- **AND** vehicle entity is created at `deploy_cell` offset with `undeploy_rotation` applied
- **AND** health is transferred by ratio
- **AND** owner is preserved
- **AND** vehicle moves to the clicked ground position

#### Scenario: Undeploy retains move command
- **WHEN** player left-clicks on ground at position (10, 0, 5) with a ConYard selected
- **AND** ConYard has `undeploys_into = "MCV"`
- **THEN** ConYard undeploys into MCV
- **AND** MCV issues a move command to position (10, 0, 5) after creation

#### Scenario: Multiple buildings undeploy
- **WHEN** player selects 3 buildings with DeployComponent and left-clicks on ground
- **AND** all 3 have `undeploys_into` set
- **THEN** all 3 buildings undeploy simultaneously
- **AND** 3 vehicle entities are created at their respective `deploy_cell` offsets
- **AND** each vehicle moves to the clicked ground position

#### Scenario: Building without DeployComponent
- **WHEN** player selects a building without DeployComponent and left-clicks on ground
- **THEN** no action is taken (buildings cannot move)

### Requirement: Health ratio transfer
The system SHALL transfer health as a percentage of source entity's current health relative to its max_health. The formula SHALL be: `target_health = int(float(target_max_health) * float(source_health) / float(source_max_health))`. If `source_max_health <= 0`, target SHALL spawn with full health. This SHALL apply to both deploy and undeploy directions.

#### Scenario: Deploy with same max_health
- **WHEN** MCV with 500/1000 HP deploys into ConYard with 1000 max HP
- **THEN** ConYard spawns with 500 HP (50% ratio preserved)

#### Scenario: Deploy with different max_health
- **WHEN** MCV with 500/1000 HP deploys into ConYard with 2000 max HP
- **THEN** ConYard spawns with 1000 HP (50% ratio preserved)

#### Scenario: Deploy with lower target max_health
- **WHEN** MCV with 800/1000 HP deploys into ConYard with 500 max HP
- **THEN** ConYard spawns with 400 HP (80% ratio preserved)

#### Scenario: Undeploy with damaged ConYard
- **WHEN** ConYard with 750/1000 HP undeploys into MCV with 1000 max HP
- **THEN** MCV spawns with 750 HP (75% ratio preserved)

#### Scenario: Source at zero max_health
- **WHEN** source entity has max_health of 0
- **THEN** target spawns with full health (target_max_health)

### Requirement: Owner preservation
The system SHALL preserve the player owner through deploy/undeploy transformations. The owner of the source entity SHALL be set on the target entity after transformation.

#### Scenario: Deploy preserves owner
- **WHEN** player 1's MCV deploys into ConYard
- **THEN** ConYard belongs to player 1

#### Scenario: Undeploy preserves owner
- **WHEN** player 1's ConYard undeploys into MCV
- **THEN** MCV belongs to player 1

### Requirement: Deploy origin calculation
The system SHALL calculate the deploy origin cell by centering the target building's foundation on the MCV's current cell. For a building with foundation (W×H), the origin SHALL be MCV cell + Vector2i(-W/2, -H/2) using integer division.

#### Scenario: MCV deploys 3x3 ConYard
- **WHEN** MCV at cell [5,5] deploys into 3x3 ConYard
- **THEN** ConYard origin is at cell [4,4]
- **AND** ConYard covers cells [4,4] to [6,6]

#### Scenario: MCV deploys 2x2 building
- **WHEN** MCV at cell [5,5] deploys into 2x2 building
- **THEN** building origin is at cell [4,4]
- **AND** building covers cells [4,4] to [5,5]

### Requirement: EntityFactory DeployComponent creation
The system SHALL add a DeployComponent to entities when `deploys_into` or `undeploys_into` is set in their EntityData. The component SHALL be configured with the EntityData's deploy fields.

#### Scenario: MCV gets DeployComponent
- **WHEN** EntityFactory creates an entity with `deploys_into = "GACNST"`
- **THEN** a DeployComponent is added with `deploys_into = "GACNST"`

#### Scenario: ConYard gets DeployComponent
- **WHEN** EntityFactory creates an entity with `undeploys_into = "MCV"`
- **THEN** a DeployComponent is added with `undeploys_into = "MCV"`

#### Scenario: Entity without deploy fields
- **WHEN** EntityFactory creates an entity with `deploys_into = ""` and `undeploys_into = ""`
- **THEN** no DeployComponent is added
