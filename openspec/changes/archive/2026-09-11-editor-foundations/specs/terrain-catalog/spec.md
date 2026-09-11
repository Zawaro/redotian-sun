## MODIFIED Requirements

### Requirement: Art resolution through the catalog
The system SHALL resolve a cell's mesh through `TerrainCatalog.resolve_art(object_id, theater_id)`: look up the object, delegate to its `art_data.resolve(object_id, theater_id)`, and return the glb path, submesh id, and rotation. `resolve_cell_art(cell_data, cell)` SHALL resolve a cell pin first when a cell is supplied — a pinned `TerrainObject` id SHALL be resolved for the active theater before the baked `object_id` and the legacy type/variant family; an unknown pinned id SHALL fall back to the derived paths with a warning. Callers without cell context MAY omit the cell, in which case no pin check is performed. When the object has no `art_data`, or resolution has no `model_path`, the catalog SHALL return an invalid resolution and the renderer SHALL draw a pink placeholder mesh for that cell with a warning.

#### Scenario: Resolves shared art for a directional object
- **WHEN** `resolve_art("cliff01_e", "temperate")` is called
- **THEN** it returns the `cliff01` art entry's glb, its submesh, and a 270° rotation

#### Scenario: Theater override changes the mesh
- **WHEN** `resolve_art("cliff01_n", "snow")` is called and the entry overrides snow
- **THEN** it returns the snow GLB path with the same submesh and a 0° rotation

#### Scenario: Pin drives cell resolution
- **WHEN** a cell is pinned to `"cliff01_e"` and `resolve_cell_art` is called for it
- **THEN** the resolution comes from the pinned object, not the cell's derived family

#### Scenario: Unknown pin falls back
- **WHEN** a cell is pinned to an unregistered object id and `resolve_cell_art` is called for it
- **THEN** a warning is emitted and resolution falls back to the derived family

#### Scenario: No cell context ignores pins
- **WHEN** `resolve_cell_art` is called without a cell
- **THEN** no pin check is performed and the derived family resolves

#### Scenario: Missing art renders a pink placeholder
- **WHEN** an object has no `art_data` or its art has no `model_path`
- **THEN** resolution is invalid, a warning is emitted, and the cell renders a pink placeholder mesh
