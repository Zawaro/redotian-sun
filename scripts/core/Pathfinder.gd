class_name Pathfinder


## Resolves the TerrainSystem autoload once per pathfinding call (hot path).
static func _get_terrain_system() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if not tree:
        return null
    return tree.root.get_node_or_null("TerrainSystem")


static func _cell_height(terrain: Node, cell: Vector2i) -> float:
    if terrain == null:
        return 0.0
    return terrain.get_height_at_world(CellUtil.cell_to_world(cell))


## Terrain passability for a unit's locomotor. Fly/hover pass everything; others
## pass only positive-speed land types. Intact ice provides footing on water.
static func _is_terrain_passable(locomotor: Locomotor, land: String, cell: Vector2i) -> bool:
    if locomotor.is_passable(land):
        return true
    if (
        land == "water"
        and SpatialHash.instance
        and SpatialHash.instance.has_intact_ice_on_cell(cell)
    ):
        return true
    return false


## Pathing cost multiplier = inverse of terrain speed multiplier. Ice-covered
## water costs like clear ground.
static func _cost_multiplier(locomotor: Locomotor, land: String, cell: Vector2i) -> float:
    if (
        land == "water"
        and not locomotor.is_passable(land)
        and SpatialHash.instance
        and SpatialHash.instance.has_intact_ice_on_cell(cell)
    ):
        return 1.0
    var mult: float = locomotor.get_speed_multiplier(land)
    return 1.0 / mult if mult > 0.0 else INF


static func find_path(
    start_world: Vector3,
    end_world: Vector3,
    blocked_cells: Dictionary = {},
    locomotor: Locomotor = null,
) -> PackedVector3Array:
    var start_cell := CellUtil.world_to_cell(start_world)
    var end_cell := CellUtil.world_to_cell(end_world)

    if start_cell == end_cell:
        return PackedVector3Array()

    var terrain: Node = _get_terrain_system()

    var open_heap: Array = [{"cell": start_cell, "f": CellUtil.heuristic(start_cell, end_cell)}]
    var open_lookup: Dictionary = {}
    open_lookup[CellUtil.cell_key(start_cell)] = true
    var closed_set: Dictionary = {}
    var came_from: Dictionary = {}
    var g_score: Dictionary = {}
    var f_score: Dictionary = {}

    g_score[CellUtil.cell_key(start_cell)] = 0.0
    f_score[CellUtil.cell_key(start_cell)] = CellUtil.heuristic(start_cell, end_cell)

    var neighbor_dirs := [
        Vector2i(1, 0),
        Vector2i(-1, 0),
        Vector2i(0, 1),
        Vector2i(0, -1),
        Vector2i(1, 1),
        Vector2i(1, -1),
        Vector2i(-1, 1),
        Vector2i(-1, -1)
    ]
    var neighbor_costs: Array[float] = [
        1.0, 1.0, 1.0, 1.0, CellUtil.SQRT2, CellUtil.SQRT2, CellUtil.SQRT2, CellUtil.SQRT2
    ]

    const MAX_ITER: int = 1500
    const STAGNANT_LIMIT: int = 500
    var iter: int = 0
    var stagnant: int = 0
    var best_cell: Vector2i = start_cell
    var best_dist: float = CellUtil.heuristic(start_cell, end_cell)

    var climb_limit: float = (
        float(locomotor.climb_tolerance) * terrain.HEIGHT_STEP if terrain and locomotor else 0.0
    )
    var ignores_height: bool = false
    if locomotor:
        ignores_height = locomotor.is_fly or locomotor.is_jumpjet

    while not open_heap.is_empty():
        var current_entry: Dictionary = _heap_pop(open_heap)
        var current: Vector2i = current_entry["cell"]
        var current_key: int = CellUtil.cell_key(current)
        open_lookup.erase(current_key)

        if closed_set.has(current_key):
            continue
        closed_set[current_key] = true
        iter += 1

        if current == end_cell:
            return _reconstruct_path(came_from, current, start_cell)

        var h := CellUtil.heuristic(current, end_cell)
        if h < best_dist:
            best_dist = h
            best_cell = current
            stagnant = 0
        else:
            stagnant += 1

        if stagnant > STAGNANT_LIMIT or iter > MAX_ITER:
            return _path_or_fallback(came_from, start_cell, best_cell)

        var current_height := _cell_height(terrain, current)

        for i in 8:
            var neighbor: Vector2i = current + neighbor_dirs[i]
            var nkey: int = CellUtil.cell_key(neighbor)

            if blocked_cells.has(nkey):
                continue

            var neighbor_height: float = _cell_height(terrain, neighbor)
            var cost_multiplier: float = 1.0
            if terrain and locomotor:
                if not ignores_height and absf(neighbor_height - current_height) > climb_limit:
                    continue
                var land: String = terrain.get_land_type(neighbor)
                if not _is_terrain_passable(locomotor, land, neighbor):
                    continue
                cost_multiplier = _cost_multiplier(locomotor, land, neighbor)

            var height_cost: float = absf(neighbor_height - current_height) * 0.5
            var tentative_g: float = (
                g_score.get(current_key, INF) + neighbor_costs[i] * cost_multiplier + height_cost
            )

            if tentative_g < g_score.get(nkey, INF):
                came_from[nkey] = current
                g_score[nkey] = tentative_g
                var nf: float = tentative_g + CellUtil.heuristic(neighbor, end_cell) * 1.2
                f_score[nkey] = nf
                if not open_lookup.has(nkey):
                    _heap_push(open_heap, neighbor, nf)
                    open_lookup[nkey] = true

    return _path_or_fallback(came_from, start_cell, best_cell)


