"""Tiberian Sun bridge terrain (.tem) parsing and end-cap derivation.

The theater tilesets `Ovrps` (`BridgeSet`, road) and `Tovrps`
(`TrainBridgeSet`, rail) carry the bridge footprints; `temperat.ini`
`[General]` maps role keys (`BridgeTopLeft1/2`, `BridgeTopRight1/2`,
`BridgeBottomLeft1/2`, `BridgeBottomRight1/2`, `BridgeMiddle1/2`) to set
indices. Each role has a clear (suffix `1`) and a water (suffix `2`) art
variant that share geometry. This module keys the tiles by that role map and
derives the directional end-cap footprint: a three-wide road/rail cut at deck
grade `4`, `rock` banks at grade `4`, and `rock` base cells at grade `0`.

A deck lane is land `11`/`12` (road) or `6` (railroad, a rail bridge's middle
lane); banks/base are land `15` (rock). The generated `cliff_bridge_end_*` /
`cliff_rail_bridge_end_*` TerrainObjects map those TS surfaces to the
registered game land ids (`road`, `railroad`, `cliff`).

The low/high/rail overlay atlases (`bridge.tem`, `railbrdg.tem`, `lobrdg*.tem`)
are pure art: a `u16 0, u16 width, u16 height, u16 frameCount` header describes
them. No pixels are imported.
"""

from __future__ import annotations

import argparse
import os
import re
import struct
from pathlib import Path

from tem import Cell, Tile, parse_tem

DEFAULT_ISOTEM_DIR = "/mnt/work2/CnC Projects/Tiberian Sun/isotem"
DEFAULT_INI = "/mnt/work2/CnC Projects/Tiberian Sun/temperat.ini"

# [General] role key -> (clear variant key, water variant key).
BRIDGE_ROLES = {
    "TopLeft": ("BridgeTopLeft1", "BridgeTopLeft2"),
    "TopRight": ("BridgeTopRight1", "BridgeTopRight2"),
    "BottomLeft": ("BridgeBottomLeft1", "BridgeBottomLeft2"),
    "BottomRight": ("BridgeBottomRight1", "BridgeBottomRight2"),
    "Middle": ("BridgeMiddle1", "BridgeMiddle2"),
}

# Deck/bank surface ids seen in the bridge sets.
ROAD_LAND_IDS = frozenset({11, 12})
RAILROAD_LAND_ID = 6
DECK_LAND_IDS = ROAD_LAND_IDS | {RAILROAD_LAND_ID}
ROCK_LAND_ID = 15

# TS surface id -> registered game LandType id (games/ts/land_types/). TS has no
# separate "rock" land type; its rock/cliff surface (15) maps to the registered
# `cliff` type, matching the other cliff terrain objects.
LAND_MAP = {
    6: "railroad",
    11: "road",
    12: "road",
    14: "clear",
    15: "cliff",
}

DECK_GRADE = 4
BASE_GRADE = 0
LANES = 3
LANE_WIDTH_PX = 48

# Overlay atlas header: reserved(0), width, height, frameCount.
ATLAS_HEADER = struct.Struct("<4H")

DIRECTIONS = ["n", "e", "s", "w"]


def parse_roles(ini_path: str | Path) -> dict[str, int]:
    """`temperat.ini` `[General]` bridge role keys -> set index."""
    text = Path(ini_path).read_text(errors="replace")
    keys = [key for pair in BRIDGE_ROLES.values() for key in pair]
    values: dict[str, int] = {}
    for key in keys:
        match = re.search(rf"^\s*{re.escape(key)}\s*=\s*(\d+)\s*$", text, re.MULTILINE)
        if match:
            values[key] = int(match.group(1))
    return values


def load_set(src_dir: str | Path, prefix: str, roles: dict[str, int]):
    """Role -> {1: tile name, 2: tile name} and tile name -> Parsed Tile."""
    src = Path(src_dir)
    role_tiles: dict[str, dict[int, str]] = {}
    tiles: dict[str, Tile] = {}
    for role, (clear_key, water_key) in BRIDGE_ROLES.items():
        role_tiles[role] = {}
        for suffix, key in ((1, clear_key), (2, water_key)):
            index = roles.get(key)
            if index is None:
                continue
            name = f"{prefix}{index:02d}"
            path = src / f"{name}.tem"
            if not path.exists():
                continue
            if name not in tiles:
                tiles[name] = parse_tem(path)
            role_tiles[role][suffix] = name
    return role_tiles, tiles


