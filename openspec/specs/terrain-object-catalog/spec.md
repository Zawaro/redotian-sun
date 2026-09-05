# terrain-object-catalog Specification

## Purpose
TBD - created by archiving change terrain-object-catalog. Update Purpose after archive.

## Requirements

### Requirement: TerrainObject data model
The system SHALL define a `TerrainObject` resource (`scripts/data/TerrainObject.gd`) representing one authored directional terrain tile. It SHALL have `id: String`, `cell_type` (`"cliff"`/`"slope"`/`"ramp"`/`"clear"`), `display_name: String`, `art_data: TerrainArtData` (the shared art entry that renders this object; multiple objects SHALL reference the same entry), and `cells: Dictionary` keyed by object-local `"x,z"` strings. Each cell value SHALL contain `land` (surface type id), `corners: Array[int]` of 4 absolute vertex heights in `[nw, ne, se, sw]` order, `crease: String` in `"flat"|"x"|"y"`, and optional `slope` (TS RampType provenance). `TerrainObject` instances SHALL be data-only; no rendering or pathfinding logic lives in the resource.

#### Scenario: Cell exposes corners and crease
- **WHEN** a `ramp01_e` object's `"1,1"` cell is read
- **THEN** it returns `corners` of 4 heights, a `crease` in `"flat"|"x"|"y"`, and a `land` type

#### Scenario: Object references shared art
- **WHEN** a `TerrainObject` is loaded
- **THEN** its `art_data` is a `TerrainArtData` shared with other objects of the same mesh family

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

### Requirement: Per-element terrain art resolution
The system SHALL define a per-element `TerrainArtData` resource (`scripts/data/TerrainArtData.gd`) that owns art acquisition and orientation for a mesh family: `id`, `model_path` (the default GLB), `submesh_id` (the GLB submesh to render, defaulting to the element's base id), and `theater_overrides: Dictionary` mapping a theater id to an alternative GLB path. The resource SHALL provide `resolve(object_id: String, theater_id: String)` returning the resolved glb path, submesh id, and Y-axis rotation derived from the object id's directional suffix (`n`→0°, `e`→270°, `s`→180°, `w`→90°). A theater with no override SHALL use `model_path`. A single art entry SHALL serve all four directional variants of its family.

#### Scenario: Directional variant resolves to shared mesh with rotation
- **WHEN** `resolve("cliff01_e", "temperate")` is called on the `cliff01` art entry
- **THEN** it returns the default `model_path`, submesh `cliff01`, and a 270° rotation

#### Scenario: Theater override replaces the glb
- **WHEN** `resolve("cliff01_n", "snow")` is called and the entry has a `"snow"` override
- **THEN** it returns the override GLB path, the same submesh id, and a 0° rotation

#### Scenario: Submesh fallback id
- **WHEN** an art entry declares `submesh_id` (e.g. the `cliff09` family)
- **THEN** `resolve` returns that submesh for every object referencing the entry

### Requirement: Light theater and global catalog registration
The system SHALL define `TheaterData` (`scripts/data/TheaterData.gd`) as a light tag with `id` and `display_name` only — it SHALL NOT embed TerrainObjects or art, and SHALL NOT carry a default land type (the game-wide default lives in `TerrainSystem.DEFAULT_LAND_TYPE`). The full directional catalog SHALL live in a global registry (`games/ts/terrain_objects/`) scanned by the TerrainCatalog autoload, independent of any theater. Theater art variation SHALL be expressed per element through `TerrainArtData.theater_overrides`. `TerrainCatalog.get_theater(theater_id)` SHALL return the theater; unknown ids SHALL return null without error.

#### Scenario: Theater is a light entry
- **WHEN** a theater resource is loaded
- **THEN** it exposes `id` and `display_name`, holds no TerrainObjects or art data, and has no land-type field

#### Scenario: All variants registered globally
- **WHEN** the TerrainCatalog scans `games/ts/terrain_objects/`
- **THEN** every `<base>_<dir>` variant resolves via `get_object`, regardless of active theater

#### Scenario: Unknown theater id returns null
- **WHEN** `get_theater("not_a_theater")` is called
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
Every catalog `.tres` SHALL load as a `TerrainObject`, SHALL have non-empty `cells`, SHALL have per-cell `corners` arrays of exactly 4 integers, `crease` values in `"flat"|"x"|"y"`, and `land` values drawn from the registered land-type ids. Every `TerrainObject` SHALL reference a non-null `art_data` that resolves. A ramp-role connection edge SHALL face an in-tile neighbor at least one step lower.

#### Scenario: All tiles load with valid cells
- **WHEN** every catalog `.tres` is loaded
- **THEN** each has non-empty `cells`, 4-element `corners`, a valid `crease`, and a valid `land`

#### Scenario: Every object resolves art
- **WHEN** every catalog object's `art_data` is resolved for the active theater
- **THEN** each resolves to a glb path and submesh (no missing-art entries in the shipped catalog)

#### Scenario: Ramp edges face lower neighbors
- **WHEN** a cell declares a `ramp`-role connection on an edge
- **THEN** the in-tile neighbor across that edge has a lower height in `corners`
