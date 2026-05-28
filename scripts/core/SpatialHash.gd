class_name SpatialHash extends Node

static var instance: SpatialHash

var _grid: Dictionary = {}


func _enter_tree() -> void:
    instance = self


func _process(_delta: float) -> void:
    rebuild()


func rebuild() -> void:
    _grid.clear()
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


func get_entries(cell: Vector2i) -> Array:
    return _grid.get(str(cell.x) + "," + str(cell.y), [])


func all_entries() -> Array:
    var result: Array = []
    for key in _grid:
        result.append_array(_grid[key])
    return result


func is_cell_idle(cell: Vector2i) -> bool:
    var entries: Array = _grid.get(str(cell.x) + "," + str(cell.y), [])
    for entry in entries:
        var mc := entry.mc as MovementController
        if mc and mc._state == MovementController.State.IDLE:
            return true
    return false