def read_atlas_header(path: str | Path) -> tuple[int, int, int]:
    """Return (width, height, frame_count) of a bridge overlay art atlas."""
    data = Path(path).read_bytes()
    if len(data) < ATLAS_HEADER.size:
        raise ValueError(f"{path}: too small to be a bridge atlas ({len(data)} bytes)")
    reserved, width, height, frames = ATLAS_HEADER.unpack_from(data, 0)
    if reserved != 0:
        raise ValueError(f"{path}: unexpected atlas reserved word {reserved}")
    return width, height, frames


def _rows(tile: Tile) -> dict[int, dict[int, Cell]]:
    rows: dict[int, dict[int, Cell]] = {}
    for cell in tile.occupied:
        rows.setdefault(cell.y, {})[cell.x] = cell
    return rows


def find_cut_row(tile: Tile):
    """The tile row carrying the deck-edge cut: a contiguous run of at least
    `LANES` deck cells at deck grade, flanked on both sides by grade-4 rock.
    Returns (y, [cells left..right]) or None."""
    for y in sorted(_rows(tile)):
        row = _rows(tile)[y]
        deck = sorted(x for x, c in row.items()
                      if c.land_type in DECK_LAND_IDS and c.height == DECK_GRADE)
        if len(deck) < LANES or deck[-1] - deck[0] + 1 != len(deck):
            continue
        left = row.get(deck[0] - 1)
        right = row.get(deck[-1] + 1)
        if left is None or right is None:
            continue
        if (left.land_type == ROCK_LAND_ID and right.land_type == ROCK_LAND_ID
                and left.height == DECK_GRADE and right.height == DECK_GRADE):
            return y, [row[x] for x in range(deck[0] - 1, deck[-1] + 2)]
    return None


def find_base_row(tile: Tile):
    """The lowest all-rock grade-0 row, used as the end's base course."""
    for y in sorted(_rows(tile), reverse=True):
        row = _rows(tile)[y]
        if all(c.land_type == ROCK_LAND_ID and c.height == BASE_GRADE for c in row.values()):
            xs = sorted(row)
            return [row[x] for x in range(xs[0], xs[-1] + 1)]
    return None


def derive_end(tile: Tile):
    """Derive the directional end footprint from a real end tile: the cut row
    (three deck lanes + grade-4 rock banks) becomes local row z=0, the base row
    (grade-0 rock) becomes local row z=1. Returns (cells, width, height) where
    each cell is (x, z, height, land_id), or None."""
    cut = find_cut_row(tile)
    base = find_base_row(tile)
    if cut is None or base is None:
        return None
    _, cut_cells = cut
    all_cells = list(cut_cells) + list(base)
    min_x = min(c.x for c in all_cells)
    width = max(c.x for c in all_cells) - min_x + 1
    cells = [(c.x - min_x, 0, c.height, c.land_type) for c in cut_cells]
    cells += [(c.x - min_x, 1, c.height, c.land_type) for c in base]
    return sorted(cells), width, 2


def deck_cells(cells: list) -> list:
    """The three cut cells at deck grade (road/railroad)."""
    return [c for c in cells if c[3] in DECK_LAND_IDS and c[2] == DECK_GRADE]


def rotate_cells(cells: list, width: int, height: int, t: int) -> list:
    """Rotate a footprint by transform t (0=n, 1=90 CW, 2=180, 3=270 CW)."""
    out = []
    for x, y, h, land in cells:
        if t == 0:
            rx, ry = x, y
        elif t == 1:
            rx, ry = height - 1 - y, x
        elif t == 2:
            rx, ry = width - 1 - x, height - 1 - y
        else:
            rx, ry = y, width - 1 - x
        out.append((rx, ry, h, land))
    return sorted(out)


