## Per-player power aggregation and low-power fan-out.
##
## Registers every PowerComponent in the scene tree via tree add/remove
## signals — catches every spawn path (BuildingManager placement, MapLoader
## starting bases, MCV deploy — all set StatsComponent.player_id before
## add_child). Purely event-driven: buildings never move, so there is no
## polling or reconcile pass. A recompute diffs the computed per-player state
## (low power, build rate) and only signals/fans out on an actual change.
## ponytail: sums are recomputed from the registry scan on each change — O(n)
## with n = registered buildings, trivially cheap at RTS scale; swap to
## incremental running sums if profiling ever disagrees. One frame of stale
## sums after queue_free is accepted (invisible in play).
##
## No class_name — the autoload singleton name `PowerGrid` is the global.
extends Node

## Emitted when a player's computed grid state changes — boundary crossing
## (healthy <-> low power) or build-rate drift within low power.
signal grid_state_changed(player_id: int)

## PowerComponent -> {"pid": int, "power": int}. Power is cached at
## registration so unregistration never reads a mid-free node.
var _registry: Dictionary = {}
## player_id -> {"output": int, "drain": int}
var _sums: Dictionary = {}
## player_id -> {"low_power": bool, "rate": float} — last diffed state.
var _state: Dictionary = {}


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)


func _on_node_added(node: Node) -> void:
    if node is PowerComponent and not _in_map_editor(node):
        _register(node as PowerComponent)


func _on_node_removed(node: Node) -> void:
    if node is PowerComponent:
        _unregister(node as PowerComponent)


func _register(pc: PowerComponent) -> void:
    var pid := _owner_id(pc)
    _registry[pc] = {"pid": pid, "power": pc.power}
    _touch_player(pid)
    # Landing into an existing deficit: the boundary fan-out only fires on a
    # state change, so a newly registered powered structure would otherwise
    # keep its default online state while the rest of the base is dark.
    if pid >= 0 and pc.powered and is_low_power(pid):
        pc.set_online(false)


func _unregister(pc: PowerComponent) -> void:
    if not _registry.has(pc):
        return
    var entry: Dictionary = _registry[pc]
    _registry.erase(pc)
    _touch_player(int(entry["pid"]))


func _touch_player(pid: int) -> void:
    if pid < 0:
        return
    _recompute_sums(pid)
    _recompute_and_diff(pid)


func _recompute_sums(pid: int) -> void:
    var output := 0
    var drain := 0
    for pc: PowerComponent in _registry:
        var entry: Dictionary = _registry[pc]
        if int(entry["pid"]) != pid:
            continue
        var power := int(entry["power"])
        if power >= 0:
            output += power
        else:
            drain -= power
    _sums[pid] = {"output": output, "drain": drain}


func _recompute_and_diff(pid: int) -> void:
    var sums: Dictionary = _sums[pid]
    var output := int(sums["output"])
    var drain := int(sums["drain"])
    var low_power := output - drain < 0
    var rate := 1.0
    if low_power:
        rate = _low_power_rate(output, drain)
    var previous: Dictionary = _state.get(pid, {"low_power": false, "rate": 1.0})
    # Exact compare: rate is a pure function of the integer sums, so any
    # inequality is real drift — is_equal_approx would swallow tiny drift on
    # huge grids and leave consumers' cached rates stale.
    if bool(previous["low_power"]) == low_power and float(previous["rate"]) == rate:
        return
    _state[pid] = {"low_power": low_power, "rate": rate}
    _fan_out(pid, low_power)
    grid_state_changed.emit(pid)


func _low_power_rate(output: int, drain: int) -> float:
    var rules := GlobalRules.get_current()
    if rules == null or drain <= 0:
        return 1.0
    var ratio := clampf(float(output) / float(drain), 0.0, 1.0)
    return lerpf(
        rules.worst_low_power_build_rate_coefficient,
        rules.best_low_power_build_rate_coefficient,
        ratio
    )


## Boundary fan-out: only `powered = true` structures flip online state;
## non-powered structures (and producers) are never touched.
func _fan_out(pid: int, low_power: bool) -> void:
    for pc: PowerComponent in _registry:
        var entry: Dictionary = _registry[pc]
        if int(entry["pid"]) != pid or not pc.powered or not is_instance_valid(pc):
            continue
        pc.set_online(not low_power)


func _owner_id(pc: PowerComponent) -> int:
    var parent := pc.get_parent()
    if parent == null:
        return -1
    var stats := parent.get_node_or_null("StatsComponent") as StatsComponent
    if stats == null:
        return -1
    return stats.player_id


## Whole-scene case (FogRenderer precedent) plus ancestor walk for entities
## parented under an editor-flagged container.
func _in_map_editor(pc: PowerComponent) -> bool:
    var scene := get_tree().current_scene
    if scene != null and scene.has_meta("is_map_editor"):
        return true
    var ancestor := pc.get_parent()
    while ancestor != null:
        if ancestor.has_meta("is_map_editor"):
            return true
        ancestor = ancestor.get_parent()
    return false


func get_output(player_id: int) -> int:
    if not _sums.has(player_id):
        return 0
    return int((_sums[player_id] as Dictionary)["output"])


func get_drain(player_id: int) -> int:
    if not _sums.has(player_id):
        return 0
    return int((_sums[player_id] as Dictionary)["drain"])


func is_low_power(player_id: int) -> bool:
    if not _state.has(player_id):
        return false
    return bool((_state[player_id] as Dictionary)["low_power"])


## Production speed multiplier: 1.0 when healthy (or unknown player);
## lerp(worst, best, output/drain) while in low power.
func get_build_rate(player_id: int) -> float:
    if not _state.has(player_id):
        return 1.0
    return float((_state[player_id] as Dictionary)["rate"])
