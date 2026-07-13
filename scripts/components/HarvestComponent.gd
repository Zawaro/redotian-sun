class_name HarvestComponent extends Node

enum State { IDLE, SEEK_NODE, HARVESTING, FULL, DOCKING, UNLOADING, QUEUED }

## Resource categories this harvester collects (e.g. ["tiberium"] for all tiberium types).
@export var harvestable_types: PackedStringArray = ["tiberium"]
## Search radius in cells when looking for the nearest harvestable resource.
@export var search_radius_cells: int = 20

var _state: int = State.IDLE
var _current_tiberium: Node3D = null
var _current_dock: Node3D = null
var _entity_factory: Node = null
var _scan_cooldown: float = 0.0
var _scan_interval: float = 1.0
var _seek_timeout: float = 0.0
var _seeking_dock: bool = false
var dock_client: DockClientComponent = null
var _path_cache: Dictionary = {}

const SEEK_TIMEOUT: float = 5.0

## Emitted when cargo amount or capacity changes (for UI updates).
signal cargoing_changed(cargo: int, capacity: int)
## Emitted on every state transition (for UI and debugging).
signal state_changed(new_state: int)


func _ready() -> void:
    var mc := get_parent().get_node_or_null("MovementController") as MovementController
    if mc:
        mc.arrived.connect(on_arrived)
    _entity_factory = get_node("/root/EntityFactory")
    dock_client = get_parent().get_node_or_null("DockClientComponent") as DockClientComponent
    if dock_client:
        dock_client.dock_slot_reserved.connect(_on_dock_slot_reserved)
        dock_client.dock_slot_failed.connect(_on_dock_slot_failed)
        dock_client.dock_cancelled.connect(_on_dock_cancelled)
        dock_client.dock_undocked.connect(on_dock_undocked)


func _exit_tree() -> void:
    _release_tiberium_cell()


func get_dock_id() -> String:
    if dock_client:
        return dock_client.get_dock_id()
    return ""


func get_cargo() -> int:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    return transport.get_cargo_total() if transport else 0


func set_cargo(type_id: String, value: int) -> void:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    if transport:
        transport.cargo[type_id] = maxi(0, value)
        cargoing_changed.emit(transport.get_cargo_total(), _get_storage_capacity())


func on_slot_available() -> void:
    print("[Harvest] on_slot_available (state=%d)" % _state)
    if _state != State.QUEUED:
        return
    _change_state(State.DOCKING)


