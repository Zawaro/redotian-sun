## MODIFIED Requirements

### Requirement: Locomotor resource class
The system SHALL provide a `Locomotor.gd` resource class defining a movement type. Properties SHALL include `id: String`, `terrain_speeds: Dictionary` (land type id → speed multiplier float, where `0.0` or an absent key = impassable, `1.0` = full speed, `1.2` = speed bonus), `climb_tolerance: int` (height levels a unit can ascend/descend in one cell transition), `crushes: PackedStringArray` (documentation of crushable categories), behavior flags `is_hover`, `is_fly`, `is_jumpjet`, `is_subterranean`, `shares_cell`, `stand_upright`, `instant_turn`, `organic_path: bool`, plus hybrid thresholds `jumpjet_fly_distance: float` and `subterranean_dig_distance: float` (0 = use the alternate mode only when the primary path is impossible). Amphibious and ship passability SHALL be driven by `terrain_speeds` water entries, not by dedicated flags. `shares_cell` SHALL default `false` and SHALL be set `true` on the `Foot` and `Jumpjet` locomotors. `stand_upright`, `instant_turn`, and `organic_path` SHALL default `false` and SHALL encode infantry-style movement feel: upright facing, instant rotation, and organic path smoothing/easing respectively.

#### Scenario: Create foot locomotor
- **WHEN** a Locomotor resource is created with `id = "Foot"`, `terrain_speeds = {"clear": 1.0, "rough": 0.89, "road": 1.11, "water": 0.0}`, `climb_tolerance = 1`
- **THEN** the resource defines a ground-walking locomotor that cannot enter water

#### Scenario: Create fly locomotor
- **WHEN** a Locomotor resource is created with `id = "Fly"`, `terrain_speeds = {}`, `climb_tolerance = 99`, `is_fly = true`
- **THEN** the resource defines an air-only locomotor that ignores terrain and height

#### Scenario: Create ship locomotor
- **WHEN** a Locomotor resource is created with `id = "Ship"`, `terrain_speeds = {"water": 1.0}`
- **THEN** the resource defines a water-only naval locomotor for which all land surfaces are impassable

#### Scenario: Foot shares cells
- **WHEN** a Locomotor with `id = "Foot"` is loaded
- **THEN** `shares_cell`, `stand_upright`, `instant_turn`, and `organic_path` are `true`

#### Scenario: Non-sharing vehicle defaults to false
- **WHEN** a Locomotor resource is created without `shares_cell`
- **THEN** `shares_cell` defaults to `false` and the unit never books sub-slots or counts toward cell capacity

## ADDED Requirements

### Requirement: Locomotor drives MovementController behavior
MovementController SHALL derive occupancy participation and infantry-style movement feel from the unit's resolved Locomotor and SHALL NOT read `EntityData.EntityType` for movement decisions. `shares_cell` SHALL gate sub-slot booking, exact sub-slot landing, per-waypoint offsets, repulsion bypass between sharers, and non-sharer blocking of sharer cells. `stand_upright` SHALL gate the facing normal (`Vector3.UP` vs terrain normal), `instant_turn` SHALL gate the direct IDLE→MOVING transition (skipping ROTATING), and `organic_path` SHALL gate path smoothing and spline-end easing.

#### Scenario: Foot infantry behaves unchanged
- **WHEN** an infantry unit resolves `locomotor = "Foot"`
- **THEN** it shares cells, stands upright, turns instantly, and walks organic paths

#### Scenario: Non-infantry shares a cell
- **WHEN** an entity whose locomotor has `shares_cell = true` targets a cell containing another `shares_cell = true` unit below capacity
- **THEN** it books a free sub-slot and counts toward the cell's capacity
