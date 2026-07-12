class_name DockUnloadComponent extends Node

@export var unload_rate: float = 2.33
@export var refinery_storage: int = 0

var _economy_manager: Node = null


func _ready() -> void:
    _economy_manager = get_node_or_null("/root/EconomyManager")
    var dock := get_parent().get_node_or_null("DockComponent") as DockComponent
    if dock:
        dock.docker_undocked.connect(_on_docker_undocked)
    set_process(false)


func begin_unload() -> void:
    set_process(true)


func _on_docker_undocked(_docker: Node) -> void:
    set_process(false)


func _process(delta: float) -> void:
    var dock := get_parent().get_node_or_null("DockComponent") as DockComponent
    if not dock or not dock.current_docker:
        set_process(false)
        return

    var docker_node := dock.current_docker as Node
    if not is_instance_valid(docker_node):
        dock.leave_dock(docker_node)
        set_process(false)
        return

    var transport := docker_node.get_node_or_null("TransportComponent") as TransportComponent
    if not transport:
        var entity := docker_node.get_parent() as Node3D
        if entity:
            transport = entity.get_node_or_null("TransportComponent") as TransportComponent
    if not transport or transport.cargo <= 0:
        dock.leave_dock(docker_node)
        return

    var amount := ceili(unload_rate * delta * 60.0)
    var actual := mini(amount, transport.cargo)
    if actual > 0:
        var rules := _get_global_rules()
        var value := rules.tiberium_value if rules else 1.0
        var credits := ceili(float(actual) * value)
        if _economy_manager:
            _economy_manager.add(0, credits, "harvest")
        transport.cargo -= actual

    if transport.cargo <= 0:
        dock.leave_dock(docker_node)


func _get_global_rules() -> GlobalRules:
    var ef := get_node_or_null("/root/EntityFactory")
    if ef and ef.has_method("get_global_rules"):
        return ef.get_global_rules() as GlobalRules
    return null
