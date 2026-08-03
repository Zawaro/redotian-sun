"""Batch-extract TS terrain tile footprints into a rotation-only deduped catalog.

Parses every cliff/wcliff/clat/ramp/slope/clear/dcliff .tem under a source
directory, groups tiles into shape families that are equivalent under 90-degree
rotation, and writes a JSON catalog to `tools/isotem/isotem_catalog.json`.

Dedup is rotation-only (4 transforms): mirror variants are real gameplay pieces
(e.g. `ramp01` vs `ramp02` climb on opposite sides) and stay distinct base
shapes. Families are also keyed by kind so water-cliffs never collapse into
cliffs even when geometry matches.

It also writes `tools/isotem/tile_lookup.json`: for every catalog cell, its
4-corner height signature (derived from the cell's level plus its authored
RampType corner offsets) canonicalized under 90-degree rotation, plus the
reverse `corner-pattern -> (tile, cell, rotation)` map that the engine's
tile resolver reproduces at runtime.

Usage:
    python tools/isotem/catalog.py [SOURCE_DIR] [--out PATH] [--lookup PATH] [--check]
The source dir defaults to $TS_ISOTEM_DIR or the local TS install path.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from tem import Cell, Tile, parse_tem

TILE_KINDS = ("cliff", "wcliff", "clat", "ramp", "slope", "clear", "dcliff")

# Map .tem surface ids to the game's LandType ids.
LAND_MAP = {
    15: "rock",
    13: "clear",  # passable slope / ramp surface
    14: "clear",  # clat transition surface
}

DEFAULT_SRC = "/mnt/work2/CnC Projects/Tiberian Sun/isotem"
DEFAULT_OUT = "tools/isotem/isotem_catalog.json"
DEFAULT_LOOKUP = "tools/isotem/tile_lookup.json"

# WAE/FinalSun RampCornerHeights: per RampType, corner offsets from the cell's
# level in NW, NE, SE, SW order. Type 0 = flat cell.
RAMP_CORNER_HEIGHTS = {
    0: (0, 0, 0, 0),   # flat
    1: (0, 1, 1, 0),   # west
    2: (0, 0, 1, 1),   # north
    3: (1, 0, 0, 1),   # east
    4: (1, 1, 0, 0),   # south
    5: (0, 0, 1, 0),   # corner nw
    6: (0, 0, 0, 1),   # corner ne
    7: (1, 0, 0, 0),   # corner se
    8: (0, 1, 0, 0),   # corner sw
    9: (0, 1, 1, 1),   # mid nw
    10: (1, 0, 1, 1),  # mid ne
    11: (1, 1, 0, 1),  # mid se
    12: (1, 1, 1, 0),  # mid sw
    13: (0, 1, 2, 1),  # steep se
    14: (1, 0, 1, 2),  # steep sw
    15: (2, 1, 0, 1),  # steep nw
    16: (1, 2, 1, 0),  # steep ne
    17: (0, 1, 0, 1),  # double up sw-ne
    18: (1, 0, 1, 0),  # double down sw-ne
    19: (0, 1, 0, 1),  # double up nw-se (duplicate)
    20: (1, 0, 1, 0),  # double down nw-se (duplicate)
}

# Corner order is NW, NE, SE, SW (clockwise). 90-degree rotation cycles them.
ROTATE_CORNERS = {
    0: (0, 1, 2, 3),  # identity
    1: (3, 0, 1, 2),  # 90 deg CW: sw -> nw, nw -> ne, ne -> se, se -> sw
    2: (2, 3, 0, 1),  # 180 deg
    3: (1, 2, 3, 0),  # 270 deg
}


def kind_of(name: str) -> str:
    for kind in TILE_KINDS:
        if name.startswith(kind):
            return kind
    return "other"


def cell_corners(cell: Cell) -> tuple[int, int, int, int]:
    """Four corner heights (NW, NE, SE, SW) of a tile cell: its level plus the
    RampType corner offsets, per WAE's RampCornerHeights model."""
    offsets = RAMP_CORNER_HEIGHTS.get(cell.slope, (0, 0, 0, 0))
    return tuple(cell.height + o for o in offsets)  # type: ignore[return-value]


# Reverse RampType lookup: corner-offset tuple -> slope codes that produce it.
REVERSE_RAMP: dict[tuple, int] = {}
for _code, _offsets in RAMP_CORNER_HEIGHTS.items():
    REVERSE_RAMP.setdefault(_offsets, _code)


