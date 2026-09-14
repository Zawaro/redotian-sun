# Tiberian Sun Core Engine & Simulation Mechanics — Deep Research Reference

Exhaustive, web-sourced reference for the core engine and simulation mechanics of
**Command & Conquer: Tiberian Sun (TS) and Firestorm (FS)**, written to inform a unified,
data-driven reimplementation (Tiberian Sun / Firestorm / Red Alert 2 / Yuri's Revenge).

## Scope, method, and authority

- **Web only.** Ground truth is ModEnc (`modenc.renegadeprojects.com`), the OpenTS Manual
  and its reconstructed TS source (`OpenTS-Developers/TibSun`, `OpenTS-Developers/OpenTS`),
  the archived shipped INIs (`Vinifera-Developers/Tiberian-Sun-INIs`), cnc.fandom.com, and
  Project Perfect Mod / CnCNet forums. No local game files were read.
- **Cross-checked** against at least two sources per mechanic where possible.
- **Version basis:** TS `RULES.INI` and FS `FIRESTRM.INI` as archived from the shipped game.
  Inline comments marked "was" are Westwood's own tuning history. Where the Firestorm
  add-on overrides a base value, both are given.
- **No code snippets.** Prose / short pseudocode only.
- Terminology follows the project `GLOSSARY.md` where it exists; engine terms are quoted as-is
  (e.g. `Verses`, `SpeedType`, `MovementZone`).

Confidence scale: **high** = multiple independent authoritative sources agree; **med** =
single authoritative source or a known-ambiguous/OpenTS-reconstructed mechanic; **low** =
inferred, dead code, or unresolved conflict.

Primary source shortcuts used throughout:

| Short name | URL |
|---|---|
| TS `RULES.INI` | https://github.com/Vinifera-Developers/Tiberian-Sun-INIs/blob/master/RULES.INI |
| TS `FIRESTRM.INI` | https://github.com/Vinifera-Developers/Tiberian-Sun-INIs/blob/master/FIRESTRM.INI |
| OpenTS Manual | https://github.com/OpenTS-Developers/OpenTS/tree/main/manual/content |
| OpenTS source | https://github.com/OpenTS-Developers/TibSun/tree/main/code |
| ModEnc | https://modenc.renegadeprojects.com/ |

**Caveat on the reconstructed source.** The OpenTS code is a faithful community
reconstruction of TS 2.03 + Firestorm, derived partly from EA's GPL-released RA/TD source and
partly by reverse engineering. Structural formulas are trustworthy; a small number of the
manual's pages explicitly describe *dead* branches (parsed but never read) and these are
called out as such below. Where the manual describes an engine behavior that the original
shipped `RULES.INI` contradicts, both are stated.

---

### TS-CORE-001 — Isometric Grid, Leptons, Cell, and Tile Size

**What** — The world is a pseudo-isometric grid of square **cells**. All sub-cell distances
are measured in **leptons**, the engine's smallest internal distance unit. A cell's pixels
are drawn in a 2:1 isometric projection, so leptons-per-pixel differ vertically and
horizontally.

**Data keys** — No INI key for the units themselves. Consumers: `Range`/`Sight` (cells),
`FLH` firing offsets (leptons), `Spread` (warhead falloff, effectively leptons×3 per step),
`PrimaryFirePixelOffset` (screen pixels), `Height` (structure, 200-lepton steps).

**Numbers**
- **1 cell = 256 × 256 leptons** (`CELL_LEPTON_W = CELL_LEPTON_H = 256`).
- **Cell render size = 24 × 48 pixels** (`CELL_PIXEL_W=24`, `CELL_PIXEL_H=48`); therefore
  **1 pixel = 256/24 ≈ 10.667 leptons horizontally** and **256/48 ≈ 5.333 vertically**.
- A separate isometric *tile* constant exists for terrain art: `ISO_TILE_SIZE ≈ 48.083`
  (`sqrt(34²·2)`), `ISO_TILE_PIXEL_W = 48`, `ISO_TILE_PIXEL_H = 24` (cos 60° × 48).
- Generic conversion macro: `LEPTON_TO_PIXEL(l) = l/7` (flat approximation); the vertical
  ratio above is the strict one.
- `LEPTON` is a 32-bit signed int typedef. `Cell` is a pair of `short`s (map coordinates),
  `Coord` is three ints (`X`, `Y`, `Z`) in leptons.
- `Cell::As_Int()` packs a cell index as `((Y - MAP_CELL_W*(X+Y) - X) << 6)`; `Coord` packs
  as `(X/10) + ((Y/10) << 16)` for event transport.

**Edge cases**
- Because the projection is 2:1, an in-game "circle" of weapon range resolves as an
  octagon/diamond, not a Euclidean circle.
- `PIXEL_LEPTON_W = 256/24`, `PIXEL_LEPTON_H = 256/48`; distance-to-damage falloff divides by
  `PIXEL_LEPTON_W` variants (`PIXEL_LEPTON_W/3`, `/4`) — so horizontal and vertical distance
  falloff are asymmetric unless the caller pre-normalises.

**Kind** — generic-engine geometry / units of measure.

**Sources**
- https://modenc.renegadeprojects.com/Lepton (high)
- `code/sun.h` (OpenTS) — `CELL_PIXEL_W/H`, `LEPTON_TO_PIXEL` (high)
- `code/globals.cpp` (OpenTS) — `ISO_TILE_*`, `LEVEL_LEPTON_H` (high)

**Confidence** — high (cell=256 leptons, 24×48 px); med (exact ISO_TILE internals, art-side).

---

### TS-CORE-002 — Map Array, Playfield, Playable Area, and Diamonds

**What** — The engine allocates a fixed **512 × 512 cell array**. The map file declares a
`[Map]` size; the *playfield* is the cells the map has, and the *playable area* is a smaller
inset region (`LocalSize=`) that orders, vision and movement are tested against. A generated
map writes the playfield 4 cells wider and 12 taller than the play area, with the play area
inset 2 columns and 5 rows.

**Data keys** — `[Map] Size=x,y` (playfield), `[Map] LocalSize=x,y` (playable area),
`[Map] Width`/`Height` (generated-map sizing), `[Map] NumPlayers`, waypoints.

**Numbers**
- `MAP_CELL_W = 512`, `MAP_CELL_H = 512`, `MAP_CELL_TOTAL = 262144`.
- Region grouping: `REGION_WIDTH = REGION_HEIGHT = 4`; region array is
  `ceil(W/4)+2 × ceil(H/4)+2`.
- Classic TS map sizes are 64×64 up to 128×128+ cells on the playfield; the array limit is
  512×512. `IsoMapPack` revision 1 addresses the original 128×128 grid; newer revisions are
  sparse and address up to the array.
- Old cell packing is 7 bytes/cell in `[IsoMapPack]`.

**Edge cases**
- Cells outside the playfield are dropped for all overlays. Crates/pods can land anywhere in
  the playfield; only the *playable area* gates orders, sight locks and lightning.
- `Cell(int cellnum)` constructor splits `% 128` / `/ 128` — legacy 128-wide assumption in
  one code path.
- A 512×512 array with a smaller `Size=` means indexing must use the declared size, not 512,
  for row-major packing.

**Kind** — generic-engine map model / title-data (map sizes).

**Sources**
- `code/sun.h` (OpenTS) — `MAP_CELL_W/H`, region constants (high)
- `systems/map-generation.md`, `formats/scenario-terrain.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Map (med)

**Confidence** — high.

---

### TS-CORE-003 — Cell ↔ Coord Conversion and Sub-Cell Positions

**What** — A cell maps to a coord at its centre; `StoppingCoordAbs[5]` gives the absolute
offset from the cell origin that an object may stop at. Only infantry (and dedicated
sub-cell logic) may stop off-centre. Five positions exist: centre + four quadrants. A cell
carries **three infantry standing places** (north-east, south-west, south-east) within those
five sub-positions.

**Data keys** — Terrain: `TemperateOccupationBits` (default `7`), `SnowOccupationBits`
(default `7`) — bitmask `1`=NE, `2`=SW, `4`=SE of the three places a *terrain object* fills.

**Numbers**
- `Cell(X,Y).As_Coord(z)` = `(X·256 + 128, Y·256 + 128, z)`.
- `StoppingCoordAbs` = centre `(128,128)`, UL `(64,64)`, UR `(192,64)`, LL `(64,192)`,
  LR `(192,192)` (all in leptons relative to the cell origin).
- Standing-place bits: `1` = NE, `2` = SW, `4` = SE. `7` fills all three and classes the
  cell as **fully blocked**; any other value (including `0`) classes it **partly blocked**.

**Edge cases**
- A terrain object marks standing places only on the cell it is anchored to; for multi-cell
  terrain foundations the remaining cells are never marked and infantry may path into them.
- `TemperateOccupationBits` is consulted in temperate theater only; `SnowOccupationBits` in
  snow. Setting one without the other changes behavior in one theater only.
- `Foundation=6x4` and `3x3Refinery` leave an odd cell open (see TS-CORE-005).

**Kind** — generic-engine cell model + title-data (occupation bit defaults).

**Sources**
- `code/const.cpp` (OpenTS) — `StoppingCoordAbs` (high)
- `keys/temperateoccupationbits.md`, `keys/snowoccupationbits.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Cell (med)

**Confidence** — high (coordinates, 3 standing places); med (exact bit semantics in original).

---

### TS-CORE-004 — Locomotor List and Piggybacking

**What** — A **locomotor** is a separate runtime object linked to each mobile instance. It
owns movement, destination, layer, occupation and locomotor-specific drawing. A type's
`Locomotor=` names the concrete class; temporary replacement (drop pods, factory exit) uses
**piggybacking**, stashing the previous locomotor and restoring it.

**Data keys** — `Locomotor={GUID}` (per Infantry/Vehicle/Aircraft type). Ten classes.
`AllowBurrowing`, `TunnelSpeed` (tunnel), `PitchAngle`/`PitchSpeed`/`RollAngle`/`FlightLevel`
(fly), `HoverBob`/`HoverDampen` (hover/levitate), `Accelerates`/`AccelerationFactor`/
`DeaccelerationFactor` (drive), `Climb`/`CruiseHeight`/`WobblesPerSecond`/`WobbleDeviation`/
`TurnRate`/`Acceleration` (`[JumpjetControls]`).

**Numbers** — Ten registered locomotor GUIDs:

| GUID | Movement |
|---|---|
| `{4A582741-9839-11D1-B709-00A024DDAFD1}` | Drive (wheeled/tracked ground) |
| `{4A582742-9839-11D1-B709-00A024DDAFD1}` | Hover |
| `{4A582743-9839-11D1-B709-00A024DDAFD1}` | Tunnel |
| `{4A582744-9839-11D1-B709-00A024DDAFD1}` | Walk (infantry) |
| `{4A582745-9839-11D1-B709-00A024DDAFD1}` | Ballistic (drop pod) |
| `{4A582746-9839-11D1-B709-00A024DDAFD1}` | Flyer (aircraft) |
| `{4A582747-9839-11D1-B709-00A024DDAFD1}` | Teleport (default when omitted) |
| `{55D141B8-DB94-11D1-AC98-006008055BB5}` | Mech (Titan/Juggernaut) |
| `{92612C46-F71F-11D1-AC9F-006008055BB5}` | Jumpjet |
| `{3DC0B295-6546-11D3-80B0-00902792494C}` | Levitate (jellyfish, FS) |

Which locomotor reads the terrain table: **only Drive is throttled by it**. Walk/Mech use the
chain at a fixed full throttle; Hover multiplies by its own ramp; Tunnel multiplies by
`TunnelSpeed` going down/up; Fly uses type top speed × own throttle; Jumpjet/Levitate read
their shared control blocks only; Drop pod reads height; Teleport is instantaneous.

**Edge cases**
- A BuildingType never creates a locomotor; `Locomotor=` is inert in a building section.
- A reinforcement chain burrows onto the map only if *every* member names the tunnel
  locomotor; one non-tunnel member disqualifies the whole chain.
- A vehicle leaving a war factory is sorted by its *current* locomotor: drive is forced onto
  the exit track, tunnel gets a temporary drive locomotor piggybacked, anything else gets a
  destination 3 cells east and 1 south.
- An unrecognized GUID that names no registered class **crashes** as the first instance is
  constructed. Malformed text is discarded and the previous value stays.

**Kind** — generic-engine locomotion + title-data (the ten registrations).

**Sources**
- `keys/locomotor.md`, `internals/locomotion.md`, `systems/movement-and-terrain.md`
  (OpenTS Manual) (high)
- `code/loco.cpp` (OpenTS) (high)

**Confidence** — high.

---

### TS-CORE-005 — Foundation / Footprint

**What** — A structure's footprint is a fixed named size. The name is the only thing that
fixes its shape; from it come occupied cells, the exit ring, width/height, and the radar
diamond. Read twice: first from the `[<Image>]` art entry, then from the art entry named
after the BuildingType (the second overrides the first **only if != `1x1`**).

**Data keys** — `Foundation=<name>` (building art), `[<Type>] Foundation=`; 22 fixed names.

**Numbers** — 22 accepted names (matched case-insensitively): `1x1`, `2x1`, `1x2`, `2x2`,
`2x3`, `3x2`, `3x3`, `3x5`, `4x2`, `3x3Refinery`, `1x3`, `3x1`, `4x3`, `1x4`, `1x5`, `2x6`,
`2x5`, `5x3`, `4x4`, `3x4`, `6x4`, `0x0`. Any unrecognized name resolves to `1x1`.
- `3x3Refinery` = 3×3 but stands on 8 of 9 cells (cell 2E,1S of top-left open); exit ring is
  its top-left corner.
- `0x0` = no cells, no exit ring, width/height 0.
- `6x4` stands on 21 cells (bottom row 3 wide starting one east); exit ring is one cell at
  2E,1N of top-left.
- `Foundation=1x1` written on the *type's own* art entry is ignored when the image entry gave
  something larger.

**Edge cases**
- A TerrainType has foundation data for only the first eight sizes.
- `Bib=yes` does **not** enlarge the footprint; the apron is art-only (`BibShape`).
- The exit ring is where a produced object is sent; a width ≥ 6 is drawn without the shared
  Z-shape.

**Kind** — generic-engine footprint system + title-data (size list).

**Sources**
- `enums/building-foundation.md`, `keys/foundation--buildingtype.md` (OpenTS Manual) (high)
- `code/bsize.hh` (OpenTS) (high)

**Confidence** — high.

---

### TS-CORE-006 — Bibs and Base Adjacency

**What** — A **bib** is an apron on a structure's eastern edge that vehicles may drive over.
Placement legality is governed by a separate **adjacency** check: a pending structure must be
near an eligible anchor owned by the same (or mutually allied) house.

**Data keys** — `Bib=yes`, `BibShape` (art), `Adjacent=n` (pending type), `BaseNormal=yes`
(existing type), `BuildOffAllyAnyStructure`.

**Numbers**
- `Bib=yes`: blocks nothing for a vehicle on the structure's eastern column, when the cell one
  step further east is not part of the same structure. Infantry are unaffected.
  - A `Refinery=yes` structure additionally opens one cell for an allied `Harvester=yes`
    vehicle; a `Weeder=yes` structure does the same for an allied `Weeder=yes` vehicle.
- Adjacency scan: the pending foundation's `Adjacent` **plus one** cell in every direction.
  `Adjacent=0` still permits contact. Accept a wall when a scanned cell is owned by the same
  house; accept any placement when a scanned cell holds a `BaseNormal=yes` building owned by
  the same or a mutually allied house.
- `BuildOffAllyAnyStructure` narrows ally anchors from any ally building to construction yards
  only; the alliance must be mutual (two-way).

**Edge cases**
- The bib flag and `BibShape` are independent: a structure can carry either without the other.
- Adjacency is checked only by the placing machine, only for the local player, and never in
  the map editor.
- A wall placement accepts a same-house-owned scanned cell with **no building required**.

**Kind** — generic-engine base placement + title-data (defaults in `[General]`).

**Sources**
- `keys/bib.md`, `systems/base-adjacency.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Bib (high)

**Confidence** — high.

---

### TS-CORE-007 — Height Levels, Grades, Ramps, and Slopes

**What** — Terrain has discrete **height levels**. One level = 104 leptons (derived from the
isometric geometry). Slopes connect levels and are classified; only four "standard ramps"
support Tiberium/veins/crates. Height affects sight, firing, bridge layering and projectile
aim.

**Data keys** — Internal: `LEVEL_LEPTON_H = 104`, `LEVEL_PIXEL_H = 12`,
`BRIDGE_CELL_HEIGHT = 4`. Art/theater: ramp/slope set roles (`CliffRamps`, `SlopeSetPieces`).
Structure `Height=n` (200-lepton steps, distinct from terrain levels).

**Numbers**
- `LEVEL_LEPTON_H = tan(90°−60°) · CELL_LEPTON_DIAG / 2 = 104` leptons.
- `LEVEL_PIXEL_H = 12`; `LEVEL_PIXEL_H_1 = 12`.
- `CELL_SLOPE_ANGLE ≈ atan(104/256) ≈ 0.3724 rad`; `CELL_DIAG_SLOPE_ANGLE ≈ 0.5116 rad`.
- `BRIDGE_LEPTON_HEIGHT = 104×4 + 0.5 → 416` leptons (four levels).
- `CELL_LEPTON_DIAG = sqrt(2·256²) ≈ 362.039`.
- A structure `Height=2` = 400 leptons of bulk; used for jumpjet fly-level and non-arcing
  aim at tall structures.
- Ground level for a newly generated map starts at **4**.

**Edge cases**
- Height is folded into every shroud/fog query: coordinate height in levels is halved and
  subtracted from both cell axes, so the answer comes from the cell a coordinate is *drawn
  over*, not the cell it stands on; at an odd height the SE cell is consulted too.
- A one-level step is the maximum a ground object may climb/descend, and only across a ramp
  (the ramp must be the lower of the two cells). A four-level step is the bridge case. Any
  other difference is refused.
- `Height=` on a structure is truncating integer; `1.5` stores `1`.

**Kind** — generic-engine terrain model; height constants are engine-fixed.

**Sources**
- `code/globals.cpp`, `code/sun.h` (OpenTS) — constant values (high)
- `systems/movement-and-terrain.md`, `keys/height--buildingtype.md` (OpenTS Manual) (high)
- `formats/scenario-terrain.md` (ice-growth flag / map heights) (high)

**Confidence** — high (104 leptons/level, 416 bridge); med (ramp artwork classification).

---

### TS-CORE-008 — Cliffs, Cliff Collapse, and CliffBackImpassability

**What** — Cliffs are height discontinuities of ≥ 2 levels. A cell directly behind a tall
cliff can be made impassable via `CliffBackImpassability`. Theater tiles can be marked
**destroyable cliffs**, which come down under fire / railgun / sonic rolls.

**Data keys** — `CliffBackImpassability` (`[General]`, default `2`), `CollapseChance`
(`[CombatDamage]`, default `100`), `DestroyableCliffs` (scenario), theater cliff roles, art
`IsCliff`.

**Numbers**
- `CliffBackImpassability=2` rewrites a cell one full cliff step below any of six examined
  neighbors to land type `Rock`; only `Clear`, `Water`, `Beach`, `Ice` are open to the rewrite.
- `CollapseChance` is a percentage: `100` collapses on every hit, `0` never, `>100` behaves as
  `100`. Rolled on: any explosion in the cell; where a railgun beam is stopped by rising
  ground; the cell the railgun settles on; and **every frame** a sonic wave sweeps a cliff
  cell (re-rolled each frame, so cliffs fall almost immediately under sonic).
- A cliff two levels high stops every ground object regardless of land type, movement zone, or
  locomotor. The zone map split seen at cliffs comes from two different growth thresholds (a
  run ends at a difference of 2 levels one way and 4 the other).

**Edge cases**
- `CollapseChance` is still rolled when no cliff is present — the cell must be theater-flagged
  as a destroyable cliff for the roll to matter.
- Sonic waves damage their whole accumulated swathe again every frame, multiplying the roll
  count.

**Kind** — generic-engine terrain + title-data (firing/behavior).

**Sources**
- `keys/collapsechance.md`, `keys/cliffbackimpassability.md`, `systems/movement-and-terrain.md`
  (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/CollapseChance (high)

**Confidence** — high.

---

### TS-CORE-009 — Full Land-Type List

**What** — Every terrain cell has exactly one **LandType**. Twelve classes exist and are
engine-fixed (a mod can retune a section but not add a thirteenth). Land type comes from the
tile below, except `Wall`, `Tiberium`, `Weeds` which arrive via overlay, and `Rock` which can
be assigned by `CliffBackImpassability`.

**Data keys** — `[Clear]`, `[Road]`, `[Water]`, `[Rock]`, `[Wall]`, `[Tiberium]`, `[Beach]`,
`[Rough]`, `[Ice]`, `[Railroad]`, `[Tunnel]`, `[Weeds]` — one rules section each. Overlay
`Land=` can force a cell's land type.

**Numbers** — Full list (constant → value → section):

| Constant | Value | Section | Notes |
|---|---:|---|---|
| `LAND_CLEAR` | 0 | `[Clear]` | default grass |
| `LAND_ROAD` | 1 | `[Road]` | roads |
| `LAND_WATER` | 2 | `[Water]` | open water |
| `LAND_ROCK` | 3 | `[Rock]` | cliffs, impassable |
| `LAND_WALL` | 4 | `[Wall]` | man-made obstacles |
| `LAND_TIBERIUM` | 5 | `[Tiberium]` | Tiberium overlay |
| `LAND_BEACH` | 6 | `[Beach]` | water/ground join |
| `LAND_ROUGH` | 7 | `[Rough]` | rocky/brush |
| `LAND_ICE` | 8 | `[Ice]` | frozen water |
| `LAND_RAILROAD` | 9 | `[Railroad]` | rail tracks |
| `LAND_TUNNEL` | 10 | `[Tunnel]` | tunnel terrain |
| `LAND_WEEDS` | 11 | `[Weeds]` | vein weeds |

**Edge cases**
- `Tiberium` overlay only yields `LAND_TIBERIUM` when the overlay's own land type is `Clear`;
  otherwise the overlay's land type wins.
- Veins report `LAND_WEEDS` outright through `Land=Weeds` on the overlay, ahead of the tile.
- `[Wall]` cells are `Foot=0/Track=0/Wheel=0/...` so all ground movement is refused even
  before the overlay blocking check.

**Kind** — generic-engine enumerations + title-data (section values).

**Sources**
- `code/land.hh`, `code/const.cpp` (`LandName`) (OpenTS) (high)
- `enums/land-type.md`, `systems/movement-and-terrain.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/LandTypes (high)

**Confidence** — high.

---

### TS-CORE-010 — Per-Land Speed/Passability Table (full 12 × 8)

**What** — Each land section holds one figure per SpeedType — `Foot`, `Track`, `Wheel`,
`Hover`, `Winged`, `Float`, `Amphibious`, `Creep`. **Exactly zero refuses the cell**; any
other figure is a fractional speed multiplier (capped at 1) that only the *drive* locomotor
applies. Firestorm adds the `Creep` column; the base game has no `Creep=` lines.

**Data keys** — `Foot=`, `Track=`, `Wheel=`, `Hover=`, `Winged=`, `Float=`, `Amphibious=`,
`Creep=`, `Buildable=` in each land section.

**Numbers** — TS `RULES.INI` shipped table (percent):

| Land | Foot | Track | Wheel | Hover | Float | Amphibious | Creep (FS) | Buildable |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Clear | 90 | 70 | 70 | 100 | 0 | 80 | +100 | yes |
| Rough | 80 | 60 | 40 | 100 | 0 | 40 | +90 | yes |
| Road | 100 | 100 | 100 | 100 | 0 | 100 | +100 | yes |
| Water | 0 | 0 | 0 | 100 | 100 | 80 | +0 | no |
| Rock | 0 | 0 | 0 | 0 | 0 | 0 | +0 | no |
| Wall | 0 | 0 | 0 | 0 | 0 | 0 | +0 | no |
| Tiberium | 90 | 70 | 50 | 100 | 0 | 50 | +100 | no |
| Weeds | 50 | 70 | 50 | 100 | 0 | 50 | +90 | no |
| Beach | 0 | 0 | 0 | 100 | 0 | 60 | +0 | no |
| Ice | 50 | 80 | 50 | 100 | 0 | 50 | +100 | no |
| Railroad | 90 | 100 | 50 | 100 | 0 | 50 | +100 | no |
| Tunnel | 100 | 100 | 100 | 100 | 0 | 100 | +100 | no |

(FS `FIRESTRM.INI` adds the `Creep=` values shown with `+`. Firestorm also redefines land
sections wholesale — each section in a later file is re-read from built-in defaults.)

**Edge cases**
- A figure above `1` (100%) is clamped down to 1 as it is read; nothing clamps the bottom.
- A land section absent from every file leaves all eight figures at **0** (impassable to
  everything), not at a sane default.
- The **`Winged`** column is never written by the shipped sections, so any vehicle given
  `SpeedType=Winged` is refused every cell unless a rules file writes the column.
- `Buildable` gates structure placement and Tiberium/vein spread; it is *not* the same check
  the per-step movement test uses.
- The zone map reads only the `Wheel` column (see TS-CORE-012).

**Kind** — generic-engine speed table + title-data (the numbers).

**Sources**
- TS `RULES.INI` lines 10343–10460 (high)
- TS `FIRESTRM.INI` lines 1721–1765 (high)
- https://modenc.renegadeprojects.com/LandTypes (high)
- `systems/movement-and-terrain.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-011 — SpeedType

**What** — A vehicle's `SpeedType` picks the terrain-table column used for both the per-step
passability test and the drive locomotor's throttle. It also selects the slope multiplier
pair.

**Data keys** — `SpeedType=` on Infantry/Vehicle/Aircraft/Building types. `Crusher=` supplies
the default when omitted.

**Numbers** — Accepted tokens: `Foot`, `Track`, `Wheel`, `Hover`, `Winged`, `Float`,
`Amphibious`, `Creep` (FS). SpeedType **constants** (engine enum): `SPEED_NONE=-1`, `FOOT=0`,
`TRACK=1`, `WHEEL=2`, `HOVER=3`, `WINGED=4`, `FLOAT=5`, `AMPHIBIOUS=6`, `CREEP=7`.
- Defaults: Infantry = `Foot`; Aircraft = `Winged`; Building = none (no locomotor);
  Vehicle = `Track` if `Crusher=yes`, otherwise `Wheel`.
- `Winged` always grants 100% movement in the per-step test (its column is moot for aircraft;
  but a *vehicle* given `SpeedType=Winged` uses the (zero) Winged column).
- Slope multiplier: `Track` → `TrackedUphill`/`TrackedDownhill`; every other speed type →
  `WheeledUphill`/`WheeledDownhill`.
- `WheeledUphill=.5`, `WheeledDownhill=1.2`, `TrackedUphill=.5`, `TrackedDownhill=1.1`.

**Edge cases**
- A misspelled `SpeedType` resolves to **no speed type** (not a fallback); the
  Track/Wheel default repair runs *before* this key is read, so it cannot undo the bad value.
  Every throttle/passability question then reads one slot short of the table's first column.
- `Hover` and `Amphibious` are TS additions; `Creep` is a Firestorm addition.

**Kind** — generic-engine movement class + title-data.

**Sources**
- `code/speed.hh`, `code/const.cpp` (`SpeedName`) (OpenTS) (high)
- `keys/speedtype.md`, `enums/speed-type.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/SpeedType (high)

**Confidence** — high.

---

### TS-CORE-012 — MovementZone and the Zone Map

**What** — `MovementZone` decides which **blockage rating** classes count as connected ground
for reachability. Before any route is searched, the map is boiled into ten zone tables (one
per class); a destination in a different zone from the mover is refused.

**Data keys** — `MovementZone=` on mobile types. Zone classes are engine-fixed.

**Numbers** — Ten classes (constant → value → token):

| Constant | Value | Token |
|---|---:|---|
| `MZONE_NORMAL` | 0 | `Normal` |
| `MZONE_CRUSHER` | 1 | `Crusher` |
| `MZONE_DESTROYER` | 2 | `Destroyer` |
| `MZONE_AMPHIBIOUS_DESTROYER` | 3 | `AmphibiousDestroyer` |
| `MZONE_AMPHIBIOUS_CRUSHER` | 4 | `AmphibiousCrusher` |
| `MZONE_AMPHIBIOUS` | 5 | `Amphibious` |
| `MZONE_SUBTERANNEAN` | 6 | `Subterannean` (historical spelling preserved) |
| `MZONE_INFANTRY` | 7 | `Infantry` |
| `MZONE_INFANTRY_DESTROYER` | 8 | `InfantryDestroyer` |
| `MZONE_FLYER` | 9 | `Fly` |

Seven blockage ratings → accepting classes:

| Rating | Accepting classes |
|---|---|
| Open land | all ten |
| Crushable | Crusher, Destroyer, AmphibiousDestroyer, AmphibiousCrusher, Subterannean, InfantryDestroyer, Fly |
| Blocked | Destroyer, AmphibiousDestroyer, Subterannean, InfantryDestroyer, Fly |
| Water | Amphibious, AmphibiousCrusher, AmphibiousDestroyer, Fly |
| Partly blocked | Infantry, InfantryDestroyer, Fly |
| Impassable | Subterannean, Fly |
| Outside | none |

**Edge cases**
- The rating is decided **only** from the `Wheel` column (+ land type Water/Beach, wall
  overlay, terrain occupation): a land type pricing `Hover`/`Track` well but `Wheel=0` drops
  out of *every* class's zones at once.
- A `Wheel=` figure of `0.005` is enterable by the per-step test yet still keeps its land type
  out of every zone (zone threshold is `≤0.01`).
- `Normal`, `Amphibious`, `Infantry` all refuse crushable ground.
- Zone growth is directional and asymmetric: one direction ends a run at a 2-level difference,
  the other at 4, so the same boundary can fall inside or between zones.
- Bridges/tunnels are recorded as crossings and stitched afterwards.

**Kind** — generic-engine pathfinding model + title-data (enum).

**Sources**
- `code/mzone.hh` (OpenTS) (high)
- `enums/movement-zone.md`, `systems/movement-and-terrain.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/MovementZone (med)

**Confidence** — high.

---

### TS-CORE-013 — Per-Step Passability Test (order)

**What** — Whether a cell may be entered is a nine-stage test returning one of eight
verdicts; only "strictly prohibited" removes the cell from a route.

**Data keys** — `MovementRestrictedTo`, `AllowBurrowing`, `Crusher`, `Crushable`, `Landable`,
`IsTrain`, overlay `Wall`/`Wood`/`High`, `Immunity`/`Immune`.

**Numbers** — Test order:
1. `MovementRestrictedTo` mismatch → refuse.
2. Tunnel geometry: entering a tunnel cell >¼ turn off its facing, or leaving one on the same
   terms → refuse.
3. Height step: level→OK; ±1→ramp only; ±4→bridge span only; else refuse.
4. Map edge: outside playable area → refuse unless `Landable`.
5. Locomotor: 9/10 accept all; tunnel locomotor applies `AllowBurrowing`.
6. Overlay: wall refused unless `Crusher`+`Crushable`, or a wall-destroying warhead; crate
   refused to a computer vehicle in a campaign.
7. Occupancy: buildings, gates, allies, enemies, crushables, cloaked objects each contribute
   a verdict (many exemptions: boarding, repair bay, refinery bib, invisible/limpet, open gate,
   inactive firestorm wall). A terrain object is destroyable only with `Wood=yes` and not
   `Immune=yes`; otherwise strictly impassable.
8. Terrain figure: SpeedType column of destination land type; refused only if exactly `0`.
9. Reservations: a cell claimed by another object's next step is "moving through"; an enemy
   infantry reservation is destroyable to an armed vehicle, refused to an unarmed one.

Eight verdicts (most severe kept): clear, cloaked enemy, moving through, closed friendly gate,
friendly obstruction destroyable, enemy obstruction destroyable, friendly temp obstruction,
strictly prohibited.

**Edge cases**
- `IsTrain=yes` treats every obstruction short of strictly-prohibited as clear.
- Infantry: no `MovementRestrictedTo`, never asks the locomotor, can walk through a wall at its
  final damage stage, skip the terrain figure while tethered (boarding/capturing).
- Aircraft: speed type Winged answers the cell test before the table; only refusal is a
  shrouded cell in a campaign for a non-loaner player aircraft.
- Bridge deck: terrain figure skipped entirely on the deck.

**Kind** — generic-engine movement rule + title-data.

**Sources**
- `systems/movement-and-terrain.md` (OpenTS Manual) (high)
- `code/cell.cpp` (`Is_Clear_To_Move`) (OpenTS) (high)
- https://modenc.renegadeprojects.com/IsClearToMove (med)

**Confidence** — high (manual/source), med (original-engine equivalence).

---

### TS-CORE-014 — Damage Model (exact sequence)

**What** — Damage reaches an object in two stages: a **blast** gathers candidates in a
1.5-cell radius (plus an airborne sweep), then a **conversion** turns one raw figure into the
strength each candidate loses, per object. Forced damage skips most of the conversion.

**Data keys** — `Damage` (weapon), `Verses`/`Spread`/`ProneDamage`/`TypeImmune` (warhead),
`Armor` (type), `Immune`, `MaxDamage`, `MinDamage` (global).

**Numbers / pseudocode** — Per object, in order:
1. Prone soldier: multiply by warhead `ProneDamage`, floor 1 (infantry lying down).
2. Webby warhead: set to 0 for non-web-immune infantry, entangle instead.
3. Divide by house armor divisor (country × difficulty), then by object armor multiplier
   (1 until an armor crate).
4. `STRONGER` veteran: divide by `VeteranArmor + 1`.
5. Floor to 1 (steps 3–4 can't take a positive hit below 1).
6. `TypeImmune=yes` ends it (same type + same house).
7. `Immune=yes` or already-zero strength ends it.
8. Multiply by `Verses[armor]`, truncate. **A product that truncates to 0 becomes 1** (so
   `0%` is not immunity; it still costs `MinDamage` close in).
9. Divide by distance step count (see TS-CORE-018).
10. Inside 4 distance steps, floor to `MinDamage=1`.
11. Cap at `MaxDamage=1000` (once per object).
12. Apply, cut back to remaining strength.

**Edge cases**
- Forced damage (C4, engineer bite, EMP? no, EMP is separate) refuses steps 1 and 3–6,
  bypasses step 7, and skips 8–11 entirely: it lands at exactly the written figure.
- A blast with no warhead, or a scenario with `Inert=yes`, zeroes the figure at step 8.
- Negative damage (healing) skips nearly all of the above (see TS-CORE-020).

**Kind** — generic-engine combat.

**Sources**
- `systems/warheads.md` (OpenTS Manual) (high)
- `code/combat.cpp` `Modify_Damage` (OpenTS) (high)
- https://modenc.renegadeprojects.com/Verses (high)

**Confidence** — high.

---

### TS-CORE-015 — Armor Classes (full list)

**What** — Five armor classes, engine-fixed. A warhead's `Verses` list is a five-element
percentage list matched in this order.

**Data keys** — `Armor=` on Building/Unit/Infantry/Aircraft types; `Verses=` on warheads.

**Numbers**

| Constant | Value | Token | Typical use |
|---|---:|---|---|
| `ARMOR_NONE` | 0 | `none` | standard infantry |
| `ARMOR_WOOD` | 1 | `wood` | light structure armor |
| `ARMOR_ALUMINUM` | 2 | `light` | light vehicles |
| `ARMOR_STEEL` | 3 | `heavy` | heavy vehicles |
| `ARMOR_CONCRETE` | 4 | `concrete` | buildings |

**Edge cases**
- An unrecognized armor name resolves to `none` silently (no error).
- TS has 5 classes only. RA2/YR extends to 11 (`none, flak, plate, light, medium, heavy,
  wood, steel, concrete, special_1, special_2`) — **do not reuse RA2 Verses lists in TS**.
- `IsOrganic` on a warhead is derived as `Modifier[ARMOR_STEEL] == 0`.

**Kind** — generic-engine enumeration + title-data.

**Sources**
- `code/armor.hh`, `code/const.cpp` (`ArmorName`) (OpenTS) (high)
- `enums/armor.md`, `systems/warheads.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Armor_types (high)

**Confidence** — high.

---

### TS-CORE-016 — Verses Semantics and Special States

**What** — `Verses` maps damage percentages to armor. In TS, one special targeting value
applies; RA2's richer 0%/1% semantics do **not** apply to TS.

**Data keys** — `Verses=`, `Secondary=` (for the 0% heavy-armor override), `ProneDamage`.

**Numbers**
- Order for TS: `none, wood, light, heavy, concrete`.
- In RA/TS: **`heavy=0%` on an InfantryType's weapon** means that infantry will not passively
  acquire nor retaliate against any vehicle/aircraft/building target — unless the `Secondary`
  weapon can target that armor type.
- The rules.ini comments describing 2% values are inaccurate to the engine.

**Edge cases**
- `Verses=100%,100%,100%,100%,100%` is the default when the key is absent.
- A hit that truncates to 0 still deals 1 (`MinDamage`) at close range; only `Immune=yes`
  refuses outright.
- Negative `Verses` reverses damage into healing.
- Ares note: from Ares 0.1 the target-selection effect still applies even though damage uses
  the original value; from 0.2 it no longer affects target selection either. This is an
  Ares-mod behavior, not vanilla TS.

**Kind** — generic-engine combat + title-data.

**Sources**
- `systems/warheads.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Verses (high)
- https://modenc.renegadeprojects.com/Armor_types (high)

**Confidence** — high (TS order and heavy=0% rule); med (exact passive-acquire nuance).

---

### TS-CORE-017 — MinDamage / MaxDamage / 0% gating

**What** — Global clamps applied after adjustment.

**Data keys** — `[CombatDamage] MinDamage`, `[CombatDamage] MaxDamage`.

**Numbers**
- `MinDamage=1` (floor inside 4 distance steps).
- `MaxDamage=1000` (per-object ceiling, once per object not per blast).

**Edge cases**
- Because the multiply-to-zero becomes 1, `MinDamage` is the effective floor for any `0%`
  verses hit that lands close.
- Raising `MinDamage` raises the low-power structure damage tick for every structure at once.
- `MaxDamage` does not apply to forced damage.

**Kind** — generic-engine.

**Sources**
- TS `RULES.INI` `[CombatDamage]` (high)
- `systems/warheads.md`, `systems/power.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-018 — Spread and Distance Falloff

**What** — Damage thins with distance. The distance is measured with three adjustments, then
divided by 3×`Spread`, clamped 0–16, and the damage divided by that step count. Falloff is
thus a set of thresholds, not a smooth curve.

**Data keys** — `Spread` (warhead; note: for `EMEffect` warheads `Spread` is the pulse
*radius* in cells, not falloff).

**Numbers**
- Steps = `clamp(leptonDistance / (Spread · 3), 0, 16)`; damage = `damage / steps` (0 steps = no
  divide).
- Distance adjustments: height difference < 1 level (104 leptons) discarded; aircraft measured
  at **half** true distance; a structure in the blast's own cell measured at 0 (direct hit),
  but only while no other object is in front of it in the cell occupant list.
- Thresholds (in leptons, scaling with `Spread`): full damage out to `6·Spread − 1`; halved
  from `6·Spread`; sixteenth from `48·Spread`; `MinDamage` floor inside `12·Spread`.
- At stock `Spread=1` (e.g. `RailShot`, `HollowPoint`) halving is 6 leptons out — anything but
  a direct hit is thinned hard.
- `Spread=0` takes a **separate branch** dividing distance by `PIXEL_LEPTON_W/4` instead of
  `Spread·PIXEL_LEPTON_W/3`, so it thins *faster* than `Spread=1`.
- A **negative** `Spread` clamps the step count to 0 and disables thinning entirely (full
  armor-scaled damage with `MinDamage` floor).
- Blast candidate gathering never spills more than one cell (1.5-cell reach) regardless of
  `Spread`.

**Edge cases**
- The airborne sweep (aircraft, `JumpJet=yes` infantry, `Jellyfish=yes` vehicles) runs only
  when the blast stands above the ground at its own cell centre, and is limited to within one
  cell in 3D; a wide-area (ExpSpread) blast never opens it.
- An `EMEffect=yes` warhead spends `Spread` as the stun radius, and cannot be tuned apart from
  its falloff.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/warheads.md`, `systems/emp-pulse.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[CombatDamage]` (high)

**Confidence** — high (thresholds/formula in reconstructed source); med (exact vanilla
rounding of some `Spread` values).

---

### TS-CORE-019 — Prone Damage

**What** — An infantryman lying down takes a warhead-specific fraction of incoming damage.

**Data keys** — `ProneDamage` per warhead (overrides the global `[CombatDamage] ProneDamage`,
which is commented out in TS).

**Numbers** — Stock values:
- `SA` 70%, `HE` 70%, `AP` 50%, `ARTYHE` 150%, `SonicWarhead` 50%, `Gas` 300%,
  `Fire`/`Fire2` 600%, `IonWH` 75%, `ORCAAP` 50%, `ORCAHE` 150%, `PlasmaWH` 350%,
  `HollowPoint` 100%, `RailShot`/`RailShot2` 100%, `SAMWH` 100%, `Super` 60%,
  `TankOGas` 50%, `MultiSpecial`-era defaults vary.
- Floor of 1 always applies (prone never reduces a positive hit to 0).
- In MP skirmish the `ARTYHE` warhead is hard-rewritten: `ProneDamage=.3`, `none=.4`,
  `wood=.85`, `light=.68`, `heavy=.35`, `concrete=.35`.

**Edge cases**
- `ProneDamage` is a warhead multiplier, so raising it raises a prone unit's vulnerability.
- Forced damage ignores it.

**Kind** — generic-engine + title-data.

**Sources**
- TS `RULES.INI` `[Warheads]` blocks (high)
- `code/warhead.cpp` (OpenTS) — `ProneDamage`, MP `ARTYHE` rewrite (high)

**Confidence** — high.

---

### TS-CORE-020 — Healing (negative damage) and Limpet Clearing

**What** — A weapon with negative `Damage` heals. It takes a different route: all normal
reductions are skipped; the whole figure is added, clamped to max strength.

**Data keys** — `Damage` (negative) on a weapon; `Mechanic`, `OmniHealer` for which kind of
target; `LimpetFactor` on warheads.

**Numbers**
- Heal lands only if target within **8 leptons** (1/32 cell) and target is not `Immune=yes`
  and has strength left.
- Out-of-range targets are not healed, but the blast still strips limpet marks from every
  object it reached (ahead of the immunity check).
- A healing hit is reported as no damage: it springs no trigger and does not cause retaliation.

**Edge cases**
- The 8-lepton test is extremely tight; healing is effectively single-target.
- A medic mends infantry, a mechanic mends vehicles; `Mechanic=yes` swaps the kind,
  `OmniHealer=yes` grants both.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/warheads.md` (healing), `systems/repair.md` (OpenTS Manual) (high)
- `code/combat.cpp` `Modify_Damage` negative branch (OpenTS) (high)

**Confidence** — high.

---

### TS-CORE-021 — Full Warhead List and Verses Values (TS + FS)

**What** — Every warhead type registered in `[Warheads]` plus auxiliary warheads defined
inline. `Verses` order is `none, wood, light, heavy, concrete`.

**Data keys** — `[Warheads]` registry; per-warhead `Spread`, `Verses`, `ProneDamage`, `Wood`,
`Wall`, `Tiberium`, `Sparky`, `Rocker`, `Bright`, `Fire`, `Conventional`, `Deform`,
`DeformThreshhold`, `InfDeath`, `AnimList`, `Particle`, `EMEffect`, `Veinhole`, `Webby`,
`WebDuration`, `WebDurationVariation`, `WebRadius`, `LimpetFactor`.

**Numbers** — TS `[Warheads]` registration order and values:

| # | Warhead | Spread | Verses (n,w,l,h,c) | Prone | Notable flags |
|---|---|---:|---|---:|---|
| 1 | `EMPuls` | 11 | (no Verses; `EMEffect=yes`) | — | pulse radius 11; `AnimList=PULSEFX1,PULSEFX2` |
| 2 | `SonicWarhead` | 2 | 100,100,100,80,60 | 50% | `Wood`, `Rocker`, `InfDeath=3` |
| 3 | `TankOGas` | 8 | 90,100,60,25,10 | 50% | `Wall`,`Wood`,`Tiberium`,`Sparky`,`Fire`,`InfDeath=4` |
| 4 | `SA` | 3 | 100,60,40,25,10 | 70% | `Bright`,`InfDeath=1` |
| 5 | `HE` | 4 | 100,85,70,35,28 | 70% | `Wall`,`Wood`,`Conventional`,`Tiberium`,`Sparky`,`Bright`,`Deform=10%`,`DeformThreshhold=300`,`InfDeath=2` |
| 6 | `AP` | 3 | 25,65,75,100,60 | 50% | `Wall`,`Wood`,`Conventional`,`InfDeath=3` |
| 7 | `Gas` | 512 | 200,150,100,20,0 | 300% | `Particle=GasCloudSys`,`InfDeath=1` |
| 8 | `Fire` | 8 | 600,148,59,6,2 | 600% | `Wood`,`Sparky`,`Fire`,`InfDeath=4` |
| 9 | `HollowPoint` | 1 | 100,5,5,5,5 | 100% | `InfDeath=1` |
| 10 | `Super` | 0 | 100,100,100,100,100 | 60% | `Tiberium`,`Sparky`,`InfDeath=5` |
| 11 | `Organic` | 0 | 100,0,0,0,0 | — | only affects infantry |
| 12 | `Slimer` | 0 | 100,100,60,40,20 | — | `InfDeath=0` |
| 13 | `FirestormWH` | 0 | 100,100,100,100,100 | — | `InfDeath=4` |
| 14 | `IonCannonWH` | 40 | 100,100,100,100,100 | — | `Wood`,`Wall`,`Fire`,`Deform=100%`,`Sparky`,`InfDeath=5` |
| 15 | `RailShot` | 1 | 200,175,160,100,25 | 100% | `InfDeath=2` |
| 16 | `Mechanical` | 0 | 0,100,100,100,100 | — | only affects mechanical |
| 17 | `VeinholeWH` | 1 | 100,100,100,100,100 | — | `Veinhole=yes` |
| 18 | `IonWH` | 6 | 90,75,60,25,100 | 75% | ion-storm strike; `Wall`,`Wood`,`Conventional`,`Rocker`,`Tiberium`,`Sparky`,`Bright`,`Deform=10%`,`InfDeath=5` |
| 19 | `ARTYHE` | 6 | 100,85,68,35,35 | 150% | `Wall`,`Wood`,`Conventional`,`Rocker`,`Tiberium`,`Bright`,`Deform=15%`,`DeformThreshhold=120` |
| 20 | `PlasmaWH` | 0 | 350,260,205,150,80 | 350% | `Wall`,`Bright`,`Tiberium`,`Sparky`,`InfDeath=5` |
| 21 | `SAMWH` | 3 | 100,100,100,100,100 | 100% | `InfDeath=3` |
| 22 | `ORCAAP` | 2 | 30,65,150,100,30 | 50% | `Wall`,`Wood`,`Conventional`,`InfDeath=3` |
| 23 | `RailShot2` | 1 | 100,130,150,110,5 | 100% | Ghost's railgun; `InfDeath=2` |
| 24 | `ORCAHE` | 512 | 200,90,75,32,100 | 150% | orca bomber; `Wall`,`Sparky`,`Wood`,`Bright`,`Fire`,`Conventional`,`Rocker`,`Tiberium`,`Deform=8%`,`DeformThreshhold=160` |
| — | `RPG` | 3 | 30,75,90,100,70 | 100% | `Wall`,`Wood`,`Rocker`,`Conventional`,`InfDeath=3` |
| — | `Fire2` | 8 | 600,148,59,6,2 | 600% | same as Fire but `Sparky=no` |
| — | `Shard` | 0 | 100,100,60,40,20 | — | `InfDeath=1` |
| FS | `WebMass` | 4 | 600,0,0,0,0 | 100% | `Webby=true`, `WebDuration=600`, `WebDurationVariation=25`, `WebRadius=2`, `Particle=WebSys` |
| FS | `LIMPY` | 0 | 0,100,100,100,100 | — | `LimpetFactor=35` |
| FS | `CoreDefPlasmaWH` | — | (FS addition, not enumerated here) | — | — |

Additional engine-recognized warhead names (`Nuke`, `NukeDown`, `Super2`, `Meteorite`,
`Stinger`, `MobileEMPulse`, `Cobra`-era) exist in the reconstructed enum for FS/engine paths
but are not all present in the shipped FS `[Warheads]` list.

**Edge cases**
- `EMPuls` defines `Spread=11` as the *radius*, and its `EMEffect=yes` means the pulse branch
  replaces blast damage entirely.
- FS's `WebMass` inflicts `0%` vs every non-infantry class and webs infantry.
- Warheads not registered in `[Warheads]` but defined inline (e.g. `RPG`, `Fire2`, `Shard`) are
  still usable because a `Warhead=` name is created on first use.
- `Meteorite`, `Nuke`, `Stinger`, `Super2`, `MobileEMPulse` are declared in the engine enum
  for later content; treat as FS/engine extras.

**Kind** — title-data (all values) on a generic warhead system.

**Sources**
- TS `RULES.INI` lines 1412–1441 (`[Warheads]`) and 8413–8671 (definitions) (high)
- TS `FIRESTRM.INI` `[Warheads]` + `WebMass`/`LIMPY` (high)
- `code/warhead.hh` (OpenTS) — full enum (high)
- https://modenc.renegadeprojects.com/Verses (high)

**Confidence** — high (values); med (`CoreDefPlasmaWH` details not captured).

---

### TS-CORE-022 — Full Projectile (BulletType) List and Parameters

**What** — A `BulletType` section describes one kind of shot. There is **no registry**; a
weapon's `Projectile=` name is created on first use, so a misspelling silently produces a
projectile with no settings. Two flight models: steered (`ROT>0`) and ballistic (`ROT=0`).

**Data keys** — `ROT`, `Acceleration`, `Elasticity` (default .75), `Arm`, `Color`,
`Arcing`, `Floater`, `High`, `VeryHigh`, `Shadow` (default yes), `Dropping`, `Inviso`,
`Proximity`, `Ranged`, `Inaccurate`, `AA`, `AG`, `AV`, `Degenerates`, `Bouncy`, `Airburst`,
`AirburstWeapon`, `Cluster` (default 1), `Splits`, `RetargetAccuracy`, `Image`, `Trailer`,
`AnimLow`, `AnimHigh`, `AnimRate`, `AnimPalette`.

**Numbers** — Engine defaults: `Elasticity=.75`, `Acceleration=3`, `Cluster=1`, `ROT=0`,
`Arm=0`, `RetargetAccuracy=0`, `IsShadow=true`, `IsAntiGround=true`, all other bools false.
Shipped TS projectile sections (overrides only; base values are engine defaults):

| Type | Key settings |
|---|---|
| `Invisible` | `Inviso=yes`, `Image=none` |
| `Invisible2` | `Inviso`, `ROT=3`, `AA=yes`, `AG=yes` (Harpy Claw) |
| `Invisible3` | `Inviso`, `AA=yes`, `AG=yes` (jumpjet cannon) |
| `Null` | `Inviso`, `Arm=9999999`, `Image=none` |
| `Cannon` | `Image=120MM`, `Arcing=true` |
| `Cannon2` | `Image=120MM`, `AA=no` (orca bomblets) |
| `ChemMissile` | `Arm=2`, `High`, `VeryHigh`, `Cluster=8`, `Proximity`, `Ranged`, `AA=no`, `Image=MISLCHEM`, `ROT=4`, `Color=DarkGreen`, `IgnoresFirestorm=yes` |
| `MultiMissile` | `Arm=2`, `High`, `VeryHigh`, `Proximity`, `Cluster=10`, `Ranged`, `AA=no`, `Image=MISLMLTI`, `ROT=4`, `Color=DarkGreen`, `Airburst=yes`, `AirburstWeapon=MultiCluster` |
| `HeatSeeker` | `Arm=2`, `High`, `Shadow=no`, `Proximity`, `Ranged`, `Image=DRAGON`, `ROT=8` |
| `ProtonTorpedo` | `Arm=2`, `High`, `Shadow=no`, `Proximity`, `Ranged`, `Image=TORPEDO`, `ROT=1`, `IgnoresFirestorm=yes` |
| `ProtonBlast` | same minus `Arm` |
| `AAHeatSeeker` | `Arm=2`, `High`, `Shadow=no`, `Proximity`, `Ranged`, `AA=yes`, `AG=no`, `Image=DRAGON`, `ROT=5` |
| `AAHeatSeeker2` | same with `AG=yes`, `ROT=8` |
| `Lobbed` | `High`, `Image=DISCUS`, `Bouncy=yes`, `Arcing=yes`, `Floater=yes` |
| `Lobbed2` | `High`, `Image=CANISTER`, `Arcing=true` |
| `Ballistic` | `High`, `Image=120MM`, `Arcing=true` |
| `PulsPr` | `High`, `Image=PULSBALL` (EMP projectile) |
| `LLine` / `LLine2` | `Inviso`, `AA=no`, `AG=yes` (laser lines) |
| `DogShard` | `Image=CRYSTAL4`, `Arcing=true` |

Weapon `Projectile=` references found in TS rules include: `Invisible`, `Invisible2`,
`Invisible3`, `ProtonBlast`, `Lobbed2`, `HeatSeeker`, `AAHeatSeeker`, `AAHeatSeeker2`,
`ProtonTorpedo`, `Lobbed`, `Cannon`, `Cannon2`, `Ballistic`, `Null`, `LLine`, `LLine2`,
`PulsPr`, `ChemMissile`, `DogShard`, `MultiMissile`.

**Edge cases**
- A projectile is not a cell occupant: nothing collides with it and cell scans don't find it;
  it is submitted to the air layer at any height.
- An aircraft overwrites launch velocity: `ROT=0` → level pitch + aircraft's turret heading +
  travel speed (discards the arc); `ROT=1` → aimed straight at target at full weapon speed;
  `ROT≥2` → launch stands.
- A projectile that omits `Image=` has its image name cleared and every art lookup skipped;
  a **voxel** projectile that omits `Image=` has no model and crashes when first drawn.
- `Airburst=yes` sets `Splits` as default (`IsSplits = ini.Get_Bool("Splits", IsAirburst)`).

**Kind** — generic projectile engine + title-data (the shipped sections).

**Sources**
- TS `RULES.INI` lines 7870–8030 (projectile sections) (high)
- `code/bullettype.cpp` (OpenTS) — defaults and key parsing (high)
- `systems/projectile-flight.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Projectile (med)

**Confidence** — high (defaults/sections); med (original-engine defaults vs reconstructed).

---

### TS-CORE-023 — Projectile Flight, Detonation, and Impact

**What** — Steered projectiles turn toward the target each frame and follow terrain; ballistic
projectiles arc under gravity and bounce. Every route to a detonation, and where the blast
lands, is fixed.

**Data keys** — `Gravity` (`[AudioVisual]`, default 6), `BallisticScatter` (default 1.0),
`HomingScatter` (default 2.0), `MissileSpeedVar=.25`, `MissileROTVar=.25`, `ProjectileRange`,
`Speed`, plus projectile keys above.

**Numbers**
- Per-frame order: dropping→mark; anim step; trailer every 3rd frame; flight step; Ranged
  fuel; position; firestorm-wall consume; tall-overlay/ground/AA tests; fuse; degenerate/
  detonate.
- Steered: speed moves toward weapon speed by `Acceleration`/frame (coasts back at half if
  too fast); launch phase gains 1 lepton every other frame and does not turn; `MissileROTVar`
  scales turn on a 15-frame cycle; turn increased ½ over the last cell. Terrain-follow samples
  ground 6 frames ahead and nudges height 18 leptons at a time.
- Ballistic: vertical speed loses `Gravity` each frame (halved for `Floater=yes`); lands when
  at/under ground, through a bridge deck, or into an obstacle within 150 leptons above ground;
  rebound uses `Elasticity`; `Bouncy` decides carry-on; max 3 bounces; detonates within 128
  leptons of a non-allied/non-firer object; leaves playfield = removed without blast.
- Ballistic aim point displaced by `BallisticScatter` (max cells) when `Inaccurate=yes` and
  `Arcing=yes`; homing by `HomingScatter`.
- Impact nudge: within 32 leptons of target centre → move onto it (suppressed by `Airburst`
  and `Inaccurate`); then within 128 leptons of an airborne target → target aim point;
  otherwise within 42 leptons of any target → that target's coordinate.

**Edge cases**
- A homing shot whose target is removed (destroyed, boarded, cloaked) detonates at world
  coordinate `0,0,0` — the corner of the cell array — harming nothing near the flight path.
- Launch speed is held to **half the distance to the aim point**, so very close shots leave
  slower; unguided projectile speed is derived from weapon `Range`.
- A projectile crossing a bridge deck plane ends at deck height.
- `Ranged=yes` spends the weapon's `ProjectileRange` as fuel.
- `Dropping=yes` detonates one frame's travel from the muzzle.
- A projectile within 128 leptons of an AA target detonates on it.

**Kind** — generic projectile engine + title-data (gravity/scatter).

**Sources**
- `systems/projectile-flight.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[AudioVisual] Gravity` / `[CombatDamage] BallisticScatter/HomingScatter` (high)
- `code/bullet.cpp` (OpenTS) (high)

**Confidence** — high.

---

### TS-CORE-024 — Cluster, Splits, Airburst, Shrapnel

**What** — Two different "multiple blast" mechanics plus bomblet and shrapnel variants.

**Data keys** — `Cluster` (>=1, default 1), `Splits`, `Airburst`, `AirburstWeapon`,
`ShrapnelWeapon`, `ShrapnelCount`, `RetargetAccuracy`.

**Numbers**
- `Splits=no` (default): `Cluster=n` repeats the whole detonation *n* times; the first on the
  point of impact, each later one thrown 1–2 cells from the original point (not walking away).
- `Splits=yes` (or `Airburst=yes` default): detonates once, then releases `Cluster` bomblets of
  `AirburstWeapon` at the carrier's own position (not the adjusted impact).
- Split ordering: carrier blast → its animation/flash → gather candidates within 5 cells →
  create bomblets. `RetargetAccuracy` governs the bomblet draw against survivors.
- `ShrapnelCount`/`ShrapnelWeapon` exist as projectile keys for shrapnel.
- `ChemMissile` uses `Cluster=8`; `MultiMissile` uses `Cluster=10` + `Airburst=yes` with
  `AirburstWeapon=MultiCluster`.

**Edge cases**
- A wide-area blast (`ExpSpread`) is a separate routine (used by `Explodes=yes` deaths and a
  loaded harvester under `TiberiumExplosive=yes`), never by a normal shot impact.
- A `Splits` projectile's carrier blast destroys objects before bomblets are created, so
  bomblets cannot target what the carrier killed.

**Kind** — generic projectile + title-data.

**Sources**
- `systems/projectile-flight.md` (OpenTS Manual) (high)
- TS `RULES.INI` `ChemMissile`/`MultiMissile` (high)
- `code/bullettype.cpp` (OpenTS) (high)

**Confidence** — high.

---

### TS-CORE-025 — Firing Geometry, FLH, Burst, and Reload

**What** — One routine resolves a shot: projectile, beam/wave, muzzle flash, report, recoil,
round, reload delay. Three weapon slots exist; the elite slot substitutes for the primary.

**Data keys** — `Primary`, `Secondary`, `Elite`, `PrimaryFireFLH`, `SecondaryFireFLH`,
`PrimaryFirePixelOffset`, `PBarrelLength`, `PBarrelThickness`, `Burst`, `BurstDelay0..3`,
`ROF`, `Anim`, `Report`, `IsLaser`, `IsSonic`, `IsRailgun`, `IsBigLaser`, `LaserDuration`,
`LaserInnerColor`, `LaserOuterColor`, `LaserOuterSpread`, `Charges`, `FiringSyncFrame1/2`,
`TurretOffset`, `UseFireParticles`, `UseSparkParticles`.

**Numbers**
- Fire sequence: fetch slot → limpet divert → effect-hold refusal → barrel elevation → damage
  computation → create+launch → recoil → two free flight turns if barrel length > 0 → spawn
  effects → burst counter/reload set → report → firing anim → sonic wave → laser → spend ammo
  + reveal.
- Damage = weapon `Damage` × house firepower × object firepower × veteran bonus; zeroed for
  `IsSonic=yes` and `UseFireParticles=yes`.
- Reload delay (first match wins): structure with >1 round → 1 frame; no weapon → 1;
  `IsSonic` or effect-hold occupied → exactly `ROF`; burst unfinished → matching `BurstDelay`
  (or random 3–5 if `-1`/past 4th); else `ROF` × house ROF bias + random 0–2, shortened by
  veteran ROF.
- `Burst` counter negates the lateral FLH component on odd shots (alternating muzzles). Beam
  and shell can leave opposite muzzles on a `Burst=2` weapon.

**Edge cases**
- Effects that lock the weapon: fire stream, spark spray, railgun trace, sonic wave.
- `FiringSyncFrame1/2` ties the first/second burst round to the firing animation for vehicles
  (first slot only).
- A structure's `PrimaryFirePixelOffset` (≠ `65535,65535`) replaces both mounting and muzzle
  with a screen offset projected onto the ground.
- An elite building's plug weapon outranks the elite weapon substitution.

**Kind** — generic weapon engine + title-data.

**Sources**
- `systems/firing-geometry.md` (OpenTS Manual) (high)
- TS `RULES.INI` weapon blocks (high)

**Confidence** — high.

---

### TS-CORE-026 — ROT / Turret Traverse

**What** — `ROT` is rate of turn (facing units per some interval). Mechs and turretless drive
vehicles must finish turning before moving; turreted vehicles keep moving. Hover doubles and
steers separately from drawn facing. Infantry use a fixed max rate until first healed.

**Data keys** — `ROT` (type-level, and `[JumpjetControls] TurnRate` for jumpjets).

**Numbers**
- Infantry are created with a fixed maximum ROT rather than the type figure, picking up the
  written figure the first time they are healed.
- A hovercraft is given **2×** its written ROT and slews.
- Damage/servicing resets turret and body ROT to the type's `ROT` (depot, heal weapon).
- `MissileROTVar=.25` fluctuates projectile ROT.

**Edge cases**
- A turretless drive vehicle or mech stops to turn; a turreted one does not.
- A `DeployToFire` vehicle may only fire from a buildable cell.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/movement-and-terrain.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/ROT (high)

**Confidence** — high.

---

### TS-CORE-027 — Flight, Altitude, and FlightLevel

**What** — Aircraft travel at a cruise altitude. `FlightLevel` (global, default 600) is the
typical height; a type may override. Height affects sight/fire distance and AA.

**Data keys** — `FlightLevel` (global and per-aircraft), `PitchAngle`, `PitchSpeed`,
`RollAngle`, `SlowdownDistance`, `IsDropship`, `LeptonsPerFireIncrease`,
`LeptonsPerSightIncrease`, `AttackingAircraftSightRange`.

**Numbers**
- `[General] FlightLevel=600` (above ground). Bridge height is ~300–500, so flight clears it.
- `LeptonsPerSightIncrease=2000`: each whole multiple of 2000 leptons of elevation adds 10%
  to sight. One height level = 104 leptons, so ~2 increments per level (default 50→actually
  the manual cites engine default 50; TS rules sets 2000). **Conflict:** TS `[General]` sets
  `LeptonsPerSightIncrease=2000`, the OpenTS manual text describes a default of 50 — the
  shipped value is authoritative.
- `LeptonsPerFireIncrease=2000`: same for firing range.
- `AttackingAircraftSightRange=6`.
- Height bonus capped at 10 cells of sight (ring-table limit).
- An unguided shot leaves level unless the aim point is >200 leptons above/below the mounting,
  in which case it is pitched (minus 20 leptons) — except arcing/voxel shots.

**Edge cases**
- A structure `Height=` (200-lepton steps) substitutes the aim point for non-arcing shots at
  tall structures.
- Jumpjet fly-level is computed from occupancy cell `Height`.
- An aircraft in flight is entered in **no cell's** occupant list, so only the airborne
  blast sweep can reach it.

**Kind** — generic-engine flight + title-data.

**Sources**
- TS `RULES.INI` `[General]` (high)
- `systems/movement-and-terrain.md`, `systems/warheads.md`, `systems/map-visibility.md`
  (OpenTS Manual) (high)

**Confidence** — high; note the LeptonsPerSightIncrease conflict above.

---

### TS-CORE-028 — [JumpjetControls] Full Block

**What** — Jumpjet infantry and jumpjet vehicles read all their flight figures from one shared
`[JumpjetControls]` section, not from the type's `Speed`.

**Data keys** — `TurnRate`, `Speed`, `Climb`, `CruiseHeight`, `Acceleration`,
`WobblesPerSecond`, `WobbleDeviation`, `CloakDetectionRadius`.

**Numbers** — TS `RULES.INI`:
- `TurnRate=4`
- `Speed=14`
- `Climb=5`
- `CruiseHeight=500` (must be higher than a bridge)
- `Acceleration=2`
- `WobblesPerSecond=.15` (was .25)
- `WobbleDeviation=40`
- `CloakDetectionRadius` — parsed by the engine; TS default **0** (per OpenTS Manual; raises
  to sweep a (2r+1)² block). Not present in the shipped `[JumpjetControls]` block.

**Edge cases**
- A unit's own `Speed=` is **not read** by the jumpjet locomotor.
- `CloakDetectionRadius` is the square's half-width, so `2` sweeps 5×5.
- Raising `CruiseHeight` too high can put a target out of jumpjet weapon range.
- Under an ion storm a moving airborne jumpjet is destroyed and a grounded one cannot take
  off; the movement zone is demoted to infantry for routing.

**Kind** — generic-engine + title-data (numbers).

**Sources**
- TS `RULES.INI` lines 279–286 (high)
- `code/rules.cpp` `Jumpjet_Controls` (OpenTS) (high)
- `systems/movement-and-terrain.md`, `systems/cloaking.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-029 — [LEVITATION] Block (Firestorm)

**What** — The Firestorm jellyfish locomotor reads its movement figures from a shared
`[LEVITATION]` block, not from the type.

**Data keys** — `Drag`, `MaxVelocityWhenHappy`, `MaxVelocityWhenFollowing`,
`MaxVelocityWhenPissedOff`, `AccelerationProbability`, `AccelerationDuration`, `Acceleration`,
`InitialBoost`, `BounceVelocity` (commented), `CollisionWaitDuration` (commented),
`MaxBlockCount`, `PropulsionSoundEffect`, `IntentionalDeacceleration`,
`IntentionalDriftVelocity`.

**Numbers** — FS `FIRESTRM.INI`:
- `Drag=0.1`
- `MaxVelocityWhenHappy=5.0`
- `MaxVelocityWhenFollowing=4.5`
- `MaxVelocityWhenPissedOff=10.0`
- `AccelerationProbability=0.01`
- `AccelerationDuration=20`
- `Acceleration=0.75`
- `InitialBoost=2.0`
- `MaxBlockCount=3`
- `PropulsionSoundEffect=FLOATMOV,FLOTMOV2,FLOTMOV3,FLOTMOV4`
- `IntentionalDeacceleration=1.0`
- `IntentionalDriftVelocity=12.0`

**Edge cases**
- Levitate locomotor reads only this block, not the type's `Speed`; `HoverBob`/`HoverDampen`
  are shared with hover.
- Only present with Firestorm.

**Kind** — generic-engine + title-data (FS numbers).

**Sources**
- FS `FIRESTRM.INI` lines 35–50 (high)
- `systems/movement-and-terrain.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-030 — Power: Supply, Demand, Fraction

**What** — Each house tallies structure power output against drain. Output = type `Power=`
plus plug values, scaled by strength fraction and truncated; drain = same sum, never scaled by
damage. The **power fraction** is `1` when output ≥ drain, else `output/drain`, and `0` when
output is 0. Never above 1.

**Data keys** — `Power=` (building), `PowersUpBuilding=`/`Upgrades` (plugs), `Powered=`,
`TogglePower=`, `FreeRadar=`, `Radar=`, `DamageDelay`, `ConditionYellow`.

**Numbers**
- Tally rebuilt from zero on a stale flag (strength change, open, off-map, change hands, plug
  installed/sold, switched on/off, discovered).
- Damage costs output from the first point: a 100-output plant at 999/1000 strength supplies
  99, at 1 strength supplies 0. Drain never falls with damage.
- Only the on/off switch removes a structure from either side; an EM pulse never touches the
  switch, so a stunned plant keeps feeding and a stunned consumer keeps drawing.
- A structure counts from the moment it is placed (even during buildup).

**Edge cases**
- A campaign house under player control skips undiscovered own structures in the tally.
- Surplus buys nothing (fraction capped at 1).
- The sidebar power bar measures type-level output/drain of every owned structure and can look
  healthy while the real tally is short; only the band split uses the real tally.

**Kind** — generic-engine economy.

**Sources**
- `systems/power.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (high)

**Confidence** — high.

---

### TS-CORE-031 — Power: Low-Power Coefficients, DamageDelay, Production, and Gating

**What** — Low power slows production, damages structures on a timer, disables radar, silences
defenses and suspends superweapons.

**Data keys** — `DamageDelay`, `ConditionYellow`, `MinProductionSpeed`, `MultipleFactory`,
`WallBuildSpeedCoefficient`, `WorstLowPowerBuildRateCoefficient`,
`BestLowPowerBuildRateCoefficient`.

**Numbers**
- **Production ladder** (engine-fixed): fraction 1 → multiplier 1; 0.75–<1 → 0.75; 0.5–<0.75 →
  the fraction; <0.5 → 0.5. Multiplier raised to `MinProductionSpeed=0.5` if below. Build time
  divided by multiplier. Delay between steps is a whole number of frames 1–255.
- **Damage tick**: house timer reloaded with `DamageDelay=1` minute (`=900` frames). On expiry
  with fraction <1, every own structure strictly above `ConditionYellow=50%` whose *type* has
  drain takes 1 point through `C4Warhead`. Timer reloads whether or not short.
- **Radar**: available while no ion storm, output ≥ drain (raw), and either `FreeRadar=yes` or
  an owned `Radar=yes` structure switched on/out of limbo/not deconstructing. Scan stops at the
  first eligible structure; if that one is stunned, radar stays dark.
- **Superweapons**: disabled outright whenever output < drain; suspended if `IsPowered=yes`.
  `UseChargeDrain=yes` weapons reset to a full `RechargeTime` on resume (losing accumulated
  charge).
- **Defenses**: three disagreeing tests — operational (off/stunned/zero strength/Powered+drain+
  TogglePower+low power); weapon busy (`Powered=yes`+drain+low power, omits TogglePower);
  SAM tracking stalled under the same test.
- **Announcement**: `SpeakDelay=2` minutes between EVA repeats; `MessageDelay=.6` minutes text.

**Edge cases**
- `WorstLowPowerBuildRateCoefficient` and `BestLowPowerBuildRateCoefficient` are **parsed and
  never consulted**; the hard-coded gentler step is 0.75.
- A `TogglePower=no` defense is silenced but stays lit.
- A sensor array doesn't go dark with the rest; it only loses refreshes.
- Cloak generator field collapses one ring/frame; a `Powered=no` generator is exempt.
- Laser fences re-evaluate on every balance change; run energizes only if both end posts are
  operational.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/power.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]`, `[CombatDamage]`, `[AudioVisual]` (high)

**Confidence** — high.

---

### TS-CORE-032 — Veterancy: Levels, Ratio, and Promotion Paths

**What** — Each instance carries one experience figure; rank is read off it. Ranks: below
rookie (<0), rookie (0–<1), veteran (1–<2), elite (≥2). Thresholds 1 and 2 are engine-fixed.

**Data keys** — `VeteranRatio`, `VeteranCap`, `InitialVeteran`, `Trainable`, `Points`,
`Cost`, `VeteranLevel` (TeamType), `Armory=yes`, `VeteranAbilities`, `EliteAbilities`, `Elite`.

**Numbers**
- Experience credited on a kill: `victim cost / (killer cost × VeteranRatio)`. Reaching veteran
  = destroying `VeteranRatio`× the killer's own cost; elite = 2× that.
- The figure taken from each type is `Cost`, not `Points`.
- Kill clamps the total to `VeteranCap` **after** adding. Engine default with no key = **1**
  (so combat cannot reach elite); `VeteranCap=2` enables elite.
- TS base `VeteranRatio=10.0`; FS `VeteranRatio=5.0`.
- Promotion without kills: veterancy crate (steps one rank; only path consulting `Trainable`),
  `Armory=yes` (below-rookie→veteran, else→elite; skips veteran for rookies), Drop Pods
  superweapon (elite), TeamType `VeteranLevel` (assigns), `InitialVeteran=yes` (elite).
- `VeteranLevel=0` assigns **−0.25** experience (below rookie).

**Edge cases**
- Only a killer whose type is `Trainable=yes` accumulates; buildings start untrainable.
- An allied killer receives no experience; capture awards no experience; selling/sinking is a
  killerless kill.
- A low `VeteranCap` **demotes** an elite on its next kill (clamp applies to the total).
- `VeteranRatio=0` or a killer `Cost=0` divides by zero.
- Price multipliers cancel out (both figures priced through the victim's house).

**Kind** — generic-engine + title-data.

**Sources**
- `systems/veterancy.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]`, FS `FIRESTRM.INI` (high)
- https://modenc.renegadeprojects.com/VeteranRatio (high)

**Confidence** — high.

---

### TS-CORE-033 — Veteran/Elite Ability Tags (full list)

**What** — A veteran draws `VeteranAbilities`; an elite draws `VeteranAbilities` **and**
`EliteAbilities`. Eighteen accepted tokens, matched case-insensitively.

**Data keys** — `VeteranAbilities=`, `EliteAbilities=`.

**Numbers** — The 18 tokens:

| Token | Effect |
|---|---|
| `FASTER` | Speed × (`VeteranSpeed`+1) |
| `STRONGER` | Incoming damage ÷ (`VeteranArmor`+1) |
| `FIREPOWER` | Weapon damage × (`VeteranCombat`+1) |
| `SCATTER` | Scatters from fire even when holding position |
| `ROF` | Reload delay ÷ (`VeteranROF`+1) |
| `SIGHT` | Sight × (`VeteranSight`+1) |
| `CLOAK` | Cloaks without `Cloakable=yes`; stays cloaked while immobilized |
| `TIBERIUM_PROOF` | No Tiberium standing damage |
| `VEIN_PROOF` | No vein damage |
| `SELF_HEAL` | Self-repairs (see TS-CORE-058) |
| `EXPLODES` | Death produces `Explodes=yes` blast |
| `RADAR_INVISIBLE` | Kept off radar unless sensed |
| `SENSORS` | Adjacent enemy cloak shimmers |
| `FEARLESS` | No fear accumulation |
| `C4` | Sabotage buildings |
| `TIBERIUM_HEAL` | Tiberium repairs |
| `GUARD_AREA` | Idle armed vehicle / human infantry uses Guard Area |
| `CRUSHER` | Crushes crushables/overlays |

**Edge cases**
- A space after a comma silences the token (`FIREPOWER, ROF` registers `FIREPOWER` only).
- Only the first **127 characters** are parsed; all 18 tokens+commas = 163 chars, so a full
  list cannot be assigned in one setting.
- An ability list replaces rather than merges; an empty value cannot clear a previously set
  list.
- An elite object makes its **whole cell** scatter when fire comes in (reads rank directly).

**Kind** — generic-engine + title-data.

**Sources**
- `systems/veterancy.md` (OpenTS Manual) (high)
- TS `RULES.INI` unit sections (examples) (high)

**Confidence** — high.

---

### TS-CORE-034 — Veteran Multipliers and Elite Weapon

**What** — Five rank multipliers read as "fraction to add". `VeteranArmor`/`VeteranROF` are
divisors; the rest are multipliers.

**Data keys** — `VeteranCombat`, `VeteranSpeed`, `VeteranSight`, `VeteranArmor`, `VeteranROF`.

**Numbers**
- TS base: `VeteranCombat=.25`, `VeteranSpeed=.30`, `VeteranSight=0.0`, `VeteranArmor=.25`,
  `VeteranROF=.20`.
- FS: `VeteranCombat=.50`, `VeteranSpeed=.30`, `VeteranSight=0.0`, `VeteranArmor=.50`,
  `VeteranROF=.30`.
- Applied as value+1 (multiplier) or ÷(value+1) (divisor). `1` halves damage taken / reload.
- Sonic and fire-particle weapons get no firepower bonus; their damage is zeroed before the
  veteran step. Reload bonus skipped for sonic and effect weapons, and within a burst.
- **Elite weapon**: an elite object fires the `Elite=` weapon wherever the primary would be
  used. The elite slot reuses the primary's FLH/barrel art. Secondary is never swapped.

**Edge cases**
- A building's plug weapon outranks the elite weapon.
- Rank is not cached: applies from the next shot/damage/movement step; sight only updates on
  the next look.
- Deploy/undeploy carries experience; ownership change keeps rank; escaped crew start rookie.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/veterancy.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]`, FS `FIRESTRM.INI` (high)