static func _reconstruct_path(
    came_from: Dictionary, current: Vector2i, start: Vector2i
) -> PackedVector3Array:
    var path_cells: Array[Vector2i] = [current]
    var key: int = CellUtil.cell_key(current)
    while came_from.has(key):
        current = came_from[key]
        path_cells.push_front(current)
        key = CellUtil.cell_key(current)

    if path_cells.size() > 1 and path_cells[0] == start:
        path_cells.remove_at(0)

    var result := PackedVector3Array()
    for cell in path_cells:
        result.append(CellUtil.cell_to_world(cell))
    return result


static func _path_or_fallback(
    came_from: Dictionary, start: Vector2i, best: Vector2i
) -> PackedVector3Array:
    if best == start:
        return PackedVector3Array()
    return _reconstruct_path(came_from, best, start)


static func _heap_push(heap: Array, cell: Vector2i, f: float) -> void:
    heap.append({"cell": cell, "f": f})
    var idx: int = heap.size() - 1
    while idx > 0:
        var parent_idx := floori(float(idx - 1) / 2.0)
        if heap[idx]["f"] >= heap[parent_idx]["f"]:
            break
        var tmp: Dictionary = heap[idx]
        heap[idx] = heap[parent_idx]
        heap[parent_idx] = tmp
        idx = parent_idx


static func _heap_pop(heap: Array) -> Dictionary:
    var result: Dictionary = heap[0]
    var last: Dictionary = heap[heap.size() - 1]
    heap[0] = last
    heap.remove_at(heap.size() - 1)

    if heap.is_empty():
        return result

    var idx: int = 0
    var size: int = heap.size()
    while true:
        var smallest: int = idx
        var left: int = idx * 2 + 1
        var right: int = idx * 2 + 2

        if left < size and heap[left]["f"] < heap[smallest]["f"]:
            smallest = left

        if right < size and heap[right]["f"] < heap[smallest]["f"]:
            smallest = right

        if smallest == idx:
            break

        var tmp: Dictionary = heap[idx]
        heap[idx] = heap[smallest]
        heap[smallest] = tmp
        idx = smallest

    return result


static func _has_line_of_sight(from: Vector2i, to: Vector2i, blocked: Dictionary) -> bool:
    var dx: int = absi(to.x - from.x)
    var dy: int = absi(to.y - from.y)
    var sx: int = 1 if from.x < to.x else -1
    var sy: int = 1 if from.y < to.y else -1
    var err: int = dx - dy
    var cx: int = from.x
    var cy: int = from.y
    while true:
        var key: int = CellUtil.cell_key(Vector2i(cx, cy))
        if blocked.has(key):
            return false
        if cx == to.x and cy == to.y:
            break
        var e2: int = 2 * err
        if e2 > -dy:
            err -= dy
            cx += sx
        if e2 < dx:
            err += dx
            cy += sy
    return true


static func smooth_path(waypoints: PackedVector3Array, blocked: Dictionary) -> PackedVector3Array:
    if waypoints.size() <= 2:
        return waypoints
    var cells: Array[Vector2i] = []
    for w in waypoints:
        cells.append(CellUtil.world_to_cell(w))
    var result := PackedVector3Array()
    result.append(waypoints[0])
    var i: int = 0
    while i < cells.size() - 1:
        var farthest: int = i + 1
        for try in range(cells.size() - 1, i, -1):
            if _has_line_of_sight(cells[i], cells[try], blocked):
                farthest = try
                break
        result.append(waypoints[farthest])
        i = farthest
    return result
