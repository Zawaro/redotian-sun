class_name RallyPointComponent extends Node

## Manages rally point for units after they exit the building.
## Players can set rally points by Alt+Left Clicking on terrain.

## Cell coordinate of rally point, or Vector2i(-1, -1) if unset.
@export var rally_point: Vector2i = Vector2i(-1, -1)

## Emitted when rally point is changed.
signal rally_point_changed(point: Vector2i)


func set_rally_point(cell: Vector2i) -> void:
    rally_point = cell
    rally_point_changed.emit(rally_point)


func clear_rally_point() -> void:
    rally_point = Vector2i(-1, -1)
    rally_point_changed.emit(rally_point)


func has_rally_point() -> bool:
    return rally_point != Vector2i(-1, -1)


func get_target_position() -> Vector3:
    if not has_rally_point():
        return Vector3.ZERO
    return CellUtil.cell_to_world(rally_point)
