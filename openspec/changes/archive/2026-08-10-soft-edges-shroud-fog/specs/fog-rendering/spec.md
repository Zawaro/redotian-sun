## MODIFIED Requirements

### Requirement: Soft-edged shroud and fog borders
The fog overlay SHALL soften the transitions between shroud, fog, and visible cells: a shroud cell SHALL be fully opaque black across its entire footprint, and a fog cell SHALL be fully dimmed at `fog_darkness` across its entire footprint, while the border between regions SHALL ramp smoothly over a tunable width (in cells) rather than a hard step. The shroud band SHALL extend its fully-opaque zone `shroud_grow` cells past the region boundary, then ramp via an S-curve to fully transparent `shroud_falloff` cells beyond that; the fog band SHALL likewise extend `fog_grow` cells past the fog boundary and ramp to transparent over `fog_falloff` cells. The two bands SHALL compose with `max()`, not a summed alpha, so a fog cell hugging a shroud edge fades through the dim floor instead of saturating to black. The soft edge SHALL be driven by a second grid-resolution RG8 texture (R = 8-neighbor Chebyshev ring distance to nearest shroud cell, G = 8-neighbor Chebyshev ring distance to nearest fog cell) baked on the same state-change event as the state texture, sampled with bilinear filtering so the band ramps linearly between cell centers; the L8 state texture SHALL keep nearest filtering so classification stays crisp. The opaque shroud sheet SHALL erode its footprint by one cell (discarding any shroud fragment with a non-shroud orthogonal neighbor) so its hard edge sits inside the fully-opaque band and never surfaces. Fragments outside the map square (the rim mesh, UVs outside `[0,1]`) SHALL render opaque shroud regardless. No per-frame CPU bake SHALL occur; the mask bake runs only when the effective-state buffer changes, and SHALL be incremental — recomputing only the band of cells within `MASK_MAX_RING` of a changed cell (plus sweep margin) into persistent grid and mask textures updated in place, never re-allocating or re-baking the full grid on the per-resolve tick.

#### Scenario: Shroud cell fully covered
- **WHEN** a shroud cell resolves to shroud
- **THEN** the plane draws it opaque black across its entire footprint, with no partial transparency inside the cell

#### Scenario: Shroud border halo
- **WHEN** an explored or visible cell is within `shroud_grow` cells of a shroud cell's edge
- **THEN** it is drawn fully opaque black (the grown shroud fringe), and beyond that fringe up to `shroud_grow + shroud_falloff` cells it is dimmed from full opacity via an S-curve ramp to fully transparent

#### Scenario: Fog cell fully dim
- **WHEN** a fog cell resolves to fog
- **THEN** the plane dims it at `fog_darkness` across its entire footprint

#### Scenario: Fog trail halo
- **WHEN** a visible cell is within `fog_grow` cells of a fog cell's edge — a unit's receding vision edge
- **THEN** it is dimmed at `fog_darkness` across the grown fringe, then from full dim at the fringe edge via an S-curve ramp to fully transparent `fog_falloff` cells out

#### Scenario: Deep visible cells clean
- **WHEN** a visible cell carries no shroud or fog halo
- **THEN** the plane draws nothing over it (fully transparent)

#### Scenario: Opaque sheet edge hidden
- **WHEN** a shroud cell has a non-shroud orthogonal neighbor
- **THEN** the opaque shroud sheet does not draw it (eroded); the translucent band covers it at full opacity, so no crisp core line is visible

#### Scenario: Rim stays opaque shroud
- **WHEN** a fragment lies outside the map square, where the textures hold no state
- **THEN** the plane draws opaque shroud regardless of the distance texture

#### Scenario: Mask re-baked only around changed cells
- **WHEN** ShroudSystem emits `state_changed` with a local dirty cell set and at least one cell's effective state actually differs
- **THEN** the L8 grid texture and the edge-mask band around those changed cells are updated in place on the persistent textures; when no local cell changed (e.g. an enemy-only resolve), no re-bake occurs

#### Scenario: Incremental band equals full transform
- **WHEN** the edge mask is re-baked incrementally after a state change
- **THEN** the resulting ring distances equal a full-grid recompute — the band path is reference-tested against the exact guarded two-sweep transform across consecutive updates and at map borders

### Requirement: Fog-driven building culling
Enemy buildings SHALL be shown once their cell is explored, and SHALL remain shown while the cell stays explored even when no revealer currently covers it. Enemy buildings in unexplored (shroud) cells SHALL be visually hidden. Friendly buildings SHALL never be hidden. Building visibility SHALL be maintained on the shroud state-change event and immediately when a building spawns — not by per-frame polling, since a building's revealed flag is constant between resolves.

#### Scenario: Building persists in fog
- **WHEN** an enemy building's cell is explored but a revealing unit has since left the area
- **THEN** the building remains visible (dimmed by the fog overlay)

#### Scenario: Building hidden before explored
- **WHEN** an enemy building's cell has never been explored
- **THEN** the building is visually hidden

#### Scenario: Friendly building always visible
- **WHEN** a friendly building's cell is unexplored
- **THEN** the building remains visible

#### Scenario: Visibility synced on state change
- **WHEN** ShroudSystem emits `state_changed` or a building spawns
- **THEN** the building's revealed flag is re-evaluated on that event, with no per-frame visibility poll
