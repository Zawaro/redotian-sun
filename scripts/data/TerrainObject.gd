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
