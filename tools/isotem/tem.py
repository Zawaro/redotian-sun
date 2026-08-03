"""Parse Tiberian Sun / Red Alert 2 .tem (TMP) isometric terrain template files.

The .tem container embeds the tile art plus a per-cell header that carries the
tile's gameplay footprint: each occupied cell's height (in lattice steps), land
type, and slope type. This parser extracts that footprint so the game's
TerrainObject catalog can be rebuilt from real TS tile data.

Format (verified against modenc.renegadeprojects.com/TMP and XCC's TMP_TS_Format):

    FileHeader (16 bytes):
        int32 BlockWidth         cells wide
        int32 BlockHeight        cells tall
        int32 BlockImageWidth    48 (iso canvas width, px)
        int32 BlockImageHeight   24 (iso canvas height, px)

    Index (BlockWidth*BlockHeight int32s, row-major x + y*width):
        0                    = empty cell (no tile here)
        otherwise            = absolute file offset of that cell's 52-byte header

    TileCellHeader (52 bytes, at each non-zero index offset):
        int32 X, Y                       pixel pos of the cell image in the tile canvas
        int32 ExtraDataOffset            rel. to header start
        int32 ZDataOffset                rel. to header start
        int32 ExtraZDataOffset           rel. to header start
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

Heights are lattice step counts. Flat and cliff cells sit on multiples of 4
(0, 4, 8, ...); ramp/clat/slope cells legitimately use intermediate steps 1-3
for their climbing surface. Only the footprint fields (grid dims + per-cell
height/land/slope) are exposed; the embedded image / heightmap blobs are
skipped.
"""

from __future__ import annotations

import argparse
import struct
from dataclasses import dataclass, field
from pathlib import Path

HEADER_STRUCT = struct.Struct("<4i")
INDEX_STRUCT = struct.Struct("<i")
# 9 int32 + bitfield + pad3 + h + land + slope + TL radar(3) + BR radar(3) + pad3
CELL_STRUCT = struct.Struct("<9i 4B 3B 3B 3B 3B")

CELL_SIZE = 52

# Known surface ids seen in .tem tiles. 15 (0x0F) is Cliff/Rock per ModEnc.
LAND_TYPE_NAMES = {
    0: "clear",
    15: "rock",
}


@dataclass
class Cell:
    x: int
    y: int
    height: int
    land_type: int
    slope: int
    extra_x: int = 0
    extra_y: int = 0
    extra_width: int = 0
    extra_height: int = 0


@dataclass
class Tile:
    path: Path
    width: int
    height: int
    image_width: int
    image_height: int
    cells: dict = field(default_factory=dict)  # (x, y) -> Cell (occupied cells only)

    @property
    def occupied(self) -> list[Cell]:
        return list(self.cells.values())


def land_type_name(value: int) -> str:
    return LAND_TYPE_NAMES.get(value, str(value))


def parse_tem(path: str | Path) -> Tile:
    """Parse a .tem file and return its Tile footprint."""
    path = Path(path)
    data = path.read_bytes()
    if len(data) < HEADER_STRUCT.size:
        raise ValueError(f"{path}: too small to be a .tem file ({len(data)} bytes)")

    width, height, image_width, image_height = HEADER_STRUCT.unpack_from(data, 0)
    if width <= 0 or height <= 0 or width * height > 256:
        raise ValueError(f"{path}: implausible grid {width}x{height}")

    tile = Tile(
        path=path,
        width=width,
        height=height,
        image_width=image_width,
        image_height=image_height,
    )

    index_offset = HEADER_STRUCT.size
    for y in range(height):
        for x in range(width):
            (cell_offset,) = INDEX_STRUCT.unpack_from(data, index_offset + (x + y * width) * 4)
            if cell_offset == 0:
                continue  # empty cell
            if cell_offset + CELL_SIZE > len(data):
                raise ValueError(f"{path}: cell ({x},{y}) offset {cell_offset} out of range")
            raw = data[cell_offset : cell_offset + CELL_SIZE]
            vals = CELL_STRUCT.unpack(raw)
            (
                _x,
                _y,
                _extra_off,
                _z_off,
                _extra_z_off,
                extra_x,
                extra_y,
                extra_w,
                extra_h,
                _bitfield,
                _pad0,
                _pad1,
                _pad2a,
                height_b,
                land_type,
                slope,
                _tl0,
                _tl1,
                _tl2,
                _br0,
                _br1,
                _br2,
                _pad3a,
                _pad3b,
                _pad3c,
            ) = vals
            tile.cells[(x, y)] = Cell(
                x=x,
                y=y,
                height=height_b,
                land_type=land_type,
                slope=slope,
                extra_x=extra_x,
                extra_y=extra_y,
                extra_width=extra_w,
                extra_height=extra_h,
            )
    return tile


def dump(tile: Tile) -> str:
    """Render a tile's footprint as a grid for humans."""
    lines = [f"{tile.path.name}: {tile.width}x{tile.height} cells, {len(tile.occupied)} occupied"]
    lines.append("        " + "  ".join(f"x={x}" for x in range(tile.width)))
    for y in range(tile.height):
        row = f"y={y}  "
        for x in range(tile.width):
            cell = tile.cells.get((x, y))
            if cell is None:
                row += "   .   "
            else:
                row += f"{land_type_name(cell.land_type):5s}@{cell.height:2d}"
        lines.append(row)
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Parse a TS .tem terrain template file.")
    parser.add_argument("files", nargs="*", help=".tem files to parse")
    parser.add_argument("--check", action="store_true", help="run the self-check against cliff01.tem")
    args = parser.parse_args(argv)

    if args.check:
        return run_self_check()

    for f in args.files:
        print(dump(parse_tem(f)))
        print()
    return 0


def run_self_check() -> int:
    """Verify the parser against the known cliff01.tem footprint."""
    import os

    candidates = [
        os.environ.get("TS_ISOTEM_DIR"),
        "/mnt/work2/CnC Projects/Tiberian Sun/isotem",
    ]
    src = next((c for c in candidates if c and Path(c, "cliff01.tem").exists()), None)
    if src is None:
        print("self-check: cliff01.tem not found (set TS_ISOTEM_DIR to the isotem dir)")
        return 1

    tile = parse_tem(Path(src, "cliff01.tem"))
    ok = True

    def expect(got, want, msg):
        nonlocal ok
        if got != want:
            ok = False
            print(f"FAIL {msg}: got {got!r}, want {want!r}")

    expect((tile.width, tile.height), (2, 3), "cliff01 grid")
    expect([(c.x, c.y) for c in tile.occupied], [(0, 0), (0, 1), (1, 1), (1, 2)], "cliff01 occupied cells")
    expect([c.height for c in tile.occupied], [4, 0, 4, 0], "cliff01 heights")
    expect({c.land_type for c in tile.occupied}, {15}, "cliff01 land types (0x0F = rock)")
    expect({c.slope for c in tile.occupied}, {0}, "cliff01 slopes")
    print("self-check PASS" if ok else "self-check FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