**Confidence** — high.

---

### TS-CORE-035 — Rank Display and Pips

**What** — Pips are small markers drawn beneath a selected object. `PipScale` picks the
quantity; `Pip` picks a color per occupant/entry.

**Data keys** — `PipScale=` (Ammo/Tiberium/Passengers/Power/Charge), `Pip=` (per stored type,
on structures like refineries), `MaxCharge`, `Storage`, `Weeder` building pip override.

**Numbers** — Pip scales (constant → token): `PIPSCALE_AMMO=1` (`Ammo`),
`PIPSCALE_TIBERIUM=2` (`Tiberium`), `PIPSCALE_PASSENGERS=3` (`Passengers`),
`PIPSCALE_POWER=4` (`Power`, row length but never filled), `PIPSCALE_CHARGE=5` (`Charge`,
measured against `MaxCharge`). Pip colors: `empty=0`, `green=1`, `yellow=2`, `white=3`,
`red=4`, `blue=5`; engine also uses medic cross, veteran/elite marks, and three health colors
not settable from rules.
- Veterancy insignia drawn from hard-coded `PIPS.SHP`, pushed further out for non-infantry,
  only for a viewer allied/spying/given the map, and hidden with the object in shroud/fog/
  unsensed cloak.
- A `Weeder=yes` building with `PipScale=Tiberium` shows the house's weed pool, bounded by
  `WeedCapacity`.

