extends Node

## Renders data-driven unit entities through per-region MultiMesh buckets.
## Mirrors TerrainRenderer: bake-merged per-model meshes (ModelBaker), one
## instance per unit, swap-remove slot lifecycle, visible_instance_count, and a
## custom_aabb per region so frustum culling still works. Instance transforms
## are synced every physics frame from the entity's world transform.

const REGION_SIZE: float = 32.0
const MAX_INSTANCES_PER_REGION: int = 512
const HIDDEN_POSITION := Vector3(-9999.0, -9999.0, -9999.0)

## entity_root(Node3D) -> entry
## entry: {model_path, model_root, region, slot, offset, is_remappable}
var _registry: Dictionary = {}
## region_key(Vector2i) -> {model_path -> bucket}
## bucket: {mmi, multimesh, active_count}
var _buckets: Dictionary = {}
var _active_count: int = 0


func _ready() -> void:
    # Sync after gameplay nodes move (higher priority runs later), so instance
    # transforms reflect the current physics step rather than the previous one.
    process_physics_priority = 100
    set_physics_process(false)


## Registers a unit whose model_root (GLB instance) is a child of the entity's
## ArtComponent. The GLB node tree is hidden on success — gameplay never reads
## mesh-child transforms (hitboxes are Area3D, movement rotates the entity
## root). Returns false when ineligible, unknown model, or no free slot.
func register(
    entity_root: Node3D,
    model_path: String,
    model_root: Node3D,
    model_offset: Transform3D,
    is_remappable: bool,
) -> bool:
    if Engine.is_editor_hint():
        return false
    if (
        not is_instance_valid(entity_root)
        or not is_instance_valid(model_root)
        or model_path.is_empty()
        or _registry.has(entity_root)
    ):
        return false
    if not _can_register(entity_root):
        return false
    var mesh: ArrayMesh = _ensure_mesh(model_path, is_remappable)
    if mesh == null:
        return false
    var region := _region_key(entity_root.global_position)
    var slot := _alloc_slot(model_path, region, mesh)
    if slot < 0:
        push_warning("UnitMeshRenderer: region %s full for %s" % [region, model_path])
        return false
    _registry[entity_root] = {
        "model_path": model_path,
        "model_root": model_root,
        "region": region,
        "slot": slot,
        "offset": model_offset,
        "is_remappable": is_remappable,
    }
    model_root.visible = false
    _active_count += 1
    set_physics_process(true)
    return true


func unregister(entity_root: Node3D) -> void:
    if not _registry.has(entity_root):
        return
    var entry: Dictionary = _registry[entity_root]
    _registry.erase(entity_root)
    _active_count -= 1
    _release_slot(entry["model_path"], entry["region"], entry["slot"])
    if _active_count <= 0:
        set_physics_process(false)


func _can_register(entity_root: Node3D) -> bool:
    if entity_root.process_mode == Node.PROCESS_MODE_DISABLED:
        return false
    var node: Node = entity_root
    while node:
        if node.has_meta("_preview") or node.has_meta("is_map_editor"):
            return false
        node = node.get_parent()
    return true


func _ensure_mesh(model_path: String, is_remappable: bool) -> ArrayMesh:
    # ModelBaker caches the baked mesh per path internally.
    var result := ModelBaker.bake_model(model_path, is_remappable)
    if result.is_empty():
        return null
    return result.get("mesh") as ArrayMesh


func _region_key(pos: Vector3) -> Vector2i:
    return Vector2i(floori(pos.x / REGION_SIZE), floori(pos.z / REGION_SIZE))


func _region_aabb(region: Vector2i) -> AABB:
    var origin := Vector3(region.x * REGION_SIZE, -50.0, region.y * REGION_SIZE)
    return AABB(origin, Vector3(REGION_SIZE, 500.0, REGION_SIZE))


func _ensure_bucket(model_path: String, region: Vector2i, mesh: ArrayMesh) -> Dictionary:
    var region_map: Dictionary = _buckets.get(region, {})
    if not region_map.has(model_path):
        var multimesh := MultiMesh.new()
        multimesh.mesh = mesh
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.instance_count = MAX_INSTANCES_PER_REGION
        multimesh.visible_instance_count = 0
        multimesh.custom_aabb = _region_aabb(region)
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = multimesh
        # bug #108058: physics interpolation corrupts per-instance transforms.
        mmi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
        add_child(mmi)
        region_map[model_path] = {"mmi": mmi, "multimesh": multimesh, "active_count": 0}
        _buckets[region] = region_map
    return region_map[model_path]