func _process(delta: float) -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return

    _scan_cooldown -= delta

    match _state:
        State.IDLE:
            if get_cargo() >= _get_storage_capacity():
                _seek_dock(entity_parent)
            elif _scan_cooldown <= 0.0:
                _scan_cooldown = _scan_interval
                var resource := _find_nearest_resource(entity_parent)
                if resource:
                    _current_tiberium = resource
                    _change_state(State.SEEK_NODE)
                elif get_cargo() > 0:
                    _seek_dock(entity_parent)

        State.SEEK_NODE:
            _seek_timeout -= delta
            if _seek_timeout <= 0.0:
                _release_tiberium_cell()
                _current_tiberium = null
                _scan_cooldown = _scan_interval
                _change_state(State.IDLE)

        State.HARVESTING:
            if not is_instance_valid(_current_tiberium):
                _release_tiberium_cell()
                _current_tiberium = null
                _change_state(State.IDLE)
                return
            var tib := _current_tiberium.get_node_or_null("TiberiumComponent") as TiberiumComponent
            if not tib:
                _release_tiberium_cell()
                _current_tiberium = null
                _change_state(State.IDLE)
                return
            var rules := _get_global_rules()
            var fill_rate := rules.harvester_fill_rate if rules else 2.0
            var collected := tib.collect(ceili(fill_rate * delta * 60.0))
            if collected > 0:
                var transport := (
                    get_parent().get_node_or_null("TransportComponent") as TransportComponent
                )
                if transport:
                    transport.add_cargo(tib.resource_type_id, collected)
                    cargoing_changed.emit(transport.get_cargo_total(), _get_storage_capacity())
            if get_cargo() >= _get_storage_capacity():
                _release_tiberium_cell()
                _current_tiberium = null
                _change_state(State.FULL)
            elif tib.is_depleted():
                _release_tiberium_cell()
                _current_tiberium = null
                _change_state(State.IDLE)

        State.FULL:
            _current_tiberium = null
            if not _seeking_dock:
                _seeking_dock = true
                _seek_dock(entity_parent)

        State.UNLOADING:
            pass

        State.DOCKING:
            if not is_instance_valid(_current_dock):
                print("[Harvest] DOCKING: dock invalid, → IDLE")
                _change_state(State.IDLE)
                return
            var dock := _current_dock.get_node_or_null("DockHostComponent") as DockHostComponent
            if not dock:
                print("[Harvest] DOCKING: DockHostComponent not found, → IDLE")
                _change_state(State.IDLE)
                return
            var target_yaw := deg_to_rad(dock.dock_rotation)
            var diff := angle_difference(entity_parent.rotation.y, target_yaw)
            if abs(diff) < 0.05:
                entity_parent.rotation.y = target_yaw
                var dock_unload := (
                    _current_dock.get_node_or_null("DockUnloadComponent") as DockUnloadComponent
                )
                print("[Harvest] DOCKING: rotation done, DockUnloadComponent=%s" % dock_unload)
                if dock_unload:
                    dock_unload.begin_unload()
                _change_state(State.UNLOADING)
            else:
                var step := deg_to_rad(180.0) * delta
                entity_parent.rotation.y += sign(diff) * minf(step, abs(diff))

        State.QUEUED:
            pass


func _seek_dock(entity_parent: Node3D) -> void:
    if not dock_client:
        _change_state(State.IDLE)
        return
    dock_client.seek_dock(entity_parent)


func set_target_node(node: Node3D) -> void:
    if node and node.get_node_or_null("TiberiumComponent"):
        _current_tiberium = node
        _current_dock = null
        _change_state(State.SEEK_NODE)


func cancel_harvest() -> void:
    _release_tiberium_cell()
    _current_tiberium = null
    _current_dock = null
    _seeking_dock = false
    if dock_client:
        dock_client.release_reservation()
    _change_state(State.IDLE)


func set_target_refinery(node: Node3D) -> void:
    if node and node.get_node_or_null("DockHostComponent"):
        if dock_client:
            dock_client.seek_dock(get_parent() as Node3D)


func on_arrived(_position: Vector3) -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return

    match _state:
        State.SEEK_NODE:
            _seek_timeout = 0.0
            _change_state(State.HARVESTING)
        State.DOCKING:
            pass


## Called when the dock host releases this entity (cargo fully unloaded).
## Transitions back to IDLE so the harvester seeks new tiberium.
func on_dock_undocked(_docker: Node = null) -> void:
    print("[Harvest] on_dock_undocked (state=%d)" % _state)
    if _state == State.UNLOADING:
        _current_dock = null
        _change_state(State.IDLE)


func _on_dock_slot_reserved(host: Node3D) -> void:
    _seeking_dock = false
    print("[Harvest] dock_slot_reserved from %s (state=%d)" % [host.name, _state])
    _current_dock = host
    _change_state(State.DOCKING)


func _on_dock_slot_failed() -> void:
    _seeking_dock = false
    print("[Harvest] dock_slot_failed (state=%d)" % _state)
    _change_state(State.QUEUED)


func _on_dock_cancelled() -> void:
    _seeking_dock = false
    print("[Harvest] dock_cancelled (state=%d)" % _state)
    _current_dock = null
    _change_state(State.IDLE)