**Edge cases**
- Below-rookie draws the frame after the last named pip.
- Buildings and `IsCoreDefender=yes` vehicles draw a pip bar rather than a selection bracket.

**Kind** — generic-engine UI + title-data.

**Sources**
- `enums/pip-scale.md`, `enums/pip-color.md`, `systems/veterancy.md`,
  `systems/transports.md`, `systems/veins.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-036 — Crates: [CrateRules] and [Powerups]

**What** — Crates are overlays carrying `Crate=yes`. Whether they appear, how a result is
chosen, and whether a collected crate is replaced all turn on campaign vs skirmish.

**Data keys** — `[CrateRules]` `CrateMaximum`, `CrateMinimum`, `CrateRadius`, `CrateRegen`,
`SilverCrate`, `SoloCrateMoney`, `UnitCrateType`, `WoodCrate`, `HealCrateSound`,
`WoodCrateImg`, `CrateImg`, `FreeMCV`; `[Powerups]` result rows; vehicle keys `CarriesCrate`,
`TrainCrate`, `TruckCrate`; overlay `CrateTrigger`.

**Numbers** — TS `[CrateRules]`:
- `CrateMaximum=255`, `CrateMinimum=1`, `CrateRadius=3.0` cells, `CrateRegen=3` minutes,
  `SilverCrate=HealBase`, `SoloCrateMoney=2000`, `UnitCrateType=none`, `WoodCrate=Money`,
  `HealCrateSound=HEALER1`, `WoodCrateImg=CRATE`, `CrateImg=CRATE`, `FreeMCV=yes`.
- Start placement count = max(`CrateMinimum`, human players), clamped to `CrateMaximum`; only
  outside a campaign. **256 tracking slots** cap tracked crates regardless of `CrateMaximum`.
- Tracked crate lifetime drawn uniformly between `0.5·CrateRegen` and `2·CrateRegen` minutes
  (stock `CrateRegen=3` → 1.5–6 min).
- Placement: uniform random cell from the map rectangle, up to **1000 attempts**; must be
  inside playable area, no overlay (else redraw to a nearby tracked-passable cell), placed as
  `WoodCrateImg`.
- A rejected cell (failed draw test) still consumes the crate and starts its timer. Engine
  never places a crate on water (not tracked-passable); a map-authored crate on water survives.

**Edge cases**
- `CrateImg` is never placed by the engine; it exists for map authors and campaign lookup.
- In a campaign, the `WoodCrateImg` test runs **after** the `CrateImg` test, so when both name
  `CRATE` (as shipped) `SilverCrate` can never take effect.
- Outside a campaign, shares are absolute weights (sum drawn 1..total), not percentages.
  A `[Powerups]` section that lists only some results **disables the rest** (missing entries
  get share 0).
- Overrides: a house with no buildings, >1500 credits, no `BaseUnit` vehicle, bases enabled →
  forced `Unit` result. Six results convert to money (Unit >50 vehicles; Squad always; Armor/
  Speed/Firepower already boosted / aircraft / no primary; Cloak already cloakable).
- Three tokens have no handler: `Invulnerability`, `IonStorm`, `Pod` (consumed, animation
  plays, nothing happens). `Squad` is rewritten to `Money`. `FreeMCV` is parsed and never read
  (the free-MCV override is unconditional).

**Kind** — generic-engine + title-data.

**Sources**
- `systems/crates.md`, `enums/crate.md`, `formats/powerups.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[CrateRules]` + `[Powerups]` (high)

**Confidence** — high.

---

### TS-CORE-037 — Crate Result Table ([Powerups] shares and data)

**What** — 19 result tokens (`CRATE_MONEY=0` … `CRATE_POD=18`), each with `Share,Anim,Data`.

**Data keys** — `[Powerups]` rows; `CrateRadius` for radius-swept results.

**Numbers** — Shipped TS `[Powerups]`:

| Result | Share | Anim | Data meaning |
|---|---:|---|---|
| `Armor` | 33 | ARMOR | armor multiplier (2.0 = halves damage) |
| `Cloak` | 20 | CLOAK | grant cloaking |
| `Darkness` | 5 | SHROUDX | reshroud whole map |
| `Explosion` | 38 | `<none>` | 500 raw damage per blast (collector + 5 blasts) |
| `Firepower` | 28 | FIREPOWR | firepower multiplier (2.0) |
| `HealBase` | 23 | HEALALL | all own objects to full strength |
| `ICBM` | 13 | CHEMISLE | one-time missile superweapon |
| `Money` | 55 | MONEY | 2000 credits + random up to 900 |
| `Napalm` | 25 | `<none>` | 600 damage (collector + midpoint blast) |
| `Reveal` | 8 | REVEAL | reveal whole map |
| `Speed` | 30 | ARMOR | speed multiplier (1.7) |
| `Squad` | 45 | `<none>` | rewritten to Money |
| `Unit` | 40 | `<none>` | create a vehicle |
| `Invulnerability` | 10 | ARMOR | no handler |
| `Veteran` | 15 | VETERAN | promotion steps (1) |
| `IonStorm` | 0 | `<none>` | no handler |
| `Gas` | 18 | `<none>` | 100 damage on 9 cells (hard-coded `GAS` warhead) |
| `Tiberium` | 35 | `<none>` | stage-1 patch + 10–20 scattered (slot 1→slot 0 redirect) |
| `Pod` | 0 | `<none>` | no handler |

**Edge cases**
- `Money` pays `SoloCrateMoney` in a campaign (falls back to random range if 0).
- `Unit` selection order: MCV override → harvester if refinery and no harvester → `UnitCrateType`
  → random `CrateGoodie=yes` type ownable/base-legal.
- Radius-swept results (`Cloak`, `Veteran`, `Armor`, `Speed`, `Firepower`) test position only,
  not ownership; `Armor` only affects objects whose multiplier is exactly 1; armor value 0 is an
  unclamped zero divisor.
- `Gas` needs a registered `GAS` warhead or does nothing.

**Kind** — title-data on a generic crate system.

**Sources**
- TS `RULES.INI` `[Powerups]` (high)
- `systems/crates.md`, `formats/powerups.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-038 — [Maximums] and Engine Object Limits

