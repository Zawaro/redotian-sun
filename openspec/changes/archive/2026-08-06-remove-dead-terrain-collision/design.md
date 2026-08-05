## Context

`scripts/core/TerrainCollision.gd` (deleted with this change) builds a `StaticBody3D` + trimesh per terrain cell and per ramp footprint on `collision_layer = 1`. The issue #208 investigation confirmed it has zero consumers:

- **Scenes** — `MainScene`, `TestMap02`, `MapEditor` mount `TerrainRenderer` but never `TerrainCollision`; no `TerrainCollision.new()` anywhere.
- **Movement** — `MovementController` is kinematic (waypoints + `TerrainSystem.get_height_at_world_smooth`); no physics bodies exist.
- **Picking** — `MouseHandler` / `MapEditor._update_hovered_cell` use math plane↔heightfield intersection; raycasts only query entity layers 15/16/17.
- **Placement / combat / passability** — land-type authority + corner heights; insta-hit combat; no physics dependency.

All terrain height, passability, and picking already derive from `TerrainSystem`'s vertex heightfield. A future physics surface is being designed separately in #209 as a heightfield-derived shape.

## Goals / Non-Goals

**Goals:**
- Remove the dead `TerrainCollision.gd` physics layer and its `.uid` file.
- Remove the test that directly instantiates it (`test_collision_body_mirrors_renderer_transform` + `COLLISION_SCRIPT`).
- Update `AGENTS.md` so the `scripts/core/` listing matches reality.
- Leave no dangling references anywhere (scripts, scenes, tests, docs).

**Non-Goals:**
- Building any replacement terrain physics — deferred to #209.
- Touching `TerrainRenderer`, `TerrainSystem`, or the heightfield sampling (all stay as-is).
- Removing `CellUtil.tile_transform` or the remaining renderer-pivot tests (they are pure math and still valid).

## Decisions

### D1: Delete the script and its test together
`TerrainCollision.gd`'s only live reference outside itself is `test_collision_body_mirrors_renderer_transform` in `test/unit/test_terrain_renderer_pivot.gd`, which instantiates the script and asserts its body transform mirrors `CellUtil.tile_transform`. That transform math is already covered by the file's other three tests (which call `CellUtil.tile_transform` directly), so the collision test adds nothing once the script is gone.

- **Alternative rejected**: keeping the collision-mirror test as a pure `tile_transform` test — redundant, the other tests already cover it.

### D2: No new files, no new abstractions
The removal touches exactly three paths: the deleted script, the test edit, and the `AGENTS.md` listing. No replacement module, no compatibility shim, no deprecation stub.

- **Rationale**: dead code stays dead; #209 owns the future surface. A stub would just reintroduce the rejected per-cell approach by another name.

### D3: Verification is grep + test suite + lint
Because the removal is purely destructive, correctness is proven by: (a) no remaining `TerrainCollision` references in `scripts/` or `scenes/`, (b) the full test suite still passing, (c) lint/format clean, (d) `redot --headless --import` succeeding.

## Risks / Trade-offs

- [A latent consumer of per-cell terrain bodies exists that grep missed] → Low risk; grep covers scripts, scenes, tests, project.godot, and AGENTS.md. The full test suite is the safety net — it passes only if nothing depended on the bodies.
- [Test count drops (one method removed)] → Intended; the removed test's coverage is subsumed by the remaining `tile_transform` tests.
- [Future #209 work conflicts with this removal] → No conflict; #209 derives collision from the heightfield, which this change does not touch.
