class_name TiberiumTreeComponent extends Node

@export var spawned_entity_id: String = ""
@export var radius_cells: int = 8
@export var tiberium_type: int = 0
@export var node_count: int = 12
@export var amount_per_node: int = 300
@export var max_amount_per_node: int = 300
@export var regrowth_rate: float = -1.0

var _spawned_crystals: Array[Node3D] = []


func _ready() -> void:
    call_deferred("_spawn_crystals")


func _spawn_crystals() -> void:
    if spawned_entity_id.is_empty() or node_count <= 0:
        return

    var parent := get_parent() as Node3D
    if not parent:
        return

    var tree_cell := Pathfinder.world_to_cell(parent.global_position)
    var placed_positions: Array[Vector2i] = []
    placed_positions.append(tree_cell)

    var max_attempts := node_count * 10
    var attempts := 0
    var spawned := 0

    while spawned < node_count and attempts < max_attempts:
        attempts += 1
        var cell := _random_cell_in_radius(tree_cell, radius_cells)

        var too_close := false
        for existing in placed_positions:
            if abs(cell.x - existing.x) < 2 and abs(cell.y - existing.y) < 2:
                too_close = true
                break
        if too_close:
            continue

        placed_positions.append(cell)
        _spawn_crystal_at(cell)
        spawned += 1


func _spawn_crystal_at(cell: Vector2i) -> void:
    var entity := (
        EntityFactory
        . create_entity(
            spawned_entity_id,
            {
                "tiberium_amount": amount_per_node,
                "tiberium_max_amount": max_amount_per_node,
                "tiberium_type": tiberium_type,
                "tiberium_regrowth_rate": regrowth_rate,
            }
        )
    )
    if not entity:
        return

    var world_pos := Pathfinder.cell_to_world(cell)
    entity.position = world_pos

    var parent := get_parent() as Node3D
    if parent and parent.get_parent():
        parent.get_parent().add_child(entity)
        _spawned_crystals.append(entity)


func _random_cell_in_radius(center: Vector2i, radius: int) -> Vector2i:
    var angle := randf() * TAU
    var dist := sqrt(randf()) * float(radius)
    return Vector2i(center.x + roundi(cos(angle) * dist), center.y + roundi(sin(angle) * dist))
