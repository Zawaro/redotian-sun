@tool
class_name ArtComponent extends Node3D

## Emitted once the model mesh has been added as a child — for both the
## cache-hit path and a completed background load.
signal model_loaded
## Emitted when a BUILDUP clip finishes and the normal art is revealed.
signal buildup_finished

@export var art_data: ArtData = null

## Health ratio at or below which an ACTIVE clip swaps to its damaged variant.
const DAMAGED_HEALTH_THRESHOLD: float = 0.5

var _foundation: Vector2i = Vector2i(1, 1)
var _configured: bool = false
var _waiting_for_path: String = ""
## Resolved (theater-applied) path of the base model currently loading/loaded.
var _resolved_model_path: String = ""
var _entity_type: int = -1
var _is_remappable: bool = false
var _registered: bool = false
var _entity_root: Node3D = null
var _model_root: Node3D = null

## Instantiated animation clips. Each record:
## {entry: AnimClipData, node, player, anim_name, damaged_node, damaged_player,
##  damaged_anim_name}
var _clips: Array[Dictionary] = []
var _clips_built: bool = false
var _health: HealthComponent = null
var _is_damaged: bool = false
var _power_online: bool = true
var _buildup_requested: bool = false
var _buildup_running: bool = false
var _buildup_record: Dictionary = {}


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if _configured:
        return
    if art_data and not art_data.model_path.is_empty():
        _try_load_model()
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
    # Connect first: _build_clips runs on the synchronous (cache-hit/placeholder)
    # path and must see the real power/damaged state, not the defaults.
    _connect_siblings()
    if art_data and not art_data.model_path.is_empty():
        _try_load_model()
    else:
        _add_placeholder()


## Wires the sibling components that drive gated and one-shot clips. Signal up:
## children emit, this component reacts — no sibling method calls.
func _connect_siblings() -> void:
    var parent := get_parent()
    if parent == null:
        return
    var exit := parent.get_node_or_null("ExitComponent")
    if exit:
        if (
            exit.has_signal("unit_spawned")
            and not exit.unit_spawned.is_connected(_on_exit_unit_spawned)
        ):
            exit.unit_spawned.connect(_on_exit_unit_spawned)
        if (
            exit.has_signal("exit_completed")
            and not exit.exit_completed.is_connected(_on_exit_completed)
        ):
            exit.exit_completed.connect(_on_exit_completed)
    var factory := parent.get_node_or_null("FactoryComponent") as FactoryComponent
    if factory and not factory.exit_in_progress.is_connected(_on_exit_in_progress):
        factory.exit_in_progress.connect(_on_exit_in_progress)
    var power := parent.get_node_or_null("PowerComponent") as PowerComponent
    if power:
        if not power.power_state_changed.is_connected(_on_power_state_changed):
            power.power_state_changed.connect(_on_power_state_changed)
        _power_online = power.is_online
    _health = parent.get_node_or_null("HealthComponent") as HealthComponent
    if _health:
        if not _health.health_changed.is_connected(_on_health_changed):
            _health.health_changed.connect(_on_health_changed)
        _is_damaged = _health.get_health_ratio() <= DAMAGED_HEALTH_THRESHOLD


func _try_load_model() -> void:
    if art_data == null or art_data.model_path.is_empty():
        return
    var path := _resolve_path(art_data.model_path)
    _resolved_model_path = path
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
    _build_clips()
    _maybe_start_buildup()


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
    var key := _resolved_model_path if not _resolved_model_path.is_empty() else art_data.model_path
    if (
        renderer
        . register(
            _entity_root,
            key,
            instance,
            model_offset,
            _is_remappable,
            _collect_sockets(),
        )
    ):
        _registered = true


## Builds the renderer's socket descriptors: id, bucket key, mesh, and pivot.
## A socket with a reserved model_path bakes that model; otherwise it uses a
## generated placeholder box keyed by size.
func _collect_sockets() -> Array:
    if art_data == null or art_data.sockets.is_empty():
        return []
    var result: Array = []
    for socket in art_data.sockets:
        if socket == null or socket.id.is_empty():
            continue
        var key := socket.model_path
        var mesh: ArrayMesh = null
        if not key.is_empty() and ResourceLoader.exists(key):
            var scene := load(key) as PackedScene
            if scene:
                var root := scene.instantiate() as Node3D
                if root:
                    var baked := ModelBaker.bake_merged_mesh(root, _is_remappable)
                    mesh = baked.get("mesh") as ArrayMesh
                    root.free()
        if mesh == null:
            if socket.placeholder_size == Vector3.ZERO:
                continue
            key = _placeholder_socket_key(socket.placeholder_size)
            mesh = _placeholder_socket_mesh(socket.placeholder_size)
        result.append({"id": socket.id, "key": key, "mesh": mesh, "pivot": socket.pivot})
    return result


