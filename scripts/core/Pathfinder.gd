class_name Pathfinder


## Batch-lifetime memo of unit-independent terrain cost data: cell height (the
## 4-corner minimum), land type, and bib status. Blocked status is deliberately
## NOT cached — the blocked set differs per unit (each movement controller erases
## its own cell), so it stays a per-call parameter. One `PathCostCache` is shared
## across a move order's drain in SelectionManager, so overlapping searches read
## terrain cost data once instead of re-probing TerrainSystem/SpatialHash.
class PathCostCache:
    var _cells: Dictionary = {}
    var generation: int = -1

    func get_cell(key: int) -> Dictionary:
        return _cells.get(key, {})

    func set_cell(key: int, entry: Dictionary) -> void:
        _cells[key] = entry

    func invalidate() -> void:
        _cells.clear()
        generation = -1


## World-mutation generation. Bumped by SelectionManager at each `request_move`
## (the order boundary); `find_path` lazily clears any `PathCostCache` whose
## generation is stale, so a mid-drain blocker/building change never serves
## stale cost data.
static var _world_generation: int = 0


static func bump_world_generation() -> void:
    _world_generation += 1


## Test-observable count of `find_path` invocations. Greedy-first movement on
## open terrain completes without a full A* search, so the counter must not move
## for a greedy-only move. Not used by gameplay logic (test-only instrumentation).
static var find_path_call_count: int = 0


## Resolves the TerrainSystem autoload once per pathfinding call (hot path).
static func _get_terrain_system() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if not tree:
        return null
    return tree.root.get_node_or_null("TerrainSystem")


## Pure-arithmetic terrain height read for a cell: the minimum of its 4 corner
## vertices, matching TerrainSystem._compute_cell_from_vertices (a slope cell
## reads at its lowest corner). No dict/string lookups. This preserves the
## pre-D7 per-cell semantics so a 2-step cliff still blocks foot units — the
## bilinear-average read made transition cells read high enough that 2-step
## walls became climbable.
static func _cell_height(terrain: Node, cell: Vector2i) -> float:
    if terrain == null:
        return 0.0
    var h := mini(
        mini(terrain.get_vertex(cell.x, cell.y), terrain.get_vertex(cell.x + 1, cell.y)),
        mini(terrain.get_vertex(cell.x, cell.y + 1), terrain.get_vertex(cell.x + 1, cell.y + 1)),
    )
    return float(h) * terrain.HEIGHT_STEP


## Unit-independent terrain cost data for a cell — height, land type, bib
## status — memoized in `cost_cache` when provided (batch lifetime) or probed
## fresh. Blocked status is NOT cached (per-unit blocked sets differ).
static func _cell_cost(terrain: Node, cell: Vector2i, cost_cache: PathCostCache) -> Dictionary:
    if cost_cache == null:
        return {
            "height": _cell_height(terrain, cell),
            "land": terrain.get_land_type(cell) if terrain else "clear",
            "bib": bool(SpatialHash.instance and SpatialHash.instance.is_bib_cell(cell)),
        }
    var key: int = CellUtil.cell_key(cell)
    var cached: Dictionary = cost_cache.get_cell(key)
    if not cached.is_empty():
        return cached
    cached = {
        "height": _cell_height(terrain, cell),
        "land": terrain.get_land_type(cell) if terrain else "clear",
        "bib": bool(SpatialHash.instance and SpatialHash.instance.is_bib_cell(cell)),
    }
    cost_cache.set_cell(key, cached)
    return cached


## Out-of-range cell value returned by `try_greedy_step` to signal a stall: too
## far outside any real grid for `cell_key`/`cell_to_world` to be valid, so it
## can never collide with a genuine cell.
const GREEDY_STALL: Vector2i = Vector2i(-1000000, -1000000)


