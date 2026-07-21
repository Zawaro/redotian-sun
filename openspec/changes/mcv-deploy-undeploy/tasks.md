## 1. EntityData Extension

- [x] 1.1 Add `deploys_into: String = ""` and `undeploys_into: String = ""` fields to `scripts/data/EntityData.gd`
- [x] 1.2 Update `gdi_mcv.tres` to set `deploys_into = "GACNST"`
- [x] 1.3 Update `gdi_construction_yard.tres` to set `undeploys_into = "MCV"`

## 2. DeployComponent

- [x] 2.1 Create `scripts/components/DeployComponent.gd` with bidirectional config fields
- [x] 2.2 Add `_add_deploy_component()` method to `scripts/entities/EntityFactory.gd`
- [x] 2.3 Wire DeployComponent configuration from EntityData in EntityFactory

## 3. Deploy Logic

- [x] 3.1 Create deploy validation logic (foundation check, cell free check)
- [x] 3.2 Create deploy origin calculation (center building on MCV cell)
- [x] 3.3 Create auto-scatter logic for blocked foundation cells
- [x] 3.4 Create deploy execution (deselect MCV, remove MCV, create building, register cells, transfer health, register prerequisite)
- [x] 3.5 Add `request_deploy()` method to `scripts/core/SelectionManager.gd`

## 4. Undeploy Logic

- [x] 4.1 Modify `SelectionManager.request_move()` to detect DeployComponent on buildings
- [x] 4.2 Create undeploy execution (deselect building, unregister building cells, unregister prerequisite, remove building, create vehicle, transfer health)
- [x] 4.3 Handle multi-select undeploy (all selected buildings with DeployComponent undeploy simultaneously)

## 5. Input Handling

- [x] 5.1 Add `deploy` input action (Ctrl+D) to `project.godot`
- [x] 5.2 Handle Ctrl+D input in `scripts/hud/MouseHandler.gd` → call `SelectionManager.request_deploy()`

## 6. Testing

- [x] 6.1 Create `test/unit/test_deploy_component.gd` — component configuration tests
- [x] 6.2 Add deploy tests to `test/unit/test_selection_manager.gd` — deploy validation, execution, deselect
- [x] 6.3 Add undeploy tests — move command detection, undeploy execution, multi-select undeploy
- [x] 6.4 Add health transfer tests — same max_health, different max_health, zero max_health guard
- [x] 6.5 Add PrerequisiteSystem integration tests — register on deploy, unregister on undeploy
- [ ] 6.6 Run full test suite: `redot --headless -s test/run_tests.gd`
- [x] 6.7 Run linting: `gdlint scripts/**/*.gd test/**/*.gd`

## 7. Manual Verification

- [x] 7.1 Test MCV deploy in-game — Ctrl+D creates ConYard at correct position
- [x] 7.2 Test ConYard undeploy — left-click on ground creates MCV
- [x] 7.3 Test health preservation through deploy/undeploy cycle (50% damaged MCV → 50% damaged ConYard)
- [x] 7.4 Test health transfer with different max_health values
- [x] 7.5 Test owner preservation through deploy/undeploy cycle
- [x] 7.6 Test auto-scatter when foundation cells are blocked
- [x] 7.7 Test multi-select undeploy — 3 buildings undeploy simultaneously
