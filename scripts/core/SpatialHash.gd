class_name SpatialHash extends Node

static var instance: SpatialHash
const _KEY_OFFSET: int = 512

var _grid: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _building_cells: Dictionary = {}
var _bib_cells: Dictionary = {}
var _reserved: Dictionary = {}
var _resource_cells: Dictionary = {}


func _enter_tree() -> void:
    instance = self


func _physics_process(_delta: float) -> void:
    rebuild()


func rebuild() -> void:
    _grid.clear()
    _blocked_cells.clear()
    for entity in get_tree().get_nodes_in_group("entities"):
        # ponytail: scene-placed units add SelectComponent (Node) to group,
        # not the root Node3D. Resolve root for MC lookup + position.
        var entity_root := entity as Node3D
        if not entity_root:
            entity_root = entity.get_parent() as Node3D
        if not is_instance_valid(entity_root):
            continue
        var mc := entity_root.get_node_or_null("MovementController") as MovementController
        var cell := Pathfinder.world_to_cell(entity_root.global_position)
        var key := _cell_key(cell)
        if not _grid.has(key):
            _grid[key] = []
        _grid[key].append({"node": entity_root, "mc": mc})
        if mc and mc._state == MovementController.State.IDLE:
            _blocked_cells[key] = true


func get_entries(cell: Vector2i) -> Array:
    return _grid.get(_cell_key(cell), [])


func get_blocked_cells() -> Dictionary:
    var result: Dictionary = _blocked_cells.duplicate()
    for key in _building_cells:
        result[key] = true
    return result


func all_entries() -> Array:
    var result: Array = []
    for key in _grid:
        result.append_array(_grid[key])
    return result


func is_cell_blocked(cell: Vector2i) -> bool:
    return _blocked_cells.has(_cell_key(cell))


func reserve_cell(cell: Vector2i) -> bool:
    var key := _cell_key(cell)
    if _reserved.has(key) or _blocked_cells.has(key) or _building_cells.has(key):
        return false
    _reserved[key] = true
    return true


func release_cell(cell: Vector2i) -> void:
    _reserved.erase(_cell_key(cell))


func force_reserve(cell: Vector2i) -> void:
    _reserved[_cell_key(cell)] = true


func clear_reservations() -> void:
    _reserved.clear()


func get_reserved() -> Dictionary:
    return _reserved


func register_building_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _building_cells[_cell_key(cell)] = true


func register_bib_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _bib_cells[_cell_key(cell)] = true


func is_bib_cell(cell: Vector2i) -> bool:
    return _bib_cells.has(_cell_key(cell))


func register_resource_cell(cell: Vector2i) -> void:
    _resource_cells[_cell_key(cell)] = true


func unregister_resource_cell(cell: Vector2i) -> void:
    _resource_cells.erase(_cell_key(cell))


func has_resource_cell(cell: Vector2i) -> bool:
    return _resource_cells.has(_cell_key(cell))


func unregister_building_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _building_cells.erase(_cell_key(cell))


func get_building_cells() -> Dictionary:
    return _building_cells


func _cell_key(cell: Vector2i) -> int:
    return (cell.x + _KEY_OFFSET) << 16 | (cell.y + _KEY_OFFSET) & 0xFFFF
