class_name ResourceComponent extends Node

@export var resource_type_id: String = "tiberium_green"
@export var regrowth_rate: float = -1.0
## How many times this crystal has spread to adjacent cells. Capped by GlobalRules.spread_max.
@export var spread_count: int = 0

var _cube_nodes: Array[Node3D] = []
var _current_visual_stage: int = -1

static var _mat_cache: Dictionary = {}


func configure(data: EntityData) -> void:
    resource_type_id = data.resource_type_id
    regrowth_rate = data.resource_regrowth_rate


func _ready() -> void:
    var root := get_parent() as Node3D
    if root and not root.is_in_group("resources"):
        root.add_to_group("resources")
    _ensure_visual_nodes.call_deferred()
    _update_visual.call_deferred()
    # Defer cell registration so the entity's global_position is settled
    # (important for spawned resources where position is set after add_child).
    _register_cell.call_deferred()


func _exit_tree() -> void:
    var root := get_parent() as Node3D
    if root and SpatialHash.instance:
        var cell := Pathfinder.world_to_cell(root.global_position)
        SpatialHash.instance.unregister_resource_cell(cell)


func _register_cell() -> void:
    var root := get_parent() as Node3D
    if root and SpatialHash.instance:
        var cell := Pathfinder.world_to_cell(root.global_position)
        SpatialHash.instance.register_resource_cell(cell)


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
            if not _mat_cache.has(resource_type_id):
                var mat := StandardMaterial3D.new()
                var rules := _get_global_rules()
                var rt: ResourceType = rules.get_resource_type(resource_type_id) if rules else null
                mat.albedo_color = rt.color if rt else Color(0.2, 0.8, 0.2)
                _mat_cache[resource_type_id] = mat
            mi.material_override = _mat_cache[resource_type_id]
            container.add_child(mi)

    for i in 3:
        var node := parent.get_node_or_null("Stage%d" % i) as Node3D
        if node:
            _cube_nodes.append(node)


func get_amount() -> float:
    var hp := _get_health()
    return hp.get_health_ratio() if hp else 0.0


func get_max_amount() -> float:
    return 1.0


func collect(bales: float) -> float:
    var hp := _get_health()
    if not hp or hp.max_health <= 0:
        return 0.0
    var health_to_take := bales * float(hp.max_health)
    var actual_health := mini(int(ceilf(health_to_take)), hp.current_health)
    hp.take_damage(actual_health)
    _update_visual()
    var collected_bales := float(actual_health) / float(hp.max_health)
    if hp.current_health <= 0:
        get_parent().queue_free()
    return collected_bales


func is_depleted() -> bool:
    var hp := _get_health()
    return hp.current_health <= 0 if hp else true


func get_visual_stage() -> int:
    var hp := _get_health()
    if not hp or hp.max_health <= 0:
        return 0
    var ratio := hp.get_health_ratio()
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


func _get_health() -> HealthComponent:
    return get_parent().get_node_or_null("HealthComponent") as HealthComponent


func _get_global_rules() -> GlobalRules:
    var ef := get_node_or_null("/root/EntityFactory")
    if ef and ef.has_method("get_global_rules"):
        return ef.get_global_rules() as GlobalRules
    return null
