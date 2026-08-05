class_name SpatialHash extends Node

static var instance: SpatialHash

var _grid: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _building_cells: Dictionary = {}
var _bib_cells: Dictionary = {}
var _reserved: Dictionary = {}
var _resource_cells: Dictionary = {}
var _shared_cell_counts: Dictionary = {}
var _ice_cells: Dictionary = {}
## Pooled per-entity entries (entity root -> entry dict). Shared with `_grid`.
var _entry_map: Dictionary = {}
var _rebuild_pending := false
## Perf-guard counter: group scans performed by the rebuild path. The per-frame
## `_reconcile()` must never increment it (test/unit/test_perf_guard.gd asserts
## this). ponytail: only catches scans routed through these scan sites.
var perf_group_scans: int = 0


func _enter_tree() -> void:
    instance = self


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)


func _on_node_added(node: Node) -> void:
    if _is_membership_node(node):
        _rebuild_pending = true


func _on_node_removed(node: Node) -> void:
    if _is_membership_node(node):
        _rebuild_pending = true


func _is_membership_node(node: Node) -> bool:
    if node.is_in_group("entities") or node.is_in_group("ice"):
        return true
    var parent := node.get_parent()
    return parent != null and (parent.is_in_group("entities") or parent.is_in_group("ice"))


func _physics_process(_delta: float) -> void:
    if _rebuild_pending:
        rebuild()
    else:
        _reconcile()


func rebuild() -> void:
    _grid.clear()
    _blocked_cells.clear()
    _shared_cell_counts.clear()
    _ice_cells.clear()
    _entry_map.clear()
    # ponytail: ice spawned mid-game by EntityFactory._add_ice_component only
    # joins _ice_cells on the next membership rebuild, so a freshly spawned ice
    # block has a short window without passability override / weight damage. Map
    # ice is scene-placed before the first rebuild, so this only matters for
    # runtime ice spawning.
    perf_group_scans += 1
    for ice in get_tree().get_nodes_in_group("ice"):
        var ice_root := ice as Node3D
        if not is_instance_valid(ice_root):
            continue
        var ice_key: int = CellUtil.cell_key(CellUtil.world_to_cell(ice_root.global_position))
        if not _ice_cells.has(ice_key):
            _ice_cells[ice_key] = []
        _ice_cells[ice_key].append(ice_root)
    perf_group_scans += 1
    for entity in get_tree().get_nodes_in_group("entities"):
        # ponytail: scene-placed units add SelectComponent (Node) to group,
        # not the root Node3D. Resolve root for MC lookup + position.
        var entity_root := entity as Node3D
        if not entity_root:
            entity_root = entity.get_parent() as Node3D
        if not is_instance_valid(entity_root):
            continue
        var mc := entity_root.get_node_or_null("MovementController") as MovementController
        var stats := entity_root.get_node_or_null("StatsComponent") as StatsComponent
        var cell := CellUtil.world_to_cell(entity_root.global_position)
        var key := CellUtil.cell_key(cell)
        var etype: int = stats.entity_type if stats else -1
        var pid: int = stats.player_id if stats else -1
        var state: int = mc._state if mc else -1
        var shares: bool = mc.shares_cell() if mc else false
        var entry := {
            "node": entity_root,
            "mc": mc,
            "stats": stats,
            "entity_type": etype,
            "player_id": pid,
            "cell_key": key,
            "state": state,
            "shares": shares,
        }
        _entry_map[entity_root] = entry
        _add_entry_to_grid(entry, key)
        # ponytail: only count IDLE sharers. Moving sharers can stack
        # beyond capacity transiently, but crush clears them. Counting
        # MOVING would block pathfinding for all cells with moving sharers.
        if mc and state == MovementController.State.IDLE:
            if shares:
                _shared_cell_counts[key] = _shared_cell_counts.get(key, 0) + 1
            else:
                _blocked_cells[key] = true
    _rebuild_pending = false


## Allocation-free drift correction. Reads cached node/MC refs and only mutates
## the grid when a cell or state actually changed. No group scans, no node
## lookups, no per-entity dictionary allocations.
func _reconcile() -> void:
    for entity_root in _entry_map:
        var entry: Dictionary = _entry_map[entity_root]
        var node: Node3D = entry["node"]
        var mc: MovementController = entry["mc"]
        var state: int = -1
        var shares := false
        if mc and is_instance_valid(mc):
            state = mc._state
            shares = mc.shares_cell()
        var key: int = CellUtil.cell_key(CellUtil.world_to_cell(node.global_position))
        var cached_key: int = entry["cell_key"]
        if key == cached_key and state == entry["state"] and shares == entry["shares"]:
            continue
        var was_blocking: bool = (
            entry["state"] == MovementController.State.IDLE and not entry["shares"]
        )
        var was_sharing: bool = entry["state"] == MovementController.State.IDLE and entry["shares"]
        _remove_entry_from_grid(entry, cached_key)
        if was_sharing:
            _decrement_shared(cached_key)
        elif was_blocking and not _has_blocking_entity(cached_key):
            # _blocked_cells is a set (key -> true), so only erase when the
            # last blocking occupant leaves.
            _blocked_cells.erase(cached_key)
        entry["cell_key"] = key
        entry["state"] = state
        entry["shares"] = shares
        _add_entry_to_grid(entry, key)
        if state == MovementController.State.IDLE:
            if shares:
                _shared_cell_counts[key] = _shared_cell_counts.get(key, 0) + 1
            else:
                _blocked_cells[key] = true


func _add_entry_to_grid(entry: Dictionary, key: int) -> void:
    var arr: Variant = _grid.get(key)
    if arr == null:
        arr = []
        _grid[key] = arr
    arr.append(entry)


