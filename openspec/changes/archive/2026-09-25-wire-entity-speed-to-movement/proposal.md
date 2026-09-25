## Why

Every mobile unit moves at the same fixed `8.0` world units/second. `EntityData.speed` — which carries the original Tiberian Sun `Speed` values (3–20 leptons/frame) — is read only as a `> 0` attach gate and never reaches `MovementController.move_speed`. The result: slow units (MCV, harvester, infantry) move far too fast and per-unit speed differences are invisible. `entity-data` already promises "speed is set by `EntityData.speed` and terrain/locomotor factors", so this is a half-finished data migration, not a new feature.

## What Changes

- Wire `EntityData.speed` into `MovementController.move_speed` in `configure()`, via a `GlobalRules`-owned conversion from TS leptons/frame to world units/second.
- Adopt the project's existing **2× time base** (`logic_fps = 30`): `move_speed = speed × 2.56 × logic_fps × CELL_SIZE / 256`, i.e. `0.6 × speed` u/s. This matches `build_speed = 0.4`, `harvester_fill_rate = 30/18`, and the 30 fps ROF base already in force.
- Correct the `EntityData.speed` doc comment from "cells per tick" to "TS leptons per frame".
- Scope the jumpjet vertical-speed clause: ascent/descent follows the unit's (now per-unit) `move_speed` rather than an unspecified fixed value.
- Raise `default_projectile_speed` from `12.0` to `24.0`, putting projectiles on the same 2× base so the default outruns the fastest unit (Orca Fighter, TS Speed 20 → 12.0 u/s).
- **BREAKING (gameplay balance)**: every unit's real speed changes; infantry/harvester/MCV drop sharply, aircraft rise. No API or save-format change.

Out of scope, documented for a follow-up change:
- Animation playback (`speed_scale`) is authored per clip and is not driven by `move_speed`, so 3-D cycles slide at 2× speed.
- Per-weapon and per-projectile TS speeds (every projectile today falls back to the single default).

## Capabilities

### New Capabilities

<!-- none — all requirements land in existing specs -->

### Modified Capabilities

- `entity-data`: `speed` documented as TS leptons/frame and required to drive `move_speed` through the GlobalRules conversion; the weight-does-not-affect-speed scenario's absolute figure corrected.
- `global-rules`: own the lepton→world-units conversion helper and the movement time base derived from `logic_fps`.
- `locomotor`: `MovementController` derives its base `move_speed` from the entity's `speed` (not a fixed scene default); jumpjet vertical clause scoped to the per-unit speed.
- `projectile-runtime`: the default projectile speed sits on the 2× base and exceeds the fastest unit, so a pursuing shot can still close.

## Impact

- Code: `scripts/components/MovementController.gd` (configure / `_ready`), `scripts/data/GlobalRules.gd` (conversion helper + projectile default), `scripts/data/EntityData.gd` (doc comment), new unit test.
- Scenes: none. Per-unit entity scenes (`NodBuggy.tscn` etc.) are unreferenced dead paths — they override no `move_speed` (only `rotation_speed`), and `EntityFactory` composes from the generic `scenes/entities/Entity.tscn`; they are left untouched.
- Systems: movement pacing; projectile flight speed (all 2× faster); indirectly pathfinding/occupancy churn (fast movers change cells twice as often).
- Docs: `openspec/specs/entity-data`, `global-rules`, `locomotor`, `projectile-runtime`; GLOSSARY may gain a `lepton` / `time base` row.