func _change_state(new_state: int) -> void:
    if _state == new_state:
        return
    if _state == State.SEEK_NODE and new_state != State.SEEK_NODE:
        _clear_path_cache()
        if new_state != State.HARVESTING:
            _release_tiberium_cell()
    _state = new_state
    state_changed.emit(_state)

    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return
    var mc := entity_parent.get_node_or_null("MovementController") as MovementController

    match _state:
        State.SEEK_NODE:
            if is_instance_valid(_current_tiberium):
                var tib_cell := Pathfinder.world_to_cell(_current_tiberium.global_position)
                var my_cell := Pathfinder.world_to_cell(entity_parent.global_position)
                if tib_cell == my_cell:
                    if SpatialHash.instance:
                        if not SpatialHash.instance.reserve_cell(tib_cell):
                            _current_tiberium = null
                            _scan_cooldown = _scan_interval
                            _change_state(State.IDLE)
                            return
                    _change_state(State.HARVESTING)
                    return
                if SpatialHash.instance:
                    if not SpatialHash.instance.reserve_cell(tib_cell):
                        _current_tiberium = null
                        _scan_cooldown = _scan_interval
                        _change_state(State.IDLE)
                        return
                _seek_timeout = SEEK_TIMEOUT
                mc.set_target_position(_current_tiberium.global_position)
        State.FULL:
            pass
        State.IDLE:
            pass


func _find_nearest_resource(parent: Node3D) -> Node3D:
    var _parent_cell := Pathfinder.world_to_cell(parent.global_position)
    var nearest: Node3D = null
    var nearest_dist := INF
    var rules := _get_global_rules()
    var _total := 0
    var _skipped := 0

    for entity in get_tree().get_nodes_in_group("tiberium"):
        _total += 1
        var tib := entity.get_node_or_null("TiberiumComponent") as TiberiumComponent
        if not tib or tib.is_depleted():
            _skipped += 1
            continue
        if rules:
            var category := rules.get_resource_category(tib.resource_type_id)
            if not harvestable_types.is_empty() and category not in harvestable_types:
                _skipped += 1
                continue
        if SpatialHash.instance:
            var ecell := Pathfinder.world_to_cell(entity.global_position)
            if SpatialHash.instance.is_cell_blocked(ecell):
                _skipped += 1
                continue
            var key: int = SpatialHash.instance._cell_key(ecell)
            if SpatialHash.instance._reserved.has(key):
                _skipped += 1
                continue
        var _entity_cell := Pathfinder.world_to_cell(entity.global_position)
        var dist := _get_path_distance(parent.global_position, entity.global_position)
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = entity

    return nearest


func _get_path_distance(from: Vector3, to: Vector3) -> float:
    var from_cell := Pathfinder.world_to_cell(from)
    var to_cell := Pathfinder.world_to_cell(to)
    if from_cell == to_cell:
        return 0.0

    var cache_key := (from_cell.x + 512) << 16 | (from_cell.y + 512) & 0xFFFF
    cache_key = cache_key << 32 | ((to_cell.x + 512) << 16 | (to_cell.y + 512) & 0xFFFF)
    if _path_cache.has(cache_key):
        return _path_cache[cache_key]

    var path := Pathfinder.find_path(from, to)
    var dist := INF
    if path.size() > 0:
        dist = 0.0
        var prev := from
        for point in path:
            dist += prev.distance_to(point)
            prev = point
    else:
        var diff := Vector2(from_cell - to_cell)
        dist = diff.length()

    _path_cache[cache_key] = dist
    return dist


func _clear_path_cache() -> void:
    _path_cache.clear()


func _get_storage_capacity() -> int:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    return transport.resource_capacity if transport else 0


func _release_tiberium_cell() -> void:
    if is_instance_valid(_current_tiberium) and SpatialHash.instance:
        var cell := Pathfinder.world_to_cell(_current_tiberium.global_position)
        SpatialHash.instance.release_cell(cell)


func _get_global_rules() -> GlobalRules:
    if _entity_factory and _entity_factory.has_method("get_global_rules"):
        return _entity_factory.get_global_rules() as GlobalRules
    return null
