class_name DockUnloadComponent extends Node

@export var unload_rate: float = 0.5
## Resource categories this dock accepts (e.g. ["tiberium"]). Empty = accepts all.
@export var accepted_resource_categories: PackedStringArray = []

var _economy_manager: Node = null
var _credit_accumulator: float = 0.0
var _global_rules: GlobalRules = null


func _ready() -> void:
    _economy_manager = get_node_or_null("/root/EconomyManager")
    var ef := get_node_or_null("/root/EntityFactory")
    if ef and ef.has_method("get_global_rules"):
        _global_rules = ef.get_global_rules() as GlobalRules
    var dock := get_parent().get_node_or_null("DockHostComponent") as DockHostComponent
    if dock:
        dock.docker_undocked.connect(_on_docker_undocked)
    set_process(false)


func configure(data: EntityData) -> void:
    accepted_resource_categories = data.accepted_resource_categories


func begin_unload() -> void:
    set_process(true)
    # Reset stale timer so the full unload duration is covered.
    var dock := get_parent().get_node_or_null("DockHostComponent") as DockHostComponent
    if dock:
        dock.reset_stale_timer()


func _on_docker_undocked(_docker: Node) -> void:
    set_process(false)


func _process(delta: float) -> void:
    var dock := get_parent().get_node_or_null("DockHostComponent") as DockHostComponent
    if not dock or not dock.current_docker:
        set_process(false)
        return

    var docker_node := dock.current_docker as Node
    if not is_instance_valid(docker_node):
        dock.leave_dock(docker_node)
        set_process(false)
        return

    # current_docker is the DockClientComponent; cargo lives on its parent entity.
    var entity := docker_node.get_parent() as Node3D
    var transport: TransportComponent = null
    if entity:
        transport = entity.get_node_or_null("TransportComponent") as TransportComponent
    if not transport or transport.get_cargo_total() <= 0.0:
        dock.leave_dock(docker_node)
        return

    # Validate cargo categories — reject if any cargo type is not accepted.
    if not _validate_cargo(transport):
        dock.leave_dock(docker_node)
        return

    var bales_to_unload := unload_rate * delta

    for type_id in transport.cargo.keys():
        var available: float = transport.cargo[type_id]
        var to_remove := minf(bales_to_unload, available)
        if to_remove > 0.0:
            var rt: ResourceType = null
            if _global_rules:
                rt = _global_rules.get_resource_type(type_id)
            var value := rt.value if rt else 1.0
            _credit_accumulator += to_remove * value
            transport.remove_cargo(type_id, to_remove)
            bales_to_unload -= to_remove
            if bales_to_unload <= 0.0:
                break

    var credits_to_add := int(_credit_accumulator)
    _credit_accumulator -= float(credits_to_add)
    if credits_to_add > 0 and _economy_manager:
        _economy_manager.add(0, credits_to_add, "harvest")

    if transport.get_cargo_total() <= 0.0:
        dock.leave_dock(docker_node)


func _validate_cargo(transport: TransportComponent) -> bool:
    if accepted_resource_categories.is_empty():
        return true
    for type_id in transport.cargo.keys():
        if transport.cargo[type_id] <= 0.0:
            continue
        var category := ""
        if _global_rules:
            category = _global_rules.get_resource_category(type_id)
        if category.is_empty():
            category = type_id
        if category not in accepted_resource_categories:
            return false
    return true
