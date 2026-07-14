class_name HarvestComponent extends Node

enum State { IDLE, SEEK_NODE, HARVESTING, DELIVERING }

## Resource categories this harvester collects (e.g. ["tiberium"] for all tiberium types).
@export var harvestable_types: PackedStringArray = ["tiberium"]
## Search radius in cells when looking for the nearest harvestable resource.
@export var search_radius_cells: int = 20

var _state: int = State.IDLE
var _current_resource: Node3D = null
var _entity_factory: Node = null
var _seek_timeout: float = 0.0
var dock_client: DockClientComponent = null

var _harvest_accumulator: float = 0.0
var _last_dock_position: Vector3 = Vector3.ZERO

const SEEK_TIMEOUT: float = 5.0

## Emitted when cargo amount or capacity changes (for UI updates).
signal cargoing_changed(cargo: float, capacity: int)
## Emitted on every state transition (for UI and debugging).
signal state_changed(new_state: int)


func _ready() -> void:
    var mc := get_parent().get_node_or_null("MovementController") as MovementController
    if mc:
        mc.arrived.connect(on_arrived)
    _entity_factory = get_node("/root/EntityFactory")
    dock_client = get_parent().get_node_or_null("DockClientComponent") as DockClientComponent
    if dock_client:
        dock_client.dock_slot_failed.connect(_on_dock_slot_failed)
        dock_client.dock_cancelled.connect(_on_dock_cancelled)
        dock_client.dock_undocked.connect(on_dock_undocked)


func _exit_tree() -> void:
    _release_resource_cell()


func get_dock_id() -> String:
    if dock_client:
        return dock_client.get_dock_id()
    return ""


func get_cargo() -> float:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    return transport.get_cargo_total() if transport else 0.0


func set_cargo(type_id: String, bales: float) -> void:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    if transport:
        transport.cargo[type_id] = maxf(0.0, bales)
        cargoing_changed.emit(transport.get_cargo_total(), _get_storage_capacity())


func _process(delta: float) -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return

    match _state:
        State.IDLE:
            pass

        State.SEEK_NODE:
            _seek_timeout -= delta
            if _seek_timeout <= 0.0:
                _release_resource_cell()
                _current_resource = null
                _assess_next_action()

        State.HARVESTING:
            if not is_instance_valid(_current_resource):
                _release_resource_cell()
                _current_resource = null
                _assess_next_action()
                return
            var tib := _current_resource.get_node_or_null("ResourceComponent") as ResourceComponent
            if not tib:
                _release_resource_cell()
                _current_resource = null
                _assess_next_action()
                return
            var rules := _get_global_rules()
            var fill_rate := rules.harvester_fill_rate if rules else 1.0
            _harvest_accumulator += fill_rate * delta
            if _harvest_accumulator > 0.001:
                var bales_to_collect := _harvest_accumulator
                _harvest_accumulator = 0.0
                var collected := tib.collect(bales_to_collect)
                if collected > 0.0:
                    var transport := (
                        get_parent().get_node_or_null("TransportComponent") as TransportComponent
                    )
                    if transport:
                        transport.add_cargo(tib.resource_type_id, collected)
                        cargoing_changed.emit(transport.get_cargo_total(), _get_storage_capacity())
            if get_cargo() >= float(_get_storage_capacity()):
                _release_resource_cell()
                _current_resource = null
                _deliver_cargo(entity_parent)
            elif tib.is_depleted():
                _release_resource_cell()
                _current_resource = null
                _assess_next_action()

        State.DELIVERING:
            pass


func _deliver_cargo(entity_parent: Node3D) -> void:
    _change_state(State.DELIVERING)
    if dock_client:
        dock_client.seek_dock(entity_parent)


func set_target_node(node: Node3D) -> void:
    if node and node.get_node_or_null("ResourceComponent"):
        _current_resource = node
        _change_state(State.SEEK_NODE)


func cancel_harvest(_player_commanded: bool = false) -> void:
    _release_resource_cell()
    _current_resource = null
    if dock_client:
        dock_client.release_reservation()
    _change_state(State.IDLE)


func set_target_refinery(node: Node3D) -> void:
    if node and node.get_node_or_null("DockHostComponent"):
        if dock_client:
            dock_client.seek_dock(get_parent() as Node3D, node)


