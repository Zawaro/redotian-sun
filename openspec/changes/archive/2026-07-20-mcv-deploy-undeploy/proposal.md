## Why

The MCV (Mobile Construction Vehicle) is the foundation of any base in Tiberian Sun. Players must be able to deploy their MCV into a Construction Yard to begin building structures, and undeploy the Construction Yard back to an MCV for relocation. Without this mechanic, the core game loop — start with MCV, deploy, build base — is broken.

This is a critical path feature for Issue #84 (First Blood milestone). All other building-related features depend on the player having a Construction Yard, which requires MCV deploy.

## What Changes

- **New DeployComponent**: Bidirectional component that handles both deploy (vehicle→building) and undeploy (building→vehicle) transformations. Configurable per entity via `.tres` resources.
- **Deploy input**: Ctrl+D hotkey triggers MCV deployment (matches canonical Tiberian Sun D key, with Ctrl modifier to avoid WASD camera conflict).
- **Undeploy via move command**: Left-click on ground with a building selected triggers undeploy instead of move (buildings cannot move).
- **Health ratio transfer**: Health is preserved as a ratio between source and target entity max_health values.
- **Owner preservation**: Player owner is preserved through deploy/undeploy via PlayerManager (#77).
- **Foundation validation**: Deploy checks that all foundation cells of the target building are free before placing.
- **Auto-scatter**: If allied units block foundation cells, they are automatically scattered to adjacent free cells.
- **EntityData extension**: New `deploys_into` and `undeploys_into` fields on EntityData for configuring deploy/undeploy targets.
- **MCV and ConYard .tres updates**: GDI MCV configured with `deploys_into = "GACNST"`, GDI Construction Yard configured with `undeploys_into = "MCV"`.

## Capabilities

### New Capabilities

- `deploy-undeploy`: Core deploy/undeploy system — DeployComponent, transform logic, foundation validation, health transfer, auto-scatter, input handling (Ctrl+D + move command interception).

### Modified Capabilities

- `entity-data`: Added `deploys_into` and `undeploys_into` fields to EntityData schema for configuring deploy/undeploy targets per entity.

## Impact

- **New files**: `scripts/components/DeployComponent.gd`, `test/unit/test_deploy_component.gd`
- **Modified files**:
  - `scripts/data/EntityData.gd` — new `deploys_into` and `undeploys_into` fields
  - `scripts/entities/EntityFactory.gd` — add `_add_deploy_component()` method
  - `scripts/core/SelectionManager.gd` — intercept move commands for buildings with DeployComponent
  - `scripts/hud/MouseHandler.gd` — handle Ctrl+D input for deploy
  - `project.godot` — add `deploy` input action (Ctrl+D)
  - `resources/entities/vehicles/gdi_mcv.tres` — set `deploys_into = "GACNST"`
  - `resources/entities/structures/gdi/gdi_construction_yard.tres` — set `undeploys_into = "MCV"`
- **Dependencies**: #77 (PlayerManager) — already implemented
- **No breaking changes**: New component, new fields, existing behavior unchanged
