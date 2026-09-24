class_name VisionComponent extends Node

## Registers the entity as a ShroudSystem revealer. Units re-stamp on cell
## boundary crossing; buildings register once permanently. Registration is
## deferred until the entity has an assigned player (the deploy path sets
## player_id after add_child).

var _parent: Node3D
var _stats: StatsComponent
var _sight: int = 0
var _entity_type: int = -1
var _height: float = 1.0
var _is_building: bool = false
var _blocks_terrain: bool = true
var _registered_player_id: int = -1
var _registered_key: int = -1
var _registered_cell: Vector2i = Vector2i.ZERO


func configure(data: EntityData) -> void:
    _sight = data.sight
    _entity_type = data.entity_type
    _height = data.height
    _is_building = data.entity_type == EntityData.EntityType.BUILDING
    # Buildings deliberately do not block line of sight (blocks_terrain = false):
    # a building revealer is never occluded by its own footprint or other
    # buildings. Only terrain height blocks LOS (see fog-of-war spec).
    _blocks_terrain = (
        data.entity_type != EntityData.EntityType.AIRCRAFT
        and data.entity_type != EntityData.EntityType.BUILDING
    )


func _ready() -> void:
    _parent = get_parent() as Node3D
    _stats = _parent.get_node_or_null("StatsComponent") as StatsComponent
    if _stats and not _stats.veterancy_changed.is_connected(_on_veterancy_changed):
        _stats.veterancy_changed.connect(_on_veterancy_changed)


func _physics_process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if _stats == null or _stats.player_id < 0:
        return
    var cell := _center_cell()
    if _registered_key < 0:
        _register(cell)
        if _is_building:
            set_physics_process(false)
        return
    if _stats.player_id != _registered_player_id:
        _unregister()
        _register(cell)
        if _is_building:
            set_physics_process(false)
        return
    if cell != _registered_cell:
        ShroudSystem.move_revealer(_registered_player_id, _registered_key, cell, _viewer_height())
        _registered_cell = cell


func _exit_tree() -> void:
    _unregister()


## The entity's global position is already its footprint center (set from
## `CellUtil.cell_origin_to_world` on placement / map load), so no footprint
## offset is applied.
func _center_cell() -> Vector2i:
    return CellUtil.world_to_cell(_parent.global_position)


func _viewer_height() -> float:
    return _parent.global_position.y + maxf(_height * 0.5, 0.5)


## Effective sight radius, including the veteran sight bonus from GlobalRules.
func _effective_sight() -> int:
    if _stats == null:
        return _sight
    var rules := GlobalRules.get_current()
    if rules == null:
        return _sight
    var mult: float = rules.get_veteran_sight_multiplier(_stats.veteran_level)
    return maxi(1, roundi(float(_sight) * mult))


## A promotion widens (or narrows) the revealed disc: re-stamp the revealer.
func _on_veterancy_changed(_level: int) -> void:
    if _stats == null or _stats.player_id < 0 or _registered_key < 0:
        return
    var cell := _center_cell()
    _unregister()
    _register(cell)


func _register(cell: Vector2i) -> void:
    if _stats == null:
        return
    _registered_key = ShroudSystem.register_revealer(
        _stats.player_id, cell, _effective_sight(), _viewer_height(), _blocks_terrain
    )
    _registered_player_id = _stats.player_id
    _registered_cell = cell


func _unregister() -> void:
    if _registered_key < 0:
        return
    ShroudSystem.unregister_revealer(_registered_player_id, _registered_key)
    _registered_key = -1
    _registered_player_id = -1