static func _placeholder_socket_key(size: Vector3) -> String:
    return "__socket:%.3f,%.3f,%.3f" % [size.x, size.y, size.z]


## Placeholder meshes are shared across every entity: the renderer buckets them
## by key and only keeps the first, so re-baking one per registration is waste.
static var _placeholder_meshes: Dictionary = {}


static func _placeholder_socket_mesh(size: Vector3) -> ArrayMesh:
    var cache_key := _placeholder_socket_key(size)
    if _placeholder_meshes.has(cache_key):
        return _placeholder_meshes[cache_key]
    var box := BoxMesh.new()
    box.size = size
    var arrays := box.surface_get_arrays(0)
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    _placeholder_meshes[cache_key] = mesh
    return mesh


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
    _build_clips()
    _maybe_start_buildup()


# --- Animation clips ---------------------------------------------------------


## Resolves an art path for the active theater id (see ArtData.resolve_art_path).
func _resolve_path(path: String) -> String:
    if art_data == null:
        return path
    return art_data.resolve_art_path(path, TerrainCatalog.get_active_theater_id())


## Instantiates and wires every authored clip once. Idempotent: clips are built
## after the base model (or placeholder) lands, whichever path runs first.
## ponytail: builds for every entity type. Instanced units render through
## UnitMeshRenderer and an animated sub-mesh here would double-render; unit
## animation is out of scope for now — see #437 before authoring unit clips.
func _build_clips() -> void:
    if _clips_built or art_data == null:
        return
    _clips_built = true
    for entry in art_data.animations:
        if entry == null or entry.model_path.is_empty():
            continue
        var record := _instantiate_clip(entry, entry.model_path)
        if record.is_empty():
            continue
        record["anim_name"] = _configure_player(record.get("player"), entry)
        if entry.role == AnimClipData.Role.ACTIVE and not entry.damaged_model_path.is_empty():
            var damaged := _instantiate_clip(entry, entry.damaged_model_path)
            if not damaged.is_empty():
                record["damaged_node"] = damaged.get("node")
                record["damaged_player"] = damaged.get("player")
                record["damaged_anim_name"] = _configure_player(damaged.get("player"), entry, true)
        var node: Node3D = record.get("node")
        if is_instance_valid(node):
            node.visible = _role_starts_visible(entry.role)
        _clips.append(record)
        _apply_clip_state(record)
        if entry.role == AnimClipData.Role.DOOR:
            _rest_at_first_frame(record.get("player"), record.get("anim_name", ""))


## Instantiates one clip scene as a child at its offset and finds its player.
## Returns {} when the scene cannot be loaded or instantiated.
func _instantiate_clip(entry: AnimClipData, raw_path: String) -> Dictionary:
    var path := _resolve_path(raw_path)
    var scene := _load_clip_scene(path)
    if scene == null:
        push_warning("ArtComponent: animation clip not found: %s" % path)
        return {}
    var node := scene.instantiate() as Node3D
    if node == null:
        push_warning("ArtComponent: animation clip is not a Node3D: %s" % path)
        return {}
    add_child(node)
    node.owner = get_tree().edited_scene_root if Engine.is_editor_hint() else owner
    node.position = entry.offset
    var player := _find_animation_player(node)
    return {"entry": entry, "node": node, "player": player}


## Cached first, then a synchronous load — clip GLBs are small and resolve at
## model-finalize time, not per frame.
func _load_clip_scene(path: String) -> PackedScene:
    var cached := BatchLoader.get_scene(path)
    if cached != null:
        return cached
    if not ResourceLoader.exists(path):
        return null
    return load(path) as PackedScene


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null


