# TS .tem terrain template research

Reverse-engineered notes on the original Tiberian Sun `isotem` terrain template
files (`.tem`), the source data for `tools/isotem/`. The `.tem` files live
outside the repo (e.g. `/mnt/work2/CnC Projects/Tiberian Sun/isotem/`); this
directory keeps the parsing tools and the decoded footprint catalog
(`isotem_catalog.json`).

## File format

A `.tem` is a TMP container that embeds the tile's isometric art plus a
per-cell header carrying the gameplay footprint. Layout:

```
FileHeader (16 bytes):
    int32 BlockWidth          cells wide
    int32 BlockHeight         cells tall
    int32 BlockImageWidth     48 (iso canvas width, px)
    int32 BlockImageHeight    24 (iso canvas height, px)

Index (BlockWidth*BlockHeight int32s, row-major x + y*width):
    0                   empty cell (no tile here)
    otherwise           absolute file offset of that cell's 52-byte header

TileCellHeader (52 bytes, at each non-zero index offset):
    int32 X, Y                       pixel pos of the cell image in the tile canvas
    int32 ExtraDataOffset            relative to header start
    int32 ZDataOffset                relative to header start
    int32 ExtraZDataOffset           relative to header start
    int32 ExtraX, ExtraY             pixel pos of the vertical-face image
    int32 ExtraWidth, ExtraHeight    size of the vertical-face image
    u8    Bitfield                   0xCB = has extra + z data
    u8    padding[3]                 0xCD
    u8    Height                     cell height in lattice steps
    u8    LandType                   surface type id (0x0F = Cliff/Rock)
    u8    SlopeType                  0 = flat
    RGB   TopLeftRadarColor
    RGB   BottomRightRadarColor
    u8    padding2[3]                0xCD

Per cell, immediately following its header:
    576 bytes  normal image (iso diamond)
    576 bytes  ZData (per-pixel height map)
    W*H bytes  extra graphics (vertical cliff face)
    W*H bytes  ExtraZData (height map of the face, 0xCD = no-data fill)
```

### Heights

`Height` is a lattice step count. Flat and cliff cells sit on multiples of 4
(0, 4, 8, ...) — a cliff rises a full 4-step tier. **Ramp, clat, and slope
cells legitimately use intermediate steps 1–3** for their climbing surface; do
not assume heights are always multiples of 4.

### Observed surface ids

| id | name | where seen |
|----|------|------------|
| 13 | clear / slope surface | clear, slope, ramp edge strip |
| 14 | clear (transition) | clat tiles, slope17–20 |
| 15 | rock (0x0F) | cliff / wcliff / ramp walls — all cliff cells, including base cells |

### Worked example — `cliff01.tem`

Grid **2×3**, 4 occupied cells in a diagonal staircase (all land 15 / rock):

| | x=0 | x=1 |
|----|-----|-----|
| y=0 | rock @ 4 | — |
| y=1 | rock @ 0 | rock @ 4 |
| y=2 | — | rock @ 0 |

## Tools

### `cli.py` — footprint dumper

```
python tools/isotem/cli.py <file.tem> ...    # print grid + heights + land types
python tools/isotem/cli.py --check           # framework-free self-check vs cliff01
```

The self-check asserts the known `cliff01` footprint (2×3, heights 4/0/4/0,
land 0x0F) and exits non-zero on mismatch. It looks for `cliff01.tem` in
`$TS_ISOTEM_DIR` or the local TS install path.

### `catalog.py` — rotation-only shape-family extraction

Batch-parses every cliff/wcliff/clat/ramp/slope/clear/dcliff `.tem` under a
source directory and clusters tiles into shape families under **90° rotation
only** — mirror variants stay distinct base shapes (`ramp01` ≠ `ramp02`).
Emits `isotem_catalog.json` (per-family base, kind, dims, members, per-cell
`x,y,height,land,slope`) and `tile_lookup.json` (per-cell corner signatures +
the reverse corner-pattern map used by the engine's tile resolver).

```
python tools/isotem/catalog.py [SOURCE_DIR] [--out PATH] [--lookup PATH]
```

### `generate_tres.py` — four-direction TerrainObject generation

Reads `isotem_catalog.json` and writes one `TerrainObject` `.tres` per
directional variant — every base family × 4 rotations (`<base>_n/_e/_s/_w`) —
with baked per-cell `corners`, a derived `crease` diagonal, `land`, and
optional `slope` provenance. Shared art is rotated by the variant's suffix.

```
python tools/isotem/generate_tres.py [--catalog PATH] [--out DIR]
```
