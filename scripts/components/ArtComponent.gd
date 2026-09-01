@tool
class_name ArtComponent extends Node3D

## Emitted once the model mesh has been added as a child — for both the
## cache-hit path and a completed background load.
signal model_loaded

@export var art_data: ArtData = null

var _animation_player: AnimationPlayer
var _foundation: Vector2i = Vector2i(1, 1)
var _configured: bool = false
var _waiting_for_path: String = ""
var _entity_type: int = -1
var _is_remappable: bool = false
var _registered: bool = false
var _entity_root: Node3D = null
var _model_root: Node3D = null
## Whether active_anims should be playing (online + model loaded).
var _active_anims_running: bool = false


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if not _configured:
        if art_data and not art_data.model_path.is_empty():
            _try_load_model()
            if not art_data.active_anims.is_empty():
                _setup_animation_player()
        else:
            _add_placeholder()


func _exit_tree() -> void:
    _unregister_with_renderer()
    if not _waiting_for_path.is_empty():
        if BatchLoader.model_loaded.is_connected(_on_batch_model_loaded):
            BatchLoader.model_loaded.disconnect(_on_batch_model_loaded)
        _waiting_for_path = ""


func configure(data: EntityData) -> void:
    art_data = data.art_data
    _foundation = data.foundation
    _entity_type = data.entity_type
    _entity_root = get_parent() as Node3D
    _is_remappable = data.art_data.is_remappable if data.art_data else false
    _configured = true
    if art_data and not art_data.model_path.is_empty():
        _try_load_model()
        if not art_data.active_anims.is_empty():
            _setup_animation_player()
    else:
        _add_placeholder()
    # Connect to ExitComponent if present
    var exit := get_parent().get_node_or_null("ExitComponent")
    if exit and exit.has_signal("unit_spawned"):
        exit.unit_spawned.connect(_on_exit_unit_spawned)
    # Powered-down structures freeze their active animations (power-grid).
    var power := get_parent().get_node_or_null("PowerComponent") as PowerComponent
    if power:
        power.power_state_changed.connect(_on_power_state_changed)
        _active_anims_running = power.is_online


func _try_load_model() -> void:
    if art_data == null or art_data.model_path.is_empty():
        return
    var path := art_data.model_path
    # 1. Check BatchLoader cache — instant hit
    var cached := BatchLoader.get_scene(path)
    if cached != null:
        _finalize_model(cached)
        return
    # 2. Check if BatchLoader is already loading this path — wait for signal
    if BatchLoader.is_in_flight(path):
        _wait_for_model(path)
        return
    # 3. Fallback: fire our own threaded request
    _load_model_fallback(path)


func _wait_for_model(path: String) -> void:
    _waiting_for_path = path
    if not BatchLoader.model_loaded.is_connected(_on_batch_model_loaded):
        BatchLoader.model_loaded.connect(_on_batch_model_loaded)


func _on_batch_model_loaded(path: String) -> void:
    if path != _waiting_for_path:
        return
    if BatchLoader.model_loaded.is_connected(_on_batch_model_loaded):
        BatchLoader.model_loaded.disconnect(_on_batch_model_loaded)
    _waiting_for_path = ""
    var scene := BatchLoader.get_scene(path)
    if scene != null and is_instance_valid(self):
        _finalize_model(scene)


func _load_model_fallback(path: String) -> void:
    if not ResourceLoader.exists(path):
        push_warning("ArtComponent: model not found: %s" % path)
        return
    var err := ResourceLoader.load_threaded_request(path)
    if err != OK:
        push_warning("ArtComponent: failed to request model: %s" % path)
        return
    _waiting_for_path = path
    # Poll via _process for the fallback path
    set_process(true)


func _process(_delta: float) -> void:
    if Engine.is_editor_hint() or _waiting_for_path.is_empty():
        return
    var path := _waiting_for_path
    var status := ResourceLoader.load_threaded_get_status(path)
    if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        return
    _waiting_for_path = ""
    set_process(false)
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        push_warning("ArtComponent: failed to load model: %s" % path)
        return
    var scene := ResourceLoader.load_threaded_get(path) as PackedScene
    if scene == null:
        push_warning("ArtComponent: loaded resource is not a PackedScene: %s" % path)
        return
    if not is_instance_valid(self):
        return
    _finalize_model(scene)


func _finalize_model(scene: PackedScene) -> void:
    var instance := scene.instantiate()
    add_child(instance)
    instance.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
    _model_root = instance
    if not art_data.texture_path.is_empty() and ResourceLoader.exists(art_data.texture_path):
        var tex := load(art_data.texture_path) as Texture2D
        if tex:
            var mat := StandardMaterial3D.new()
            mat.albedo_texture = tex
            _apply_material(instance, mat)
    # Deferred so a consumer connecting right after configure() (cache-hit path) still
    # receives it; the async path is already post-connection but stays uniform this way.
    model_loaded.emit.call_deferred()
    _request_registration(instance)
    _maybe_freeze_into_depot(instance)
    _start_active_anims_if_online()


