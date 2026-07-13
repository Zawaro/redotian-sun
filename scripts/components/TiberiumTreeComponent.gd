class_name TiberiumTreeComponent extends Node

@export var spawned_entity_id: String = ""
@export var radius_cells: int = 8
@export var resource_type_id: String = "tiberium_green"
@export var node_count: int = 12
@export var amount_per_node: int = 300
@export var max_amount_per_node: int = 300
@export var regrowth_rate: float = -1.0


func _ready() -> void:
    var root := get_parent() as Node3D
    if root and not root.is_in_group("tiberium_trees"):
        root.add_to_group("tiberium_trees")


func configure(data: EntityData) -> void:
    spawned_entity_id = data.spawned_entity_id
    radius_cells = data.radius_cells
    resource_type_id = data.resource_type_id
    node_count = data.node_count
    amount_per_node = data.amount_per_node
    max_amount_per_node = data.max_amount_per_node
    regrowth_rate = data.tiberium_regrowth_rate


func _random_cell_in_radius(center: Vector2i, radius: int) -> Vector2i:
    var angle := randf() * TAU
    var dist := sqrt(randf()) * float(radius)
    return Vector2i(center.x + roundi(cos(angle) * dist), center.y + roundi(sin(angle) * dist))
