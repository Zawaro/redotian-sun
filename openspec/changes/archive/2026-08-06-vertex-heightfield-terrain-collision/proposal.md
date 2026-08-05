## Why

The engine answers ground height, passability, and picking entirely from `TerrainSystem`'s vertex heightfield (`_vertex_grid`); no physics bodies exist for terrain. When terrain physics becomes necessary (ballistic projectiles, physics-based knockback, LOS queries), the collision shape must derive from the vertex heightfield — theater-independent, cheap, and consistent with the gameplay data that movement and picking already use. The old per-cell `StaticBody3D`/trimesh `TerrainCollision.gd` is dead and architecturally rejected (issues #208/#209). This change establishes the heightfield-derived collision surface as a first-class, testable capability, built when the first real consumer (ballistic projectiles) lands.

## What Changes

- Introduce a pure-GDScript heightfield intersection API on `TerrainSystem` that answers "does a ray/segment intersect terrain?" against the bilinear vertex heightfield, mirroring the existing `get_height_at_world_smooth` sampling path. This is the default, dependency-free surface used by ballistics and LOS.
- Add a `HeightMapShape3D` builder that produces a native physics shape from `_vertex_grid`, using NAN holes outside the playable diamond. This is opt-in and only instantiated by consumers that need the physics server (e.g. knockback collision response), not by default.
- Define the crease-diagonal policy explicitly: the runtime heightfield is treated as a bilinear surface (matches `get_height_at_world_smooth` and the current renderer's shared resolution), with authored `TerrainObject.crease` data remaining the reference for art-authoring.
- Delete nothing that is currently live. (The dead per-cell `TerrainCollision.gd` removal is tracked separately in #208 and is a prerequisite before this change's shape builder is exercised.)

## Capabilities

### New Capabilities
- `terrain-heightfield-collision`: Terrain collision derived from the vertex heightfield — a segment/ray intersection API for gameplay queries, a `HeightMapShape3D` builder for physics-server consumers, diamond-boundary handling (NAN holes), and the crease-diagonal policy.

### Modified Capabilities
<!-- No spec-level behavior of existing capabilities changes; TerrainSystem gains new query methods without altering existing height/picking semantics. -->

## Impact

- **Scripts**: `scripts/core/TerrainSystem.gd` (new intersection + shape-builder methods; existing height/normal APIs unchanged). Optionally a small helper for building the shape from the vertex grid if it grows.
- **Data**: `scripts/data/TerrainObject.gd` — read-only reference for the crease policy; no schema changes.
- **Tests**: new unit/integration tests under `test/unit/` (ray vs bilinear surface, diamond-boundary NAN holes, invariance across map shapes).
- **No scene changes** — no physics bodies are mounted by default; consumers (projectiles, knockback, LOS) opt in.
- **Dependencies**: none new — uses engine-native `HeightMapShape3D` only when a consumer requests a shape.