## The loaded GLB instance, used by fog-ghost freeze to reparent it into the
## depot. Non-GLB entities (e.g. tiberium cubes) return null.
func get_model_root() -> Node3D:
    return _model_root


## A model that finishes loading while its entity is already fogged parents
## straight into the ghost depot so it never flashes live under fog. Units are
## exempt: their GLB tree stays hidden and the MultiMesh handles the freeze.
func _maybe_freeze_into_depot(instance: Node3D) -> void:
    if Engine.is_editor_hint():
        return
    if _eligible_for_instancing():
        return
    if not is_instance_valid(_entity_root):
        return
    var depot := GhostDepot.get_instance()
    if depot == null or depot.has_ghost(_entity_root):
        return
    if not GhostDepot.is_frozen_candidate(_entity_root):
        return
    (
        depot
        . reparent_in(
            _entity_root,
            instance,
            self,
            CellUtil.world_to_cell(_entity_root.global_position),
            false,
        )
    )


## Unit-type entities render through the UnitMeshRenderer MultiMesh buckets
## instead of their GLB node tree. Registration is deferred so the entity is in
## the scene tree (register needs global_position and the autoload).
func _request_registration(instance: Node3D) -> void:
    if Engine.is_editor_hint():
        return
    if not _eligible_for_instancing():
        return
    call_deferred("_register_with_renderer", instance)


func _eligible_for_instancing() -> bool:
    return (
        _entity_type == EntityData.EntityType.INFANTRY
        or _entity_type == EntityData.EntityType.VEHICLE
        or _entity_type == EntityData.EntityType.AIRCRAFT
    )


func _register_with_renderer(instance: Node3D) -> void:
    if not is_instance_valid(self) or _registered:
        return
    if not is_instance_valid(instance) or not is_instance_valid(_entity_root):
        return
    var tree := get_tree()
    if tree == null:
        return
    var renderer := tree.root.get_node_or_null("UnitMeshRenderer")
    if renderer == null:
        return
    var model_offset := transform * instance.transform
    if renderer.register(_entity_root, art_data.model_path, instance, model_offset, _is_remappable):
        _registered = true


func _unregister_with_renderer() -> void:
    if not _registered:
        return
    _registered = false
    var tree := get_tree()
    if tree == null or not is_instance_valid(_entity_root):
        return
    var renderer := tree.root.get_node_or_null("UnitMeshRenderer")
    if renderer != null:
        renderer.unregister(_entity_root)


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
    _model_root = instance
    if Engine.is_editor_hint():
        return
    # Placeholders render through the node tree, not a baked MultiMesh: units
    # register with the renderer (fog freeze via slot -1), non-units freeze
    # into the ghost depot like their GLB counterparts.
    if _eligible_for_instancing():
        _request_registration(instance)
    else:
        _maybe_freeze_into_depot(instance)


func _setup_animation_player() -> void:
    if not has_node("AnimationPlayer"):
        var ap := AnimationPlayer.new()
        ap.name = "AnimationPlayer"
        add_child(ap)
    _animation_player = get_node("AnimationPlayer") as AnimationPlayer


func play_animation(anim_name: String) -> void:
    if _animation_player and _animation_player.has_animation(anim_name):
        _animation_player.play(anim_name)


## Start/pause every active_anim. The Animation resource's loop mode follows
## ActiveAnimData.loop. Missing animations are skipped silently (play_animation
## guards on has_animation). Pausing preserves the playhead; play() resumes it.
func set_active_anims_running(running: bool) -> void:
    _active_anims_running = running
    if art_data == null or _animation_player == null:
        return
    if not running:
        _animation_player.pause()
        return
    for anim in art_data.active_anims:
        if anim == null or anim.anim_name.is_empty():
            continue
        if not _animation_player.has_animation(anim.anim_name):
            continue
        if anim.loop:
            _animation_player.get_animation(anim.anim_name).loop_mode = Animation.LOOP_LINEAR
        _animation_player.play(anim.anim_name)


func _on_power_state_changed(is_online: bool) -> void:
    set_active_anims_running(is_online)


## Kick active animations once the model (and its animations) has landed.
func _start_active_anims_if_online() -> void:
    if _active_anims_running:
        set_active_anims_running(true)


func _on_exit_unit_spawned(_unit: Node3D) -> void:
    if not art_data:
        return
    if not art_data.door_anim.is_empty():
        play_animation(art_data.door_anim)
    if not art_data.under_door_anim.is_empty():
        play_animation(art_data.under_door_anim)