def rotate_cell(x: int, y: int, width: int, height: int, t: int) -> tuple[int, int]:
    """Rotate a cell coordinate on a width x height grid by transform t
    (0 = identity, 1 = 90 deg CW, 2 = 180 deg, 3 = 90 deg CCW)."""
    if t == 0:
        return x, y
    if t == 1:
        return height - 1 - y, x
    if t == 2:
        return width - 1 - x, height - 1 - y
    return y, width - 1 - x


def rotate_slope(slope: int, t: int) -> int:
    """Rotate a RampType corner-offset code by transform t. The offsets cycle
    under rotation, so a rotated cell's slope code must follow its geometry."""
    if slope == 0 or t == 0:
        return slope
    offsets = RAMP_CORNER_HEIGHTS.get(slope, (0, 0, 0, 0))
    order = ROTATE_CORNERS[t]
    rotated_offsets = tuple(offsets[i] for i in order)
    return REVERSE_RAMP.get(rotated_offsets, slope)


def rotate_footprint(cells: list[tuple], width: int, height: int, t: int) -> tuple:
    """Rotate a footprint (list of (x, y, height, land, slope)) by transform t,
    rotating each cell's slope code to match its rotated geometry and normalizing
    the origin so the key is translation-invariant."""
    rotated = []
    for x, y, h, land, slope in cells:
        rx, ry = rotate_cell(x, y, width, height, t)
        rs = rotate_slope(slope, t)
        rotated.append((rx, ry, h, land, rs))
    mx = min(p[0] for p in rotated)
    my = min(p[1] for p in rotated)
    return tuple(sorted((p[0] - mx, p[1] - my, p[2], p[3], p[4]) for p in rotated))


def canonical_footprint(tile: Tile) -> tuple:
    """Minimal rotation-invariant key for a footprint under the 4 rotations."""
    cells = [(c.x, c.y, c.height, c.land_type, c.slope) for c in tile.occupied]
    if not cells:
        return ()
    best = None
    for t in range(4):
        key = rotate_footprint(cells, tile.width, tile.height, t)
        if best is None or key < best:
            best = key
    return best  # type: ignore[return-value]


def _normalize_origin(cells: list) -> list:
    """Translate a footprint so its origin is (0, 0) without rotating it."""
    mx = min(p[0] for p in cells)
    my = min(p[1] for p in cells)
    return [(p[0] - mx, p[1] - my, p[2], p[3], p[4]) for p in cells]


def build_catalog(src: Path) -> dict:
    tiles: dict[str, Tile] = {}
    for path in sorted(src.glob("*.tem")):
        name = path.stem
        if not any(name.startswith(k) for k in TILE_KINDS):
            continue
        try:
            tiles[name] = parse_tem(path)
        except (ValueError, OSError) as exc:
            print(f"skip {name}: {exc}")

    # Group by (kind, canonical footprint): cliffs and water-cliffs share geometry
    # but differ semantically, so they must not collapse into one family. Rotation
    # dedup only — mirrors stay separate.
    families: dict[tuple, dict] = {}
    for name in sorted(tiles):
        tile = tiles[name]
        key = (kind_of(name), canonical_footprint(tile))
        fam = families.setdefault(key, {"members": []})
        fam["members"].append(name)

    catalog = {}
    for key, fam in sorted(families.items(), key=lambda kv: (kv[1]["members"][0])):
        members = fam["members"]
        base = members[0]
        base_tile = tiles[base]
        cells = [(c.x, c.y, c.height, c.land_type, c.slope) for c in base_tile.occupied]
        fam["base"] = base
        fam["kind"] = key[0]
        fam["width"] = base_tile.width
        fam["height"] = base_tile.height
        # Store the base tile in its RAW orientation (origin-normalized). The
        # canonical footprint is only a dedup key; the generator's `_n` variant
        # must reproduce the actual TS tile, so re-orienting here would corrupt
        # the data. Rotations are applied by generate_tres.py per direction.
        fam["cells"] = sorted(_normalize_origin(cells))
        catalog[base] = fam
    return catalog


