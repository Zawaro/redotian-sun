class_name HarvestComponent extends Node

enum State { IDLE, SEEK_NODE, HARVESTING, FULL, SEEK_REFINERY, DOCKING, UNLOADING, QUEUED }

var _state: int = State.IDLE
var _current_crystal: Node3D = null
var _current_dock: Node3D = null
var _cargo: int = 0
var _dock_id: String = ""
var _search_radius_cells: int = 20
var _entity_factory: Node = null
var _economy_manager: Node = null
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
    _economy_manager = get_node("/root/EconomyManager")


func get_dock_id() -> String:
    return _dock_id


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
            if _cargo <= 0 and _scan_cooldown <= 0.0:
                _scan_cooldown = _scan_interval
                var crystal := _find_nearest_crystal(entity_parent)
                if crystal:
                    _current_crystal = crystal
                    _change_state(State.SEEK_NODE)

        State.HARVESTING:
            if not is_instance_valid(_current_crystal):
                _change_state(State.IDLE)
                return
            var tib := _current_crystal.get_node_or_null("TiberiumComponent") as TiberiumComponent
            if not tib:
                _change_state(State.IDLE)
                return
            var rules := _get_global_rules()
            var fill_rate := rules.harvester_fill_rate if rules else 2.0
            var collected := tib.collect(ceili(fill_rate * delta * 60.0))
            _cargo += collected
            cargoing_changed.emit(_cargo, _get_storage_capacity())
            if tib.is_depleted() or _cargo >= _get_storage_capacity():
                _current_crystal = null
                _change_state(State.FULL)

        State.UNLOADING:
            if not is_instance_valid(_current_dock):
                _change_state(State.FULL)
                return
            var dock := _current_dock.get_node_or_null("DockComponent") as DockComponent
            if not dock:
                _change_state(State.FULL)
                return
            var unload_amount := ceili(dock.unload_rate * delta * 60.0)
            var actual := mini(unload_amount, _cargo)
            if actual > 0:
                var rules := _get_global_rules()
                var value := rules.tiberium_value if rules else 1.0
                var credits := ceili(float(actual) * value)
                if _economy_manager:
                    _economy_manager.add(0, credits, "harvest")
                _cargo -= actual
                cargoing_changed.emit(_cargo, _get_storage_capacity())
            if _cargo <= 0:
                dock.leave_dock(self)
                _current_dock = null
                _change_state(State.IDLE)

        State.QUEUED:
            if _scan_cooldown <= 0.0:
                _scan_cooldown = _scan_interval
                entity_parent = get_parent() as Node3D
                if entity_parent:
                    _try_dock(entity_parent)


func set_target_node(node: Node3D) -> void:
    if node and node.get_node_or_null("TiberiumComponent"):
        _current_crystal = node
        _current_dock = null
        _change_state(State.SEEK_NODE)


func set_target_refinery(node: Node3D) -> void:
    if node and node.get_node_or_null("DockComponent"):
        _current_dock = node
        _change_state(State.SEEK_REFINERY)


func on_arrived() -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return

    match _state:
        State.SEEK_NODE:
            _change_state(State.HARVESTING)
        State.DOCKING:
            _change_state(State.UNLOADING)
        State.FULL:
            _change_state(State.SEEK_REFINERY)
        State.SEEK_REFINERY:
            _try_dock(entity_parent)


func _try_dock(entity_parent: Node3D) -> void:
    if not is_instance_valid(_current_dock):
        var dock_entity := _find_nearest_dock(entity_parent)
        if dock_entity:
            _current_dock = dock_entity
        else:
            _change_state(State.IDLE)
            return

    var dock := _current_dock.get_node_or_null("DockComponent") as DockComponent
    if not dock:
        _change_state(State.FULL)
        return

    if dock.request_dock(self):
        _change_state(State.DOCKING)
        _orient_to_dock(dock)
    else:
        _change_state(State.QUEUED)


func _orient_to_dock(dock: DockComponent) -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return
    var offset := entity_parent.global_transform.basis * dock.dock_position
    var target_pos := _current_dock.global_position + offset
    var mc := entity_parent.get_node_or_null("MovementController") as MovementController
    if mc:
        mc.set_target_position(target_pos)


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
            if is_instance_valid(_current_crystal):
                mc.set_target_position(_current_crystal.global_position)
        State.FULL:
            mc.set_target_position(entity_parent.global_position)
        State.SEEK_REFINERY:
            if is_instance_valid(_current_dock):
                mc.set_target_position(_current_dock.global_position)
        State.IDLE:
            _cargo = maxi(0, _cargo)


func _find_nearest_crystal(parent: Node3D) -> Node3D:
    var parent_cell := Pathfinder.world_to_cell(parent.global_position)
    var nearest: Node3D = null
    var nearest_dist := float(_search_radius_cells * _search_radius_cells)
    var sh := SpatialHash.instance
    if not sh:
        return null

    for dx in range(-_search_radius_cells, _search_radius_cells + 1):
        for dz in range(-_search_radius_cells, _search_radius_cells + 1):
            var cell := parent_cell + Vector2i(dx, dz)
            var entries := sh.get_entries(cell)
            for entry in entries:
                var entity := entry.get("node") as Node3D
                if not entity:
                    continue
                var tib := entity.get_node_or_null("TiberiumComponent") as TiberiumComponent
                if not tib or tib.is_depleted():
                    continue
                var dist := dx * dx + dz * dz
                if dist < nearest_dist:
                    nearest_dist = dist
                    nearest = entity

    return nearest


func _find_nearest_dock(parent: Node3D) -> Node3D:
    var parent_cell := Pathfinder.world_to_cell(parent.global_position)
    var nearest: Node3D = null
    var nearest_dist := float(_search_radius_cells * _search_radius_cells)
    var buildings_parent := get_tree().current_scene.get_node_or_null("Buildings")
    if not buildings_parent:
        return null

    for child in buildings_parent.get_children():
        var dock := child.get_node_or_null("DockComponent") as DockComponent
        if not dock:
            continue
        if not dock.can_dock(_dock_id):
            continue
        var child_cell := Pathfinder.world_to_cell(child.global_position)
        var dist := Vector2(parent_cell - child_cell).length_squared()
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = child

    return nearest


func _get_storage_capacity() -> int:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    return transport.storage if transport else 0


func _get_global_rules() -> GlobalRules:
    if _entity_factory and _entity_factory.has_method("get_global_rules"):
        return _entity_factory.get_global_rules() as GlobalRules
    return null
