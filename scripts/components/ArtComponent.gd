@tool
class_name ArtComponent extends Node3D

@export var art_data: ArtData = null

var _animation_player: AnimationPlayer
var _foundation: Vector2i = Vector2i(1, 1)
var _configured: bool = false


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if _configured:
        return
    if art_data and not art_data.model_path.is_empty():
        _load_model()
        if not art_data.active_anims.is_empty():
            _setup_animation_player()
    else:
        _add_placeholder()


func configure(data: EntityData) -> void:
    art_data = data.art_data
    _foundation = data.foundation
    _configured = true
    if art_data and not art_data.model_path.is_empty():
        _load_model()
        if not art_data.active_anims.is_empty():
            _setup_animation_player()
    else:
        _add_placeholder()


func _load_model() -> void:
    if art_data == null or art_data.model_path.is_empty():
        return
    if not ResourceLoader.exists(art_data.model_path):
        push_warning("ArtComponent: model not found: %s" % art_data.model_path)
        return
    var scene := load(art_data.model_path) as PackedScene
    if scene == null:
        push_warning("ArtComponent: failed to load model: %s" % art_data.model_path)
        return
    var instance := scene.instantiate()
    add_child(instance)
    instance.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
    if not art_data.texture_path.is_empty() and ResourceLoader.exists(art_data.texture_path):
        var tex := load(art_data.texture_path) as Texture2D
        if tex:
            var mat := StandardMaterial3D.new()
            mat.albedo_texture = tex
            _apply_emission(mat)
            _apply_material(instance, mat)


func _apply_material(node: Node, mat: StandardMaterial3D) -> void:
    if node is MeshInstance3D:
        node.set_surface_override_material(0, mat)
    for child in node.get_children():
        _apply_material(child, mat)


func _apply_emission(mat: StandardMaterial3D) -> void:
    if art_data and art_data.emission_enabled:
        mat.emission_enabled = true
        mat.emission = art_data.emission_color
        mat.emission_energy_multiplier = art_data.emission_energy_multiplier


func _add_placeholder() -> void:
    var cell_size := 2.0
    var mesh := BoxMesh.new()
    if art_data and art_data.placeholder_size != Vector3.ZERO:
        mesh.size = art_data.placeholder_size
    else:
        mesh.size = Vector3(_foundation.x * cell_size, cell_size, _foundation.y * cell_size)
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    var half_y: float = mesh.size.y * 0.5
    instance.position = Vector3(0, half_y, 0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.4, 0.4, 0.4)
    _apply_emission(mat)
    instance.material_override = mat
    add_child(instance)
    instance.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner


func _setup_animation_player() -> void:
    if not has_node("AnimationPlayer"):
        var ap := AnimationPlayer.new()
        ap.name = "AnimationPlayer"
        add_child(ap)
    _animation_player = get_node("AnimationPlayer") as AnimationPlayer


func play_animation(anim_name: String) -> void:
    if _animation_player and _animation_player.has_animation(anim_name):
        _animation_player.play(anim_name)
