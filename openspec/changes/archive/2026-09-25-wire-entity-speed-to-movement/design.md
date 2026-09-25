## Context

`MovementController.move_speed` is an `@export` defaulting to `8.0` (`MovementController.gd:11`). `EntityData.speed` carries the original TS `Speed` values (3–20 leptons/frame, see `games/ts/entities/**`) but is read in only two places: the `> 0` attach gate (`EntityFactory.gd:355`) and validation (`MovementController.gd:852`). `configure()` (`:122`) sets locomotor, zone and rotation only.

Consequences today: every mobile unit moves at `8.0` u/s; slow units are 2–4× too fast; per-unit speed is invisible. The `entity-data` spec already asserts speed drives movement, so the data migration was started and left half-wired. The original design (archived `2026-06-06-unit-movement` spec:93) authored `move_speed` per scene; when movement went data-driven, the link was lost. Per-unit scenes with hardcoded `move_speed` (`NodBuggy.tscn`) are dead paths — `EntityFactory` composes from the generic `scenes/entities/Entity.tscn`.

The step chain (`MovementController.gd:1025`) already multiplies the base by jitter, veteran, slope, terrain and ramp factors, so only the base value itself needs to become per-unit.

## Goals / Non-Goals

**Goals:**

- Wire `EntityData.speed` → `move_speed` through one GlobalRules-owned conversion.
- Choose and document the movement time base (decided: the project's 2× base, `logic_fps = 30`, → `0.6 × speed`).
- Correct the `EntityData.speed` doc comment and the specs that overstate today's behavior.
- Leave a regression test that derives expected units/second from TS lepton geometry, not the production formula.

**Non-Goals:**

- Driving animation playback (`speed_scale`) from `move_speed`.
- Authoring per-weapon/per-projectile TS speeds (every projectile still falls back to the single default).
- Retuning movement-adjacent constants (repulsion strength, arrival/snap, scatter/wait thresholds) that were eyeballed at a flat `8.0`.
- Cleaning up the unreferenced per-unit entity scenes (`NodBuggy.tscn` etc.).
- Switching to TS wall-clock (15 Hz base); that would re-anchor the whole game (build/harvest/ROF) and is a much larger change.

## Decisions

### D1: 2× time base (`0.6 × speed`), not TS-faithful 15 Hz

`build_speed = 0.4` vs TS `.8`, `harvester_fill_rate = 30/18` vs TS `15/18`, and the combat ROF base (`combat-firing/spec.md:29`, cooldown = `rate_of_fire / logic_fps`) are all already 2× TS. Movement joining them keeps one internal policy. At `0.6`, Titan = 3.6, Harvester = 3.0, MCV = 1.8, Wolverine = 4.8, Buggy = 6.0, Attack Cycle = 7.2, Orca Fighter = 12.0 u/s. `0.3` would make movement the lone 1× system (sluggish infantry relative to build/ROF/harvest) while being the only TS-wall-clock-faithful option — rejected as the larger, cross-cutting choice.

### D2: Conversion is a derived GlobalRules helper, not a new export

Add `speed_to_units_per_second(speed)` to `GlobalRules`, computing `speed * 2.56 * logic_fps * CellUtil.CELL_SIZE / 256` from `logic_fps` and `CELL_SIZE`. A hand-maintained `@export move_speed_per_speed_unit` would drift from `logic_fps`; deriving keeps one authority. `game_speed_bias` (`GlobalRules.gd:84`) stays dead for now — deleting or repurposing it is not needed for this change. If a future title needs a movement time base decoupled from combat, that is when an explicit knob is added.

### D3: Store raw speed in `configure()`, apply when rules resolve

`configure()` runs in `EntityFactory.create_entity` before the entity enters the tree, so the controller's `_ready()` (which resolves `_rules`) has not run. Store `data.speed` in a private `_speed_leptons` field and apply `move_speed = _rules.speed_to_units_per_second(_speed_leptons)` from an idempotent `_apply_speed()` called at the end of both `configure()` and `_ready()`. This is robust to either ordering and avoids a null-rules `configure()`. When no GlobalRules is resolvable (bare test/editor controllers), `move_speed` keeps the `@export` default, preserving existing mechanics tests.

### D4: Jumpjet vertical speed follows the per-unit `move_speed`

`MovementController.gd:1618,1623` already use `move_speed` for ascent/descent, and `jumpjet-vertical-transitions/spec.md` already specifies `move_speed`. The `locomotor` "SHALL be unaffected" clause is scoped to mean unaffected by the accelerate/decelerate **ramp**, not by per-unit speed. No separate vertical-speed field is introduced.

### D5: Test shape

Regression test on a non-ramping locomotor (Hover/Amphibious/Ship — `Track`/`Wheel` ramp and would average below cruise), with `_speed_jitter = 1.0` (set by `_ready` from `randf_range(0.95, 1.0)`). Expected cells/second is computed independently: `speed * 2.56 * logic_fps / 256` cells/s, × `CELL_SIZE` for u/s.

### D6: Review fix — projectile default on the 2× base, not an aircraft cap

The first review pass found the Orca Fighter (Speed 20 → 12.0 u/s) tied `default_projectile_speed` (12.0), so a pursuing shot could fail to close. Raise the default to `24.0` rather than cap aircraft: projectiles are tick-based content and belong on the same 2× base as movement/build/ROF, and a cap distorts the one unit while leaving the placeholder a landmine for future fast movers. No `.tres` overrides the value and every test sets its own rules fixture, so the blast radius is one field; per-weapon TS speeds remain the fidelity follow-up.

### D7: Review fix — non-vacuity control measures rate, not stored speed

The original control only compared stored `move_speed` to `8.0`. It now forces both controllers to flat `8.0` and runs the same `_travel` the regression test runs, asserting the measured rate ratio is `1.0` — so the `10:6` assertion provably fails on the pre-fix behavior.

### D8: Review fix — integration seam and immobile gate covered

Add `EntityFactory.create_entity("GDI_TITAN")` asserting `move_speed == 3.6`, and `create_entity(..., {"speed": 0.0})` asserting no `MovementController` — the wiring and the immobile scenario were only tested via direct `configure()` calls before.

### D9: Review fix — wording and naming

Correct the proposal's dead-scene rationale (those scenes override no `move_speed`), rename `_speed_units` → `_speed_leptons`, document `_apply_speed()`'s `_rules` fallback side effect, and call 2.56 the *linear scale factor* in code/spec (the engine clamp is intentionally not modeled).

## Risks / Trade-offs

- [Large, player-visible balance shift] → intended and confined to one reviewable change; the base is a single value to retune if pacing is wrong.
- [Fast movers approach projectile speed] → fixed: `default_projectile_speed` raised to 24 u/s (D6); per-weapon TS speeds remain a follow-up.
- [Animation slide widens] → animation is not speed-matched to movement today; 2× widens the existing gap. Non-goal; follow-up.
- [Cell-transition/pathfinding churn doubles for fast movers] → per-frame cell changes scale with speed; existing perf guards cover the pass, but a stress check is worth running.
- [Movement-adjacent constants tuned at flat 8.0] → repulsion/arrival/scatter may need retuning after speeds settle; non-goal here.
- [Silent coupling to `logic_fps`] → retuning `logic_fps` for combat now rescales movement too; kept (D2) and documented by the global-rules `Conversion scales with the logic rate` scenario.

## Migration Plan

Single change, no save-format migration. Land as the repo's two commits:

1. `feat`: `GlobalRules` helper + projectile default, `MovementController` wiring, `EntityData` doc, `GLOSSARY`, and all tests.
2. `docs(openspec)`: archive the change and sync the spec deltas.

Rollback: revert the change; `move_speed` returns to its export default and units move at a flat `8.0` again. The `@export` default is intentionally retained as the fallback, so no scene edits are needed to revert.

## Open Questions

- Should animation playback scale with `move_speed`? (Affects visual fidelity at both ends of the speed range.)
