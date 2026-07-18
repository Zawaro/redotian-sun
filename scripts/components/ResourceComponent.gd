class_name ResourceComponent extends Node

@export var resource_type_id: String = "tiberium_green"
@export var regrowth_rate: float = -1.0
## How many times this crystal has spread to adjacent cells. Capped by GlobalRules.spread_max.
@export var spread_count: int = 0

var _cube_nodes: Array[Node3D] = []
var _current_visual_stage: int = -1
var _art_data: ArtData = null

const CRYSTAL_SHADER: Shader = preload(
    "res://shaders/entities/tiberium_crystal.gdshader"
)

static var _mat_cache: Dictionary = {}


func configure(data: EntityData) -> void:
    resource_type_id = data.resource_type_id
    regrowth_rate = data.resource_regrowth_rate
    _art_data = data.art_data


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
                var mat := ShaderMaterial.new()
                mat.shader = CRYSTAL_SHADER
                var rules := _get_global_rules()
                var rt: ResourceType = rules.get_resource_type(resource_type_id) if rules else null
                var base_color: Color = rt.color if rt else Color(0.2, 0.8, 0.2)
                var dark_color := base_color * 0.3
                dark_color.a = 1.0
                mat.set_shader_parameter("color_bottom", dark_color)
                mat.set_shader_parameter("color_top", base_color)
                if _art_data and _art_data.emission_enabled:
                    mat.set_shader_parameter(
                        "emission_strength", _art_data.emission_energy_multiplier
                    )
                _mat_cache[resource_type_id] = mat
            mi.material_override = _mat_cache[resource_type_id]
            mi.layers = 2
            container.add_child(mi)

    for i in 3:
        var node := parent.get_node_or_null("Stage%d" % i) as Node3D
        if node:
            _cube_nodes.append(node)

    if _art_data and _art_data.point_light_enabled:
        _spawn_point_light(parent)
    _spawn_sparkles(parent)
    _spawn_glow_sprite(parent)


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


func _spawn_point_light(parent: Node3D) -> void:
    var light := OmniLight3D.new()
    light.name = "PointLight"
    light.position = Vector3(0, 1.0, 0)
    light.light_color = _art_data.point_light_color
    light.light_energy = _art_data.point_light_energy
    light.omni_range = _art_data.point_light_range
    light.omni_attenuation = _art_data.point_light_attenuation
    light.shadow_enabled = false
    light.light_cull_mask = 1
    parent.add_child(light)
    light.owner = parent.owner


func _spawn_sparkles(parent: Node3D) -> void:
    var particles := GPUParticles3D.new()
    particles.name = "Sparkles"
    particles.position = Vector3(0, 0.5, 0)
    particles.amount = 6
    particles.lifetime = 2.0
    particles.explosiveness = 0.0
    particles.randomness = 0.8
    particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    particles.visibility_aabb = AABB(
        Vector3(-1.0, -0.5, -1.0), Vector3(2.0, 2.0, 2.0)
    )

    var mat := ParticleProcessMaterial.new()
    mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    mat.emission_box_extents = Vector3(2.0, 0.1, 2.0)
    mat.direction = Vector3(0, 1, 0)
    mat.spread = 15.0
    mat.initial_velocity_min = 0.1
    mat.initial_velocity_max = 0.3
    mat.gravity = Vector3.ZERO
    mat.scale_min = 0.01
    mat.scale_max = 0.05
    mat.color = Color(0.4, 1.0, 0.4, 0.8)

    var gradient := Gradient.new()
    gradient.set_color(0, Color(0.4, 1.0, 0.4, 0.8))
    gradient.add_point(0.5, Color(0.2, 0.8, 0.2, 0.4))
    gradient.add_point(1.0, Color(0.1, 0.5, 0.1, 0.0))
    var color_ramp := GradientTexture1D.new()
    color_ramp.gradient = gradient
    mat.color_ramp = color_ramp

    particles.process_material = mat
    particles.draw_pass_1 = _make_particle_mesh()
    parent.add_child(particles)
    particles.owner = parent.owner


func _make_particle_mesh() -> SphereMesh:
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 6
    mesh.rings = 3
    return mesh


func _spawn_glow_sprite(parent: Node3D) -> void:
    var sprite := Sprite3D.new()
    sprite.name = "GlowAura"
    sprite.position = Vector3(2.0, 2.0, 2.0)
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.pixel_size = 0.01
    sprite.modulate = Color(0.3, 1.0, 0.3, 0.25)
    sprite.layers = 1
    sprite.scale = Vector3(8, 8, 1)
    sprite.texture = _make_glow_texture()
    parent.add_child(sprite)
    sprite.owner = parent.owner


func _make_glow_texture() -> ImageTexture:
    var size := 64
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    var center := Vector2(size * 0.5, size * 0.5)
    var max_dist := size * 0.5
    for y in size:
        for x in size:
            var dist := Vector2(x, y).distance_to(center) / max_dist
            var alpha := clampf(1.0 - dist, 0.0, 1.0)
            alpha = alpha * alpha
            img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
    var tex := ImageTexture.create_from_image(img)
    return tex


func _get_global_rules() -> GlobalRules:
    var ef := get_node_or_null("/root/EntityFactory")
    if ef and ef.has_method("get_global_rules"):
        return ef.get_global_rules() as GlobalRules
    return null
