class_name HarvestComponent extends Node

enum State { IDLE, SEEK_NODE, HARVESTING, FULL, SEEK_REFINERY, DOCKING, UNLOADING, QUEUED }

var _state: int = State.IDLE
var _current_tiberium: Node3D = null
var _current_dock: Node3D = null
var _dock_id: String = ""
var _search_radius_cells: int = 20
var _entity_factory: Node = null
var _scan_cooldown: float = 0.0
var _scan_interval: float = 1.0

signal cargoing_changed(cargo: int, capacity: int)
signal state_changed(new_state: int)


func _ready() -> void:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    if transport:
        _dock_id = transport.dock
    var mc := get_parent().get_node_or_null("MovementController") as MovementController
    if mc:
        mc.arrived.connect(on_arrived)
    _entity_factory = get_node("/root/EntityFactory")


func get_dock_id() -> String:
    return _dock_id


func get_cargo() -> int:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    return transport.cargo if transport else 0


func set_cargo(value: int) -> void:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    if transport:
        transport.cargo = maxi(0, value)
        cargoing_changed.emit(transport.cargo, _get_storage_capacity())


func on_slot_available() -> void:
    if _state != State.QUEUED:
        return
    var entity_parent := get_parent() as Node3D
    if entity_parent:
        _try_dock(entity_parent)


func _process(delta: float) -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return

    _scan_cooldown -= delta

    match _state:
        State.IDLE:
            if get_cargo() < _get_storage_capacity() and _scan_cooldown <= 0.0:
                _scan_cooldown = _scan_interval
                var tiberium := _find_nearest_tiberium(entity_parent)
                if tiberium:
                    _current_tiberium = tiberium
                    _change_state(State.SEEK_NODE)

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
                set_cargo(get_cargo() + collected)
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
            var dock_entity := _find_nearest_dock(entity_parent)
            if dock_entity:
                _current_dock = dock_entity
                _change_state(State.SEEK_REFINERY)

        State.UNLOADING:
            # Passive wait — DockUnloadComponent on the building handles the tick.
            # When cargo reaches 0, the building's DockComponent calls leave_dock(),
            # which emits docker_undocked. We listen for that to transition.
            pass

        State.DOCKING:
            if not is_instance_valid(_current_dock):
                _change_state(State.IDLE)
                return
            var dock := _current_dock.get_node_or_null("DockComponent") as DockComponent
            if not dock:
                _change_state(State.IDLE)
                return
            var target_yaw := deg_to_rad(dock.dock_rotation)
            var diff := angle_difference(entity_parent.rotation.y, target_yaw)
            if abs(diff) < 0.05:
                entity_parent.rotation.y = target_yaw
                var dock_unload := _current_dock.get_node_or_null(
                    "DockUnloadComponent"
                ) as DockUnloadComponent
                if dock_unload:
                    dock_unload.begin_unload()
                _change_state(State.UNLOADING)
            else:
                var step := deg_to_rad(180.0) * delta
                entity_parent.rotation.y += sign(diff) * minf(step, abs(diff))

        State.QUEUED:
            if _scan_cooldown <= 0.0:
                _scan_cooldown = _scan_interval
                entity_parent = get_parent() as Node3D
                if entity_parent:
                    _try_dock(entity_parent)


func set_target_node(node: Node3D) -> void:
    if node and node.get_node_or_null("TiberiumComponent"):
        _current_tiberium = node
        _current_dock = null
        _change_state(State.SEEK_NODE)


func cancel_harvest() -> void:
    _release_tiberium_cell()
    _current_tiberium = null
    _current_dock = null
    _change_state(State.IDLE)


func set_target_refinery(node: Node3D) -> void:
    if node and node.get_node_or_null("DockComponent"):
        _current_dock = node
        _change_state(State.SEEK_REFINERY)


func on_arrived(_position: Vector3) -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return

    match _state:
        State.SEEK_NODE:
            if is_instance_valid(_current_tiberium) and SpatialHash.instance:
                var cell := Pathfinder.world_to_cell(
                    _current_tiberium.global_position
                )
                SpatialHash.instance.reserve_cell(cell)
            _change_state(State.HARVESTING)
        State.DOCKING:
            pass  # handled in _process: rotate then UNLOADING
        State.SEEK_REFINERY:
            _try_dock(entity_parent)


func on_dock_undocked(_docker: Node) -> void:
    if _state == State.UNLOADING or _state == State.DOCKING:
        _current_dock = null
        _change_state(State.IDLE)


