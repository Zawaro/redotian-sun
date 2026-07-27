@tool
class_name ArtComponent extends Node3D

## Emitted once the model mesh has been added as a child — for both the
## cache-hit path and a completed background load.
signal model_loaded

## Process-wide cache of loaded model scenes (model_path -> PackedScene),
## shared across every ArtComponent so each model is read from disk at most once.
static var _model_cache: Dictionary = {}

@export var art_data: ArtData = null

var _animation_player: AnimationPlayer
var _foundation: Vector2i = Vector2i(1, 1)
var _configured: bool = false
var _loading_path: String = ""


func _init() -> void:
    # Only poll while a background load is in flight (see _load_model / _process).
    set_process(false)


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if not _configured:
        if art_data and not art_data.model_path.is_empty():
            _load_model()
            if not art_data.active_anims.is_empty():
                _setup_animation_player()
        else:
            _add_placeholder()
    # Node3D re-enables _process on tree entry (overriding _init), so gate it here:
    # only poll while a threaded load is actually in flight (_process clears it on completion).
    set_process(not _loading_path.is_empty())


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
    # Connect to ExitComponent if present
    var exit := get_parent().get_node_or_null("ExitComponent")
    if exit and exit.has_signal("unit_spawned"):
        exit.unit_spawned.connect(_on_exit_unit_spawned)


func _load_model() -> void:
    if art_data == null or art_data.model_path.is_empty():
        return
    var path := art_data.model_path
    var cached := _model_cache.get(path) as PackedScene
    if cached != null:
        _finalize_model(cached)
        return
    if not ResourceLoader.exists(path):
        push_warning("ArtComponent: model not found: %s" % path)
        return
    # Load off the main thread; completion is polled in _process().
    var err := ResourceLoader.load_threaded_request(path)
    if err != OK:
        push_warning("ArtComponent: failed to request model: %s" % path)
        return
    _loading_path = path
    set_process(true)


func _process(_delta: float) -> void:
    if Engine.is_editor_hint() or _loading_path.is_empty():
        return
    var status := ResourceLoader.load_threaded_get_status(_loading_path)
    if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        return
    var path := _loading_path
    _loading_path = ""
    set_process(false)
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        push_warning("ArtComponent: failed to load model: %s" % path)
        return
    var scene := ResourceLoader.load_threaded_get(path) as PackedScene
    if scene == null:
        push_warning("ArtComponent: loaded resource is not a PackedScene: %s" % path)
        return
    _model_cache[path] = scene
    if not is_instance_valid(self):
        return
    _finalize_model(scene)


func _finalize_model(scene: PackedScene) -> void:
    var instance := scene.instantiate()
    add_child(instance)
    instance.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
    if not art_data.texture_path.is_empty() and ResourceLoader.exists(art_data.texture_path):
        var tex := load(art_data.texture_path) as Texture2D
        if tex:
            var mat := StandardMaterial3D.new()
            mat.albedo_texture = tex
            _apply_material(instance, mat)
    # Deferred so a consumer connecting right after configure() (cache-hit path) still
    # receives it; the async path is already post-connection but stays uniform this way.
    model_loaded.emit.call_deferred()


func _apply_material(node: Node, mat: StandardMaterial3D) -> void:
    if node is MeshInstance3D:
        node.set_surface_override_material(0, mat)
    for child in node.get_children():
        _apply_material(child, mat)


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


func _on_exit_unit_spawned(_unit: Node3D) -> void:
    if not art_data:
        return
    if not art_data.door_anim.is_empty():
        play_animation(art_data.door_anim)
    if not art_data.under_door_anim.is_empty():
        play_animation(art_data.under_door_anim)
