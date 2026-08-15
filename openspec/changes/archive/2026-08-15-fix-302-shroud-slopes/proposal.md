## Why

Walking a unit up a 1-2 step graded slope, the shroud stays unrevealed on the slope face ahead of it. `ShroudSystem._cell_blocks` treats any cell whose tallest corner pokes more than `viewer_height + 0.611` above the viewer as a blocking wall, so a graded ramp face blocks LOS exactly like a sheer cliff (#302).

## What Changes

- Add a per-cell grade predicate to `TerrainSystem` (`get_cell_grade_steps`) derived from the existing height snapshot.
- Change `ShroudSystem._cell_blocks` so a cell with only one level of internal corner variation (a walkable graded slope/ramp) never blocks LOS; cells with two or more steps of variation (true cliffs) keep the existing `get_cell_max_height` height-delta check.
- Amend the `fog-of-war` spec's Height-aware shadowcasting requirement to state the slope exemption and its boundary.

## Capabilities

### New Capabilities

- `terrain-grade`: per-cell slope-grade classification (max-min corner steps) used to distinguish walkable graded faces from vertical cliff faces.

### Modified Capabilities

- `fog-of-war`: the Height-aware shadowcasting requirement changes — graded 1-step slope cells no longer block line of sight; the 2-step+ cliff rule is unchanged.

## Impact

- `scripts/core/TerrainSystem.gd` — new `get_cell_grade_steps` helper (uses existing snapshot, no new storage).
- `scripts/core/ShroudSystem.gd` — `_cell_blocks` gains the grade exemption.
- `openspec/specs/fog-of-war/spec.md` — requirement delta.
- Test: `test/unit/test_shroud_system.gd` — new graded-ridge reveal regression; existing `test_hill_blocks_vision` / `test_high_ground_sees_over` must pass unchanged.
- No scene or resource changes; additive and inert for flat terrain.
