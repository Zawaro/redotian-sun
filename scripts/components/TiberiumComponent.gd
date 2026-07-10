class_name TiberiumComponent extends Node

@export var amount: int = 0
@export var max_amount: int = 0
@export var tiberium_type: int = 0
@export var regrowth_rate: float = -1.0


func _ready() -> void:
    _ensure_visual_nodes()
    _update_visual()


func _ensure_visual_nodes() -> void:
    var parent := get_parent()
    if not parent:
        return
    for i in 3:
        var existing := parent.get_node_or_null("Stage%d" % i)
        if not existing:
            var mi := MeshInstance3D.new()
            mi.name = "Stage%d" % i
            mi.mesh = BoxMesh.new()
            mi.visible = false
            var offset := float(i) * 0.3
            mi.position = Vector3(offset, 0.5, offset)
            parent.add_child(mi)


func collect(amount_to_collect: int) -> int:
    var collected := mini(amount_to_collect, amount)
    amount -= collected
    _update_visual()
    return collected


func is_depleted() -> bool:
    return amount <= 0


func get_visual_stage() -> int:
    if max_amount <= 0:
        return 0
    var ratio := float(amount) / float(max_amount)
    if ratio <= 0.33:
        return 0
    elif ratio <= 0.66:
        return 1
    else:
        return 2


func _update_visual() -> void:
    var parent := get_parent()
    if not parent:
        return
    var stage := get_visual_stage()
    for i in 3:
        var node := parent.get_node_or_null("Stage%d" % i) as Node3D
        if node:
            node.visible = (i == stage)