**What** — The classic `[Maximums]` section is nearly empty in TS; most caps are engine-fixed
in code. This is important for a data-driven engine to distinguish.

**Data keys** — `[Maximums] Players` (the only shipped key), `[General] MaximumQueuedObjects`,
`CrateMaximum`, plus hard-coded caps.

**Numbers**
- `[Maximums] Players=8` (IPX layer limit); `MAX_PLAYERS=8`.
- `MaximumQueuedObjects=4` in `[General]` (build-queue ceiling = 1 + this per category).
- Hard-coded: 256 tracked crates; 500 block-list entries per pathfinding stage; 65,527 cells
  max taken up per pathfinding pass; 131,072 recorded search cells; 2,000-step route list;
  512×512 map array; `MAX_EVENTS=64` per frame; `MAX_TEAM_CLASSCOUNT=6`;
  `MAX_TEAM_MISSIONS=50`; 4 Tiberium storage compartments per house/harvester.
- TS `Heap_Maximums` reads only `Players`; the classic TD/RA2 maximum keys are absent.

**Edge cases**
- A 5th Tiberium type writes past the 4-compartment record.
- A route of ≥2,000 cells overruns its list; ≥131,072 cells fill the search record.
- `VeteranCap` defaults to 1 if omitted, capping combat promotion at veteran.

