extends Node

## FactionCatalog autoload — the registry for a game's faction (house) roster,
## mirroring EntityFactory/TerrainCatalog/AudioManager data-set loading. Scans
## `<layer root>/factions/` for Faction resources, caches them by id, and
## projects the ordered roster into `Houses` for map ownership and the
## editor/sidebar consumers. Missing directories and failed loads warn and
## continue — never crash gameplay.

var _factions: Dictionary = {}
var _data_sets: Array[String] = []


func _ready() -> void:
    GameContext.game_changed.connect(_on_game_changed)
    _load_from_context()


## Registers factions from the active game's layer roots. Pulled at _ready
## (boot-time game_changed fires before this autoload exists) and re-run on
## every runtime game switch.
func _load_from_context() -> void:
    reset_content()
    var def := GameContext.current
    if def == null:
        return
    for root in def.data_sets:
        register_data_set(root.trim_suffix("/") + "/factions/")


func _on_game_changed(_def: GameDefinition) -> void:
    _load_from_context()


## Clears all registered factions and empties the projected house roster.
## Called before every (re)registration.
func reset_content() -> void:
    _factions.clear()
    _data_sets.clear()
    Houses.clear_roster()


## Registers a factions directory, recursing into subdirectories and caching
## each Faction by id (later roots win). Idempotent per path, and re-projects
## the house roster after every scan.
func register_data_set(path: String) -> void:
    if _data_sets.has(path):
        return
    _data_sets.append(path)
    _scan_directory(path)
    Houses.apply_roster(get_ordered())


func _scan_directory(path: String) -> void:
    # ponytail: per-catalog scan mirrors EntityFactory/TerrainCatalog/AudioManager;
    # extract a shared recursive resources_in(path) helper if a fifth appears.
    var dir := DirAccess.open(path)
    if not dir:
        push_warning("FactionCatalog: Cannot open directory: %s" % path)
        return
    dir.list_dir_begin()
    var file_name := dir.get_next()
    while file_name != "":
        var resource_path := file_name.trim_suffix(".remap")
        if resource_path.ends_with(".tres"):
            var resource := load(path + resource_path)
            if resource is Faction:
                _factions[(resource as Faction).id] = resource
        elif dir.current_is_dir() and not file_name.begins_with("."):
            _scan_directory(path + file_name + "/")
        file_name = dir.get_next()
    dir.list_dir_end()


## The faction registered under `faction_id`, or null.
func get_faction(faction_id: String) -> Faction:
    return _factions.get(faction_id) as Faction


## All registered factions, ascending `order`, ties broken by id.
func get_ordered() -> Array[Faction]:
    var out: Array[Faction] = []
    for key in _factions:
        out.append(_factions[key] as Faction)
    out.sort_custom(
        func(a: Faction, b: Faction) -> bool:
            if a.order != b.order:
                return a.order < b.order
            return a.id < b.id
    )
    return out


## The subset of the ordered roster eligible for the default player roster.
func get_playable() -> Array[Faction]:
    var out: Array[Faction] = []
    for faction in get_ordered():
        if faction.playable:
            out.append(faction)
    return out
