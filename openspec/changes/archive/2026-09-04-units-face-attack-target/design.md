## Context

`CombatComponent._physics_process` (`scripts/components/CombatComponent.gd:188-219`) fires the instant a target is in range with zero yaw consideration. `MovementController` owns all rotation state (`_rotation_yaw`, `_rotation_target`, slope-aware `_apply_facing` at `MovementController.gd:1017-1034`, the `angle_difference` + step idiom reused by `DeployComponent`) but only yaws while driving a `MOVING` leg — stationary units keep frozen yaw. `EntityData.rotation_speed` (the `rules.ini` `ROT=` home, set to 180.0 in every vehicle `.tres`) is never read by `MC.configure()` (`MovementController.gd:110-112` copies only `locomotor` + `movement_zone`), so the scene-export default is the real turn rate and per-unit `ROT=` variety (visceroid 16, harvester 3, disruptor 4) is dead. No `.tres` sets `turret = true`; no scene has a turret pivot; `rotation_target_path` is unset everywhere — whole-body rotation is the only mechanism on this branch.

## Goals / Non-Goals

**Goals:**
- Stationary and post-arrival units end up facing their attack target before firing (TS fidelity).
- One owner for yaw math (`MovementController`); combat asks, movement turns.
- `ROT=` values become live turn rates via the `configure()` rewire.
- The yaw basis #326's FLH resolver needs is established (body yaw is correct at fire time).

**Non-Goals:**
- Turret pivots, multi-turret, turret-vs-body yaw split (future issue).
- `deploy_to_fire` / `no_moving_fire` enforcement (future issue; flags stay dead).
- Chase-path changes; out-of-range behavior is untouched.
- ROT-unit → deg/s conversion tables; `.tres` values are already deg/s and stay as-is.

## Decisions

### 1. `face_toward(target_pos, delta) -> bool` on MovementController; combat never touches rotation
Combat driving `parent.rotation.y` directly would duplicate the slope-projection in `_apply_facing`, the `_rotation_target` indirection, and the threshold idiom. MC already owns all three, so it exposes one additive method: compute desired yaw from the XZ direction to `target_pos`, advance toward it, return whether `|angle_difference| <= rotation_angle_threshold`. Combat calls it and gates fire on the result. Alternative (combat-side yaw helper) rejected: two yaw implementations diverge at 3am.

### 2. Face-first-then-fire gate, not fire-while-turning
In-range branch becomes: resolve MC → if present and unit needs turning, `face_toward`; hold fire this tick unless aligned. `instant_turn` locomotors (Foot, Jumpjet) snap via `_apply_facing` and report aligned immediately, so infantry fires same tick with no behavior change. Track/Wheel slew at `rotation_speed` and fire on arrival within tolerance. Alternative (slew while firing) rejected per branch scope: turretless TS vehicles face before firing, and the gate is what makes the yaw observable for #326.

### 3. `rotation_speed` sourced from `EntityData` (ROT=), not derived from move speed
`rules.ini` keeps `ROT=` and `Speed=` as independent axes (Tick Tank ROT=5/Speed=6, visceroids ROT=16); coupling them would break TS parity and make every speed tweak silently retune turning. The fix is a `configure()` one-liner adopting `data.rotation_speed`, with the scene export as fallback default. `Locomotor` has no rate field — only `instant_turn` as a snap override — so there is nothing locomotor-side to blend in. `DeployComponent._get_rotation_speed` already reads `data.rotation_speed` the same way.

### 4. Tolerance = `rotation_angle_threshold` (5°); deadzone is distance-based, not angle-based
One knob for "close enough to count as facing" — no second constant. Anti-jitter is a distance check: target closer than ~1 cell (`CellUtil.CELL_SIZE`) fires regardless of yaw, because angle deadzones still oscillate when a target orbits at close range while distance deadzones don't. Vertical separation ignored (XZ only), consistent with the existing range check.

### 5. Facing engages only when MC is not driving a move leg
The chase approach already yaws the body toward the stop point on the line to the target, so facing is the settle-after-arrival + stationary-engage path. When MC state is `MOVING`/`ROTATING` with live waypoints, combat skips `face_toward` and lets movement own the yaw. Facing must not issue moves, touch `_waypoints`, or emit `movement_started` (which clears attack targets via `_on_movement_started`) — it only advances `_rotation_yaw` through `_apply_facing`.

## Risks / Trade-offs

- [Rewire changes turn feel] ROT= variety goes live (visceroids spin fast, harvesters lumber) → Mitigation: flag in proposal/impact; values are data-tunable per `.tres` without code changes.
- [Facing fights movement] `face_toward` during a chase leg could desync `_rotation_yaw` from spline tangents → Mitigation: decision 5 — never face while a move leg is live; `_on_movement_arrived` pass already exists as the handoff point.
- [Hold-fire stalls DPS] a unit whose target jitters at the tolerance boundary sheds shots → Mitigation: distance deadzone + threshold reuse keeps the boundary identical to movement's own settle behavior; cooldowns keep ticking while held so fire resumes immediately on alignment.
- [Buildings unaffected] no MC means no gate — verified, not assumed: `EntityFactory._add_movement_controller` only attaches when `speed > 0`.
