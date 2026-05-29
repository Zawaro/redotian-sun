class_name SpatialHash extends Node

static var instance: SpatialHash

var _grid: Dictionary = {}
var _blocked_cells: Dictionary = {}
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
        _grid[key].append({ "node": parent, "mc": mc })
        if mc._state == MovementController.State.IDLE:
            _blocked_cells[key] = true


func get_entries(cell: Vector2i) -> Array:
    return _grid.get(str(cell.x) + "," + str(cell.y), [])


func get_blocked_cells() -> Dictionary:
    return _blocked_cells


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