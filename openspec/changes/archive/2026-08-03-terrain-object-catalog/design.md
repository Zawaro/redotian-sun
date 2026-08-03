## Context

Terrain rendering and collision are hardcoded: `TerrainRenderer._get_mesh_name` / `TerrainCollision._get_mesh_name` map cell `type + variant → GLB submesh`, and a sparse `_land_types` overlay defaults everything to `clear`. The seed `TerrainObject` catalog (`cliff_straight_*`, `ramp_n`, `slope`, `clear`) was hand-authored to reproduce current behavior, not to match any real TS tile. The placeholder GLB (`placeholder_terrain01.glb`) ships the full TS mesh set (cliff01–42, wcliff01–28, ramps, slopes, clears), and the TS install provides the canonical `.tem` template files that define the real footprints.

This change makes terrain tile data data-driven: parse TS `.tem` footprints, dedupe them under rotation, and generate a full `TerrainObject` catalog with baked per-cell geometry, so the game can represent actual TS-shaped terrain and reuse one art set across rotated variants.

Stakeholders: the map editor tools (future facing-palette), rendering/collision (mesh + height sampling), pathfinding (land-type authority), and any future theater (tileset) content.

## Goals / Non-Goals

**Goals:**
- A permanent Python `.tem` parser + CLI + catalog extractor (`tools/isotem/`).
- A full data-driven `TerrainObject` catalog matching real TS tile footprints.
- **Baked 4-direction variants**: every base shape × 4 rotations authored as separate `.tres` with explicit per-cell `corners`, `crease`, `slope`, `land` — no runtime footprint rotation.
- Shared art across rotated variants via a suffix-aware `TerrainArtData.mesh_name()` seam.
- Connection role set reduced to `cliff / ramp / ground / water` (`plateau` folded into `ground`).
- Theater registration (`temperate.tres`) so the catalog ships as usable data.
- Ground-truth cross-validation: generated tiles must reproduce the known TS footprints.

**Non-Goals:**
- Replacing placeholder GLB meshes with real TS art (art swap stays on the `TerrainArtData` seam).
- Runtime loading of `.tem` files (offline authoring tool only).
- Wiring catalog variants into editor facing-palette / placement.
- Global catalog / theater-art-only separation (deferred to the theater sub-issues).
- Runtime resolver consuming all corner patterns (dynamic tiling resolver is a separate sub-issue).
- `TerrainSystem` stamping applying `corners` (stamping is a separate sub-issue).

## Decisions

### D1: Per-cell geometry is baked `corners` (4 ints), not `height` + `slope`
Each catalog cell stores `corners: [nw, ne, se, sw]` — absolute vertex heights in lattice steps. This is the geometry authority. The `.tem` `RampType`/`SlopeType` code is retained as `slope` provenance only (optional, emitted when non-zero). The old model (`height` + implicit `RAMP_CORNER_HEIGHTS[slope]`) left corner math to the engine and duplicated the WAE corner table in two places (`catalog.py` and `TerrainSystem.gd`); baking the corners removes the runtime dependency on that table and makes the data verifiable by inspection.

- *Alternatives considered:* (a) keep `height`+`slope` and teach the engine to apply corner offsets — rejected: keeps implicit math and table duplication; (b) a 9-point grid (4 corners + 4 edge midpoints + center) — rejected: the source data encodes only 4 corners per cell; mid-cell cuts/bends are not TS concepts, they live at cell boundaries. The crease concern that motivated 9-points is solved by D2.

### D2: `crease` field declares the triangulation diagonal per cell
Each cell carries `crease: "flat" | "x" | "y"`:
- `flat` — all four corners equal; single quad.
- `x` — fold along NE–SW (triangles NW-NE-SW, NE-SE-SW).
- `y` — fold along NW–SE (triangles NW-NE-SE, NW-SE-SW).

The height sampler and the collision generator both read `crease` and triangulate identically, so an entity's sampled Y and the collision surface agree by construction. The generator derives `crease` from the corner pattern (a pure function of which corners are high) — no hand-authoring needed.

- *Alternatives considered:* derive the split at runtime from the corner pattern — rejected: two independent consumers would each implement the fold rule and could drift; declaring it in data makes agreement structural. A 9-point grid — rejected (see D1).

