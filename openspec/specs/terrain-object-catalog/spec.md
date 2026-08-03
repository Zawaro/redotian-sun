# terrain-object-catalog Specification

## Purpose
TBD - created by archiving change terrain-object-catalog. Update Purpose after archive.
## Requirements
### Requirement: TerrainObject data model
The system SHALL define a `TerrainObject` resource (`scripts/data/TerrainObject.gd`) representing one authored directional terrain tile. It SHALL have `id: String`, `cell_type` (`"cliff"`/`"slope"`/`"ramp"`/`"clear"`), `display_name: String`, and `cells: Dictionary` keyed by object-local `"x,z"` strings. Each cell value SHALL contain `land` (surface type id), `corners: Array[int]` of 4 absolute vertex heights in `[nw, ne, se, sw]` order, `crease: String` in `"flat"|"x"|"y"`, and optional `slope` (TS RampType provenance). `TerrainObject` instances SHALL be data-only; no rendering or pathfinding logic lives in the resource.

#### Scenario: Cell exposes corners and crease
- **WHEN** a `ramp01_e` object's `"1,1"` cell is read
- **THEN** it returns `corners` of 4 heights, a `crease` in `"flat"|"x"|"y"`, and a `land` type

#### Scenario: Slope is optional provenance
- **WHEN** a cell was authored with a non-zero TS RampType
- **THEN** its `slope` field carries that code; cells with flat type carry no `slope` field

### Requirement: Baked directional variants
The `terrain_objects/` catalog SHALL contain four directional variants per base shape (`<base>_n`, `<base>_e`, `<base>_s`, `<base>_w`), each with its per-cell corners already rotated to that facing. The engine SHALL place a variant directly without rotating its footprint at runtime. Mirror-distinct bases (e.g. `ramp01` vs `ramp02`) SHALL exist as separate variant sets.

#### Scenario: Variant corners are pre-rotated
- **WHEN** the `_e` variant of a shape is compared to its `_n` variant
- **THEN** each cell's corners are rotated 90° and `crease` is updated to the same geometric fold

#### Scenario: Mirrors are separate bases
- **WHEN** `ramp01` and `ramp02` are both in the catalog
- **THEN** each has its own `_n/_e/_s/_w` variant set and they are not merged

### Requirement: Suffix-aware art seam
`TerrainArtData.mesh_name(tile_id)` SHALL strip a directional suffix (`_n`/`_e`/`_s`/`_w`) from the tile id before resolving the GLB submesh, so one mesh per family serves all four variants. The renderer SHALL derive the mesh instance rotation from the suffix (`n`→0°, `e`→90°, `s`→180°, `w`→270°). Tile ids absent from the GLB SHALL resolve through the existing fallback mesh table.

#### Scenario: Directional variant maps to base mesh
- **WHEN** `mesh_name("cliff01_e")` is called
- **THEN** it returns the `cliff01` submesh name, not `cliff01_e`

#### Scenario: Seed ids resolve via fallback table
- **WHEN** `mesh_name("cliff_straight_n")` is called
- **THEN** it returns the closest authored mesh from the fallback table

### Requirement: Theater registration of the catalog
`resources/theaters/temperate.tres` SHALL register the full directional catalog (all base families × 4 variants) in its `terrain_objects` dictionary alongside its `art_data`. The theater SHALL expose `get_terrain_object(object_id)` for object lookups. Theater remains the container for the data + art bundle in this change.

#### Scenario: All variants registered
- **WHEN** the temperate theater is loaded
- **THEN** every generated `<base>_<dir>` variant resolves via `get_terrain_object`

#### Scenario: Unknown object id returns null
- **WHEN** `get_terrain_object("not_a_tile")` is called
- **THEN** it returns null without error

### Requirement: Connection role vocabulary
`TerrainObject` per-edge connections SHALL use the role set `cliff / ramp / ground / water`. The elevated-vs-base distinction previously carried by a `plateau` role SHALL be expressed by the cell's `corners` instead; `plateau` SHALL NOT appear in the catalog or the data model.

#### Scenario: Elevated edge is ground
- **WHEN** a catalog cell's edge meets flat terrain at the elevated side
- **THEN** the connection role is `ground`, and the elevated height is visible in `corners`

#### Scenario: Ramp-capable edge declares ramp
- **WHEN** a cell edge may dock a ramp
- **THEN** the connection declares `{"role": "ramp"}` (optionally with an `allowed` list of ramp ids)

### Requirement: Catalog data integrity
Every catalog `.tres` SHALL load as a `TerrainObject`, SHALL have non-empty `cells`, and SHALL have per-cell `corners` arrays of exactly 4 integers, `crease` values in `"flat"|"x"|"y"`, and `land` values drawn from the registered land-type ids. A ramp-role connection edge SHALL face an in-tile neighbor at least one step lower.

#### Scenario: All tiles load with valid cells
- **WHEN** every catalog `.tres` is loaded
- **THEN** each has non-empty `cells`, 4-element `corners`, a valid `crease`, and a valid `land`

#### Scenario: Ramp edges face lower neighbors
- **WHEN** a cell declares a `ramp`-role connection on an edge
- **THEN** the in-tile neighbor across that edge has a lower height in `corners`

