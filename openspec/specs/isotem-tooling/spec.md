# isotem-tooling Specification

## Purpose
TBD - created by archiving change terrain-object-catalog. Update Purpose after archive.
## Requirements
### Requirement: TS .tem template parser
The system SHALL provide a permanent Python parser (`tools/isotem/tem.py`) that decodes TS/RA2 TMP `.tem` template files. It SHALL read the 16-byte file header (`BlockWidth`, `BlockHeight`, image width, image height), the per-cell index (0 = empty cell, otherwise absolute file offset), and the 52-byte per-cell headers (`Height`, `LandType`, `SlopeType`, radar colors, extra-face geometry). The parser SHALL expose a `Tile` with its grid dimensions and per-cell footprint data. It SHALL reject files that are too small, have implausible grid dimensions, or reference out-of-range cell offsets.

#### Scenario: Parse a flat clear tile
- **WHEN** `parse_tem` is called on a `clear01.tem` file
- **THEN** it returns a `Tile` whose grid matches the file header and whose occupied cells carry `height`, `land_type`, and `slope` values from their headers

#### Scenario: Empty cells skipped
- **WHEN** a `.tem` file's index contains a zero entry
- **THEN** that grid position is recorded as empty and no cell is created

#### Scenario: Malformed file rejected
- **WHEN** `parse_tem` is called on a file shorter than the header or with an out-of-range cell offset
- **THEN** it raises `ValueError` and does not return a partial `Tile`

### Requirement: CLI footprint dumper with self-check
The system SHALL provide a CLI (`tools/isotem/cli.py`) that prints a tile's width/height, occupied-cell grid, and per-cell height + land type + slope. It SHALL support a framework-free `--check` mode that verifies the parser against the known `cliff01` footprint: grid 2×3, occupied cells `(0,0), (0,1), (1,1), (1,2)`, heights `4/0/4/0`, land type `0x0F` (rock), slope 0.

#### Scenario: Dump a footprint
- **WHEN** the CLI is run with a `.tem` file path
- **THEN** it prints the grid, heights, land types, and slopes and exits 0

#### Scenario: Self-check passes on cliff01
- **WHEN** the CLI is run with `--check` and `cliff01.tem` is available
- **THEN** it verifies all expected values and exits 0

#### Scenario: Self-check reports missing source
- **WHEN** the CLI is run with `--check` and no `.tem` source directory is configured
- **THEN** it prints an error and exits non-zero

### Requirement: Rotation-only shape-family catalog
The system SHALL provide a catalog extractor (`tools/isotem/catalog.py`) that batch-parses every cliff/wcliff/clat/ramp/slope/clear/dcliff `.tem` under a source directory and clusters tiles into shape families under **90° rotation only** (4 transforms). Mirror variants SHALL NOT collapse into the same family (`ramp01` ≠ `ramp02`). The extractor SHALL emit `tools/isotem/isotem_catalog.json` with, per base family, its kind, dimensions, member tile names, and per-cell `(x, y, height, land_type, slope)` data. The source directory SHALL be selectable via CLI arg or `TS_ISOTEM_DIR` env var.

#### Scenario: Rotated variants collapse into one family
- **WHEN** two `.tem` files represent the same shape under a 90° rotation
- **THEN** they are listed as members of the same family with one base tile

#### Scenario: Mirrored variants stay separate
- **WHEN** two `.tem` files are mirrors of each other (e.g. `ramp01` and `ramp02`)
- **THEN** they form distinct families

#### Scenario: Land/geometry kinds do not merge
- **WHEN** a cliff and a water-cliff share identical geometry
- **THEN** they remain separate families because their kinds differ

### Requirement: Corner lookup for catalog cells
The system SHALL emit `tools/isotem/tile_lookup.json` containing, for every catalog family, each cell's 4 corner heights (derived from the cell level plus its RampType corner offsets), a canonical corner pattern under 90° rotation, and the rotation mapping to the observed orientation. It SHALL also emit the reverse map from canonical corner pattern to the list of `(tile, cell, rotation, land)` matches.

#### Scenario: Canonicalization round-trips rotations
- **WHEN** a corner tuple is canonicalized and the canonical form is re-rotated through all 4 orientations
- **THEN** every rotation maps back to the same canonical pattern

### Requirement: TerrainObject .tres generator
The system SHALL provide a generator (`tools/isotem/generate_tres.py`) that reads `isotem_catalog.json` and writes one `TerrainObject` `.tres` per directional variant — every base family × 4 rotations. Each cell SHALL contain `corners: [nw, ne, se, sw]` (absolute vertex heights), `crease: "flat"|"x"|"y"` (the triangulation diagonal), `land` (surface type), and optional `slope` (TS RampType provenance, emitted only when non-zero). `crease` SHALL be derived from the corner pattern. Variant ids SHALL follow the `<base>_<dir>` form with `dir` in `n/e/s/w`.

#### Scenario: Four variants per base family
- **WHEN** the generator runs on a base family
- **THEN** it writes `n`, `e`, `s`, and `w` variants, each with corners rotated to that facing

#### Scenario: Crease derived from corners
- **WHEN** a cell has two adjacent high corners
- **THEN** its `crease` is `"flat"` (the quad is planar; no fold diagonal) and `corners` reflects the rotated heights

#### Scenario: Opposite high corners fold along the high diagonal
- **WHEN** a cell has two opposite high corners (a saddle)
- **THEN** its `crease` is `"y"`, folding along the diagonal connecting the high corners

#### Scenario: Single or triple high corner folds
- **WHEN** a cell has one or three high corners (tent or inverted tent)
- **THEN** its `crease` is `"x"`

#### Scenario: Slope emitted as provenance only
- **WHEN** a cell has a non-zero TS RampType
- **THEN** the `.tres` includes `slope` alongside `corners` and `crease`

#### Scenario: Symmetric tiles still expand
- **WHEN** a family is rotationally symmetric (e.g. a 1×1 tile)
- **THEN** it still emits all four directional variants