func _get_multimesh(model_path: String, region: Vector2i) -> MultiMesh:
    var region_map: Dictionary = _buckets.get(region, {})
    var bucket: Dictionary = region_map.get(model_path, {})
    return bucket.get("multimesh", null)


func _alloc_slot(model_path: String, region: Vector2i, mesh: ArrayMesh) -> int:
    var bucket := _ensure_bucket(model_path, region, mesh)
    var multimesh: MultiMesh = bucket["multimesh"]
    var count: int = bucket["active_count"]
    if count >= MAX_INSTANCES_PER_REGION:
        return -1
    bucket["active_count"] = count + 1
    multimesh.visible_instance_count = count + 1
    return count


func _release_slot(model_path: String, region: Vector2i, slot: int) -> void:
    var region_map: Dictionary = _buckets.get(region, {})
    var bucket: Dictionary = region_map.get(model_path, {})
    if bucket.is_empty():
        return
    var multimesh: MultiMesh = bucket["multimesh"]
    var last: int = bucket["active_count"] - 1
    if slot != last:
        var last_transform: Transform3D = multimesh.get_instance_transform(last)
        multimesh.set_instance_transform(slot, last_transform)
        for entity in _registry:
            var entry: Dictionary = _registry[entity]
            if (
                entry["model_path"] == model_path
                and entry["region"] == region
                and entry["slot"] == last
            ):
                entry["slot"] = slot
                break
    bucket["active_count"] = last
    multimesh.visible_instance_count = last
    multimesh.set_instance_transform(last, Transform3D(Basis(), HIDDEN_POSITION))
    if last == 0:
        var mmi: MultiMeshInstance3D = bucket["mmi"]
        if is_instance_valid(mmi):
            remove_child(mmi)
            mmi.queue_free()
        region_map.erase(model_path)
        if region_map.is_empty():
            _buckets.erase(region)


func _physics_process(_delta: float) -> void:
    if Engine.is_editor_hint() or _registry.is_empty():
        return
    var in_map_editor := _current_scene_is_map_editor()
    for entity in _registry.keys():
        var entity_node: Node3D = entity
        if not is_instance_valid(entity_node):
            unregister(entity)
            continue
        var entry: Dictionary = _registry[entity_node]
        var model_root: Node3D = entry["model_root"]
        var preview := (
            in_map_editor
            or entity_node.process_mode == Node.PROCESS_MODE_DISABLED
            or entity_node.has_meta("_preview")
        )
        if preview:
            _set_model_visible(model_root, true)
            # ponytail: a parked preview keeps its slot counted toward region
            # capacity (one transient preview at a time, negligible under 512);
            # eject the slot too if previews ever outnumber region headroom.
            var parked: MultiMesh = _get_multimesh(entry["model_path"], entry["region"])
            if parked and entry["slot"] >= 0:
                parked.set_instance_transform(entry["slot"], Transform3D(Basis(), HIDDEN_POSITION))
            continue
        _set_model_visible(model_root, false)
        var region := _region_key(entity_node.global_position)
        if region != entry["region"]:
            _release_slot(entry["model_path"], entry["region"], entry["slot"])
            entry["region"] = region
            var migrated_mesh: ArrayMesh = _ensure_mesh(entry["model_path"], entry["is_remappable"])
            entry["slot"] = _alloc_slot(entry["model_path"], region, migrated_mesh)
            if entry["slot"] < 0:
                push_warning(
                    (
                        "UnitMeshRenderer: region %s full for %s; falling back to node-tree"
                        % [region, entry["model_path"]]
                    )
                )
                _set_model_visible(model_root, true)
        if entry["slot"] >= 0:
            var multimesh: MultiMesh = _get_multimesh(entry["model_path"], entry["region"])
            if multimesh:
                multimesh.set_instance_transform(
                    entry["slot"], entity_node.global_transform * entry["offset"]
                )


func _set_model_visible(model_root: Node3D, visible: bool) -> void:
    if is_instance_valid(model_root) and model_root.visible != visible:
        model_root.visible = visible


func _current_scene_is_map_editor() -> bool:
    var scene := get_tree().current_scene
    return scene != null and scene.has_meta("is_map_editor")


func clear_all() -> void:
    for entity in _registry.keys():
        unregister(entity)
