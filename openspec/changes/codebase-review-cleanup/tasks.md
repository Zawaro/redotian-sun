## 1. Bug Fixes

- [x] 1.1 Replace `assert()` with `push_error()` + `return` in `MouseHandler.gd` (L58, L70, L123, L129)
- [x] 1.2 Replace fragile relative path `"../MouseHandler/camera_pivot"` in `BoundsSystem.gd` with `@export var camera_pivot: Node3D` and wire in scenes
- [x] 1.3 Add setter to `grid_cells` in `TerrainSystem.gd` that calls `_init_vertex_grid()` with value clamping
- [x] 1.4 Remove `* 60.0` from `CameraController.gd` L59 and L17, adjust `navigation_speed` and `axis_speed` base values

## 2. Dead Code Removal

- [x] 2.1 Delete `scripts/core/SceneManager.gd` and remove any scene references
- [x] 2.2 Delete `_on_deselected()` method from `SelectComponent.gd` (L125-127)
- [x] 2.3 Delete `grid_size` getter from `MapEditor.gd` (L18-19)
- [x] 2.4 Replace `_vkey()` calls with `_cell_key()` in `TerrainSystem.gd` and delete `_vkey` function
- [~] ~~2.5~~ **Won't do** — TestMap02 `raise_cell()` duplicate is intentional (two calls needed for height 2, each increments by 1)

## 3. Refactoring

- [x] 3.1 Optimize Pathfinder heap: cache `f_score` lookups to avoid repeated `_cell_key()` string concatenation in `Pathfinder.gd`
- [x] 3.2 Extract catmull-rom functions from `MovementController.gd` into new `scripts/core/SplineUtil.gd` as static methods
- [x] 3.3 Simplify `BoundsSystem.clamp_camera_position()` using `clampf()` per-component instead of if/elif chains
- [~] ~~3.4~~ **Deferred** — MapEditor UI: 48 lines of simple programmatic UI, low ROI for scene extraction
- [~] ~~3.5~~ **Deferred** — SelectComponent extraction: 286-line _ready(), tightly coupled to state, would require many parameters

## 4. Style Fixes

- [x] 4.1 Replace `emit_signal("name", args)` with `signal_name.emit(args)` in `HealthComponent.gd` (4 locations)
- [x] 4.2 Rename `@onready var Text` to `@onready var text_label` in `MainMenuItem01.gd` and update references

## 5. CI Linting

- [x] 5.1 Add lint job to `.github/workflows/test.yml` using gdtoolkit (`gdlint` + `gdformat --check`)
- [x] 5.2 Add `.gdlintrc` config file to suppress acceptable warnings if needed

## 6. Documentation

- [x] 6.1 Update `AGENTS.md`: folder structure, file counts, remove "No test framework" and "No CI/CD", add testing/linting section
- [x] 6.2 Update `README.md`: add Development section with prerequisites, test commands, lint commands