## Greedy descent primitive for group moves: returns the best strictly-
## improving passable 8-neighbor toward `target_cell`, or `GREEDY_STALL` when no
## passable neighbor strictly reduces the distance to the target. Uses the same
## per-locomotor cost model as `find_path` (octile step, terrain speed
## multiplier, height penalty, bib penalty, climb tolerance, `ignores_height`).
## Ties break toward the target direction, then the previous heading, so a
## plateau keeps moving instead of oscillating. Terrain cost data is memoized in
## `cost_cache` when provided (batch lifetime).
static func try_greedy_step(
    from_cell: Vector2i,
    target_cell: Vector2i,
    blocked_cells: Dictionary = {},
    locomotor: Locomotor = null,
    previous_cell: Vector2i = GREEDY_STALL,
    cost_cache: PathCostCache = null,
) -> Vector2i:
    var terrain: Node = _get_terrain_system()
    var climb_limit: float = (
        float(locomotor.climb_tolerance) * terrain.HEIGHT_STEP if terrain and locomotor else 0.0
    )
    var ignores_height: bool = false
    if locomotor:
        ignores_height = locomotor.is_fly or locomotor.is_jumpjet

    var neighbor_dirs := [
        Vector2i(1, 0),
        Vector2i(-1, 0),
        Vector2i(0, 1),
        Vector2i(0, -1),
        Vector2i(1, 1),
        Vector2i(1, -1),
        Vector2i(-1, 1),
        Vector2i(-1, -1),
    ]
    var neighbor_costs: Array[float] = [
        1.0,
        1.0,
        1.0,
        1.0,
        CellUtil.SQRT2,
        CellUtil.SQRT2,
        CellUtil.SQRT2,
        CellUtil.SQRT2,
    ]

    var from_height: float = _cell_height(terrain, from_cell)
    var from_dist := CellUtil.heuristic(from_cell, target_cell)
    var rules := GlobalRules.get_current()
    var bib_penalty: float = rules.bib_cost_penalty if rules else 0.0
    var best: Vector2i = GREEDY_STALL
    var best_dist: float = from_dist
    var best_cost: float = INF
    var best_align: float = INF

    for i in 8:
        var neighbor: Vector2i = from_cell + neighbor_dirs[i]
        var nkey: int = CellUtil.cell_key(neighbor)
        if blocked_cells.has(nkey):
            continue
        var cost: Dictionary = _cell_cost(terrain, neighbor, cost_cache)
        var neighbor_height: float = cost["height"]
        var cost_multiplier: float = 1.0
        if terrain and locomotor:
            if not ignores_height and absf(neighbor_height - from_height) > climb_limit:
                continue
            var land: String = cost["land"]
            if not _is_terrain_passable(locomotor, land, neighbor):
                continue
            cost_multiplier = _cost_multiplier(locomotor, land, neighbor)

        var ndist := CellUtil.heuristic(neighbor, target_cell)
        if ndist >= from_dist:
            # Strictly-improving only: a plateau or worsening neighbor is not a
            # greedy step — the caller falls back to A* instead of oscillating.
            continue
        var step_cost: float = (
            neighbor_costs[i] * cost_multiplier
            + absf(neighbor_height - from_height) * 0.5
            + (bib_penalty if cost["bib"] else 0.0)
        )
        # Tie-break: target direction (smaller dist), then terrain cost, then
        # continuing the previous heading (smaller alignment distance).
        var align_dist := CellUtil.heuristic(neighbor, previous_cell)
        if (
            ndist < best_dist - 0.001
            or (
                absf(ndist - best_dist) <= 0.001
                and (
                    step_cost < best_cost - 0.001
                    or (absf(step_cost - best_cost) <= 0.001 and align_dist < best_align)
                )
            )
        ):
            best = neighbor
            best_dist = ndist
            best_cost = step_cost
            best_align = align_dist

    return best


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
    ignore_bib_penalty: bool = false,
    cost_cache: PathCostCache = null,
) -> PackedVector3Array:
    find_path_call_count += 1
    # Resolve TerrainSystem once per path, not per neighbour.
    var terrain: Node = _get_terrain_system()
    var grid_cells: Vector2i = terrain.grid_cells if terrain else Vector2i(32, 32)
    var start_cell := CellUtil.world_to_cell(start_world, grid_cells)
    var end_cell := CellUtil.world_to_cell(end_world, grid_cells)

    if start_cell == end_cell:
        return PackedVector3Array()

    # A shared cache is valid only while the world generation matches; a stale
    # cache (blockers/buildings changed mid-drain) is cleared before reuse.
    # Without a shared cache, a per-call local memo still dedups repeated
    # neighbor probes within this one search.
    var local_cache: PathCostCache = null
    if cost_cache == null:
        local_cache = PathCostCache.new()
        cost_cache = local_cache
    elif cost_cache.generation != _world_generation:
        cost_cache.invalidate()
        cost_cache.generation = _world_generation

    # Bib cells are walkable but penalized — dockers (harvesters) path onto the
    # dock pad, but ordinary traffic detours around it. Null-safe: no penalty in
    # editor/test contexts where GlobalRules is unavailable. `ignore_bib_penalty`
    # is used for building-associated moves (e.g. exiting a factory), where the
    # unit legitimately crosses its own pad.
    var rules := GlobalRules.get_current()
    var bib_penalty: float = (
        0.0 if ignore_bib_penalty else (rules.bib_cost_penalty if rules else 0.0)
    )

    var open_heap: Array = [
        {
            "cell": start_cell,
            "f": CellUtil.heuristic(start_cell, end_cell),
            "height": _cell_height(terrain, start_cell),
        }
    ]
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

        # Height was already computed when this node was relaxed as a neighbor
        # and stored in its heap entry (see _heap_push) — no re-probe here.
        var current_height: float = current_entry["height"]

        for i in 8:
            var neighbor: Vector2i = current + neighbor_dirs[i]
            var nkey: int = CellUtil.cell_key(neighbor)

            if blocked_cells.has(nkey):
                continue

            var cost: Dictionary = _cell_cost(terrain, neighbor, cost_cache)
            var neighbor_height: float = cost["height"]
            var cost_multiplier: float = 1.0
            if terrain and locomotor:
                if not ignores_height and absf(neighbor_height - current_height) > climb_limit:
                    continue
                var land: String = cost["land"]
                if not _is_terrain_passable(locomotor, land, neighbor):
                    continue
                cost_multiplier = _cost_multiplier(locomotor, land, neighbor)

            var height_cost: float = absf(neighbor_height - current_height) * 0.5
            var bib_cost: float = bib_penalty if cost["bib"] else 0.0
            var tentative_g: float = (
                g_score.get(current_key, INF)
                + neighbor_costs[i] * cost_multiplier
                + height_cost
                + bib_cost
            )

            if tentative_g < g_score.get(nkey, INF):
                came_from[nkey] = current
                g_score[nkey] = tentative_g
                var nf: float = tentative_g + CellUtil.heuristic(neighbor, end_cell) * 1.2
                f_score[nkey] = nf
                if not open_lookup.has(nkey):
                    _heap_push(open_heap, neighbor, nf, neighbor_height)
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


static func _heap_push(heap: Array, cell: Vector2i, f: float, height: float) -> void:
    heap.append({"cell": cell, "f": f, "height": height})
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


static func has_line_of_sight(from: Vector2i, to: Vector2i, blocked: Dictionary) -> bool:
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
            if has_line_of_sight(cells[i], cells[try], blocked):
                farthest = try
                break
        result.append(waypoints[farthest])
        i = farthest
    return result
