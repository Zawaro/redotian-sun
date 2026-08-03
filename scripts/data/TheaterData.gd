class_name TheaterData extends Resource

## A theater bundles a terrain's authored look: a set of TerrainObjects, the
## TerrainArtData (GLB + tile-to-mesh mapping) for its visuals, and the default
## land type. Theaters vary visuals/buildability/colors only — movement
## passability stays global in Locomotor.terrain_speeds.

@export_group("Theater")
## Unique identifier (e.g. "temperate", "desert", "winter").
@export var id: String = ""
## Human-readable name shown in the new-map dialog.
@export var display_name: String = ""
## Terrain objects: object id -> TerrainObject resource.
@export var terrain_objects: Dictionary = {}
## Art for this theater: which GLB holds its tile meshes and how tile ids map
## to submeshes. The placeholder entry ships as one theater so the editor can
## render placeholder vs proper art for the same tileset.
@export var art_data: TerrainArtData = null
## Default land type for cells with no explicit surface assignment.
@export var default_land_type: String = "clear"


## TerrainObject registered under `object_id`, or null.
func get_terrain_object(object_id: String) -> TerrainObject:
    return terrain_objects.get(object_id) as TerrainObject
