class_name TerrainArtData extends Resource

## The art seam for terrain. A theater references a TerrainArtData to say which
## GLB holds its tile meshes and how catalog tile ids map to GLB submeshes.
## The placeholder GLB (with textures) ships as one entry so the MapEditor can
## render either placeholder or proper art for the same theater; proper TS art
## swaps in as a second TerrainArtData without touching gameplay data.

## Directional suffix -> Y-axis rotation in degrees, applied to the shared
## family mesh so one GLB submesh serves all four authored variants.
const DIRECTION_ROTATIONS: Dictionary = {
    "n": 0.0,
    "e": 270.0,
    "s": 180.0,
    "w": 90.0,
}

@export_group("Terrain Art")
## Unique identifier (e.g. "placeholder", "temperate", "snow").
@export var id: String = ""
## Path to the GLB/PackedScene whose submeshes are named after tile ids
## (e.g. "res://assets/models/theater/placeholder/placeholder_terrain01.gltf").
@export var glb_path: String = ""
## True when this entry renders the colored placeholder meshes, false when it
## is the proper theater art. Drives the editor's two render modes.
@export var is_placeholder: bool = false

## Catalog tile ids that have no GLB submesh of their own, mapped to the closest
## submesh that approximates them. Art knowledge — lives here, not in gameplay
## data. Tile ids absent from this table resolve to themselves (after the
## directional suffix is stripped). One entry per base family; directional
## variants share it.
const FALLBACK_MESHES: Dictionary = {
    "clat01": "cliff02",
    "cliff12": "cliff09",
    "cliff26": "cliff24",
    "cliff27": "cliff14",
    "dcliff01": "cliff02",
    "ramp05": "ramp01",
    "ramp06": "ramp01",
    "ramp07": "ramp01",
    "ramp08": "ramp01",
    "ramp09": "ramp01",
    "ramp10": "ramp01",
    "slope01": "slope_edge",
    "slope05": "slope_corner",
    "slope09": "slope_tri",
    "slope13": "slope_steep",
    "slope17": "slope_saddle",
    "wcliff12": "wcliff01",
    "wcliff28": "wcliff01",
    "clear": "clear01",
    "ramp_n": "ramp01",
    "slope": "slope_edge",
    "cliff_straight_n": "cliff23",
    "cliff_straight_e": "cliff24",
    "cliff_straight_s": "cliff23",
    "cliff_straight_w": "cliff24",
}


## Strips a directional suffix ("_n"/"_e"/"_s"/"_w") from a tile id, returning
## the base family id. Ids without a suffix return unchanged.
func base_mesh_id(tile_id: String) -> String:
    for dir in DIRECTION_ROTATIONS:
        var suffix := "_" + String(dir)
        if tile_id.ends_with(suffix):
            return tile_id.substr(0, tile_id.length() - suffix.length())
    return tile_id


## GLB submesh name for a catalog tile id. Exact (suffixed seed) ids resolve
## through the fallback table first; otherwise the directional suffix is stripped
## so one submesh per family serves all four variants, then the fallback table is
## consulted for the base id.
func mesh_name(tile_id: String) -> String:
    if FALLBACK_MESHES.has(tile_id):
        return String(FALLBACK_MESHES[tile_id])
    var base := base_mesh_id(tile_id)
    return String(FALLBACK_MESHES.get(base, base))


## Y-axis rotation in degrees for a directional tile id, so the shared family
## mesh is oriented to the variant's facing. 0 for non-directional ids.
func mesh_rotation(tile_id: String) -> float:
    for dir in DIRECTION_ROTATIONS:
        var suffix := "_" + String(dir)
        if tile_id.ends_with(suffix):
            return float(DIRECTION_ROTATIONS[dir])
    return 0.0
