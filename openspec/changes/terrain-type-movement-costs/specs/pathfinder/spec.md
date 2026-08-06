## ADDED Requirements

### Requirement: Crystal fields raise path cost per-locomotor
`find_path()` SHALL weight neighbour transitions into a cell whose resolved land
type is `resource` (a resource-occupied cell) by the inverse of the unit's
`resource` terrain speed, exactly as for any other land type via the existing
per-locomotor multiplier. A wheeled unit crossing a crystal field SHALL pay
`base / 0.5 = 2.0×` per step, a foot unit `base / 0.9 ≈ 1.11×`, and a hover unit
`1.0×` (no penalty). Water passability SHALL remain per-locomotor: a neighbour
water cell is skipped only when the unit's `terrain_speeds` lacks a positive
`water` entry.

#### Scenario: Wheeled unit routes around a crystal field
- **WHEN** a wheeled unit (`resource = 0.5`) has a cheap detour around a single
  resource-occupied cell
- **THEN** the path detours around the cell instead of crossing it

#### Scenario: Hover unit crosses a crystal field directly
- **WHEN** a hover unit (`resource = 1.0`) paths across the same resource cells
- **THEN** the path crosses them at the same cost as clear ground

#### Scenario: Foot blocked by water
- **WHEN** a foot unit (no `water` entry) pathfinds across a water cell
- **THEN** the water cell is skipped and the path routes around it
