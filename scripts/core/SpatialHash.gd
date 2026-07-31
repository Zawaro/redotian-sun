class_name SpatialHash extends Node

static var instance: SpatialHash

var _grid: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _building_cells: Dictionary = {}
var _bib_cells: Dictionary = {}
var _reserved: Dictionary = {}
var _resource_cells: Dictionary = {}
var _infantry_cell_counts: Dictionary = {}
var _ice_cells: Dictionary = {}


func _enter_tree() -> void:
    instance = self


func _physics_process(_delta: float) -> void:
    rebuild()


func rebuild() -> void:
    _grid.clear()
    _blocked_cells.clear()
    _infantry_cell_counts.clear()
    _ice_cells.clear()
    for ice in get_tree().get_nodes_in_group("ice"):
        var ice_root := ice as Node3D
        if not is_instance_valid(ice_root):
            continue
        var ice_key: int = CellUtil.cell_key(CellUtil.world_to_cell(ice_root.global_position))
        if not _ice_cells.has(ice_key):
            _ice_cells[ice_key] = []
        _ice_cells[ice_key].append(ice_root)
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
        if not _grid.has(key):
            _grid[key] = []
        var etype: int = stats.entity_type if stats else -1
        var pid: int = stats.player_id if stats else -1
        (
            _grid[key]
            . append(
                {
                    "node": entity_root,
                    "mc": mc,
                    "entity_type": etype,
                    "player_id": pid,
                }
            )
        )
        if mc and mc._state == MovementController.State.IDLE:
            # ponytail: only count IDLE infantry. Moving infantry can stack
            # beyond 3 transiently, but crush clears them. Counting MOVING
            # would block pathfinding for all cells with moving infantry.
            if stats and stats.entity_type == EntityData.EntityType.INFANTRY:
                _infantry_cell_counts[key] = _infantry_cell_counts.get(key, 0) + 1
            else:
                _blocked_cells[key] = true


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


func get_infantry_count(cell: Vector2i) -> int:
    return _infantry_cell_counts.get(CellUtil.cell_key(cell), 0)


func is_cell_full_for_infantry(cell: Vector2i) -> bool:
    return get_infantry_count(cell) >= 3


func get_full_infantry_cells() -> Dictionary:
    var result: Dictionary = {}
    for key in _infantry_cell_counts:
        if _infantry_cell_counts[key] >= 3:
            result[key] = true
    return result


func get_infantry_cells() -> Dictionary:
    var result: Dictionary = {}
    for key in _infantry_cell_counts:
        if _infantry_cell_counts[key] > 0:
            result[key] = true
    return result


func get_crusher_blocking_cells(player_id: int) -> Dictionary:
    var result: Dictionary = {}
    for key in _infantry_cell_counts:
        if _infantry_cell_counts[key] <= 0:
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
