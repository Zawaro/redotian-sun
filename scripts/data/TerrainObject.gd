class_name TerrainObject extends Resource

## A single authored directional terrain tile (the .tres analog of Tiberian Sun
## sprite tile data): per-cell land types, per-cell geometry (baked corner
## heights + crease diagonal), and per-edge connection roles that describe how
## this object mates with neighboring cliffs and ramps.
## Data-only — no rendering, art, or pathfinding logic lives here. Visuals come
## from the theater's TerrainArtData.

@export_group("Terrain Object")
## Unique identifier (e.g. "cliff01_n", "ramp01_e", "cliff_straight_n").
@export var id: String = ""
## Cell family: "cliff", "slope", "ramp", or "clear".
@export var cell_type: String = "clear"
## Human-readable name shown in editor tooltips.
@export var display_name: String = ""
## Shared art entry that renders this object. Mirrors EntityData.art_data:
## gameplay data links to the art that draws it. Multiple objects SHALL
## reference the same entry (e.g. all four directional variants of a base).
@export var art_data: TerrainArtData = null
## Per-cell surface data keyed by object-local "x,z" -> {"land": land_type_id,
## "corners": [nw, ne, se, sw] (absolute vertex heights), "crease": "flat"|"x"|"y",
## "slope": int (optional TS RampType provenance), "connections": {edge: role}}.
## Per-edge connection roles live inside each cell (see `connections` on the
## cell entry); there is no tile-level connections field.
@export var cells: Dictionary = {}


## Land type id at an object-local coordinate ("x,z"), or "" when unset.
func land_type_at(local_key: String) -> String:
    var entry: Variant = cells.get(local_key, {})
    if entry is Dictionary:
        return String(entry.get("land", ""))
    return ""


## Corner heights at an object-local coordinate ("x,z"), or an empty array
## when unset. The result is a copy so callers cannot mutate the resource.
func corners_at(local_key: String) -> Array[int]:
    var entry: Variant = cells.get(local_key, {})
    if entry is Dictionary:
        var corners: Array = entry.get("corners", [])
        if corners.size() == 4:
            return [int(corners[0]), int(corners[1]), int(corners[2]), int(corners[3])]
    return []


## Axis-aligned bounds of the whole footprint in lattice units: position holds
## the min cell index (x/z) and min corner height (y); size holds the span
## across cells and the min..max height range. Pure — no scene dependencies.
static func footprint_bounds(obj: TerrainObject) -> AABB:
    var keys: Array = obj.cells.keys()
    if keys.is_empty():
        return AABB(Vector3.ZERO, Vector3.ZERO)
    var min_x := 1 << 30
    var min_z := 1 << 30
    var max_x := -(1 << 30)
    var max_z := -(1 << 30)
    var min_h := 1 << 30
    var max_h := -(1 << 30)
    for key in keys:
        var parts: PackedStringArray = String(key).split(",")
        if parts.size() != 2:
            continue
        var x := int(parts[0])
        var z := int(parts[1])
        min_x = mini(min_x, x)
        max_x = maxi(max_x, x)
        min_z = mini(min_z, z)
        max_z = maxi(max_z, z)
        var entry: Variant = obj.cells.get(String(key), {})
        if entry is Dictionary:
            var corners: Array = entry.get("corners", [])
            for c in corners:
                var h := int(c)
                min_h = mini(min_h, h)
                max_h = maxi(max_h, h)
    if min_h == 1 << 30:
        min_h = 0
        max_h = 0
    return AABB(
        Vector3(min_x, min_h, min_z), Vector3(max_x - min_x + 1, max_h - min_h, max_z - min_z + 1)
    )