## Applies speed and loop to a clip player and returns the resolved animation
## name ("" when the player or the named animation is missing). With
## `fallback_first`, a missing named animation falls back to the player's first
## animation — the damaged variant is a separate GLB and may name its clip
## differently.
func _configure_player(
    player: AnimationPlayer, entry: AnimClipData, fallback_first := false
) -> String:
    if player == null:
        return ""
    _isolate_player_library(player)
    var anim_name := _resolve_clip_name(player, entry.clip_name)
    if anim_name.is_empty() and fallback_first:
        anim_name = _resolve_clip_name(player, "")
    player.speed_scale = entry.speed_scale
    if not anim_name.is_empty():
        var animation := player.get_animation(anim_name)
        if animation:
            var loop_mode := Animation.LOOP_LINEAR if _clip_loops(entry) else Animation.LOOP_NONE
            animation.loop_mode = loop_mode
    return anim_name


## Only ACTIVE clips loop; every other role is a one-shot lifecycle clip and
## must stop (BUILDUP needs animation_finished; DOOR must not cycle). The
## per-entry `loop` flag is honored for ACTIVE only.
func _clip_loops(entry: AnimClipData) -> bool:
    return entry.role == AnimClipData.Role.ACTIVE and entry.loop


## Duplicates every animation library on a clip player so per-instance loop
## edits never mutate the shared PackedScene handed out by the BatchLoader
## cache (all entities using a clip would otherwise share one Animation).
# ponytail: duplicates per clip instance; clips are small and few per entity.
func _isolate_player_library(player: AnimationPlayer) -> void:
    for lib_name in player.get_animation_library_list():
        var library := player.get_animation_library(lib_name)
        if library == null:
            continue
        player.remove_animation_library(lib_name)
        player.add_animation_library(lib_name, library.duplicate(true) as AnimationLibrary)


func _resolve_clip_name(player: AnimationPlayer, clip_name: String) -> String:
    if not clip_name.is_empty():
        return clip_name if player.has_animation(clip_name) else ""
    var list := player.get_animation_list()
    return String(list[0]) if not list.is_empty() else ""


## ACTIVE and DOOR clips are visible from the start (idle shows the door's first
## frame); other one-shots stay hidden until triggered.
func _role_starts_visible(role: AnimClipData.Role) -> bool:
    return role == AnimClipData.Role.ACTIVE or role == AnimClipData.Role.DOOR


## Applies the current power and damaged state to one clip record. ACTIVE clips
## swap to their damaged variant and play/pause; one-shot clips only pause on a
## blackout (they are event-driven and never auto-resume).
func _apply_clip_state(record: Dictionary) -> void:
    var entry: AnimClipData = record.get("entry")
    if entry == null:
        return
    var powered := _power_online or not entry.requires_power
    if entry.role != AnimClipData.Role.ACTIVE:
        if not powered:
            var one_shot: AnimationPlayer = record.get("player")
            if one_shot != null and one_shot.is_playing():
                one_shot.pause()
        return
    var damaged_node: Node3D = record.get("damaged_node")
    var use_damaged := _is_damaged and is_instance_valid(damaged_node)
    var node: Node3D = record.get("node")
    if is_instance_valid(node):
        node.visible = not use_damaged
    if is_instance_valid(damaged_node):
        damaged_node.visible = use_damaged
    _set_player_running(
        record.get("player"), record.get("anim_name", ""), powered and not use_damaged
    )
    _set_player_running(
        record.get("damaged_player"),
        record.get("damaged_anim_name", ""),
        powered and use_damaged,
    )


## Rests a door clip on its first frame while idle. A never-played player shows
## the bind pose, which is not necessarily keyframe 0.
func _rest_at_first_frame(player: AnimationPlayer, anim_name: String) -> void:
    if player == null or anim_name.is_empty():
        return
    player.play(anim_name)
    player.seek(0.0, true)
    player.pause()


## Plays/pauses a clip player, resuming from the paused playhead on resume.
## (AnimationPlayer.pause() clears current_animation but keeps the position.)
func _set_player_running(player: AnimationPlayer, anim_name: String, running: bool) -> void:
    if player == null or anim_name.is_empty():
        return
    if running:
        if player.is_playing():
            return
        var position := player.current_animation_position
        player.play(anim_name)
        if position > 0.0:
            player.seek(position, true)
    elif player.is_playing():
        player.pause()


func _on_power_state_changed(is_online: bool) -> void:
    _power_online = is_online
    for record in _clips:
        _apply_clip_state(record)


func _on_health_changed(_new_health: int, _old_health: int) -> void:
    if _health == null:
        return
    var damaged := _health.get_health_ratio() <= DAMAGED_HEALTH_THRESHOLD
    if damaged == _is_damaged:
        return
    _is_damaged = damaged
    for record in _clips:
        _apply_clip_state(record)