**Kind** — generic-engine limits + title-data (Players).

**Sources**
- TS `RULES.INI` `[Maximums]` + `[General]` (high)
- `code/rules.cpp` `Heap_Maximums`, `code/sun.h` (OpenTS) (high)
- `systems/route-search.md`, `systems/tiberium.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-039 — Simulation Timing and Tick Units

**What** — The simulation runs on a fixed frame/tick. Rules time values are authored in
**minutes** and converted with 900 ticks/minute.

**Data keys** — All "minutes" values (`ShroudRate`, `FogRate`, `DamageDelay`, `RepairRate`,
`BuildSpeed`, `C4Delay`, `RechargeTime`, etc.).

**Numbers**
- `TICKS_PER_SECOND = 15`; `TICKS_PER_MINUTE = 900`; `TICKS_PER_HOUR = 54000`.
- Every "minutes" rules value × 900 = frames. E.g. `RepairRate=.016` → 14 frames;
  `ReloadRate=.5` → 450 frames; `C4Delay=.03` → 27 frames; `RechargeTime` in minutes × 900.
- Ion-storm trigger action multiplies its number by 15 (seconds→frames); team mission passes
  frames unchanged.
- A full production object takes **54 steps**; step delay = build-time-frames / 54, clamped
  1–255.
- `TICKS_PER_LEPTON` is not a fixed constant; projectile speed is leptons/frame.

**Edge cases**
- Values that truncate to a non-integer modulus (e.g. `RepairRate·900` between 0 and 1) can
  divide by zero in the repair tick.
- `ShroudRate`/`FogRate` timers start at 0, so the first eligible frame runs a pass
  immediately. Game speed setting scales animation rates (buildup, etc.).

**Kind** — generic-engine timing.

**Sources**
- `code/stimer.h` (OpenTS) (high)
- `systems/ion-storms.md`, `systems/repair.md`, `systems/production.md` (OpenTS Manual) (high)

**Confidence** — high.

---

### TS-CORE-040 — Crushing and Weight

**What** — A `Crusher=yes` vehicle drives over `Crushable=yes` objects/overlays. Weight governs
ice and blast rocking; a rules-wide `Crush` distance decides when an AI crusher runs over
instead of shooting.

**Data keys** — `Crusher`, `Crushable`, `Crush` (`[CombatDamage]`, default 1.8 stock / 1.5
manual default — see conflict), `AutoCrush`, `PlayerAutoCrush`, `TiltsWhenCrushes`, `Weight`,
`CrushSound`.

**Numbers**
- TS `[CombatDamage] Crush=1.8` cells. The OpenTS Manual lists the engine default as `1.5` and
  notes TS ships `1.8`; use `1.8` for TS.
- Crushing a `Crushable=yes` overlay destroys the segment outright (`-1` damage), ignoring
  ownership and damage stage; plays `CrushSound` and rocks the vehicle.
- `TiltsWhenCrushes` (default yes) only affects the visual forward lurch and only for sandbag
  wall; `Accelerates=yes` vehicles are held to **1/5 speed** while crushing.
- `Weight` default `1`. Rock tilt = `(0.04 − distance·0.000025) · force / Weight`, ignored
  below `0.01`, capped at `0.05`; forward component half, sideways full.
- AI crush/retaliation tests run only for computer-controlled houses; a `Crush` target must be
  within the distance. Difficulty slot 2 (`[Difficult]`, handed to an Easy computer) never
  auto-crushes.

**Edge cases**
- `PlayerAutoCrush` and per-type `AutoCrush` reach no live branch (parsed, unused).
- `Crusher=yes` also sets the default SpeedType to `Track` (else `Wheel`).
- A vehicle's `DeployToFire` restricts where it may shoot (buildable cells).

**Kind** — generic-engine + title-data.

**Sources**
- TS `RULES.INI` `[CombatDamage]` `Crush`, `PlayerAutoCrush` (high)
- `keys/crush.md`, `keys/crusher.md`, `keys/weight.md`, `systems/movement-and-terrain.md`
  (OpenTS Manual) (high)

**Confidence** — high; note the `Crush` default conflict (1.8 shipped vs 1.5 manual).

---

### TS-CORE-041 — Ice Cracking, Breaking, and Drowning

**What** — In the snow theater, a vehicle finishing a move onto ice cracks or breaks it by
weight; ice refreezes after a delay. Weapon fire can also crack ice.

**Data keys** — `IceCrackingWeight`, `IceBreakingWeight`, `IceGrowthRate`,
`IceSolidifyFrameTime`, `IceCrackSounds`, `[AudioVisual] Wake`, `[CombatDamage] SplashList`.

**Numbers**
- `IceCrackingWeight=2.0`, `IceBreakingWeight=4.0` (TS shipped 2.0/4.0; Tebrey guide explains
  1.0 = infantry cracks). Comparisons are **at-or-above**; step 2 reached only if step 1 fails.
- `IceGrowthRate=1.5`; `IceSolidifyFrameTime=1000` frames.
- `IceCrackSounds=ICECRAK1,ICECRAK2,ICECRAK3`.
- Stock weights: harvester `1` (untouched), most tanks `3.5` (crack), recreational vehicle `4`
  (only stock type heavy enough to break).
- Breaking opens a 2×2 block ahead of the facing; every cell must already be water/ice. All four
  cells take the broken edge tile; occupants sink and are stunned, infantry/aircraft are removed
  outright and fire their triggers; each affected object leaves a wake.
- Cracking replaces the tile with a cracked tile (one of three ice sets), plays a crack sound,
  and schedules refreeze `IceSolidifyFrameTime` later. A cracked cell re-crossed falls through
  to breaking.
- Weapon fire: any warhead that destroys walls or sets fires (`Wall=yes` or `Fire=yes`) cracks
  the ice it lands on, no weight needed.

**Edge cases**
- Only vehicles run the test, only snow theater, only as a move finishes, never on a bridge.
- An amphibious vehicle standing on the broken block is spared sinking, **except** the vehicle
  whose arrival broke the ice, which sinks regardless.
- Infantry and aircraft never trigger it.

**Kind** — generic-engine + title-data.

**Sources**
- TS `RULES.INI` `[General]` (high)
- `keys/icecrackingweight.md`, `keys/icebreakingweight.md` (OpenTS Manual) (high)
- http://tiberian.iwarp.com/editingguidetots.htm (med)

**Confidence** — high.

---

### TS-CORE-042 — Bridges

**What** — A bridge cell is two places: deck and ground beneath. A bridge four levels above
the ground is traversed only across a marked span. Spans can be destroyed and repaired.

**Data keys** — `DestroyableBridges` (`[CombatDamage]`), `BridgeStrength`, `BridgeVoxelMax`,
`BridgeExplosions`, `[OverlayTypes]` bridge set, `BridgeRepairHut`, `BridgeSet`,
`ZShapePointMove`, `[SpecialFlags]` bridge option.

**Numbers**
- `BRIDGE_CELL_HEIGHT = 4` levels; `BRIDGE_LEPTON_HEIGHT = 416` leptons.
- `BridgeStrength=1500` (roll `Random_Pick(1, BridgeStrength) < strength`).
- `BridgeVoxelMax=3` — parsed, never used (OpenTS manual: dead setting).
- `DestroyableBridges=yes` in TS. `[SpecialFlags]` bridge option is read in campaigns only;
  outside a campaign the lobby option replaces it.
- A vehicle crossing a bridge skips the terrain figure on the deck (so a tracked unit with
  `[Water] Track=0` crosses a river); at ground level under the bridge it is refused as open.
- Height step of four levels allowed only across a bridge span; ±1 only across a ramp.

**Edge cases**
- A projectile crossing the deck plane detonates at deck height.
- A blast's nine-cell sweep reads either all deck occupants or all ground occupants, decided by
  the blast's own cell (208 leptons above ground splits the two).
- A bridge repairing hut (`BridgeRepairHut=yes`) replaces both engineer restore and capture;
  rail vs road repair chosen from a 5×5 block around the engineer.
- Falling off a bridge into water skips debris and blast (water exit), leaving a wake/splash.

**Kind** — generic-engine + title-data.

**Sources**
- TS `RULES.INI` `[CombatDamage]` (high)
- `code/sun.h`, `code/globals.cpp` (OpenTS) — height constants (high)
- `keys/bridgevoxelmax.md`, `systems/warheads.md`, `systems/capture.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Bridge (med)

**Confidence** — high.

---

### TS-CORE-043 — Shroud: Regrowth and Reveal

**What** — The shroud is a single map-wide cover every scenario starts with (not per-house
knowledge). Cells are **mapped** (partly out) or **clear** (no cover left). Since the shroud
isn't per-house, non-local looks are filtered before touching cells.

**Data keys** — `ShroudGrow=yes/no` (default no in TS `[AudioVisual]`), `ShroudRate=4`
minutes, `Shroud=` scenario option, `AllyReveal=yes`, `RevealTriggerRadius=9`.

**Numbers / rules**
- Each cell builds shrouded; reading `[Map] Size` rebuilds all cells shrouded. Every map
  begins fully dark; only triggers reveal at start.
- `ShroudGrow=yes` + `ShroudRate≠0`: a pass every `ShroudRate` game minutes marks only the
  **fringe** (mapped cells still carrying a partial shroud piece), shrouds each, then has
  everything still watching look again. Creeps inward exactly one cell per pass; never
  reappears mid-revealed-area. Timer starts at 0 → first eligible frame runs immediately.
