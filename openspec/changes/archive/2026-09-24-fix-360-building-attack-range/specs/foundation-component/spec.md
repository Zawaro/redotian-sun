## ADDED Requirements

### Requirement: Nearest world point on foundation footprint
`FoundationComponent` SHALL expose `nearest_world_point(from: Vector3) -> Vector3` returning the world-space point on the foundation footprint rectangle nearest to `from`. The footprint rectangle SHALL be the axis-aligned XZ rectangle centered on the owning entity's `global_position` with half-extents `foundation * CellUtil.CELL_SIZE * 0.5`; the returned point SHALL be the per-axis clamp of `from` onto that rectangle, with the Y component taken from the entity. When `from` projects inside the rectangle the method SHALL return `from` itself (clamped), so an attacker standing on or inside the footprint reports zero distance. The method SHALL be O(1) and SHALL NOT iterate foundation cells.

#### Scenario: Nearest point outside a face
- **WHEN** `nearest_world_point(from)` is called with `from` directly beyond one face of a 4x4 foundation
- **THEN** it returns the point on that face at `from`'s lateral offset, one half-depth from the center along the normal

#### Scenario: Nearest point outside a corner
- **WHEN** `from` is beyond a corner diagonally
- **THEN** it returns that corner of the footprint rectangle

#### Scenario: Point inside the footprint returns itself
- **WHEN** `from` projects inside the footprint rectangle
- **THEN** it returns `from` clamped to the rectangle (equal to `from`)

#### Scenario: Single-cell footprint
- **WHEN** the foundation is 1x1
- **THEN** the rectangle is the single cell and the nearest point is the clamp onto that cell's square
