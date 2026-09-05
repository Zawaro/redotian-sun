# locomotor Specification (Delta)

## MODIFIED Requirements

### Requirement: Locomotor resource class
The system SHALL provide a `Locomotor.gd` resource class defining a movement type. Properties SHALL include `id: String`, `terrain_speeds: Dictionary` (land type id → speed multiplier float, where `0.0` or an absent key = impassable, `1.0` = full speed, `1.2` = speed bonus), `climb_tolerance: int` (height levels a unit can ascend/descend in one cell transition), `crushes: PackedStringArray` (documentation of crushable categories), behavior flags `is_hover`, `is_fly`, `is_jumpjet`, `is_subterranean`, `shares_cell`, `stand_upright`, `instant_turn`, `organic_path: bool`, **accelerate: bool**, **decelerate: bool**, plus hybrid thresholds `jumpjet_fly_distance: float` and `subterranean_dig_distance: float` (0 = use the alternate mode only when the primary path is impossible). Amphibious and ship passability SHALL be driven by `terrain_speeds` water entries, not by dedicated flags. `shares_cell`, `accelerate`, and `decelerate` SHALL default `false`. `stand_upright`, `instant_turn`, and `organic_path` SHALL default `false` and SHALL encode infantry-style movement feel: upright facing, instant rotation, and organic path smoothing/easing respectively.

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
- **THEN** `shares_cell`, `accelerate`, and `decelerate` default to `false` and the unit never books sub-slots or counts toward cell capacity

## ADDED Requirements

### Requirement: Speed ramp behavior
MovementController SHALL ramp a locomotor's per-tick speed when `accelerate` or `decelerate` is `true`. The ramp SHALL target `move_speed` directly; per-unit factors (vertical split, veteran, slope, terrain, speed jitter) and the neighbor-proximity slowdown SHALL multiply on top of the ramped speed via the step chain, never inside the ramp's target. A decel-only locomotor (`decelerate = true`, `accelerate = false` — TS semantics: no Accelerate = immediate cruise) SHALL start fresh moves at full target speed; an accelerating locomotor SHALL start from standstill. Ramp state SHALL reset only at arrival and `_finish_stop()`, and SHALL carry across mid-move re-targets and stop-order truncations. Jumpjet vertical ascent/descent speed SHALL be unaffected.

#### Scenario: Accelerate ramp-up
- **WHEN** a locomotor with `accelerate = true` starts a move from standstill
- **THEN** per-frame displacement rises from below target speed toward full speed, never exceeding it

#### Scenario: Decelerate ramp-down
- **WHEN** a locomotor with `decelerate = true` approaches its final waypoint
- **THEN** per-frame displacement falls below target speed, ending at ~crawl speed at arrival

#### Scenario: No-regression default-off
- **WHEN** `accelerate` and `decelerate` are `false` (default)
- **THEN** per-frame displacement is identical to current constant-speed behavior

#### Scenario: Short-move no overshoot
- **WHEN** a 1–2 cell order runs with both flags `true`
- **THEN** the ramp collapses to a triangular profile and the unit lands exactly on the sub-slot with no overshoot

#### Scenario: Terrain factor scales ramp
- **WHEN** a ramping unit enters a slow-terrain cell
- **THEN** the terrain multiplier scales the ramped speed proportionally

#### Scenario: Decel-only starts at cruise
- **WHEN** a locomotor with `decelerate = true` and `accelerate = false` orders its first move
- **THEN** the ramp starts at full target speed rather than from standstill

#### Scenario: Carry-forward on retarget
- **WHEN** an internal re-target (blocked arrival, repair, scatter) occurs mid-move
- **THEN** current ramped speed carries forward

#### Scenario: Fresh order starts from standstill
- **WHEN** a fresh order starts from IDLE on an accelerating locomotor
- **THEN** the ramp starts at 0