func on_arrived(_position: Vector3) -> void:
    if _state == State.SEEK_NODE:
        _seek_timeout = 0.0
        _change_state(State.HARVESTING)


## Called when the dock host releases this entity (cargo fully unloaded).
func on_dock_undocked(_docker: Node = null) -> void:
    if _state == State.DELIVERING:
        _assess_next_action()


func _on_dock_slot_failed() -> void:
    if _state == State.DELIVERING:
        _assess_next_action()


func _on_dock_cancelled() -> void:
    if _state == State.DELIVERING:
        _assess_next_action()


## Immediately scan for resources or go idle. Skips IDLE entirely.
func _assess_next_action() -> void:
    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        _change_state(State.IDLE)
        return
    if get_cargo() >= float(_get_storage_capacity()):
        _deliver_cargo(entity_parent)
        return
    var resource := _find_nearest_resource(entity_parent.global_position)
    if not resource and _last_dock_position != Vector3.ZERO:
        resource = _find_nearest_resource(_last_dock_position)
    if resource:
        _current_resource = resource
        _change_state(State.SEEK_NODE)
    elif get_cargo() > 0.0:
        _deliver_cargo(entity_parent)
    else:
        _change_state(State.IDLE)


func _change_state(new_state: int) -> void:
    if _state == new_state:
        return
    if _state == State.SEEK_NODE and new_state != State.SEEK_NODE:
        if new_state != State.HARVESTING:
            _release_resource_cell()
    if _state == State.HARVESTING and new_state != State.HARVESTING:
        _harvest_accumulator = 0.0
    _state = new_state
    state_changed.emit(_state)

    var entity_parent := get_parent() as Node3D
    if not entity_parent:
        return
    var mc := entity_parent.get_node_or_null("MovementController") as MovementController

    match _state:
        State.SEEK_NODE:
            if is_instance_valid(_current_resource):
                var tib_cell := Pathfinder.world_to_cell(_current_resource.global_position)
                var my_cell := Pathfinder.world_to_cell(entity_parent.global_position)
                if tib_cell == my_cell:
                    if SpatialHash.instance:
                        if not SpatialHash.instance.reserve_cell(tib_cell):
                            _current_resource = null
                            call_deferred("_assess_next_action")
                            return
                    _change_state(State.HARVESTING)
                    return
                if SpatialHash.instance:
                    if not SpatialHash.instance.reserve_cell(tib_cell):
                        _current_resource = null
                        call_deferred("_assess_next_action")
                        return
                _seek_timeout = SEEK_TIMEOUT
                mc.set_target_position(_current_resource.global_position)
        State.DELIVERING:
            _last_dock_position = entity_parent.global_position


func _find_nearest_resource(search_from: Vector3) -> Node3D:
    var nearest: Node3D = null
    var nearest_dist := INF
    var rules := _get_global_rules()

    for entity in get_tree().get_nodes_in_group("resources"):
        var tib := entity.get_node_or_null("ResourceComponent") as ResourceComponent
        if not tib or tib.is_depleted():
            continue
        if rules:
            var category := rules.get_resource_category(tib.resource_type_id)
            if not harvestable_types.is_empty() and category not in harvestable_types:
                continue
        if SpatialHash.instance:
            var ecell := Pathfinder.world_to_cell(entity.global_position)
            if SpatialHash.instance.is_cell_blocked(ecell):
                continue
            var key: int = SpatialHash.instance._cell_key(ecell)
            if SpatialHash.instance._reserved.has(key):
                continue
        var dist := search_from.distance_squared_to(entity.global_position)
        if dist < nearest_dist:
            nearest_dist = dist
            nearest = entity

    return nearest


func _get_storage_capacity() -> int:
    var transport := get_parent().get_node_or_null("TransportComponent") as TransportComponent
    return transport.storage if transport else 0


func _release_resource_cell() -> void:
    if is_instance_valid(_current_resource) and SpatialHash.instance:
        var cell := Pathfinder.world_to_cell(_current_resource.global_position)
        SpatialHash.instance.release_cell(cell)


func _get_global_rules() -> GlobalRules:
    if _entity_factory and _entity_factory.has_method("get_global_rules"):
        return _entity_factory.get_global_rules() as GlobalRules
    return null