# --- One-shot lifecycle clips ------------------------------------------------


func _on_exit_in_progress() -> void:
    _set_door_open(true)
    _set_production(true)


func _on_exit_completed() -> void:
    _set_door_open(false)
    _set_production(false)


func _on_exit_unit_spawned(_unit: Node3D) -> void:
    _play_role_once(AnimClipData.Role.UNDER_DOOR)


## DOOR clips are one mesh: forward opens, backward closes to the holding frame.
func _set_door_open(open: bool) -> void:
    for record in _clips:
        var entry: AnimClipData = record.get("entry")
        if entry == null or entry.role != AnimClipData.Role.DOOR:
            continue
        var node: Node3D = record.get("node")
        if is_instance_valid(node):
            node.visible = true
        var player: AnimationPlayer = record.get("player")
        var anim_name: String = record.get("anim_name", "")
        if player == null or anim_name.is_empty():
            continue
        player.speed_scale = entry.speed_scale
        if open:
            player.play(anim_name)
        else:
            player.play_backwards(anim_name)


func _set_production(on: bool) -> void:
    for record in _clips:
        var entry: AnimClipData = record.get("entry")
        if entry == null or entry.role != AnimClipData.Role.PRODUCTION:
            continue
        var node: Node3D = record.get("node")
        if is_instance_valid(node):
            node.visible = on
        var player: AnimationPlayer = record.get("player")
        var anim_name: String = record.get("anim_name", "")
        if player == null or anim_name.is_empty():
            continue
        if on:
            if not player.is_playing():
                player.play(anim_name)
        elif player.is_playing():
            player.stop()


func _play_role_once(role: AnimClipData.Role) -> void:
    for record in _clips:
        var entry: AnimClipData = record.get("entry")
        if entry == null or entry.role != role:
            continue
        var node: Node3D = record.get("node")
        if is_instance_valid(node):
            node.visible = true
        var player: AnimationPlayer = record.get("player")
        var anim_name: String = record.get("anim_name", "")
        if player != null and not anim_name.is_empty():
            player.play(anim_name)


## Plays the BUILDUP clip once, hiding the base model and ACTIVE clips until it
## finishes. Called by BuildingManager on placement; map-load and deploy-created
## structures never call it, so they skip buildup.
func play_buildup() -> void:
    _buildup_requested = true
    _maybe_start_buildup()


func _maybe_start_buildup() -> void:
    if not _buildup_requested or _buildup_running or not _clips_built:
        return
    var record := _first_role(AnimClipData.Role.BUILDUP)
    if record.is_empty():
        return
    _buildup_running = true
    _buildup_record = record
    if is_instance_valid(_model_root):
        _model_root.visible = false
    for active in _clips:
        var entry: AnimClipData = active.get("entry")
        if entry == null or entry.role != AnimClipData.Role.ACTIVE:
            continue
        var node: Node3D = active.get("node")
        if is_instance_valid(node):
            node.visible = false
        var damaged_node: Node3D = active.get("damaged_node")
        if is_instance_valid(damaged_node):
            damaged_node.visible = false
    var buildup_node: Node3D = record.get("node")
    if is_instance_valid(buildup_node):
        buildup_node.visible = true
    var player: AnimationPlayer = record.get("player")
    var anim_name: String = record.get("anim_name", "")
    if player != null and not anim_name.is_empty():
        if not player.animation_finished.is_connected(_on_buildup_finished):
            player.animation_finished.connect(_on_buildup_finished, CONNECT_ONE_SHOT)
        player.play(anim_name)
    else:
        _finish_buildup()


func _on_buildup_finished(_anim_name: StringName) -> void:
    _finish_buildup()


func _finish_buildup() -> void:
    _buildup_running = false
    _buildup_requested = false
    var record := _buildup_record
    _buildup_record = {}
    if not record.is_empty():
        var node: Node3D = record.get("node")
        if is_instance_valid(node):
            node.visible = false
    if is_instance_valid(_model_root):
        _model_root.visible = true
    for active in _clips:
        _apply_clip_state(active)
    buildup_finished.emit()


func _first_role(role: AnimClipData.Role) -> Dictionary:
    for record in _clips:
        var entry: AnimClipData = record.get("entry")
        if entry != null and entry.role == role:
            return record
    return {}
