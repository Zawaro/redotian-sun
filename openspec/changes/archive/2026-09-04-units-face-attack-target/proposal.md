## Why

Units fire at attack targets without rotating to face them — a stationary vehicle shooting a target behind it fires sideways, breaking Tiberian Sun fidelity and the yaw basis that #326's FLH muzzle resolver needs. `rules.ini` `ROT=` already has a home in `EntityData.rotation_speed`, but `MovementController.configure()` never reads it, so per-unit turn rates are dead data and every vehicle turns identically.

## What Changes

- `MovementController` gains a `face_toward(target_pos, delta) -> bool` API: slews the body toward a world position at its wired `rotation_speed`, snaps instantly for `instant_turn` locomotors (Foot, Jumpjet), reports alignment against `rotation_angle_threshold`.
- `CombatComponent` gates firing behind facing for turretless mobile units: in-range but not aligned holds fire for that tick while slewing; aligned fires. Infantry snaps and fires same tick.
- `MovementController.configure()` adopts `data.rotation_speed` (the `ROT=` value), so per-unit turn rates (visceroid 16 vs harvester 3) actually diverge.
- Buildings (no `MovementController`) fire as today — nothing rotates.
- Close-range deadzone: targets inside ~1 cell fire regardless of yaw (anti-jitter).

## Capabilities

### New Capabilities
- `combat-facing`: body-facing model for combat engagement — who rotates, snap vs slew, fire gate, deadzone, MC ownership.

### Modified Capabilities
- `combat-firing`: in-range firing gains a facing precondition for turretless mobile units (previously: in-range + off-cooldown always fires).

## Impact

- `scripts/components/MovementController.gd` (new API + `configure()` rewire), `scripts/components/CombatComponent.gd` (fire gate in `_physics_process`).
- No scene changes; no new autoloads; no API changes beyond the additive `face_toward`.
- Playtest-feel change: units with distinct `ROT=` values (visceroids, harvesters, disruptor) now turn at distinct rates.
- Explicit non-scope (separate future issues): vehicle turret pivots + multi-turret, `deploy_to_fire` / `no_moving_fire` enforcement, #326 FLH resolver (consumes this branch's yaw basis).
