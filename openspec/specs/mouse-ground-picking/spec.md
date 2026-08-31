## ADDED Requirements

### Requirement: Screen point to terrain position
`TerrainSystem` SHALL expose `mouse_ray_to_terrain(camera: Camera3D, screen_pos: Vector2) -> Variant`: it casts a ray from the camera through the screen point, intersects it with the ground plane (Y=0), then refines the hit position against the smoothed terrain height (`get_height_at_world_smooth`) for a fixed 4 iterations, returning the refined world position, or `null` when the ray misses the ground plane. This SHALL be the single implementation of the ray→terrain refinement routine in gameplay code: placement preview repositioning (EntityPlacer session), BuildingManager build-mode preview positioning (both its call sites), and MouseHandler order ground targeting SHALL obtain cursor terrain positions through it and MUST NOT keep inline copies of the refinement loop.

#### Scenario: Flat terrain returns the plane hit
- **WHEN** the camera looks at flat terrain and a screen point over it is passed
- **THEN** `mouse_ray_to_terrain` returns the ground-plane intersection at the terrain surface height

#### Scenario: Sloped terrain refinement
- **WHEN** the ray passes over sloped terrain
- **THEN** the returned position sits on the terrain surface (iterated refinement), not on the Y=0 plane

#### Scenario: Ray misses the ground
- **WHEN** the ray points away from the ground plane (e.g. camera pitched up)
- **THEN** `mouse_ray_to_terrain` returns `null` and the caller skips repositioning

#### Scenario: Consumers share one implementation
- **WHEN** any of EntityPlacer, BuildingManager, or MouseHandler needs the cursor's terrain position
- **THEN** it calls `TerrainSystem.mouse_ray_to_terrain`; a code search for the plane-intersect-plus-height-refinement loop finds it only in `TerrainSystem`
