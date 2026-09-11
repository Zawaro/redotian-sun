## Why

Placing a multi-cell building leaves the shroud/fog around it dark. `VisionComponent._center_cell()` adds half the foundation to the entity's `global_position`, but building `global_position` is already the footprint center (`CellUtil.cell_origin_to_world` returns the center). The revealer is therefore stamped `foundation` cells diagonally off the structure: a 4×3 refinery's reveal disc is centred +4,+3 cells away, so part of the building's own footprint and the whole near side of its surroundings stay shrouded. Units are unaffected because their 1×1 foundation makes the offset zero — which is exactly why units "reveal correctly" and buildings do not.

## What Changes

- Fix the building revealer's center cell so it is the footprint center, not the footprint center plus half the footprint.
- Works uniformly for sidebar placement, construction-yard production, and map-loaded buildings (all set `global_position` to the footprint center).
- Add a regression test that fails on the current offset (rejects an asymmetric/off-footprint reveal) and passes once centered.
- Reveal stays permanent while the building lives; registration/unregistration timing already holds and is not changed.

Not in scope: the `blocks_terrain = false` setting for building revealers, which contradicts its own comment ("Only terrain height blocks LOS") and lets buildings see over ridges like aircraft. That produces *extra* reveal, the opposite of this defect; it needs its own decision and is left untouched.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `fog-of-war`: add a requirement that a player-owned entity's revealer is centered on its own footprint center cell (multi-cell buildings included), so the sight radius is revealed symmetrically around the structure at the moment of placement and remains revealed while it lives.

## Impact

- `scripts/components/VisionComponent.gd` — `_center_cell()` (remove the foundation offset).
- `test/unit/test_vision_component.gd` — add the regression case; existing building tests assert cells ~4.2 away at `sight = 6`, which masks the offset.
- `test/integration/test_building_placement.gd` — optional placement-path assertion.
- No data (`.tres`), scene (`.tscn`), or public API changes. `ShroudSystem.register_revealer` semantics unchanged.