func _try_dock(entity_parent: Node3D) -> void:
    var dock_entity := _find_nearest_dock(entity_parent)
    if dock_entity:
        _current_dock = dock_entity
    elif not is_instance_valid(_current_dock):
        _change_state(State.IDLE)
        return

    var dock := _current_dock.get_node_or_null("DockComponent") as DockComponent
    if not dock:
        _change_state(State.FULL)
        return

    if dock.request_dock(self):
        if not dock.docker_undocked.is_connected(on_dock_undocked):
            dock.docker_undocked.connect(on_dock_undocked, CONNECT_ONE_SHOT)
        _change_state(State.DOCKING)
        _orient_to_dock(dock)
    else:
        var next_entity := _find_nearest_dock(entity_parent, _current_dock)
        if next_entity:
            var parent_cell := Pathfinder.world_to_cell(entity_parent.global_position)
            var next_dock := next_entity.get_node_or_null("DockComponent") as DockComponent
            if next_dock:
                var next_cell := Pathfinder.world_to_cell(
                    Pathfinder.cell_to_world(next_dock._dock_cell)
                )
                var dist := Vector2(parent_cell - next_cell).length_squared()
                if dist <= float(_search_radius_cells * _search_radius_cells):
                    _current_dock = next_entity
                    _try_dock(entity_parent)
                    return
        _change_state(State.QUEUED)


func _orient_to_dock(dock: DockComponent) -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return
    var target_pos := _get_dock_target_pos(dock)
    if entity_parent.global_position.distance_to(target_pos) < 0.5:
        _change_state(State.DOCKING)
        return
    var mc := entity_parent.get_node_or_null("MovementController") as MovementController
    if mc:
        mc.set_target_position(target_pos)


func _get_dock_target_pos(dock: DockComponent) -> Vector3:
    var cs := Pathfinder.CELL_SIZE
    var origin_cell := Vector2i(
        floori((_current_dock.global_position.x - dock.foundation.x * 0.5 * cs) / cs),
        floori((_current_dock.global_position.z - dock.foundation.y * 0.5 * cs) / cs)
    )
    var top_left_world := Pathfinder.cell_to_world(origin_cell)
    return top_left_world + _current_dock.global_transform.basis * dock.dock_position


func _change_state(new_state: int) -> void:
    if _state == new_state:
        return
    _state = new_state
    state_changed.emit(_state)

    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return
    var mc := entity_parent.get_node_or_null("MovementController") as MovementController

    match _state:
        State.SEEK_NODE:
            if is_instance_valid(_current_tiberium):
                var tib_cell := Pathfinder.world_to_cell(
                    _current_tiberium.global_position
                )
                var my_cell := Pathfinder.world_to_cell(entity_parent.global_position)
                if tib_cell == my_cell:
                    if SpatialHash.instance:
                        SpatialHash.instance.reserve_cell(tib_cell)
                    _change_state(State.HARVESTING)
                    return
                mc.set_target_position(_current_tiberium.global_position)
        State.FULL:
            pass  # handled in _process: find dock and transition
        State.SEEK_REFINERY:
            if is_instance_valid(_current_dock):
                var dock := _current_dock.get_node_or_null("DockComponent") as DockComponent
                if dock:
                    mc.set_target_position(_get_dock_target_pos(dock))
        State.IDLE:
            set_cargo(maxi(0, get_cargo()))


func _find_nearest_tiberium(parent: Node3D) -> Node3D:
    var parent_cell := Pathfinder.world_to_cell(parent.global_position)
    var nearest: Node3D = null
    var nearest_dist := float(_search_radius_cells * _search_radius_cells)

    for entity in get_tree().get_nodes_in_group("tiberium"):
        var tib := entity.get_node_or_null("TiberiumComponent") as TiberiumComponent
        if not tib or tib.is_depleted():
            continue
        if SpatialHash.instance:
            var ecell := Pathfinder.world_to_cell(entity.global_position)
            var key: int = SpatialHash.instance._cell_key(ecell)
            if SpatialHash.instance._reserved.has(key):
                continue
        var entity_cell := Pathfinder.world_to_cell(entity.global_position)
        var dist := Vector2(parent_cell - entity_cell).length_squared()
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = entity

    return nearest


func _find_nearest_dock(parent: Node3D, exclude: Node3D = null) -> Node3D:
    var parent_cell := Pathfinder.world_to_cell(parent.global_position)
    var nearest: Node3D = null
    var nearest_dist := float(_search_radius_cells * _search_radius_cells)
    var buildings_parent := get_tree().current_scene.get_node_or_null("Buildings")
    if not buildings_parent:
        return null

    for child in buildings_parent.get_children():
        if child == exclude:
            continue
        var dock := child.get_node_or_null("DockComponent") as DockComponent
        if not dock:
            continue
        if not dock.can_dock(_dock_id):
            continue
        var dock_cell := Pathfinder.world_to_cell(
            Pathfinder.cell_to_world(dock._dock_cell)
        )
        var dist := Vector2(parent_cell - dock_cell).length_squared()
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = child

    return nearest


func _get_storage_capacity() -> int:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    return transport.storage if transport else 0


func _release_tiberium_cell() -> void:
    if is_instance_valid(_current_tiberium) and SpatialHash.instance:
        var cell := Pathfinder.world_to_cell(_current_tiberium.global_position)
        SpatialHash.instance.release_cell(cell)


func _get_global_rules() -> GlobalRules:
    if _entity_factory and _entity_factory.has_method("get_global_rules"):
        return _entity_factory.get_global_rules() as GlobalRules
    return null