- Reveal-clamp: shroud reveal also lifts fog from the same cell; fog never lifts shroud.
- A look is redirected to the local player if: a local limpet rides the looker; the local
  player has spied the looking house's radar; or the looking house is an ally and
  `AllyReveal=yes`.

**Edge cases**
- Induced reveals: reveal-around-waypoint (`RevealTriggerRadius` cells, height test on),
  reveal-zone-of-waypoint (2 cells around every cell in the waypoint's crusher zone), reveal-all,
  mission reveal (shroud only), observer/defeat (both covers).
- Partial-piece artwork chosen from which of eight neighbours are unmapped; revealing one cell
  may force neighbouring cells open.
- A spy inside an enemy `Radar=yes` structure makes every object of the spied house look at
  once and keeps the mark until the radar structure is destroyed/captured.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/map-visibility.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[AudioVisual]` (high)
- https://modenc.renegadeprojects.com/ShroudGrow (high)

**Confidence** — high.

---

### TS-CORE-044 — Fog of War

**What** — Fog is a separate layer, enabled by lobby option (skirmish) or `FogOfWar=yes` (map,
campaign only). While running, the shroud is drawn with fog artwork.

**Data keys** — `[General] FogOfWar=no`, `FogRate=.5` minutes, `[Map] FogOfWar`, `BlendedFog`,
`AircraftFogReveal=6`.

**Numbers / rules**
- Fog raised over every cell at end of scenario load when on.
- A cell passing under fog photographs structures (per-footprint-cell stand-ins); mobile
  objects simply vanish and are deselected.
- Fog regrowth: every `FogRate` game minutes, mark fringe, have every object look in a
  mark-clearing mode, fog surviving marks. Timer starts at 0.
- `BlendedFog` selects a fog rendering path but both call sites pass the guard false, so it is
  **unreachable/dead** (OpenTS manual). TS ships `BlendedFog=yes`.
- `AircraftFogReveal=6`: fallback fog-only reveal for aircraft with `Sight=0` while fog is on;
  height test only below half the global `FlightLevel`.

**Edge cases**
- Fog never removes shroud; shroud reveal also removes fog.
- An allied structure during the fog pass maps cells it can see (with `AllyReveal=yes`) —
  a known quirk giving free terrain during each pass.
- A player given the whole map (observer/defeated outside coach) is told nothing is fogged.
- `CameraRange=9` is stored and read by nothing (dead).

**Kind** — generic-engine + title-data.

**Sources**
- `systems/map-visibility.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]`, `[AudioVisual]` (high)
- https://modenc.renegadeprojects.com/Fog_of_War (high)

**Confidence** — high.

---

### TS-CORE-045 — Sight and Reveal Rules

**What** — `Sight` is a count of cells (not leptons). Height and veteran modifiers apply, the
result capped at 10 cells. Vehicles/infantry look on reaching a cell centre; aircraft look
every 15 frames.

**Data keys** — `Sight` (per type), `LeptonsPerSightIncrease`, `VeteranSight`, `RevealByHeight`,
`AttackingAircraftSightRange`, `MoveToShroud`, `AllowShroudedSubteranneanMoves`, `Landable`.

**Numbers**
- Sight × height bonus: +10% per whole `LeptonsPerSightIncrease` (TS = 2000) leptons of
  elevation. One level = 104 leptons.
- ×(`VeteranSight`+1) for the `SIGHT` ability.
- Capped at **10 cells** (ring tables stop at ring 10).
- `RevealByHeight=yes`: a candidate is revealed only if a probed cell (candidate displaced 2
  cells on both axes, stepped once toward the centre) is no more than 3 levels above the looker.
- Firing reveals a hard-coded 2 cells around the firer to the target's owner under specified
  conditions; an attacking local aircraft reveals `AttackingAircraftSightRange=6`.
- `LeptonsPerSightIncrease=0` divides by zero on the next look (crash).

**Edge cases**
- An object looks only once locked to the playable area (`LocalSize`); a never-locked object
  reveals nothing.
- A landed aircraft sees exactly one cell.
- `MoveToShroud=yes` allows an order onto a shrouded cell (reduced to a plain move).
- A subterranean unit needs `AllowShroudedSubteranneanMoves=yes` to click a shrouded object;
  aircraft are refused regardless.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/map-visibility.md`, `systems/movement-and-terrain.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (high)

**Confidence** — high.

---

### TS-CORE-046 — Cloaking and Detection

**What** — Three pieces of state: per-object cloak state, per-cell set of houses whose cloak
field covers it, per-cell set of houses whose sensor coverage reaches it.

**Data keys** — `Cloakable`, `CloakStop`, `CloakingSpeed`, `CloakingStages`, `CloakDelay`,
`CloakGenerator`, `CloakRadiusInCells`, `SensorArray`, `Sensors`, `CloakSound`,
`CloakDetectionRadius`, `Invisible`, `InvisibleInGame`, `RadarVisible`, `HasRadialIndicator`.

**Numbers**
- `CloakingStages=9` (TS `[General]`). Fade bands as fractions: <¼ indistinct, ¼–½ darkened,
  ½–¾ shadowy, ¾–<1 ripple, 1 not drawn. Fade-out counts as hidden at the **shadowy** band
  (half `CloakingStages`); fade-in starts one stage below the top.
- A structure uses 15 fixed translucency levels, one per frame; complete at 15.
- Fade clock: each stage lasts `CloakingSpeed` frames. Above `ConditionRed`, hiding starts
  immediately; at/below, 4% chance/frame.
- `CloakDelay=.02` minutes forced surface delay for subs; `CloakingStages=9`.
- Cloak generator marks the disc out to `CloakRadiusInCells` (engine default 20), growing one
  ring per frame; a field is squared off in a working area `max(CloakRadiusInCells)+16` wide.
- Sensor array marks every cell strictly nearer than `CloakRadiusInCells`.
- `CloakDetectionRadius` (jumpjet) is a square half-width: `2` sweeps 5×5; default 0.
- Radar plot order: `Invisible` never; `RadarVisible` always; local houses once discovered;
  else while not fogged/hidden/>20 leptons below ground/no `RADAR_INVISIBLE`/not shrouded; else
  only while sensed.

**Edge cases**
- Uncloak causes: firing (aircraft exempt through fades), taking damage, crushing, planting
  C4, carrying a flag, walking past a detector at cell arrival, blocking the way (cost 1000),
  jumpjet overflight (no ownership test), losing field cover, being stunned, critical damage
  10%/frame in the darkened band.
- A field never covers an ally; only the owner's mark is set.
- A hidden blocker is priced (1000), not impassable; stepping in uncloaks.
- Human cloaked objects don't self-acquire on Guard; computers do.
- `RadarInvisible` is dead; `IsMobileStealth` is a deployed-vehicle marker, not cloak.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/cloaking.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (`CloakingStages`, `CloakDelay`) (high)

**Confidence** — high.

---

### TS-CORE-047 — Tiberium: Types, Growth, Spread, Harvest

**What** — Registered Tiberium types grow through 12 stages, spread to adjacent cells, and are
harvested for credits/storage. Four types are registered in TS.

**Data keys** — `[Tiberiums]` list; per-type `Name`, `Image`, `Value`, `Power`, `Growth`,
`GrowthPercentage`, `Spread`, `SpreadPercentage`, `Color`, `Debris`, `Shard`; scenario
`TiberiumGrows`, `TiberiumSpreads`, `TiberiumGrowthEnabled`; harvester `Storage`, `Dock`,
`HarvesterLoadRate`, `HarvesterDumpRate`, `TiberiumNearScan`, `TiberiumFarScan`.

**Numbers** — TS types:

| Slot | Name | Image | Value | Power | Growth | Growth% | Spread | Spread% |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 0 | `Riparius` | 1 | 25 | 4 | 2200 | .09 | 2200 | .09 |
| 1 | `Cruentus` | 2 | 70 | 10 | 10000 | 0 | 10000 | 0 |
| 2 | `Vinifera` | 3 | 40 | 100 | 10000 | .05 | 10000 | .05 |
| 3 | `Aboreus` | 4 | 30 | 10 | 10000 | .05 | 10000 | .05 |

- Cell value = `Value × (stage+1)`; stages 0–11.
- Newly seeded cell starts at **stage 5**; smoothing on any placed overlay sets stage by the
  count of same-type neighbours (0→stage 0 … 8→stage 11).
- Growth budget = queued × `GrowthPercentage`, clamped 5–50; spread budget clamped 5–25.
- `TiberiumGrows=yes` multiplies the reloaded growth delay by **0.3** (it shortens, not
  enables). Growth gating is the scenario `TiberiumGrowthEnabled` switch.
- Spread ripeness threshold = `floor(slot/2)`: slots 0–1 spread from stage 1, slots 2–3 from
  stage 2.
- Infantry standing on Tiberium take `Power/10` (min 1) unless `TiberiumProof`/ability.
- Harvest cycle = 9 stage-ticks of `HarvesterLoadRate` frames; weed cycle is 3× slower (9×
  `HarvesterLoadRate`).

**Edge cases**
- `Image=2` (Cruentus) has a single growth stage: can neither grow nor be seeded, only
  map-placed or spewed by a destroyed `TiberiumHeal=yes` object.
- A harvested full-stage-11 cell stops growing back (refused re-queue).
- Only 4 storage compartments; a 5th type writes past the record.
- `TiberiumGrows`/`TiberiumExplosive` in `[MultiplayerDefaults]/[SpecialFlags]` are parsed and
  never read; `TiberiumStrength` and `TiberiumTransmogrify` are stored and never consulted.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/tiberium.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[Tiberiums]` blocks (high)
- https://modenc.renegadeprojects.com/Tiberium (med)

**Confidence** — high.

---

### TS-CORE-048 — Tiberium Damage, Chain Reaction, Explosive

**What** — Tiberium overlays can chain-react; loaded harvesters can explode; craters strip
stages.

**Data keys** — `TiberiumExplosive` (`[CombatDamage]`), `TiberiumExplosionDamage=100`,
`TiberiumHeal`, `RadChainReaction` warhead `Tiberium=yes`, overlay `ChainReaction=yes`,
animation `TiberiumChainReaction=yes`.

**Numbers**
- Chain reaction chance = **5 × stage** percent. Consumes half the stage, deals `stages ×
  Power`. Each of eight neighbours above stage 2 has an 80% chance of delayed detonation.
