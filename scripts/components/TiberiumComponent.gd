class_name TiberiumComponent extends Node

@export var amount: int = 0
@export var max_amount: int = 0
@export var resource_type_id: String = "tiberium_green"
@export var regrowth_rate: float = -1.0
## How many times this crystal has spread to adjacent cells. Capped by GlobalRules.spread_max.
@export var spread_count: int = 0

var _cube_nodes: Array[Node3D] = []
var _current_visual_stage: int = -1

static var _green_mat: StandardMaterial3D = null


func configure(data: EntityData) -> void:
    amount = data.tiberium_amount
    max_amount = data.tiberium_max_amount
    resource_type_id = data.resource_type_id
    regrowth_rate = data.tiberium_regrowth_rate


func _ready() -> void:
    var root := get_parent() as Node3D
    if root and not root.is_in_group("tiberium"):
        root.add_to_group("tiberium")
    _ensure_visual_nodes.call_deferred()
    _update_visual.call_deferred()


func _ensure_visual_nodes() -> void:
    var parent := get_parent() as Node3D
    if not parent:
        return
    var cell := Pathfinder.world_to_cell(parent.global_position)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(cell)

    var configs: Array[Dictionary] = [
        {"count": 3, "big": false},
        {"count": 2, "big": true},
        {"count": 5, "big": true},
    ]

    for si in configs.size():
        var cfg := configs[si]
        var container := Node3D.new()
        container.name = "Stage%d" % si
        parent.add_child(container)
        container.owner = parent.owner

        for i in cfg.count:
            var mi := MeshInstance3D.new()
            mi.name = "Cube%d" % i
            var box := BoxMesh.new()
            if cfg.big:
                box.size = Vector3.ONE * rng.randf_range(0.35, 0.55)
            else:
                box.size = Vector3.ONE * rng.randf_range(0.15, 0.25)
            mi.mesh = box
            var pos_x := rng.randf_range(-0.8, 0.8)
            var pos_z := rng.randf_range(-0.8, 0.8)
            var world_x := parent.global_position.x + pos_x
            var world_z := parent.global_position.z + pos_z
            var terrain_h := TerrainSystem.get_height_at_world_smooth(Vector3(world_x, 0, world_z))
            var y_offset := terrain_h - parent.global_position.y
            mi.position = Vector3(pos_x, y_offset + box.size.y * 0.5, pos_z)
            if _green_mat == null:
                _green_mat = StandardMaterial3D.new()
                _green_mat.albedo_color = Color(0.2, 0.8, 0.2)
            mi.material_override = _green_mat
            container.add_child(mi)

    for i in 3:
        var node := parent.get_node_or_null("Stage%d" % i) as Node3D
        if node:
            _cube_nodes.append(node)


func collect(amount_to_collect: int) -> int:
    if not is_instance_valid(get_parent()):
        return 0
    var collected := mini(amount_to_collect, amount)
    amount -= collected
    _update_visual()
    if amount <= 0:
        get_parent().queue_free()
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
    if stage == _current_visual_stage:
        return
    _current_visual_stage = stage
    for i in 3:
        if i < _cube_nodes.size():
            var node := _cube_nodes[i] as Node3D
            if node:
                node.visible = (i == stage)


func update_slope_positions() -> void:
    var parent := get_parent() as Node3D
    if not parent:
        return
    for container in _cube_nodes:
        if not container:
            continue
        for child in container.get_children():
            var mi := child as MeshInstance3D
            if not mi or not mi.mesh:
                continue
            var box := mi.mesh as BoxMesh
            if not box:
                continue
            var pos_x := mi.position.x
            var pos_z := mi.position.z
            var world_x := parent.global_position.x + pos_x
            var world_z := parent.global_position.z + pos_z
            var terrain_h := TerrainSystem.get_height_at_world_smooth(Vector3(world_x, 0, world_z))
            var y_offset := terrain_h - parent.global_position.y
            mi.position.y = y_offset + box.size.y * 0.5
