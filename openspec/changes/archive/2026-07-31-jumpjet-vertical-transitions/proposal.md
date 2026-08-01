## Why

Jumpjet infantry snap to their flight altitude (`GlobalRules.hover_height`, shared with hover units) instead of ascending/descending smoothly, and their target height is not configurable. Attacks are not zone-aware: an airborne jumpjet can descend to the ground when issued an attack approach move, and its 3D range check makes hovering attackers unable to fire at ground targets. This is a follow-up to the `locomotor-enforcement-movement-zones` change (#34).

## What Changes

- Add a configurable `jumpjet_target_height` field to the `Locomotor` resource (terrain height units, default `6.0` ≈ `6 × HEIGHT_STEP` world units), replacing the shared `GlobalRules.hover_height` as the jumpjet's flight altitude. Applied to `resources/locomotors/Jumpjet.tres`.
- Introduce a **vertical state machine** in `MovementController`: `GROUND`, `ASCENDING`, `AIR`, `DESCENDING`. Y is moved toward the target altitude at `move_speed` per frame instead of being snapped.
- **Zone retention on attack**: an attack approach (`CombatComponent._move_toward_target`) passes a `keep_zone` flag so a jumpjet attacks on land when grounded and in the air when airborne; if mid-transition it ascends to the target height and attacks.
- **Walk-first move orders**: move orders walk on foot when reachable, and fly-fallback (fly to the destination then land) only when the walk path is empty or the distance exceeds `jumpjet_fly_distance`.
- **New order while descending** returns the unit to the air zone (ascends), matching TS interrupt behavior.
- Terrain speed factor is skipped while the jumpjet is airborne (flying over rough shouldn't slow it).
- **Combat range is horizontal (XZ)**: the range check in `CombatComponent` ignores the Y axis, so an attacker hovering above terrain can fire at ground targets, and airborne jumpjets can engage both land and air targets regardless of altitude.

## Capabilities

### New Capabilities
- `jumpjet-vertical-transitions`: configurable jumpjet flight altitude, vertical ascend/descend state machine, zone-retaining attack movement, walk-first move orders with fly-fallback landing, and airborne terrain-speed exemption.

### Modified Capabilities
- `combat-firing`: range checking changes from 3D distance to horizontal (XZ) distance so altitude does not push hovering attackers out of range.

## Impact

- **Modified scripts**: `scripts/components/MovementController.gd` (vertical state machine, `jumpjet_target_height`, `keep_zone` param, airborne terrain-speed exemption, guarded Y-snaps), `scripts/components/CombatComponent.gd` (XZ range check, `keep_zone` attack approach), `scripts/data/Locomotor.gd` (new `jumpjet_target_height` export).
- **Modified resources**: `resources/locomotors/Jumpjet.tres`.
- **New/updated specs**: `openspec/specs/jumpjet-vertical-transitions/`; delta to `openspec/specs/combat-firing/`.
- **Tests**: unit tests for target-height config, ascend/descend transitions, zone retention on attack, walk-first fly-fallback and landing, descend-interrupt ascend, and XZ combat range.
- Non-goals: jumpjet animation states, per-entity height overrides, aircraft (`is_fly`) altitude.