- A zero result still consumes growth and performs neighbour checks.
- `TiberiumExplosionDamage=100` (large chain-reaction explosion).
- `TiberiumExplosive=yes`: a destroyed vehicle carrying Tiberium explodes over 1.5 cells; damage
  = Σ(compartment amount × that type's `Power`).
- A crater-forming animation strips 6 stages from its cell; a laser fence clears 12 from every
  cell along its span.
- `TiberiumTransmogrify=40`: chance infantry dying on Tiberium becomes a visceroid (parsed,
  never consulted in reconstructed source — treat as title-data intent).

**Edge cases**
- A warhead needs `Tiberium=yes` to detonate Tiberium (a sonic wave skips the test).
- `ChainReaction=yes` overlay only detonates at stage ≥ 2.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/tiberium.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[CombatDamage]` (high)
- `code/combat.cpp` `Chain_Reaction_Damage` (OpenTS) (high)

**Confidence** — high.

---

### TS-CORE-049 — Ion Storms

**What** — A scripted map-wide condition that grounds aircraft/hovercraft, calls lightning, and
swaps lighting. No rules setting or weather model schedules one.

**Data keys** — `IonLightningFrequency`, `IonLightningRandomness`, `IonLightningDamage`,
`IonStormDuration`, `IonStormWarning`, `IonStorms`, `IonStormWarhead`, `IonSensitive`,
`LightningRod`, `IonImmune`, `IonAmbient/IonRed/IonGreen/IonBlue/IonGround/IonLevel`,
`AmbientChangeRate`, `AmbientChangeStep`.

**Numbers** — TS `[General]`:
- `IonLightningFrequency=10`. The engine draws 0..1000 and fires when the draw is below
  **10× the written value**, so TS's shipped 10 compares against 100 (≈10% of frames); the
  OpenTS manual's "one frame in four" is for its default of 25.
- `IonLightningRandomness=90` (% of bolts on a random cell).
- `IonLightningDamage=500`, `IonStormDuration=120` (ignored), `IonStormWarning=31` seconds,
  `IonStorms=no`, `IonStormWarhead=IonWH`.
- Warning announces every 15 s; at 31 s → two announcements.
- Sensitive locomotors: Fly and Hover only. Fly exempt if `HunterSeeker=yes`; Hover exempt if in
  radio contact with a WeaponsFactory or on its doorway row.
- Lightning candidate chances: building/vehicle/infantry 2%; switched-on building with
  `LightningRod=yes` 42%; powered vehicle/infantry with rod 12%; aircraft excluded.
- `AmbientChangeRate=.2`, `AmbientChangeStep=.1`; ramp moves current ambient by step×100.

**Edge cases**
- Jumpjet: moving airborne ones take full strength damage (destroyed); grounded ones cannot take
  off; movement zone demoted to infantry for routing.
- Aircraft off the ground crash (strength 0, no kill credited).
- Radar lost outright for the duration (before power/building checks).
- `IonStormDuration` and `IonStorms` are parsed and never gate/define anything.
- The two scripted durations use different units (trigger action seconds×15; team mission
  frames).

**Kind** — generic-engine + title-data.

**Sources**
- `systems/ion-storms.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (high)
- https://modenc.renegadeprojects.com/Ion_Storm (med)

**Confidence** — high; med (IonLightningFrequency exact threshold wording).

---

### TS-CORE-050 — EMP Pulse

**What** — A warhead with `EMEffect=yes` creates a pulse instead of blast damage; `Damage`
becomes stun duration in frames and `Spread` the radius in cells.

**Data keys** — `EMEffect`, `Spread`, `Damage`, `EMPulseCannon`, `IsMobileEMP`, `StartCharge`,
`MaxCharge`, `EMPulseSparkles`, `IsCoreDefender`.

**Numbers**
- Radius = `Spread` cells; duration = weapon `Damage` (scaled by firepower where from combat).
- Applies once at creation; later entrants unaffected. `Damage=0` does nothing and is deleted
  same frame.
- Aircraft handled first: <1 height level above ground and within `Spread` cells → paralyzed
  event + crash path (crash does nothing at exactly 0 height; then the cell sweep stuns it).
- Cell sweep: buildings register only on their centre cell; invisible ones skipped; limpet
  destroyed; `IsCoreDefender` springs trigger but isn't stunned; else powered off + stunned
  (+ `EMPulseSparkles` if deployed-vehicle kind). Ground objects stunned if vehicle/aircraft
  (with locomotor, not core-defender, not the firer) or cyborg infantry. Visceroids and the
  firer exempt.
- `EMPulseCannon` superweapon: nearest powered cannon takes missile mission; hard-coded
  `PULSBALL` animation, 32-frame wait, then fires its primary weapon.
- `IsMobileEMP`: gains 1 charge/frame from `StartCharge` to `MaxCharge`; deploy at full charge
  detonates `MobileEMPulseWeapon`.

**Edge cases**
- Non-cyborg infantry are never affected (a famous TS quirk).
- A building is tested on one cell only; a large footprint overlapping the circle is untouched
  if its centre is outside.
- A stunned building reports unpowered, refuses to switch on, drops radar, can't be a launch
  site; house power tally is unaffected (the on/off state is untouched).
- Recovery is per-object countdown; buildings power back on and refresh radar.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/emp-pulse.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[SpecialWeapons]`, `[Warheads] EMPuls` (high)

**Confidence** — high.

---

### TS-CORE-051 — Veins and Veinhole Monsters

**What** — A veinhole monster owns a field of vein overlays that damage occupants and fill a
house's weed pool.

**Data keys** — `VeinholeTypeClass`, `VeinholeGrowthRate`, `VeinholeShrinkRate`,
`MaxVeinholeGrowth`, `VeinDamage`, `VeinAttack`, `VeinholeWarhead`, `ImmuneToVeins`,
`IsVeins`, `Land=Weeds`, `WeedCapacity`, `Weeder`, `VeinGrowthEnabled`, `VeinholeMonsters`.

**Numbers** — TS `[General]`:
- `VeinholeGrowthRate=300` (was 3000), `VeinholeShrinkRate=100`, `MaxVeinholeGrowth=2000`,
  `VeinDamage=5`, `VeinholeTypeClass=VEINTREE`, `VeinholeWarhead=VeinholeWH`.
- Growth: first step `VeinholeGrowthRate` frames after creation, then that + up to half random.
  Steps take 1–5 frontier cells, lowest score first. Score = current frame/50 + random 1–50.
- A step runs only while frontier entries ≤ `MaxVeinholeGrowth−40` and mature cells ≤
  `MaxVeinholeGrowth−100`, and `VeinGrowthEnabled` is on.
- Vein overlays are fixed at `[OverlayTypes]` positions **126 (veins), 167 (veinhole), 178
  (dummy ring)** — reordering breaks the system.
- Standing damage: `VeinDamage=5` with `VeinholeWarhead` every other frame on flat mature vein,
  height ≤5, not immune.
- Weed loading cycle = 9 stage-ticks of 3× `HarvesterLoadRate` frames; adds one unit to first
  compartment (+1 if not full).
- Weed pool consumed only when a house holds exactly `WeedCapacity` units and owns an
  uncharged chem-missile superweapon, which then charges and empties the pool.

**Edge cases**
- Vengeance/destruction: a destroyed monster replaces its cell + 4 neighbours with vein, clears
  4 diagonals, then runs placement over a 5×5 block; thereafter withers the field by
  `VeinholeShrinkRate` + random up to half.
- Splash damage reaches the monster only at its own cell.
- Veins never attack on slopes; a thin cell with no mature cardinal neighbour loses its overlay.
- Veins stop one cell short of a wall/bridge/crate/Tiberium cell.
- `WeedCapacity` defaults to 0 when unset (store refuses the first unit).
- `VeinholeMonsterStrength` and `VeinGrowthRate` are parsed and never read.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/veins.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (high)

**Confidence** — high.

---

### TS-CORE-052 — Superweapons (full list and behaviors)

**What** — `[SuperWeaponTypes]` declares weapons; each house gets its own copy/timer. `Type=`
selects one of seven hard-coded behaviors.

**Data keys** — `[SuperWeaponTypes]` list; per section `Name`, `Type`, `RechargeTime`,
`IsPowered`, `ManualControl`, `UseChargeDrain`, `Action`, `WeaponType`, `SidebarImage`,
`ChargingVoice`, `RechargeVoice`, `ImpatientVoice`, `SuspendVoice`; `SuperWeapon`/`SuperWeapon2`
on structures; `AuxBuilding`, `NukeSilo`, `EMPulseCannon`, `HSBuilding`.

**Numbers** — TS `[SuperWeaponTypes]`: `MultiSpecial`, `EMPulseSpecial`, `FirestormSpecial`,
`IonCannonSpecial`, `HuntSeekSpecial`, `ChemicalSpecial`. Types: `MultiMissile`, `EMPulse`,
`Firestorm`, `IonCannon`, `HunterSeeker`, `ChemMissile`, `DropPod`.
- `RechargeTime` in minutes × 900. Shipped: Multi=10, EMPulse=4.5, Firestorm=3, Ion=8.5,
  HunterSeeker=12. `RechargeTime=0` reads as absent (default 5 min).
- `UseChargeDrain` (Firestorm): firing rescales timer by `ChargeToDrainRatio=.333`; firing again
  reverses. `ChargeToDrainRatio=.333`, `DamageToFirestormDamageCoefficient=.1`.
- One-time weapons forced to full charge, never suspended, removed on discharge.
- Ion cannon rating table (per difficulty via `AIIonCannon*Value` keys, with three fixed
  engine figures); fixed figures:
  infantry 2, other structure 4, other vehicle 2.
- Missile silo projectile: hard-coded strength 200, released 160 leptons north of centre.
- One-time missiles launch from map edge using `MultiLauncher`/`ChemLauncher`, range 100000.

**Edge cases**
- `[SuperWeaponTypes]` order must match behavior order or a silo launches the wrong weapon.
- Computer never fires `EMPulse` or `Firestorm` from its decision pass.
- A plug-supplied superweapon is granted without the `AuxBuilding` test.
- `NukeProjectile`/`NukeDown`/`EMPulseWarhead`/`EMPulseProjectile` are parsed and never used.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/superweapons.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[SuperWeaponTypes]` + special sections (high)

**Confidence** — high.

---

### TS-CORE-053 — Repair and Healing (all paths)

**What** — Five restore paths: structure wrench, service depot, hospital/armory, self-healing,
Tiberium healing. They share settings in non-obvious ways.

**Data keys** — `RepairRate`, `URepairRate`, `IRepairRate`, `RepairStep`, `IRepairStep`,
`RepairPercent`, `TiberiumHeal`, `SelfHealRate`, `SelfHealStep`, `SelfHealCap`,
`SelfHealingRate/Step/Cap`, `RepairPercent`, `ReloadRate`, `UnitRepair`, `UnitReload`,
`RepairBay`, `Hospital`, `Armory`, `Mechanic`, `OmniHealer`.

**Numbers** — TS `[General]`:
- `RepairRate=.016` (14 frames), `URepairRate=.016`, `IRepairRate=.001` (hospital/armory count),
  `RepairStep=8`, `IRepairStep=1`, `RepairPercent=20%`, `TiberiumHeal=.010` (15 frames),
  `ReloadRate=.5` (450 frames), `RepairPercent=20%`.
- Cost of one repair step (integer): `cost = (rawCost / (Strength/RepairStep)) × RepairPercent`,
  never below 1. Worked example: cost 1000, Strength 400, RepairStep 5, Percent 0.25 → 80 steps,
  step 1 = 3 credits; full rebuild = 240 not 250.
- Self-healing fallback: step 1, interval `RepairRate`, ceiling `ConditionYellow` (50%).
- Tiberium healing: every `TiberiumHeal×900` frames, amount = `IRepairStep` (infantry) or
  `RepairStep` (rest), clamps to max. Buildings never Tiberium-heal.
- Armory: promotes below-rookie occupant to veteran, else elite; `IRepairRate` count runs
  ~14× slower than a hospital's.
- Service depot: `UnitRepair=yes` offers pad; `RepairBay` names the BuildingType a repair order
  steers to; steps at `URepairRate×900`, same step arithmetic as structures.

**Edge cases**
- `RepairStep=0` divides by zero; `RepairStep>Strength` makes a later term zero → crash;
  `RepairRate×900` truncated to 0 → modulus crash.
- A hospital/armory with no `Ammo` serves exactly one visitor (`-1` → clamped to 0).
- A building with no `RepairBay=` crashes any vehicle taking a repair order.
- `RepairPercent` is charged as an integer ratio, so full repair rarely lands on it.
- A limpet mine survives repairs; a mined structure at max strength still spends a pointless
  step.
- An engineer restores an allied structure to full strength at no cost and forces the repair
  flag off.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/repair.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (high)

**Confidence** — high.

---

### TS-CORE-054 — Production, Factories, and Build Time

**What** — A player's house has four production slots (infantry/vehicle/aircraft/structure),
one object per slot with a queue; a computer house runs production per factory. Both take 54
steps.

**Data keys** — `Factory`, `WeaponsFactory`, `BuildSpeed`, `BuildTime`, `BuildupTime`,
`MaximumQueuedObjects`, `PlacementDelay`, `MultipleFactory`, `WallBuildSpeedCoefficient`,
`MinProductionSpeed`, `Cost`, `Prerequisite*`, `Owner`, `BuildLimit`, `TechLevel`,
`SeparateAircraft`, `FreeUnit`.

**Numbers** — TS `[General]`:
- `BuildSpeed=.8` (minutes per 1000-credit item → 720 frames base; step delay 720/54).
- `BuildupTime=.06`, `MaximumQueuedObjects=4` (queue ceiling 1+4 = 5 per category),
  `PlacementDelay=.05`, `MultipleFactory=0` (default 0 → no bonus), `MinProductionSpeed=.5`,
  `WallBuildSpeedCoefficient=.5`.
- Build time steps: Cost × `BuildSpeed` × 0.9 frames/credit → × house difficulty BuildTime ×
  `GameSpeedBias` → ÷ power multiplier → × multiple-factory factor → × wall coefficient.
  Divided by 54, clamped 1–255 frames per step.
- Worked: 1000 credits, all multipliers 1 → 900 frames /54 = 16 frames/step (truncated) → 864
  frames = 57.6 s. Clamp: min 54 frames (3.6 s, covers <120 credits), max 13,770 frames
  (~15.3 min, at 15,300 credits).
- Multiple factory multiplier at `MultipleFactory=1`: 1→1, 2→1, 3→0.5, 4→0.333. At `0.5`:
  1→1, 2→2, 3→1, 4→0.667. Zero or below skips.
- Full price charged across 54 installments (outstanding / steps left); a shortfall stalls the
  build in place.

**Edge cases**
- `Factory=` short names (`Unit`, `Infantry`, `Aircraft`, `Building`) work for a computer
  house but never for a player (player test uses `...Type`).
- Primary factory auto-flag uses the count of structures of the **8th** `[BuildingTypes]`
  entry — an order-dependent oddity.
- Build limits: `>0` counts current objects, `0` never buildable, `<0` counts ever-produced.
  Computer houses bypass build limits.
- Structures never queue; a second structure order is refused while any is outstanding.
- Buildings placed by hand fill the gap to a nearby same-house wall of the same type.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/production.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]`, `[MultiplayerDefaults]` (high)

**Confidence** — high.

---

### TS-CORE-055 — Transports

**What** — Any type with `Passengers>0` can carry infantry/vehicles (buildings, vehicles,
aircraft); only infantry and vehicles can be passengers, and aircraft cannot be ordered in.

**Data keys** — `Passengers`, `Size`, `SizeLimit`, `IsVehicleTransport`, `PipScale`, `Pip`,
`Loadable`, `DeployTime`.

**Numbers**
- Admission order: capacity/sender/alliance → vehicle-sender test (`IsVehicleTransport`) →
  fit (`Size` within `SizeLimit`, spent+size within `Passengers`) → a vehicle transport on
  water/shore refuses.
- Unload: deploy, turn, one passenger per pass, cells offered from the transport's rear; a
  bridge-under cell skipped.
- Infantry land on a sub-cell spot (share a cell); vehicles land at cell centre.
- On destruction, passengers try to exit where it stood; one that cannot enter is killed.
- Pip row shows the hold (one pip per space), each colored by `Pip`; `PipScale` sets length.

**Edge cases**
- A carryall lifting a vehicle takes hold directly and asks nothing (bypasses fit checks).
- Carrying passengers suppresses the transport's own crew escape.
- A passenger that can't be placed is put back at the front of the chain in an aircraft context.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/transports.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Passengers (med)

**Confidence** — high.

---

### TS-CORE-056 — Walls, Gates, Wall Towers, Laser Fences

**What** — A wall BuildingType converts to a cell overlay on placement; gates and wall towers
stay structures and stitch into the run. Laser fences are separate energized structures.

**Data keys** — `Wall`, `ToOverlay`, `DamageLevels`, `Strength` (overlay per-hit threshold),
`WallOwner`, `Gate`, `GateStages`, `GateCloseDelay`, `DeployTime`, `WallTower`, `GDIGateOne/Two`,
`NodGateOne/Two`, `LaserFence`, `LaserFencePost`, `High`, `GuardRange`, `Unsellable`,
`Crushable`, `CrushSound`, `FirestormWall`.

**Numbers** — TS `[General]` hack keys: `GDIGateOne=GAGATE_A`, `GDIGateTwo=GAGATE_B`,
`WallTower=GACTWR`, `NodGateOne=NAGATE_A`, `NodGateTwo=NAGATE_B`.
- A wall overlay `Strength` is a per-hit threshold: damage ≥ value advances one stage; below,
  advances only if a random 0..value comes out below the damage. Damage `-1` advances
  unconditionally.
- `DamageLevels` default 1 (first landed hit removes). At `DamageLevels-1` and `DamageLevels>2`,
  each cardinal same-type stage-0 neighbour takes 200 (cascade).
- Isolated segments (connection frame 0) are deleted by a fixed-position rule at six
  `[OverlayTypes]` positions (0 GASAND, 1 CYCL, 2 GAWALL, 3 BARB, 22 FENC, 26 NAWALL).
- Connection frames: 4 bits, one per cardinal; rebuilt touching 5 cells. Gates stitch only
  along the axis of the `[General]` key naming them; wall tower connects from all four sides to
  brick/sandbag only.
- Gate door travel = `DeployTime` minutes each way; close timer `GateCloseDelay` minutes,
  reloaded while anything stands in the footprint.
- Wall gap fill: `GuardRange=5` cells cardinal only (truncated int); three stock IDs pinned at 5.
- Selling a wall returns **no credits**.

**Edge cases**
- A wall with `Wall=yes` and no `ToOverlay=` crashes on placement.
- A wall's owner is a cell-stored house index; map walls are assigned to the nearest active
  `WallOwner=yes` building; `WallOwner` is forced by lobby outside campaigns.
- A soldier set on fire refuses to enter a `Wall` land type / wall-overlay cell.
- A `High=yes` overlay stops projectiles below height 100 that aren't themselves `High=yes`.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/walls-and-gates.md`, `systems/laser-fences.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (high)

**Confidence** — high.

---

### TS-CORE-057 — Route Search / Pathfinding

**What** — A destination is checked against the zone map first; a route is found in two stages
(8×8/4×4/2×2 block corridor, then cell-by-cell A*-like search). The search does **not** price
terrain; it prices the per-step verdict.

**Data keys** — `ThreatAvoidanceCoefficient`, `AvoidThreats`, `BlockagePathDelay`, `PathDelay`,
`CloseEnough`, `Stray`, `IsTrain`, `Landable`, `Passive`.

**Numbers**
- Corridor skips: a train, an object that hasn't entered the playable area or may leave it, or
  either end outside the playable area. A corridor > **500 blocks** is abandoned.
- Cell search cap: 65,527 cells taken up per pass; **10,000** cells taken up on a completed pass
  is treated as failure; **131,072** recorded cells fills the record and yields no route;
  up to 5 passes with struck-out block links.
- Step prices by verdict: clear 1; closed friendly gate 1; moving through 1 or 4; friendly temp
  obstruction 8; enemy destroyable obstruction 20; friendly destroyable 60; cloaked enemy 1000;
  strictly prohibited 10,000 (never paid/added).
- Direction sliver `0.001`–`0.008`; tunnel step = larger of the two mouth distances, no sliver.
- Destination substitution when blocked and beyond `CloseEnough=2.25` (or `Stray=2.0` on a
  team): nearest enterable cell within 6 cells of the straight distance.
- Route straightening: two passes (corner-to-straight; first 20 steps re-plot).
- Route list holds 2,000 entries; a 2,000-cell route overruns it (buffer overflow).

**Edge cases**
- The search is not guaranteed shortest: cells are never reconsidered and the heuristic
  (straight-line distance) can overshoot.
- Bridge-avoidance and cost-multiplier switches are fixed off/1 (dead).
- A prohibited destination gives the route it has, ending beside it; a route of only the
  current cell is rejected.

**Kind** — generic-engine pathfinding.

**Sources**
- `systems/route-search.md` (OpenTS Manual) (high)
- `code/astar.cpp` (OpenTS) (high)

**Confidence** — high.

---

### TS-CORE-058 — Target Selection, Threat Scoring, Retaliation

**What** — Objects scan for targets on certain missions, score candidates by threat/effectiveness,
and may retaliate when damaged.

**Data keys** — `Retaliate`, `Scatter`, `CanPassiveAquire`, `GuardRange`, `Sight`,
`ThreatPosed`, `SpecialThreatValue`, `MyEffectivenessCoefficientDefault`,
`TargetEffectivenessCoefficientDefault`, `TargetSpecialThreatCoefficientDefault`,
`TargetStrengthCoefficientDefault`, `TargetDistanceCoefficientDefault`,
`Dumb*Coefficient`, `EnemyHouseThreatBonus`, `BaseBias`, `DestroyWalls`.

**Numbers** — TS `[General]`:
- `MyEffectivenessCoefficientDefault=200`, `TargetEffectivenessCoefficientDefault=-200`,
  `TargetSpecialThreatCoefficientDefault=200`, `TargetStrengthCoefficientDefault=-200`,
  `TargetDistanceCoefficientDefault=-10`.
- Dumb evaluation: `DumbMyEffectivenessCoefficient=200`, `DumbTargetEffectivenessCoefficient=200`,
  `DumbTargetSpecialThreatCoefficient=200`, `DumbTargetStrengthCoefficient=200`,
  `DumbTargetDistanceCoefficient=-1`.
- `EnemyHouseThreatBonus=400`, `BaseBias=2`, `BaseDefenseDelay=.25` minutes.
- Retaliation: refused if current mission sets `Retaliate=no`; immediate if source in range;
  out of range a computer retaliates from any distance, a human only if source within `Sight`
  plus half a cell. An object that can't retaliate scatters under conditions.
- An `Infiltrate=yes`/engineer's threat scans follow special rules (e.g., engineer skips
  scanning on guard).
- `Thief=yes` widens scan targets.

**Edge cases**
- A warhead with `Webby=yes` in the primary slot and an empty secondary makes retaliation fail
  as soon as damaged by anything it cannot web.
- A cloaked enemy is priced 1000 in pathing; threat scans reject hidden objects outright.
- A computer's easy slot (`[Difficult]` section via inverse) sets `DestroyWalls=no` → no wall
  targeting.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/target-selection.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]` (high)

**Confidence** — high.

---

### TS-CORE-059 — Capture, Sabotage, and Vehicle Theft

**What** — Engineer/agent/C4/vehicle-thief behaviors keyed on infantry flags, resolved on
arrival at a structure or vehicle.

**Data keys** — `Engineer`, `EngineerCaptureLevel`, `C4`, `C4Delay`, `C4Warhead`, `Agent`,
`Infiltrate`, `VehicleThief`, `Thief`, `Capturable`, `Repairable`, `IsMobileWar`,
`BridgeRepairHut`.

**Numbers** — TS `[General]`:
- `C4Delay=.03` minutes (27 frames, ~1.8 s), `C4Warhead=HE`.
- `Engineer` crew type = `ENGINEER`; `Crew=E1`, `Technician=CTECH`, `Disguise=E1`,
  `Paratrooper=E1`, `Pilot=E1`.
- `CrewEscape=50%` chance crew escapes a destroyed vehicle.
- `EngineerCaptureLevel=1` in TS (in FS `EngineerCaptureLevel=1.0`, `EngineerDamage=0.0`).
- Engineer damage (MP option on): `min(Strength − MaxStrength·ConditionRed/2,
  MaxStrength·(1−ConditionRed/2)/2)` forced via `C4Warhead`. At `ConditionRed=0.5` → max
  37.5% bite: 100%→62.5%→25%→captured.
- Survivors: `Cost × SurvivorRate / SurvivorDivisor`, clamped 1–5, divisor doubled for a
  captured structure, 0 for non-`Crewed=yes`; per footprint cell roll 1/3 (never captured, no
  saboteur), 1/2 (no capture, saboteur), 1/9 (captured, no saboteur), 1/8 (captured + saboteur).
  TS `SurvivorRate=.4`, `SurvivorDivisor=100`; FS `SurvivorRate=.1`.

**Edge cases**
- `Infiltrate=no` cannot be written on a `C4=yes` or `Engineer=yes` type (forced on after read).
- A deployed vehicle is treated as a vehicle for the engineer's vehicle branch, so an engineer
  takes a mobile war factory outright regardless of strength/Capturable/alliance.
- A vehicle thief counts against the thief type's `BuildLimit` while the stolen vehicle lives;
  when destroyed the hijacker steps back out (strength 5..half max).
- A demolition charge cannot be defused; a C4 detonation is forced and marks survivorless.
- Capture awards no experience; a captured structure halves future survivors and never returns
  the `[General] Engineer` type.
- `EngineerDamage` is parsed and never consulted (dead); the sabotage cell-destination branch
  is unreachable.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/capture.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[General]`, FS `FIRESTRM.INI` (high)

**Confidence** — high.

---

### TS-CORE-060 — Difficulty Scaling and Handicap Combination

**What** — A campaign carries two difficulty slots (setting and `2−setting`); a section picks
one. Seven multipliers are folded once when a house is given its slot.

**Data keys** — `[Easy]`, `[Normal]`, `[Difficult]` sections with `FirePower`, `Groundspeed`,
`Armor`, `ROF`, `Cost`, `BuildTime`, `RepairDelay`, `DestroyWalls`; country keys `Firepower`,
`Groundspeed`, `Armor`, `ROF`, `Cost`, `BuildTime`; `GameSpeedBias`.

**Numbers** — Combine rules:
- FirePower: campaign = section alone; outside = × country.
- Groundspeed: × `GameSpeedBias`; outside also × country.
- Armor: campaign section alone; outside × country.
- ROF: campaign section alone; outside × country.
- Cost: campaign section alone; outside × country.
- BuildTime: × `GameSpeedBias`; outside × country.
- RepairDelay: taken as written.
- Outside a campaign every human house gets slot 1 regardless of setting.
- A section absent from all files leaves its multipliers at **0** (zero damage/speed/cost;
  armor 0 → damage divided by 0 floors at 1 → near-invulnerable).
- TS `[Easy]`/`[Normal]`/`[Difficult]` sections exist in `RULES.INI` (lines 1729–1754).

**Edge cases**
- A later file carrying `[Difficult]` resets the rest of the block to built-in values.
- A campaign map omitting `PlayerControl=yes` gives the player the computer handicap.
- `MultiplayerAICM=250,200,100` credit multiplier by difficulty.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/difficulty.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[Easy]/[Normal]/[Difficult]` (high)

**Confidence** — high.

---

### TS-CORE-061 — Starting Forces and Skirmish Setup

**What** — At match start, each house receives a starting force at its start waypoint; crates
scatter if requested; computer houses take credit multipliers.

**Data keys** — `[MultiplayerDefaults] Money`, `MaxMoney`, `Bases`, `TiberiumGrows`, `Crates`,
`CaptureTheFlag`, `ShadowGrow`, `InitialVeteran`, `MultiplayerAICM`, `MultiMCV`.

