class_name SpatialHash extends Node

static var instance: SpatialHash

var _grid: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _building_cells: Dictionary = {}
var _reserved: Dictionary = {}


func _enter_tree() -> void:
    instance = self


func _physics_process(_delta: float) -> void:
    rebuild()


func rebuild() -> void:
    _grid.clear()
    _blocked_cells.clear()
    for entity in get_tree().get_nodes_in_group("entities"):
        var parent := entity.get_parent() as Node3D
        if not is_instance_valid(parent):
            continue
        var mc := parent.get_node_or_null("MovementController") as MovementController
        if not mc:
            continue
        var cell := Pathfinder.world_to_cell(parent.global_position)
        var key := str(cell.x) + "," + str(cell.y)
        if not _grid.has(key):
            _grid[key] = []
        _grid[key].append({"node": parent, "mc": mc})
        if mc._state == MovementController.State.IDLE:
            _blocked_cells[key] = true


func get_entries(cell: Vector2i) -> Array:
    return _grid.get(str(cell.x) + "," + str(cell.y), [])


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


func is_cell_idle(cell: Vector2i) -> bool:
    return _blocked_cells.has(str(cell.x) + "," + str(cell.y))


func reserve_cell(cell: Vector2i) -> bool:
    var key := str(cell.x) + "," + str(cell.y)
    if _reserved.has(key) or _blocked_cells.has(key):
        return false
    _reserved[key] = true
    return true


func release_cell(cell: Vector2i) -> void:
    _reserved.erase(str(cell.x) + "," + str(cell.y))


func force_reserve(cell: Vector2i) -> void:
    _reserved[str(cell.x) + "," + str(cell.y)] = true


func clear_reservations() -> void:
    _reserved.clear()


func get_reserved() -> Dictionary:
    return _reserved


func register_building_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _building_cells[_cell_key(cell)] = true


func unregister_building_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _building_cells.erase(_cell_key(cell))


func get_building_cells() -> Dictionary:
    return _building_cells


func _cell_key(cell: Vector2i) -> String:
    return str(cell.x) + "," + str(cell.y)
