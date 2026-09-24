## Kill attribution for veterancy.
##
## Watches every HealthComponent in the scene tree via tree add/remove signals,
## so deaths reach the system through every spawn path (placement, map load, MCV
## deploy, projectiles). When one dies, it credits the killer's StatsComponent
## with the victim's cost, subject to the Trainable and allied gates.
##
## No class_name — the autoload singleton name `VeterancySystem` is the global.
extends Node

## HealthComponent -> the Callable connected to its `killed` signal.
var _registry: Dictionary = {}


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)


func _on_node_added(node: Node) -> void:
    if node is HealthComponent and not _in_map_editor(node):
        _register(node as HealthComponent)


func _on_node_removed(node: Node) -> void:
    if node is HealthComponent:
        _unregister(node as HealthComponent)


func _register(health: HealthComponent) -> void:
    if _registry.has(health):
        return
    var callback := _on_killed.bind(health)
    _registry[health] = callback
    health.killed.connect(callback)


func _unregister(health: HealthComponent) -> void:
    if not _registry.has(health):
        return
    var callback: Callable = _registry[health]
    _registry.erase(health)
    if health.killed.is_connected(callback):
        health.killed.disconnect(callback)


## Credits the killer with the victim's cost. No-ops on any failed gate:
## freed killer, untrainable killer, missing victim cost, or an allied kill.
func _on_killed(killer: Node3D, health: HealthComponent) -> void:
    if not is_instance_valid(killer):
        return
    var killer_stats := killer.get_node_or_null("StatsComponent") as StatsComponent
    if killer_stats == null or not killer_stats.trainable:
        return
    var victim := health.get_parent() as Node3D
    var victim_stats: StatsComponent = null
    if victim:
        victim_stats = victim.get_node_or_null("StatsComponent") as StatsComponent
    var victim_cost: int = victim_stats.cost if victim_stats else 0
    if victim_cost <= 0:
        return
    if _is_allied_kill(victim_stats, killer_stats):
        return
    killer_stats.add_kill_experience(victim_cost)


func _is_allied_kill(victim_stats: StatsComponent, killer_stats: StatsComponent) -> bool:
    var victim_pid: int = victim_stats.player_id if victim_stats else -1
    var killer_pid: int = killer_stats.player_id
    if victim_pid < 0 or killer_pid < 0:
        return false
    return not PlayerManager.is_enemy(victim_pid, killer_pid)


func _in_map_editor(node: Node) -> bool:
    var scene := get_tree().current_scene
    if scene != null and scene.has_meta("is_map_editor"):
        return true
    var ancestor := node.get_parent()
    while ancestor != null:
        if ancestor.has_meta("is_map_editor"):
            return true
        ancestor = ancestor.get_parent()
    return false