def build_tile_lookup(catalog: dict) -> dict:
    """Per-tile corner signatures plus the reverse corner-pattern map."""
    lookup: dict[str, dict] = {}
    reverse: dict[str, list] = {}
    for base, fam in sorted(catalog.items()):
        entry_cells = []
        for x, y, height, land, slope in fam["cells"]:
            corners = tuple(
                height + RAMP_CORNER_HEIGHTS.get(slope, (0, 0, 0, 0))[k] for k in range(4)
            )
            canon, rotation = corner_canonical(corners)
            key = json.dumps(list(canon))
            entry_cells.append(
                {
                    "x": x,
                    "y": y,
                    "height": height,
                    "land": LAND_MAP.get(land, "clear"),
                    "slope": slope,
                    "corners": list(corners),
                    "canon": key,
                    "rotation": rotation,
                }
            )
            reverse.setdefault(key, []).append(
                {"tile": base, "cell": f"{x},{y}", "rotation": rotation,
                 "land": LAND_MAP.get(land, "clear")}
            )
        lookup[base] = {
            "kind": fam["kind"],
            "width": fam["width"],
            "height": fam["height"],
            "cells": entry_cells,
        }
    lookup["_lookup"] = reverse
    return lookup


def corner_canonical(corners: tuple[int, int, int, int]) -> tuple[tuple, int]:
    """Canonicalize a (NW, NE, SE, SW) corner tuple under 90-degree rotation.
    Returns (canonical_rel_key, rotation) where rotation maps canonical -> the
    observed orientation. rel values are normalized by the tuple's minimum."""
    lo = min(corners)
    rel = tuple(c - lo for c in corners)
    best = None
    best_t = 0
    for t, order in ROTATE_CORNERS.items():
        key = tuple(rel[i] for i in order)
        if best is None or key < best:
            best = key
            best_t = t
    return best, best_t  # type: ignore[return-value]


def _apply_rotation(rel: tuple, t: int) -> tuple:
    order = ROTATE_CORNERS[t]
    return tuple(rel[i] for i in order)


def check() -> int:
    """Self-check: corner canonicalization round-trips under all rotations."""
    ok = True
    samples = [
        (2, 1, 1, 0),
        (4, 4, 3, 3),
        (0, 1, 0, 1),
        (3, 3, 3, 3),
        (2, 3, 3, 2),
    ]
    for corners in samples:
        lo = min(corners)
        rel = tuple(c - lo for c in corners)
        canon, rotation = corner_canonical(corners)
        keys = set()
        for t in ROTATE_CORNERS:
            k, _ = corner_canonical(_apply_rotation(rel, t))
            keys.add(k)
        if len(keys) != 1 or canon not in keys:
            ok = False
            print(f"FAIL round-trip for corners {corners}: keys={keys} canon={canon}")
        if tuple(canon) not in [_apply_rotation(rel, t) for t in ROTATE_CORNERS]:
            ok = False
            print(f"FAIL canonical not in rotation orbit for {corners}")
        if rotation not in ROTATE_CORNERS:
            ok = False
            print(f"FAIL invalid rotation {rotation} for {corners}")
    print("catalog --check", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Extract a TS terrain tile catalog.")
    parser.add_argument("src", nargs="?", default=os.environ.get("TS_ISOTEM_DIR", DEFAULT_SRC))
    parser.add_argument("--out", default=DEFAULT_OUT)
    parser.add_argument("--lookup", default=DEFAULT_LOOKUP)
    parser.add_argument("--check", action="store_true", help="run the corner round-trip self-check")
    args = parser.parse_args(argv)

    if args.check:
        return check()

    src = Path(args.src)
    if not src.is_dir():
        print(f"source dir not found: {src} (set TS_ISOTEM_DIR)")
        return 1

    catalog = build_catalog(src)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(catalog, indent=2, sort_keys=True) + "\n")

    lookup = build_tile_lookup(catalog)
    lookup_path = Path(args.lookup)
    lookup_path.parent.mkdir(parents=True, exist_ok=True)
    lookup_path.write_text(json.dumps(lookup, indent=2, sort_keys=True) + "\n")

    print(f"wrote {len(catalog)} unique families -> {out}")
    print(f"wrote corner lookup ({len(lookup['_lookup'])} patterns) -> {lookup_path}")
    for base, fam in sorted(catalog.items(), key=lambda kv: kv[0]):
        n = len(fam["members"])
        kind = kind_of(base)
        print(f"  {base:12s} {kind:6s} {fam['width']}x{fam['height']} cells={len(fam['cells'])} "
              f"{'+%d variants' % (n - 1) if n > 1 else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
