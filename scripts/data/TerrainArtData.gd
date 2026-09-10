class_name TerrainArtData extends Resource

## The art seam for one terrain element (a mesh family). Owns art acquisition
## and orientation: which GLB holds the element's mesh, which submesh to render
## (with alias fallbacks), and per-theater overrides so one element can swap art
## by theater (e.g. snow). One entry serves all four directional variants of its
## family; orientation is derived from the object id's directional suffix.

## Directional suffix -> Y-axis rotation in degrees, applied to the shared
## family mesh so one GLB submesh serves all four authored variants.
const DIRECTION_ROTATIONS: Dictionary = {
    "n": 0.0,
    "e": 270.0,
    "s": 180.0,
    "w": 90.0,
}

@export_group("Terrain Art")
## Unique identifier — the element base id this art serves (e.g. "cliff01").
@export var id: String = ""
## Path to the GLB/PackedScene whose submeshes are named after tile ids
## (e.g. "res://games/ts/assets/models/theater/placeholder/placeholder_terrain01.gltf").
@export var model_path: String = ""
## GLB submesh to render. Empty = the element's own base id. Alias families
## set this to the closest authored submesh (e.g. "cliff12" art → "cliff09").
@export var submesh_id: String = ""
## Per-theater art override: theater id -> alternative GLB path. Theaters not
## listed use `model_path`.
@export var theater_overrides: Dictionary = {}
## Minimap color for this terrain element. This is the primary terrain color
## (our stand-in for the tile art's radar color). TRANSPARENT (default) = fall
## back to the cell's LandType color. See `minimap_color`.
@export var color: Color = Color.TRANSPARENT


## Result of resolving art for a specific object id + theater.
class ArtResolution:
    var glb_path: String
    var submesh_id: String
    var rotation: float
    var valid: bool

    func _init(
        p_glb: String = "", p_submesh: String = "", p_rotation: float = 0.0, p_valid: bool = false
    ) -> void:
        glb_path = p_glb
        submesh_id = p_submesh
        rotation = p_rotation
        valid = p_valid


## Y-axis rotation in degrees for a directional object id, so the shared family
## mesh is oriented to the variant's facing. 0 for non-directional ids.
func mesh_rotation(object_id: String) -> float:
    return direction_rotation(object_id)


## Static suffix lookup: `_n`/`_e`/`_s`/`_w` -> rotation in degrees, 0 for ids
## without a directional suffix. Available without an art instance so the
## gameplay model can bake facing without touching the catalog.
static func direction_rotation(object_id: String) -> float:
    for dir in DIRECTION_ROTATIONS:
        var suffix := "_" + String(dir)
        if object_id.ends_with(suffix):
            return float(DIRECTION_ROTATIONS[dir])
    return 0.0


## Minimap color for a terrain cell, resolving the raw cell inputs.
## Precedence (issue #178):
## - this element's authored color wins (per-element terrain color);
## - otherwise the cell's LandType color is the fallback;
## - otherwise null: the cell has no map color.
static func minimap_color(art_data: TerrainArtData, land_type: LandType = null) -> Variant:
    if art_data != null and art_data.color.a > 0.0:
        return art_data.color
    if land_type != null and land_type.color.a > 0.0:
        return land_type.color
    return null


## Applies height + theater shading to a resolved terrain color: the color is
## scaled by a brightness lerped from `low_brightness` (flat ground) to
## `high_brightness` (max height) by the cell's normalized height.
static func shade_map_color(
    base: Color, height_ratio: float, low_brightness: float, high_brightness: float
) -> Color:
    var t: float = clampf(height_ratio, 0.0, 1.0)
    var brightness: float = lerpf(low_brightness, high_brightness, t)
    return Color(base.r * brightness, base.g * brightness, base.b * brightness, base.a)


## Resolves the concrete art for an object id in a theater: the override glb
## (or the default model), the submesh to render, and the facing rotation.
## Returns an invalid resolution when no model is available.
func resolve(object_id: String, theater_id: String) -> ArtResolution:
    if model_path.is_empty():
        return ArtResolution.new()
    var glb := model_path
    if not theater_id.is_empty() and theater_overrides.has(theater_id):
        glb = String(theater_overrides[theater_id])
    var submesh := submesh_id
    if submesh.is_empty():
        submesh = _base_id(object_id)
    return ArtResolution.new(glb, submesh, mesh_rotation(object_id), true)


## Strips a directional suffix ("_n"/"_e"/"_s"/"_w") from an object id, returning
## the element base id. Ids without a suffix return unchanged.
func _base_id(object_id: String) -> String:
    for dir in DIRECTION_ROTATIONS:
        var suffix := "_" + String(dir)
        if object_id.ends_with(suffix):
            return object_id.substr(0, object_id.length() - suffix.length())
    return object_id
