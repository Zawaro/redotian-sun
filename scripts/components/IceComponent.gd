class_name IceComponent extends Node

## Breakable surface entity: when this ice breaks, units occupying its cell drown.

@onready var _health: HealthComponent = get_parent().get_node_or_null("HealthComponent")


func _ready() -> void:
    if _health:
        _health.health_zero.connect(_on_break)


func _on_break() -> void:
    var parent := get_parent() as Node3D
    if not is_instance_valid(parent) or SpatialHash.instance == null:
        return
    var cell := CellUtil.world_to_cell(parent.global_position)
    for entry in SpatialHash.instance.get_entries(cell):
        var node: Node3D = entry["node"]
        if node == parent:
            continue
        if node.get_node_or_null("MovementController") as MovementController:
            var hc := node.get_node_or_null("HealthComponent") as HealthComponent
            if hc:
                hc.kill()
