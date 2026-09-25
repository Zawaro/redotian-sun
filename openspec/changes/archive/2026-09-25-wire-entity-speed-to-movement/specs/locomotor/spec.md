## ADDED Requirements

### Requirement: MovementController base speed derives from EntityData

`MovementController` SHALL set its base `move_speed` from the entity's `EntityData.speed` via `GlobalRules.speed_to_units_per_second()`, not from a fixed default. Because `configure()` runs before the controller enters the tree (and thus before `_ready()` resolves `GlobalRules`), the controller SHALL retain the raw `EntityData.speed` and apply the conversion as soon as rules are available, so the converted value is in force before the first move. The exported `move_speed` default SHALL serve only as a fallback for controllers constructed directly without `configure()` (tests, editor previews).

#### Scenario: Configured controller uses the converted speed

- **WHEN** a MovementController is configured from an EntityData with `speed = 6.0` at `logic_fps = 30`
- **THEN** its `move_speed` is `3.6` world units per second

#### Scenario: Conversion applied when rules resolve later

- **WHEN** `configure()` runs before GlobalRules is resolvable and the entity is then added to the tree
- **THEN** `move_speed` reflects the converted `EntityData.speed` before the first movement step

#### Scenario: Bare controller keeps its export default

- **WHEN** a MovementController is created and `_handle_moving_movement` runs without `configure()` having been called
- **THEN** `move_speed` remains the scene/export default and existing mechanics tests are unaffected

## MODIFIED Requirements

### Requirement: Speed ramp behavior

MovementController SHALL ramp a locomotor's per-tick speed when `accelerate` or `decelerate` is `true`. The ramp SHALL target `move_speed` directly; per-unit factors (vertical split, veteran, slope, terrain, speed jitter) and the neighbor-proximity slowdown SHALL multiply on top of the ramped speed via the step chain, never inside the ramp's target. A decel-only locomotor (`decelerate = true`, `accelerate = false` — TS semantics: no Accelerate = immediate cruise) SHALL start fresh moves at full target speed; an accelerating locomotor SHALL start from standstill. Ramp state SHALL reset only at arrival and `_finish_stop()`, and SHALL carry across mid-move re-targets and stop-order truncations. Jumpjet vertical ascent/descent SHALL use the unit's per-unit `move_speed` directly and SHALL NOT be subject to the accelerate/decelerate ramp.

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

#### Scenario: Ramp targets the per-unit speed

- **WHEN** the same locomotor runs on two units with different `EntityData.speed`
- **THEN** each ramps toward its own converted `move_speed`