def run_self_check(src_dir: str | None = None, ini_path: str | None = None) -> int:
    """Verify the role map, known rail/road footprints, and the derived end."""
    src = Path(src_dir or os.environ.get("TS_ISOTEM_DIR", DEFAULT_ISOTEM_DIR))
    ini = Path(ini_path or os.environ.get("TS_TEMPERAT_INI", DEFAULT_INI))
    if not Path(src, "ovrps01.tem").exists():
        print(f"bridge self-check: {src}/ovrps01.tem not found (set TS_ISOTEM_DIR)")
        return 1
    ok = True

    def expect(got, want, msg):
        nonlocal ok
        if got != want:
            ok = False
            print(f"FAIL {msg}: got {got!r}, want {want!r}")

    roles = parse_roles(ini)
    expect(roles.get("BridgeTopLeft1"), 1, "BridgeTopLeft1 -> 1")
    expect(roles.get("BridgeTopRight1"), 4, "BridgeTopRight1 -> 4")
    expect(roles.get("BridgeMiddle2"), 12, "BridgeMiddle2 -> 12")

    road_roles, road_tiles = load_set(src, "ovrps", roles)
    rail_roles, rail_tiles = load_set(src, "tovrps", roles)
    expect(sorted(road_roles.get("TopRight", {})), [1, 2], "road TopRight has clear+water")
    expect(sorted(rail_roles.get("Middle", {})), [1, 2], "rail Middle has clear+water")

    # Rail deck lane: tovrps01 (TopLeft) column x=0 rows 1..3 = road, railroad, road.
    t01 = parse_tem(src / "tovrps01.tem")
    expect(t01.cells[(0, 2)].land_type, RAILROAD_LAND_ID, "tovrps01 middle lane is railroad")
    expect(t01.cells[(0, 1)].land_type, 11, "tovrps01 outer lane (top) is road")
    expect(t01.cells[(0, 3)].land_type, 11, "tovrps01 outer lane (bottom) is road")
    expect({t01.cells[(0, y)].height for y in (1, 2, 3)}, {DECK_GRADE}, "tovrps01 deck grade 4")

    # Road set bank land is rock (15), deck at grade 4.
    o04 = road_tiles.get(road_roles["TopRight"][1]) or parse_tem(src / "ovrps04.tem")
    expect(o04.cells[(0, 0)].land_type, ROCK_LAND_ID, "ovrps04 bank is rock (15) at grade 4")
    expect(o04.cells[(0, 0)].height, DECK_GRADE, "ovrps04 bank at deck grade")

    # Derived directional end: three deck cells at grade 4, grade-4 rock banks,
    # grade-0 rock base; rail middle lane is railroad.
    for prefix, rail in (("ovrps", False), ("tovrps", True)):
        role_tiles = road_roles if prefix == "ovrps" else rail_roles
        tiles = road_tiles if prefix == "ovrps" else rail_tiles
        tile = tiles[role_tiles["TopRight"][1]]
        derived = derive_end(tile)
        if derived is None:
            ok = False
            print(f"FAIL {prefix} TopRight: no cut/base row found")
            continue
        cells, _, _ = derived
        cut = deck_cells(cells)
        expect(len(cut), LANES, f"{prefix} end cut is three cells")
        expect({c[2] for c in cut}, {DECK_GRADE}, f"{prefix} end cut at grade 4")
        banks = [c for c in cells if c[1] == 0 and c[2] == DECK_GRADE and c[3] == ROCK_LAND_ID]
        expect(len(banks), 2, f"{prefix} end has two grade-4 rock banks")
        expect({c[2] for c in cells if c[1] == 1}, {BASE_GRADE}, f"{prefix} end base at grade 0")
        if rail:
            expect(cells and sorted(c[3] for c in cut), [RAILROAD_LAND_ID, 11, 11],
                   "rail middle cut lane is railroad")
        else:
            expect(sorted(c[3] for c in cut), [11, 11, 11], "road cut lanes are road")

    # Overlay art atlases: three lanes wide, header-reported frames.
    for name, want_h, want_frames in (
        ("bridge.tem", 144, 36),
        ("railbrdg.tem", 144, 36),
        ("lobrdg01.tem", 96, 6),
    ):
        path = src / name
        if not path.exists():
            ok = False
            print(f"FAIL missing atlas {name}")
            continue
        width, height, frames = read_atlas_header(path)
        expect((width, height), (3 * LANE_WIDTH_PX, want_h), f"{name} atlas dimensions")
        expect(frames, want_frames, f"{name} frame count")

    print("bridge --check", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def _render_cells(cells: list) -> str:
    lines = ["{"]
    entries = []
    # Low cells first, high cells last: adjacent cut/base cells share vertices at
    # the cliff face, and the deck-grade cut must win the absolute write so its
    # authored flat corners survive stamping (a vertical TS cliff is a
    # discontinuity the heightfield can only approximate).
    for x, y, height, land in sorted(cells, key=lambda c: (c[2], c[1], c[0])):
        corners = ", ".join([str(height)] * 4)
        land_id = LAND_MAP.get(land, "clear")
        entries.append(
            f'"{x},{y}": {{\n'
            f'"corners": [{corners}],\n'
            f'"crease": "flat",\n'
            f'"land": "{land_id}"\n'
            f"}}"
        )
    lines.append(",\n".join(entries))
    lines.append("}")
    return "\n".join(lines)


OBJECT_TEMPLATE = """[gd_resource type="Resource" script_class="TerrainObject" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/data/TerrainObject.gd" id="1_script"]
[ext_resource type="Resource" path="{art}" id="2_art"]

[resource]
script = ExtResource("1_script")
art_data = ExtResource("2_art")
id = "{obj_id}"
cell_type = "cliff"
display_name = "{display}"
cells = {cells}
"""

# base object id -> art resource path (rotated per direction by the art seam).
ART_PATHS = {
    "cliff_bridge_end": "res://games/ts/art/terrain/cliff_bridge_end.tres",
    "cliff_bridge_end_water": "res://games/ts/art/terrain/cliff_bridge_end_water.tres",
    "cliff_rail_bridge_end": "res://games/ts/art/terrain/cliff_rail_bridge_end.tres",
}

DISPLAY_NAMES = {
    "cliff_bridge_end": "Bridge End Cliff",
    "cliff_bridge_end_water": "Bridge End Cliff (Water)",
    "cliff_rail_bridge_end": "Rail Bridge End Cliff",
}


def generate(out_dir: str, src_dir: str, ini_path: str) -> int:
    """Write the eight real-footprint end caps (plus a water road variant)."""
    src = Path(src_dir)
    roles = parse_roles(ini_path)
    road_roles, road_tiles = load_set(src, "ovrps", roles)
    rail_roles, rail_tiles = load_set(src, "tovrps", roles)

    road_base = derive_end(road_tiles[road_roles["TopRight"][1]])
    rail_base = derive_end(rail_tiles[rail_roles["TopRight"][1]])
    if road_base is None or rail_base is None:
        print("cannot derive bridge end footprint from the source tiles")
        return 1
    road_cells, width, height = road_base
    rail_cells, _, _ = rail_base

    presets = [
        ("cliff_bridge_end", road_cells),
        ("cliff_bridge_end_water", road_cells),
        ("cliff_rail_bridge_end", rail_cells),
    ]
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    written = 0
    for base_id, base_cells in presets:
        for t, direction in enumerate(DIRECTIONS):
            world = rotate_cells(base_cells, width, height, t)
            obj_id = f"{base_id}_{direction}"
            body = OBJECT_TEMPLATE.format(
                art=ART_PATHS[base_id],
                obj_id=obj_id,
                display=f"{DISPLAY_NAMES[base_id]} {direction.upper()}",
                cells=_render_cells(world),
            )
            (out / f"{obj_id}.tres").write_text(body)
            written += 1
    print(f"generated {written} bridge-end TerrainObject variants -> {out}")
    return 0


def report_atlases(src_dir: str | Path) -> int:
    """Print the three-lane overlay atlas dimensions/frame counts."""
    src = Path(src_dir)
    names = ["bridge.tem", "railbrdg.tem"]
    names += sorted(p.name for p in src.glob("lobrdg*.tem"))
    found = 0
    for name in names:
        path = src / name
        if not path.exists():
            continue
        width, height, frames = read_atlas_header(path)
        lanes = width // LANE_WIDTH_PX
        print(f"{name}: {width}x{height} px, {lanes} lanes, {frames} frames")
        found += 1
    if found == 0:
        print(f"no bridge atlases found in {src} (set TS_ISOTEM_DIR)")
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Parse TS bridge tiles and generate end caps.")
    parser.add_argument("--check", action="store_true", help="run the bridge self-check")
    parser.add_argument("--generate", action="store_true", help="write the end-cap .tres files")
    parser.add_argument("--atlas", action="store_true", help="report the overlay atlas headers")
    parser.add_argument("--src", default=os.environ.get("TS_ISOTEM_DIR", DEFAULT_ISOTEM_DIR))
    parser.add_argument("--ini", default=os.environ.get("TS_TEMPERAT_INI", DEFAULT_INI))
    parser.add_argument("--out", default="games/ts/terrain_objects")
    args = parser.parse_args(argv)

    if args.check:
        return run_self_check(args.src, args.ini)
    if args.generate:
        return generate(args.out, args.src, args.ini)
    if args.atlas:
        return report_atlases(args.src)
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
