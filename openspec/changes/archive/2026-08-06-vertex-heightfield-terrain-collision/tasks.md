# Implementation Tasks

## 1. Intersection API

- [x] 1.1 Refactor `TerrainSystem.get_height_at_world_smooth` to expose a reusable bilinear sampler (e.g. `_sample_heightfield_at(vx: float, vz: float) -> float`) so intersection and shape-building share one code path; keep the public method's behavior identical
- [x] 1.2 Add `intersect_heightfield_segment(from: Vector3, to: Vector3) -> Dictionary` on `TerrainSystem`: march the segment across the heightfield's XZ grid cell-by-cell, test each cell's bilinear surface, return `{point, cell}` on first hit or `{}` (empty) on no hit
- [x] 1.3 Define and document the contract for segments starting below terrain and segments fully above terrain (per spec "Segment fully above terrain misses" / "Segment starting below terrain")

## 2. HeightMapShape3D builder

- [x] 2.1 Add `build_heightfield_shape() -> HeightMapShape3D` on `TerrainSystem`: fill `map_data` from `_vertex_grid` (`height * HEIGHT_STEP`), write `NAN` for vertices outside the playable diamond via `CellUtil.is_in_diamond`, set `map_width`/`map_depth` to the square extent
- [x] 2.2 Verify the builder creates no physics nodes (returns a shape resource only)

## 3. Tests

- [x] 3.1 Unit tests for the bilinear sampler: flat cell, single-corner-raised slope, and cross-map invariance (square / rectangular / odd / even grid_cells), each with independently calculated expected heights
- [x] 3.2 Unit tests for `intersect_heightfield_segment`: vertical segment hits flat terrain at `h * HEIGHT_STEP`; segment fully above misses; segment crossing a sloped cell hits the bilinear surface; segment starting below terrain returns no hit; segment over an out-of-diamond corner returns no hit
- [x] 3.3 Unit tests for `build_heightfield_shape`: in-diamond `map_data` equals `height * HEIGHT_STEP`, out-of-diamond values are `NAN`, diamond corners are holes, and no nodes are added to the scene tree
- [x] 3.4 Consistency test: at the same XZ position, `get_height_at_world_smooth`, segment intersection, and the built shape report the same surface height on a sloped cell

## 4. Verification

- [x] 4.1 `redot --headless --import` succeeds
- [x] 4.2 `gdlint scripts/**/*.gd test/**/*.gd` and `gdformat --check scripts/**/*.gd test/**/*.gd` pass; `grep -P '\t'` shows no tabs introduced
- [x] 4.3 Full test suite (`redot --headless -s test/run_tests.gd`) passes
