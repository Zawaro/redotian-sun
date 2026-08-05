## Why

`scripts/core/TerrainCollision.gd` creates per-cell `StaticBody3D` + trimesh physics bodies from GLB submeshes (art), but has **zero consumers**. No scene mounts it, movement is kinematic, picking uses math-based heightfield intersection, and raycasts only query entity layers — never layer 1. It is dead code that re-introduces an architecturally rejected approach (#209 directs future terrain physics to derive from the vertex heightfield, not art meshes).

## What Changes

- Delete `scripts/core/TerrainCollision.gd` + `.uid`.
- Remove `test_collision_body_mirrors_renderer_transform()` and the `COLLISION_SCRIPT` const from `test/unit/test_terrain_renderer_pivot.gd` (the remaining transform-mirror assertions are pure `CellUtil.tile_transform` math, already covered by the other three tests in that file).
- Remove the `TerrainCollision` entry from the `scripts/core/` folder listing in `AGENTS.md`.
- **BREAKING**: Any consumer relying on per-cell `StaticBody3D` terrain bodies loses them — verified none exist. Future terrain physics is out of scope (see #209).

## Capabilities

### New Capabilities
<!-- No new capabilities. This change removes dead code. -->

### Modified Capabilities
<!-- No spec-level behavior changes to current specs. TerrainCollision was spec'd in the basic-terrain-system archive (2026-06-06) as a MapEditor-only capability and is de-scoped with this change; that archived spec stays historical. The heightfield collision surface is spec'd under terrain-heightfield-collision (#209) and is unaffected. -->

## Impact

- **Scripts**: delete `scripts/core/TerrainCollision.gd` + `.uid`. No other production script references it (verified via grep).
- **Tests**: `test/unit/test_terrain_renderer_pivot.gd` loses one method + one const; the other three tests stay.
- **Docs**: `AGENTS.md` `scripts/core/` listing drops `TerrainCollision`.
- **No scene changes**: TerrainCollision is not mounted in any `.tscn`.
- **No physics behavior change**: picking, movement, placement, and combat are all unaffected (verified in #208's investigation).
