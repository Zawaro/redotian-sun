## Why

Units move at full target speed from frame one and stop instantly at their destination. Tiberian Sun locomotors have `Accelerate=`/`Decelerate=` flags that ramp speed up from 0 at move start and down to ~0 at arrival, giving heavy vehicles a sense of momentum. This feature adds those flags to the locomotor resource.

## What Changes

- **Locomotor.gd**: Two new behavior flags `accelerate: bool = false` and `decelerate: bool = false` (Behavior Flags group)
- **GlobalRules.gd + global_rules.tres**: Three time-based ramp constants (`ramp_accel_time`, `ramp_decel_time`, `ramp_crawl_fraction`)
- **MovementController.gd**: Closed-form speed ramp using a braking envelope `sqrt(2·decel_rate·remaining_distance)` plus acceleration, applied to the per-tick step chain
- **Track.tres / Wheel.tres**: Both flags enabled (`true`)
- **test_movement_ramp.gd**: New unit tests for ramp behavior

## Capabilities

### New Capabilities

- `speed-ramp`: Closed-form ramping of locomotor speed from 0 to target and back to ~0 at arrival; crawl floor; reset edges / carry-forward

### Modified Capabilities

- `locomotor`: Locomotor resource gains `accelerate`/`decelerate` boolean flags; MovementController ramps speed when these are enabled

## Impact

- **Scripts**: `scripts/data/Locomotor.gd`, `scripts/data/GlobalRules.gd`, `scripts/components/MovementController.gd`
- **Data**: `resources/locomotors/Track.tres`, `resources/locomotors/Wheel.tres` (and any `.uid` files)
- **Tests**: `test/unit/test_movement_ramp.gd`
- **Glossary**: New term "speed ramp" added to Movement section