**Numbers** — TS `[MultiplayerDefaults]`:
- `Money=10000`, `MaxMoney=10000`, `Bases=yes`, `TiberiumGrows=yes`, `Crates=yes`,
  `CaptureTheFlag=no`, `ShadowGrow=no`.
- `InitialVeteran=yes` makes randomly drawn starting units/infantry elite (per veterancy doc).
- Starting forces drawn from a random selection; `MultiMCV=yes` drops the construction-yard
  test from ownership.
- A generated map's multiplayer fixups run only after generation completes.

**Edge cases**
- A house with `InitialVeteran` and `Trainable` starts elite; the crate path also checks
  `Trainable`.
- `MaxMoney` caps starting money; in-game credit cap separate.

**Kind** — generic-engine + title-data.

**Sources**
- TS `RULES.INI` `[MultiplayerDefaults]` (high)
- `systems/map-generation.md`, `systems/veterancy.md` (OpenTS Manual) (high)

**Confidence** — high; med (exact starting-force composition is map/scenario-driven).

---

### TS-CORE-062 — Random Map Generation (bounds and passes)

**What** — A `.SED` seed carries 20 settings; the generator lays terrain, water, cliffs, roads,
beliefs, Tiberium, and one start position per player. Passes run in a fixed order.

**Data keys** — `[RandomMap]` `Width`, `Height`, `NumPlayers`, `Biome`, `Time`, `WaterAmount`,
`RegionSize`, `Accessibility`, `Ruggedness`, `Vegetation`, `UrbanPresence`, `Tiberium`,
`TiberiumLayout`, `UseBlueTiberium`, `TiberiumWildlife`, `VeinholeMonsters`, `UseIonStorms`,
`UseTransitions`, `Seed`, `Description`.

**Numbers / rules**
- Playfield written 4 cells wider and 12 taller than the play area; play area inset 2 columns
  and 5 rows. Starting ground level 4.
- Water budget = `WaterAmount × playable area × biome factor + 100`; river/lake each up to 10
  attempts.
- Region-size splitting repeats until no region exceeds `RegionSize`.
- Start points: 15 candidate cells per player needing a 10×10 road-capable block, ≥4 cells inside
  the play area; first `NumPlayers` of the spread become waypoints; each start floods exactly
  **400** clear cells; failure retries from the next RNG state (unbounded).
- Veinholes: at most 200 attempts total.
- Tiberium layout fields grown; per-player compensating field size =
  `(playerMeanDist − minMeanDist)×15 + 500`.
- Ground cover: four chances (green, rough, sand, woods), `Vegetation` scales green/woods, ×10
  along shorelines.

**Edge cases**
- A seed file's settings are **not range-checked**; `Biome`/`NumPlayers`/`Time` index fixed
  tables and can crash.
- `UseTransitions` is excluded from the saved-seed digest.
- Tundra uses arctic water/ice and skips region splitting (no generated cliffs); taiga uses
  ordinary water and no ice.
- `Description` is read by no pass.

**Kind** — generic-engine generator + title-data (settings).

**Sources**
- `systems/map-generation.md`, `formats/map-seed.md` (OpenTS Manual) (high)
- https://modenc.renegadeprojects.com/Random_map_generator (med)

**Confidence** — high.

---

### TS-CORE-063 — Object Destruction, Debris, and Survivors

**What** — A destroying hit runs a shared step (voice, radio break, Tiberium spread, water exit,
wreckage, collateral blast) then a kind-specific step.

**Data keys** — `MaxDebris`, `DebrisTypes`, `MetallicDebris`, `Explodes`, `CollateralDamageCoefficient`,
`DeathFrames`, `MaxDeathCounter`, `CrewEscape`, `Crewed`, `SurvivorRate`, `SurvivorDivisor`,
`ScrapMetal`, `ScrapExplosion`, `Wake`, `SplashList`, `InfantryExplode`, `DeadBodies`,
`TiberiumExplosive`, `Storage`.

**Numbers**
- Water exit: object ≤10 leptons above ground, falling, land type water → skip debris/blast;
  leave wake + splash.
- Wreckage thrown by `MaxDebris` from `DebrisTypes` (or `MetallicDebris` 20 leptons above).
- A vehicle with `DeathFrames` is put to 1 strength and plays a wreck animation until
  `MaxDeathCounter`; each further hit re-books the kill (exploit).
- Structure destruction: central mark (1/2 scorch vs crater) for ≥2×2; per-cell even chance of
  `SmallFire` (and half of those a `LargeFire`); per-cell `Explosion` entry; spills stored
  Tiberium; survivors from footprint walk.
- Survivor count as in TS-CORE-059; a count of 0 abandons the walk (no footprint marks).
- Aircraft in the air crash with a fixed **1000** points of area damage through `C4Warhead`,
  no kill credited.
- `ShakeScreen=400` divides object strength to decide a screen shake.

**Edge cases**
- A delayed-removal structure (`Explodes=yes` or mid-decimation) runs the survivor/scarring walk
  twice (double soldiers/marks).
- A destroyed harvester's cargo spills inside the collateral blast; a harvester that is neither
  `Explodes=yes` nor carrying the ability keeps its load.
- A terrain object brought to zero starts crumbling and is removed same step; a
  `SpawnsTiberium=yes` tree substitutes a 100-point blast + chain reaction.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/destruction-and-debris.md` (OpenTS Manual) (high)
- TS `RULES.INI` `[AudioVisual]`, `[CombatDamage]`, `[General]` (high)

**Confidence** — high.

---

### TS-CORE-064 — Aircraft Operations and Landing Zones

**What** — Aircraft reserve their destination cell as a landing zone while approaching; hostile
reservations do not reserve. Unloading, repairs, and no-ammo orders have special rules.

**Data keys** — `Landable`, `PadAircraft`, `Helipad`, `UnitReload`, `ReloadRate`, `Sight`.

**Numbers**
- A landing-zone scan rejects a cell already holding a foot object; an actual occupant blocks
  regardless of ownership. A destination held by another active aircraft blocks only if same
  house or mutually allied.
- A loaded aircraft cannot unload while any building occupies its cell (including helipad/repair).
- A passenger aircraft removes one passenger per placement attempt; an unplaceable passenger is
  returned to the front of the chain.
- A player cannot order an attack from a grounded, no-ammo aircraft.

**Edge cases**
- A carryall does not treat the vehicle it is collecting as a blocker.
- During an ion storm an aircraft produced by a factory is placed on a nearby free cell rather
  than docked.

**Kind** — generic-engine + title-data.

**Sources**
- `systems/aircraft-operations.md` (OpenTS Manual) (high)
- TS `RULES.INI` `PadAircraft`, `SeparateAircraft` (high)

**Confidence** — high.

---

### TS-CORE-065 — Tiberium/Crate/Scatter Misc. Simulation Mechanics

**What** — Additional simulation behaviors not covered above.

**Data keys** — `[General]` `IonStorms`, `Visceroids`, `Meteorites`, `LargeVisceroid`,
`SmallVisceroid`, `TiberiumTransmogrify`, `TreeStrength`, `TreeFlammability`, `WindDirection`,
`MaxWaypointPathLength`, `ChargeToDrainRatio`, `DamageToFirestormDamageCoefficient`,
`AllowShroudedSubteranneanMoves`, `AircraftFogReveal`, `BridgeVoxelMax`,
`Spotlight*`, `RevealTriggerRadius`, `CameraRange`, `AIIonCannon*`, `[IQ]`.

**Numbers** — TS `[General]` notable values:
- `TreeStrength=200`, `TreeFlammability=.05`, `WindDirection=1`,
  `MaxWaypointPathLength=15`, `CameraRange=9`, `RevealTriggerRadius=9`.
- `IonLightningFrequency=10`, `IonLightningRandomness=90`, `IonLightningDamage=500`.
- `Visceroids=no`, `Meteorites=no`, `TiberiumTransmogrify=40`, `LargeVisceroid=VISC_LRG`,
  `SmallVisceroid=VISC_SML`.
- `SpotlightSpeed=.015`, `SpotlightMovementRadius=2000`, `SpotlightLocationRadius=1000`,
  `SpotlightAcceleration=.0025`, `SpotlightAngle=.5`.
- `[IQ]` section (lines 1553–1584) gates AI superweapons, production, guard area, repair/sell,
  auto-crush, scatter, content scan, aircraft, harvester, sell-back.
- `ChargeToDrainRatio=.333`, `DamageToFirestormDamageCoefficient=.1`.
- Firestorm defense halves via `DamageToFirestormDamageCoefficient`: incoming damage converts to
  charge drain on the `UseChargeDrain` weapon.

**Edge cases**
- `CameraRange`/`BridgeVoxelMax`/`WorstLowPowerBuildRateCoefficient`/`BestLowPowerBuildRateCoefficient`
  are parsed and unused.
- `ChargeToDrainRatio` cycle: firing moves a charge-draining weapon to discharged and rescales
  the timer by the ratio; switching off early restores proportional charge.

**Kind** — generic-engine + title-data.

**Sources**
- TS `RULES.INI` `[General]`, `[IQ]` (high)
- `systems/superweapons.md`, `systems/power.md`, `systems/spotlight`-related key pages
  (OpenTS Manual) (high)

**Confidence** — high (values); med (some dead-setting classifications).

---

### TS-CORE-066 — Firestorm Add-on Deltas (full)

**What** — Firestorm patches base TS rules via `FIRESTRM.INI`, read after `RULES.INI`; each
section it carries is re-read from built-in defaults. It adds units, warheads, superweapon
`DropPod`, the levitation locomotor, and retunes values.

**Data keys** — FS `FIRESTRM.INI` sections; new warheads `WebMass`, `LIMPY`, `CoreDefPlasmaWH`;
new superweapon `DropPodSpecial`; `[LEVITATION]`; `Webby`/`WebDuration`/`WebDurationVariation`/
`WebRadius`; `LimpetFactor`.

**Numbers** — FS `[General]` deltas:
- `DropPodInfantryMinimum=5` (was 3), `DropPodInfantryMaximum=8` (was 5),
  `DropPodWeapon=DropGun`.
- `BallisticScatter=2.0` (was 1.5), `EngineerCaptureLevel=1.0`, `EngineerDamage=0.0`,
  `SurvivorRate=.1` (was .4), `SurvivorDivisor=100`.
- Veteran: `VeteranRatio=5.0` (was 10.0), `VeteranCombat=.50`, `VeteranArmor=.50`,
  `VeteranROF=.30`.
- `PrerequisiteFactory=GAWEAP,NAWEAP,DGWEAP,DNWEAP`; `PrerequisiteGDIFactory=GAWEAP,DGWEAP`;
  `PrerequisiteNodFactory=NAWEAP,DNWEAP`.
- `[AudioVisual] WebbedInfantry=WEBGUY`; `DropPod=DROPPOD,DROPPOD2,DROPPODY,DROPPODY2`;
  `[AI] BuildWeapons=...`.
- Land sections gain `Creep=` values (see TS-CORE-010).
- `[LEVITATION]` block as in TS-CORE-029.
- `WebMass` warhead: `Webby=true`, `WebDuration=600` (was 300), `WebDurationVariation=25`,
  `WebRadius=2`, `Particle=WebSys`, `Spread=4`, `Verses=600,0,0,0,0`.
- `LIMPY`: `LimpetFactor=35`, `Verses=0,100,100,100,100`.
- `IsMobileEMP=true` units added.

**Edge cases**
- FS warheads list is `1=WebMass,2=LIMPY,3=CoreDefPlasmaWH` — an addition, not a replacement.
- The FS `[Warheads]` list in the archived INI is incomplete relative to the engine enum
  (`Meteorite`, `RPG`, `Shard`, `Fire2`, `Nuke`, `Stinger`, `Super2`, `MobileEMPulse`); these
  resolve on first use.
- Firestorm adds the `Creep` speed type used by the levitation locomotor and some units.

**Kind** — title-data on the generic systems.

**Sources**
- FS `FIRESTRM.INI` (full) (high)
- `code/warhead.hh` (OpenTS) — Firestorm warhead enum additions (high)

**Confidence** — high (deltas); med (incomplete FS warhead registry).

---

### TS-CORE-067 — Dead / Parsed-But-Unused Settings Ledger

**What** — Settings the engine parses into rules but never consults (critical for a faithful
reimplementation to distinguish from live data).

**Data keys / list**
- `[General]`: `WorstLowPowerBuildRateCoefficient`, `BestLowPowerBuildRateCoefficient`,
  `IonStormDuration`, `TiberiumStrength`, `TiberiumTransmogrify`, `BlendedFog`,
  `CameraRange`, `BridgeVoxelMax`, `VeinholeMonsterStrength`, `VeinGrowthRate`,
  `PlayerAutoCrush`, `AutoCrush` (per type), `TooBigToFitUnderBridge` (movement), `FreeMCV`,
  `StatisticTimeInterval`, `NamedCivilians` (partial).
- Warhead: `IsLocomotor`/`Locomotor` (RA2-era), `WallAbsoluteDestroyer` (RA2-era).
- Building: `RadarInvisible`, `IsMobileStealth` (only a deployed-vehicle marker).
- Difficulty: `BuildDelay`, `BuildSlowdown`.
- General team: `NukeProjectile`, `NukeDown`, `EMPulseWarhead`, `EMPulseProjectile`.
- Overlay/bridge: `BridgeVoxelMax`.
- `PlayerScatter`/`PlayerReturnFire` are live only in specific conditions; `ProneDamage` in
  `[CombatDamage]` is commented out in TS.

**Numbers** — N/A.

**Edge cases**
- Some are dead only because a specific engine feature was cut (e.g. gap generator, GPS reveal,
  radar jamming) and the code remains but never compiles.
- A faithful remake should mark these explicitly so that "setting does nothing" is intentional,
  not a bug.

**Kind** — generic-engine bookkeeping.

**Sources**
- OpenTS Manual key pages marked `no_effect: true` (e.g. `keys/bridgevoxelmax.md`,
  `keys/playerautocrush.md`, `keys/radarinvisible.md`) (high)
- `systems/movement-and-terrain.md`, `systems/power.md`, `systems/superweapons.md`,
  `systems/tiberium.md` (OpenTS Manual) (high)

**Confidence** — high (per reconstructed source); med (original-engine exact dead-set).

---

## Coverage Checklist

| # | Scope item | Covered by |
|---|---|---|
| 1 | Isometric grid: tile px, cell↔lepton, lepton unit, coord system, bounds/diamonds | TS-CORE-001, 002, 003, 007 |
| 2 | Sub-cell/slot occupancy per locomotor; foundation vs footprint; bibs | TS-CORE-003, 004, 005, 006, 013 |
| 3 | Height: grades, cliffs, ramps, slope/tilt, cliff collapse | TS-CORE-007, 008 |
| 4 | Full land-type list + per-locomotor speed/passability | TS-CORE-009, 010, 011, 012, 013 |
| 5 | Shroud vs fog: all params, sight, ally reveal | TS-CORE-043, 044, 045, 046 |
| 6 | Damage model, armor classes, full warhead list w/ Verses, clamps, 0% gating | TS-CORE-014–021 |
| 7 | Full projectile type list + params | TS-CORE-022, 023, 024 |
| 8 | ROT/turret; flight/altitude; [JumpjetControls] | TS-CORE-026, 027, 028, 029 |
| 9 | Power: supply/demand, coefficients, DamageDelay, superweapon gating | TS-CORE-030, 031 |
| 10 | Veterancy: levels, ratio, bonus tags, EliteAbilities, pip display | TS-CORE-032–035 |
| 11 | Crates: full [CrateRules] | TS-CORE-036, 037 |
| 12 | [Maximums], object limits, sim timing/tick units | TS-CORE-038, 039 |
| 13 | Crushing/weight; ice cracking/drowning; bridges | TS-CORE-040, 041, 042 |
| 14 | Any other simulation mechanic | TS-CORE-043–067 (shroud/fog/sight, cloak, Tiberium, ion storms, EMP, veins, superweapons, repair, production, transports, walls, route search, targeting, capture, difficulty, starting forces, map gen, destruction, aircraft, Firestorm, dead settings) |

Also enumerated: all 5 armor classes, all 12 land types, all 8 speed types, all 10 movement
zones, all 10 locomotor GUIDs, all 24 TS + FS warheads with Verses, all TS projectile sections,
all 19 crate results, all 18 veteran abilities, all 7 superweapon behaviors, all 22 building
foundations.

---

## Open Questions and Uncertainties

1. **Reconstructed vs original source.** The OpenTS manual/source is a community reconstruction.
   Structural formulas and enum layouts are high confidence; a small number of edge behaviors
   (rounding of `Spread` steps, exact original default of `LeptonsPerSightIncrease`,
   `Crush` default 1.8 shipped vs 1.5 manual) may differ from the 2.03 binary. Each is flagged
   inline.
2. **`LeptonsPerSightIncrease` conflict.** TS `[General]` ships `2000`; the OpenTS manual text
   describes an engine default of `50` (and "one whole level buys two increments"). The shipped
   value is authoritative for TS; the internal default constant is unresolved.
3. **`Crush` default conflict.** TS `[CombatDamage]` ships `Crush=1.8`; the OpenTS key page
   lists the engine default as `1.5`. Use `1.8` for TS, `1.5` only if reconstructing the
   engine constant.
4. **`IonLightningFrequency` scaling.** OpenTS says the compared threshold is `10×` the written
   value (so the key is a tenth of the real threshold). ModEnc's ion-storm description is thin;
   exact vanilla tuning not independently verified.
5. **Full original projectile defaults.** The shipped `RULES.INI` only carries projectile
   overrides; base `Speed`, `ROT`, `Elasticity` etc. live in the compiled-in defaults. Exact
   original defaults for un-overridden projectiles are medium confidence.
6. **Crate `[Powerups]` omission behavior.** The manual states a partial `[Powerups]` section
   zeroes every omitted result; the shipped file lists all 19, so this is only observable in
   mods. Confidence medium on whether this is original or an OpenTS reconstruction quirk.
7. **`CoreDefPlasmaWH` and remaining FS warheads.** The FS `[Warheads]` registry in the archived
   INI is incomplete relative to the engine enum; exact Verses for the FS-only warheads
   (`Meteorite`, `CoreDefPlasmaWH`, `Stinger`, `Super2`, `MobileEMPulse`) were not captured.
8. **Original `[Maximums]` set.** The shipped TS `[Maximums]` holds only `Players`; older
   TD/RA2 maximum keys (`Aircraft`, `Buildings`, `Units`, `Infantry`, `Vessels`, `Tiberiums`,
   `Terrain`, `Warheads`, etc.) are absent, but whether the TS binary still accepted them is
   unverified.
9. **Dead-code classification.** A handful of "parsed but unused" settings are asserted by the
   OpenTS reconstruction; some may have had a live effect in the original binary that the
   reconstruction did not yet port. Treat the TS-CORE-067 ledger as a to-verify list.
10. **Exact `3x3Refinery` / `6x4` cell maps.** The OpenTS manual describes the irregular
    shapes; the precise per-cell lists should be validated against the original art geometry.

---

*Document compiled from web sources only. Every claim cites a URL or reconstructed-source path
in its block. Where two sources conflict, both are stated and the shipped INI is preferred.*

