extends Node

## TerrainCatalog autoload — the global registry for terrain content, mirroring
## EntityFactory's data sets. Scans resources/terrain_objects/, resources/art/
## terrain/, and resources/theaters/ and caches TerrainObject, TerrainArtData,
## and TheaterData by id. Owns the active theater (selected from the map JSON by
## MapLoader) and the resolve_art mesh-resolution choke point shared by the
## renderer and collision.

const TERRAIN_GLB_PATH: String = (
    "res://assets/models/theater/placeholder/" + "placeholder_terrain01.gltf"
)

var _objects: Dictionary = {}
var _art: Dictionary = {}
var _theaters: Dictionary = {}
var _active_theater: TheaterData = null
var _data_sets: Array[String] = []
var _terrain_scene: PackedScene = null


func _ready() -> void:
    register_data_set("res://resources/terrain_objects/")
    register_data_set("res://resources/art/terrain/")
    register_data_set("res://resources/theaters/")


## The active terrain art's GLB scene (from the art seam, so corner-pivoted
## tiles are used), cached. Falls back to the placeholder const when art cannot
## resolve.
func load_terrain_scene() -> PackedScene:
    if _terrain_scene:
        return _terrain_scene
    var resolution := resolve_art("clear01", get_active_theater_id())
    if resolution.valid and not resolution.glb_path.is_empty():
        var scene := load(resolution.glb_path) as PackedScene
        if scene != null:
            _terrain_scene = scene
            return _terrain_scene
    _terrain_scene = load(TERRAIN_GLB_PATH) as PackedScene
    return _terrain_scene


## Registers a directory to scan, recursing into subdirectories and caching each
## .tres by id in the cache matching its resource type. Idempotent per path.
func register_data_set(path: String) -> void:
    if _data_sets.has(path):
        return
    _data_sets.append(path)
    _scan_directory(path)


func _scan_directory(path: String) -> void:
    var dir := DirAccess.open(path)
    if not dir:
        push_warning("TerrainCatalog: Cannot open directory: %s" % path)
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        var resource_path := file_name.trim_suffix(".remap")
        if resource_path.ends_with(".tres"):
            var full_path := path + resource_path
            var resource: Resource = load(full_path)
            if resource is TerrainObject:
                _objects[resource.id] = resource
            elif resource is TerrainArtData:
                _art[resource.id] = resource
            elif resource is TheaterData:
                _theaters[resource.id] = resource
        elif dir.current_is_dir() and not file_name.begins_with("."):
            _scan_directory(path + file_name + "/")
        file_name = dir.get_next()
    dir.list_dir_end()


## TerrainObject registered under `object_id`, or null.
func get_object(object_id: String) -> TerrainObject:
    return _objects.get(object_id) as TerrainObject


## TerrainArtData registered under `art_id`, or null.
func get_art(art_id: String) -> TerrainArtData:
    return _art.get(art_id) as TerrainArtData


## TheaterData registered under `theater_id`, or null.
func get_theater(theater_id: String) -> TheaterData:
    return _theaters.get(theater_id) as TheaterData


## Registers a TerrainArtData directly (runtime content registration, mirrors
## register_data_set). Overwrites an existing entry with the same id.
func register_art(art: TerrainArtData) -> void:
    if art and not art.id.is_empty():
        _art[art.id] = art


## Registers a TheaterData directly (runtime content registration). Overwrites
## an existing entry with the same id.
func register_theater(theater: TheaterData) -> void:
    if theater and not theater.id.is_empty():
        _theaters[theater.id] = theater


## Every registered object: id -> TerrainObject (copy).
func get_all_objects() -> Dictionary:
    return _objects.duplicate(true)


## Every registered art entry: id -> TerrainArtData (copy).
func get_all_art() -> Dictionary:
    return _art.duplicate(true)


## Every registered theater: id -> TheaterData (copy).
func get_all_theaters() -> Dictionary:
    return _theaters.duplicate(true)


## Selects the active theater by id. Unknown ids fall back to the first
## registered theater and emit a warning; an empty id clears the selection.
func set_active_theater(theater_id: String) -> void:
    if theater_id.is_empty():
        _active_theater = null
        return
    var theater := get_theater(theater_id)
    if theater:
        _active_theater = theater
        return
    push_warning(
        "TerrainCatalog: unknown theater id '%s'; using first registered theater" % theater_id
    )
    _active_theater = _first_theater()


## The currently selected theater, or the first registered when unset.
func get_active_theater() -> TheaterData:
    if _active_theater:
        return _active_theater
    return _first_theater()


## Id of the active theater, or "" when none is registered.
func get_active_theater_id() -> String:
    var theater := get_active_theater()
    return theater.id if theater else ""


## Resolves a cell's mesh: the object's shared art entry resolved for the
## theater, or the art entry keyed by the id directly. Invalid when neither an
## object with art nor an art entry exists for the id.
func resolve_art(object_id: String, theater_id: String) -> TerrainArtData.ArtResolution:
    var obj := get_object(object_id)
    if obj and obj.art_data:
        return obj.art_data.resolve(object_id, theater_id)
    var art := get_art(object_id)
    if art:
        return art.resolve(object_id, theater_id)
    return TerrainArtData.ArtResolution.new()


## Resolves a rendered cell's art from its cell data: uses the baked object_id
## when present (catalog path), otherwise the legacy type/variant family, then
## resolves for the active theater. Invalid when neither path yields art.
func resolve_cell_art(cell_data: Dictionary) -> TerrainArtData.ArtResolution:
    var object_id: String = cell_data.get("object_id", "")
    var family := (
        object_id
        if not object_id.is_empty()
        else _get_mesh_family(
            String(cell_data.get("type", "clear")), int(cell_data.get("variant", 1))
        )
    )
    return resolve_art(family, get_active_theater_id())


## Legacy mesh-family fallback for cells without a baked object_id
## (type+variant -> e.g. "clear01", "slope02"). New cells carry object_id.
static func _get_mesh_family(terrain_type: String, variant: int) -> String:
    var prefix := ""
    match terrain_type:
        "clear":
            prefix = "clear"
        "slope":
            prefix = "slope"
        "cliff":
            prefix = "cliff"
        _:
            prefix = "clear"
    return prefix + str(variant).pad_zeros(2)


func _first_theater() -> TheaterData:
    for key in _theaters:
        return _theaters[key] as TheaterData
    return null
