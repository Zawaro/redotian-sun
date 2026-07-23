class_name RallyPointComponent extends Node

## Manages rally path for units after they exit the building.
## Players can set rally points by right-clicking on terrain.

## Path of waypoints units follow after exiting (in cell coordinates).
@export var rally_path: Array[Vector2i] = []

## Emitted when rally point is changed.
signal rally_point_changed(path: Array[Vector2i])


func set_rally_point(cell: Vector2i) -> void:
    rally_path = [cell]
    rally_point_changed.emit(rally_path)


func clear_rally_point() -> void:
    rally_path = []
    rally_point_changed.emit(rally_path)


func has_rally_point() -> bool:
    return not rally_path.is_empty()


func get_target_position() -> Vector3:
    if rally_path.is_empty():
        return Vector3.ZERO
    var cell: Vector2i = rally_path[rally_path.size() - 1]
    var cs := Pathfinder.CELL_SIZE
    return Vector3((cell.x + 0.5) * cs, 0.0, (cell.y + 0.5) * cs)
