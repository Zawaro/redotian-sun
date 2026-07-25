## MODIFIED Requirements

### Requirement: DeployComponent order targeter
DeployComponent SHALL implement `get_order_for_target()`. When target is the same entity (self) and `can_deploy()` is true, it SHALL return DEPLOY cursor, priority 15, and execute callback that calls `execute_deploy(parent)`. When target is null and `can_undeploy()` is true, it SHALL return MOVE cursor and execute callback that calls `execute_undeploy(parent, target_pos)`. The undeploy execute callback SHALL compute its own cell offset from the selection center at execution time, not at resolution time. Otherwise returns null.

#### Scenario: Click self to deploy
- **WHEN** an MCV is selected and cursor is over itself
- **THEN** cursor SHALL be DEPLOY and clicking SHALL deploy the MCV

#### Scenario: Click ground to undeploy
- **WHEN** a deployed building is selected and cursor is over terrain
- **THEN** cursor SHALL be MOVE and clicking SHALL undeploy the building to that position

#### Scenario: Undeploy offset calculation
- **WHEN** multiple buildings are selected and one clicks terrain to undeploy
- **THEN** each building's execute callback SHALL compute its own offset from the selection center using its own global_position, not a shared target_pos

#### Scenario: Cannot deploy
- **WHEN** an entity has DeployComponent but `can_deploy()` returns false
- **THEN** get_order_for_target() SHALL return null for self-target

#### Scenario: Cannot undeploy
- **WHEN** an entity has DeployComponent but `can_undeploy()` returns false
- **THEN** get_order_for_target() SHALL return null for terrain-target

### Requirement: DeployComponent removes get_cursor_for_target
DeployComponent SHALL remove the existing `get_cursor_for_target()` method. Cursor behavior is now provided by `get_order_for_target()`. During the migration period, both methods may coexist temporarily — the old method is removed in the final cleanup task.

#### Scenario: Old method removed
- **WHEN** `get_cursor_for_target()` is called on DeployComponent after migration
- **THEN** it SHALL not exist (method removed)

### Requirement: Deploy-on-click via order system
MouseHandler SHALL no longer check for DeployComponent directly when an already-selected entity is clicked. Instead, the normal order resolution path via OrderSystem.get_orders() SHALL handle deploy via DeployComponent's get_order_for_target().

#### Scenario: Deploy via order system
- **WHEN** an already-selected MCV is clicked again
- **THEN** OrderSystem.get_orders() SHALL return the deploy OrderResult from DeployComponent

#### Scenario: No hardcoded deploy check
- **WHEN** MouseHandler._handle_left_click_normal() processes a click on a selected entity
- **THEN** it SHALL NOT contain a direct check for DeployComponent