### D3: 4-direction variants are authored data; no runtime footprint rotation
`generate_tres.py` emits, for every base shape, four `.tres` files (`cliff01_n`, `cliff01_e`, `cliff01_s`, `cliff01_w`) with corners already rotated to that facing. The engine places the tile directly — it never rotates a footprint. Mirrors stay distinct base shapes: the catalog dedup is **rotation-only** (4 transforms), so `ramp01` ≠ `ramp02` even though they share geometry. Expansion is uniform across all families (including symmetric/single-cell tiles) for consistency.

- *Alternatives considered:* (a) one `.tres` per family + a runtime `rotation` field — rejected: runtime footprint rotation needs mirror support the renderer lacks, and re-derives geometry instead of using authored data; (b) dedup under the full dihedral group (rotations + mirrors) — rejected: would collapse mirror-distinct pieces the game needs as separate bases.

### D4: Art is shared via a suffix-aware mesh seam
`TerrainArtData.mesh_name(tile_id)` strips the directional suffix (`cliff01_n` → `cliff01`) before resolving the GLB submesh; the renderer derives the mesh instance rotation from the suffix (`n`→0°, `e`→90°, `s`→180°, `w`→270°). One GLB submesh per family serves all four variants. Seed ids (`cliff_straight_n/e/s/w`, `ramp_n`, `slope`, `clear`) resolve via the existing `FALLBACK_MESHES` table, which stays one entry per family.

- *Alternatives considered:* explicit per-variant `facing` field + 4× `FALLBACK_MESHES` entries — rejected: redundant; the suffix → rotation mapping is a pure function of the id.

### D5: Connection roles collapse `plateau` into `ground`
The role set is `cliff / ramp / ground / water`. `plateau` and `ground` were runtime-identical (both mean "open flat boundary edge, no dock"); nothing branches on the difference. The elevated-vs-base semantics live in `corners`, so a distinct role name adds vocabulary without behavior.

### D6: Theater remains the container for data + art in this change
The full catalog registers in `resources/theaters/temperate.tres` alongside its `art_data`. The "catalog global, theater art-only" separation is deferred to the theater sub-issues so this change ships the data against the structure that exists today.

## Risks / Trade-offs

- **Generated data volume** (≈96 `.tres`) → Accepted: they are generated, not maintained; the generator is the review surface, the files are output.
- **Art fallback quality** — directional variants rely on `mesh_name()` suffix-stripping + the existing `FALLBACK_MESHES`; a tile with no GLB submesh falls back to an approximation → Mitigated by keeping the fallback table and documenting the mapping in `TerrainArtData`.
- **Two sources of truth** (baked corners vs live vertex grid) — stamping is out of scope, so baked corners are data now and runtime geometry later → Mitigated by deferring stamping; the data format is chosen to be exactly what the stamping sub-issue will consume.
- **Mirror-distinct bases inflate the catalog** (ramp01 + ramp02 both expanded 4×) → Accepted: mirrors are real gameplay pieces (climbable edge on opposite sides).
- **Rotation-only dedup may leave near-duplicate families** if two `.tem` files differ only by art noise → Mitigated by spot-checking family membership during review.
- **Regression on existing tests** (pathfinding/classification reference current land-type/mesh behavior) → Mitigated by the catalog test staying data-only; no runtime consumer changes in this change.

## Migration Plan

1. Land the three data classes (`TerrainObject.gd`, `TheaterData.gd`, `TerrainArtData.gd`) + placeholder art so generated `.tres` compile.
2. Land the parser tooling (`tem.py`, `cli.py`, README) with the framework-free self-check.
3. Land the rotation-only catalog + corner lookup (`catalog.py`, both JSON outputs), cross-validated against the known `cliff01`/`ramp01` footprints.
4. Land the generator + all `terrain_objects/*.tres` with baked corners/crease.
5. Register the catalog in `temperate.tres`; fold seeds into the variants; add the suffix-aware art seam.
6. Rewrite the catalog test for the baked model; archive the openspec change.
7. Rollback: delete the new files; existing JSON maps and `LandType` resources are unaffected.

## Open Questions

- Whether a second theater (e.g. `snow`) should ship data-only here or with the theater sub-issues → deferred; this change ships `temperate` only.
- Whether any `.tem` member collapses into a family whose base orientation is non-canonical (affects which 4 rotations are emitted) → resolved by picking the canonical-oriented member as the family base, same rule the existing extractor uses.