func _remove_entry_from_grid(entry: Dictionary, key: int) -> void:
    var arr: Variant = _grid.get(key)
    if arr == null:
        return
    arr.erase(entry)
    if arr.is_empty():
        _grid.erase(key)


func _decrement_shared(key: int) -> void:
    var count: int = int(_shared_cell_counts.get(key, 0)) - 1
    if count <= 0:
        _shared_cell_counts.erase(key)
    else:
        _shared_cell_counts[key] = count


## True when at least one entry on the cell still blocks it (IDLE + non-shaver).
func _has_blocking_entity(key: int) -> bool:
    var arr: Variant = _grid.get(key)
    if arr == null:
        return false
    for entry in arr:
        if entry["state"] == MovementController.State.IDLE and not entry["shares"]:
            return true
    return false


func get_entries(cell: Vector2i) -> Array:
    return _grid.get(CellUtil.cell_key(cell), [])


## Ice entities (breakable surfaces) occupying a cell.
func get_ice_entities_on_cell(cell: Vector2i) -> Array:
    return _ice_cells.get(CellUtil.cell_key(cell), [])


## True when a live (intact) ice entity occupies the cell.
func has_intact_ice_on_cell(cell: Vector2i) -> bool:
    for ice in _ice_cells.get(CellUtil.cell_key(cell), []):
        if not is_instance_valid(ice):
            continue
        var hc := (ice as Node3D).get_node_or_null("HealthComponent") as HealthComponent
        if hc and hc.current_health > 0:
            return true
    return false


func get_blocked_cells() -> Dictionary:
    var result: Dictionary = _blocked_cells.duplicate()
    for key in _building_cells:
        result[key] = true
    return result


func all_entries() -> Array:
    var result: Array = []
    for key in _grid:
        result.append_array(_grid[key])
    return result


func is_cell_blocked(cell: Vector2i) -> bool:
    return _blocked_cells.has(CellUtil.cell_key(cell))


func get_shared_cell_count(cell: Vector2i) -> int:
    return _shared_cell_counts.get(CellUtil.cell_key(cell), 0)


func is_cell_full_for_shared(cell: Vector2i) -> bool:
    return get_shared_cell_count(cell) >= CellSubPositions.get_slot_count()


func get_shared_cells() -> Dictionary:
    var result: Dictionary = {}
    for key in _shared_cell_counts:
        if _shared_cell_counts[key] > 0:
            result[key] = true
    return result


func get_crusher_blocking_cells(player_id: int) -> Dictionary:
    var result: Dictionary = {}
    for key in _shared_cell_counts:
        if _shared_cell_counts[key] <= 0:
            continue
        var entries: Array = _grid.get(key, [])
        for entry in entries:
            var entry_type: int = entry["entity_type"]
            if entry_type != EntityData.EntityType.INFANTRY:
                continue
            var entry_pid: int = entry["player_id"]
            if entry_pid == -1 or not PlayerManager.is_enemy(player_id, entry_pid):
                result[key] = true
                break
            var entry_node: Node3D = entry["node"]
            var entry_stats := entry_node.get_node_or_null("StatsComponent") as StatsComponent
            if entry_stats and not entry_stats.crushable:
                result[key] = true
                break
    return result


func get_crushable_enemies_on_cell(cell: Vector2i, player_id: int) -> Array:
    var result: Array = []
    var entries: Array = _grid.get(CellUtil.cell_key(cell), [])
    for entry in entries:
        var entry_node: Node3D = entry["node"]
        var entry_pid: int = entry["player_id"]
        var entry_type: int = entry["entity_type"]
        if entry_type != EntityData.EntityType.INFANTRY:
            continue
        if entry_pid == -1 or not PlayerManager.is_enemy(player_id, entry_pid):
            continue
        var entry_stats := entry_node.get_node_or_null("StatsComponent") as StatsComponent
        if entry_stats and entry_stats.crushable:
            result.append(entry_node)
    return result


func is_any_entity_on_cell(cell: Vector2i) -> bool:
    var entries: Array = _grid.get(CellUtil.cell_key(cell), [])
    for entry in entries:
        if entry["mc"] != null:
            return true
    return false


func reserve_cell(cell: Vector2i) -> bool:
    var key := CellUtil.cell_key(cell)
    if _reserved.has(key) or _blocked_cells.has(key) or _building_cells.has(key):
        return false
    _reserved[key] = true
    return true


func release_cell(cell: Vector2i) -> void:
    _reserved.erase(CellUtil.cell_key(cell))


func force_reserve(cell: Vector2i) -> void:
    _reserved[CellUtil.cell_key(cell)] = true


func clear_reservations() -> void:
    _reserved.clear()


func get_reserved() -> Dictionary:
    return _reserved


func register_building_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _building_cells[CellUtil.cell_key(cell)] = true


func register_bib_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _bib_cells[CellUtil.cell_key(cell)] = true


func unregister_bib_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _bib_cells.erase(CellUtil.cell_key(cell))


func is_bib_cell(cell: Vector2i) -> bool:
    return _bib_cells.has(CellUtil.cell_key(cell))


func register_resource_cell(cell: Vector2i) -> void:
    _resource_cells[CellUtil.cell_key(cell)] = true


func unregister_resource_cell(cell: Vector2i) -> void:
    _resource_cells.erase(CellUtil.cell_key(cell))


func has_resource_cell(cell: Vector2i) -> bool:
    return _resource_cells.has(CellUtil.cell_key(cell))


func unregister_building_cells(cells: Array[Vector2i]) -> void:
    for cell in cells:
        _building_cells.erase(CellUtil.cell_key(cell))


func get_building_cells() -> Dictionary:
    return _building_cells
