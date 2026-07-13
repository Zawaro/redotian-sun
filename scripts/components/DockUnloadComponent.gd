class_name DockUnloadComponent extends Node

@export var unload_rate: float = 2.33
@export var refinery_storage: int = 0

var _economy_manager: Node = null


func _ready() -> void:
    _economy_manager = get_node_or_null("/root/EconomyManager")
    var dock := get_parent().get_node_or_null("DockHostComponent") as DockHostComponent
    if dock:
        dock.docker_undocked.connect(_on_docker_undocked)
    set_process(false)


func begin_unload() -> void:
    print("[DockUnload] begin_unload called")
    set_process(true)


func _on_docker_undocked(_docker: Node) -> void:
    set_process(false)


func _process(delta: float) -> void:
    var dock := get_parent().get_node_or_null("DockHostComponent") as DockHostComponent
    if not dock or not dock.current_docker:
        print("[DockUnload] no dock or no docker, stopping")
        set_process(false)
        return

    var docker_node := dock.current_docker as Node
    if not is_instance_valid(docker_node):
        print("[DockUnload] docker invalid, leaving dock")
        dock.leave_dock(docker_node)
        set_process(false)
        return

    var transport := docker_node.get_node_or_null("TransportComponent") as TransportComponent
    if not transport:
        var entity := docker_node.get_parent() as Node3D
        if entity:
            transport = entity.get_node_or_null("TransportComponent") as TransportComponent
    if not transport or transport.get_cargo_total() <= 0:
        print("[DockUnload] no transport or empty cargo, leaving dock")
        dock.leave_dock(docker_node)
        return

    var rules := _get_global_rules()
    var amount := ceili(unload_rate * delta * 60.0)
    var total_credits := 0

    for type_id in transport.cargo.keys():
        var available: int = transport.cargo[type_id]
        var to_remove := mini(amount, available)
        if to_remove > 0:
            var rt: ResourceType = rules.get_resource_type(type_id) if rules else null
            var value := rt.value_per_unit if rt else 1.0
            total_credits += ceili(float(to_remove) * value)
            transport.remove_cargo(type_id, to_remove)
            amount -= to_remove
            if amount <= 0:
                break

    if total_credits > 0 and _economy_manager:
        _economy_manager.add(0, total_credits, "harvest")

    if transport.get_cargo_total() <= 0:
        print("[DockUnload] cargo empty, leaving dock")
        dock.leave_dock(docker_node)


func _get_global_rules() -> GlobalRules:
    var ef := get_node_or_null("/root/EntityFactory")
    if ef and ef.has_method("get_global_rules"):
        return ef.get_global_rules() as GlobalRules
    return null
