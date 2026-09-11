## Per-player radar availability aggregation.
##
## Registers every RadarComponent in the scene tree via tree add/remove signals
## — catching every spawn path (BuildingManager placement, MapLoader starting
## bases, MCV deploy) — and tracks, per player, how many registered radar
## components currently report `has_radar()`. Power-driven flips arrive through
## `RadarComponent.radar_state_changed`, so nothing polls.
##
## No class_name — the autoload singleton name `RadarSystem` is the global.
extends Node

## Emitted when a player's radar availability flips (including via the debug
## override).
signal radar_availability_changed(player_id: int)

## Debug override: while true, every player reads as radar-available.
var force_online: bool:
    get:
        return _force_online
    set(value):
        if _force_online == value:
            return
        _force_online = value
        _refresh_all()

## player_id -> count of registered components currently available.
var _online_counts: Dictionary = {}
## player_id -> last emitted availability, for edge-triggered emission.
var _available: Dictionary = {}
## RadarComponent -> {"pid": int, "active": bool, "callback": Callable}.
var _registry: Dictionary = {}
var _force_online: bool = false


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)


func _on_node_added(node: Node) -> void:
    if node is RadarComponent and not _in_map_editor(node):
        _register(node as RadarComponent)


func _on_node_removed(node: Node) -> void:
    if node is RadarComponent:
        _unregister(node as RadarComponent)


func _register(rc: RadarComponent) -> void:
    if _registry.has(rc):
        return
    var pid := _owner_id(rc)
    var active := rc.has_radar()
    var callback := _on_component_changed.bind(rc)
    _registry[rc] = {"pid": pid, "active": active, "callback": callback}
    rc.radar_state_changed.connect(callback)
    if pid >= 0 and active:
        _bump(pid, 1)
    _refresh(pid)


func _unregister(rc: RadarComponent) -> void:
    if not _registry.has(rc):
        return
    var entry: Dictionary = _registry[rc]
    _registry.erase(rc)
    var callback: Callable = entry["callback"]
    if rc.radar_state_changed.is_connected(callback):
        rc.radar_state_changed.disconnect(callback)
    var pid := int(entry["pid"])
    if pid >= 0 and bool(entry["active"]):
        _bump(pid, -1)
    _refresh(pid)


func _on_component_changed(is_active: bool, rc: RadarComponent) -> void:
    if not _registry.has(rc):
        return
    var entry: Dictionary = _registry[rc]
    if bool(entry["active"]) == is_active:
        return
    entry["active"] = is_active
    var pid := int(entry["pid"])
    if pid >= 0:
        _bump(pid, 1 if is_active else -1)
    _refresh(pid)


## True when the player owns at least one available radar, or the debug
## override is on.
func player_has_radar(player_id: int) -> bool:
    if _force_online:
        return true
    return _online_count(player_id) > 0


## Current count of available radar components for a player (tests + diagnostics).
func get_online_count(player_id: int) -> int:
    return _online_count(player_id)


func _online_count(player_id: int) -> int:
    return int(_online_counts.get(player_id, 0))


func _bump(player_id: int, delta: int) -> void:
    _online_counts[player_id] = maxi(_online_count(player_id) + delta, 0)


func _refresh(player_id: int) -> void:
    if player_id < 0:
        return
    var available := player_has_radar(player_id)
    if bool(_available.get(player_id, false)) == available:
        return
    _available[player_id] = available
    radar_availability_changed.emit(player_id)


## Re-evaluates availability for every player the system has seen (plus the
## local player). Used when the debug override flips so consumers get the edge.
func _refresh_all() -> void:
    var ids := {}
    for pid in _available:
        ids[pid] = true
    for pid in _online_counts:
        ids[pid] = true
    ids[PlayerManager.get_local_player_id()] = true
    for pid in ids:
        _refresh(int(pid))


func _owner_id(rc: RadarComponent) -> int:
    var parent := rc.get_parent()
    if parent == null:
        return -1
    var stats := parent.get_node_or_null("StatsComponent") as StatsComponent
    if stats == null:
        return -1
    return stats.player_id


## Whole-scene case (PowerGrid/FogRenderer precedent) plus ancestor walk for
## entities parented under an editor-flagged container.
func _in_map_editor(rc: RadarComponent) -> bool:
    var scene := get_tree().current_scene
    if scene != null and scene.has_meta("is_map_editor"):
        return true
    var ancestor := rc.get_parent()
    while ancestor != null:
        if ancestor.has_meta("is_map_editor"):
            return true
        ancestor = ancestor.get_parent()
    return false
