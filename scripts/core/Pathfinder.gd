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


## Pure-arithmetic terrain height read for a cell surfaced at `level`. At level 0
## it is the minimum of the cell's 4 corner vertices, matching
## TerrainSystem._compute_cell_from_vertices (a slope cell reads at its lowest
## corner); a deck above the cell is ignored, so the ground beneath a deck keeps
## its own height. At level > 0 it reads that level's walkable deck surface. No
## dict/string lookups. Reads through the world-lifetime TerrainSystem height
## snapshot (`terrain-height-cache`) when the node supports it. This preserves the
## pre-D7 per-cell semantics so a 2-step cliff still blocks foot units — the
## bilinear-average read made transition cells read high enough that 2-step
## walls became climbable.
static func _cell_height(terrain: Node, cell: Vector2i, level: int = 0) -> float:
    if terrain == null:
        return 0.0
    if level > 0 and terrain.has_method("get_cell_surface_height"):
        return terrain.get_cell_surface_height(cell, level)
    if terrain.has_method("get_cell_min_height"):
        return terrain.get_cell_min_height(cell)
    var h := mini(
        mini(terrain.get_vertex(cell.x, cell.y), terrain.get_vertex(cell.x + 1, cell.y)),
        mini(terrain.get_vertex(cell.x, cell.y + 1), terrain.get_vertex(cell.x + 1, cell.y + 1)),
    )
    return float(h) * terrain.HEIGHT_STEP


## Unit-independent terrain cost data for a `(cell, level)` node — height, land
## type, bib status — memoized in `cost_cache` when provided (batch lifetime) or
## probed fresh. Blocked status is NOT cached (per-unit blocked sets differ). The
## cache key is `CellUtil.cell_level_key`, so a ground surface and a deck surface
## at the same cell never collide.
static func _cell_cost(
    terrain: Node, cell: Vector2i, level: int, cost_cache: PathCostCache
) -> Dictionary:
    if cost_cache == null:
        return {
            "height": _cell_height(terrain, cell, level),
            "land": terrain.get_land_type(cell, level) if terrain else "clear",
            "bib": bool(SpatialHash.instance and SpatialHash.instance.is_bib_cell(cell)),
        }
    var key: int = CellUtil.cell_level_key(cell, level)
    var cached: Dictionary = cost_cache.get_cell(key)
    if not cached.is_empty():
        return cached
    cached = {
        "height": _cell_height(terrain, cell, level),
        "land": terrain.get_land_type(cell, level) if terrain else "clear",
        "bib": bool(SpatialHash.instance and SpatialHash.instance.is_bib_cell(cell)),
    }
    cost_cache.set_cell(key, cached)
    return cached


## Surface levels present on a cell — ground (0) plus each deck level. Falls back
## to ground-only when no terrain node is threaded (editor/test contexts).
static func _surface_levels(terrain: Node, cell: Vector2i) -> Array[int]:
    if terrain != null and terrain.has_method("get_cell_surface_levels"):
        return terrain.get_cell_surface_levels(cell)
    var only: Array[int] = [0]
    return only


## Cost multiplier for a bridge/level transition (two or more height levels) from
## the locomotor's Road row, falling back to its Bridge row when no Road row is
## declared. The destination deck's own terrain figure is skipped entirely.
static func _road_cost_multiplier(locomotor: Locomotor) -> float:
    var mult: float = locomotor.get_speed_multiplier("road")
    if mult <= 0.0:
        mult = locomotor.get_speed_multiplier("bridge")
    return 1.0 / mult if mult > 0.0 else INF


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
## Greedy descent primitive for group moves: returns the best strictly-
## improving passable neighbor state toward `target_cell`, or a stall entry when
## no passable neighbor strictly reduces the distance to the target. Uses the same
## per-locomotor cost model as `find_path` (octile step, terrain speed
## multiplier, height penalty, bib penalty, climb tolerance, `ignores_height`).
## Ties break toward the target direction, then the previous heading, so a
## plateau keeps moving instead of oscillating. Terrain cost data is memoized in
## `cost_cache` when provided (batch lifetime). The returned state carries the
## neighbor's resolved surface level so a greedy step onto a deck is tracked.
static func try_greedy_step_detailed(
    from_cell: Vector2i,
    target_cell: Vector2i,
    blocked_cells: Dictionary = {},
    locomotor: Locomotor = null,
    previous_cell: Vector2i = GREEDY_STALL,
    cost_cache: PathCostCache = null,
    terrain: Node = null,
    from_level: int = 0,
    target_level: int = 0,
) -> Dictionary:
    if terrain == null:
        terrain = _get_terrain_system()
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

    var from_height: float = _cell_height(terrain, from_cell, from_level)
    var from_dist := CellUtil.heuristic(from_cell, target_cell)
    var rules := GlobalRules.get_current()
    var bib_penalty: float = rules.bib_cost_penalty if rules else 0.0
    var best: Vector2i = GREEDY_STALL
    var best_level: int = from_level
    var best_dist: float = from_dist
    var best_cost: float = INF
    var best_align: float = INF

    for i in 8:
        var neighbor: Vector2i = from_cell + neighbor_dirs[i]
        for nl in _surface_levels(terrain, neighbor):
            var nkey: int = CellUtil.cell_level_key(neighbor, nl)
            if blocked_cells.has(nkey):
                continue
            var trans: Dictionary = _evaluate_transition(
                terrain,
                locomotor,
                from_height,
                from_cell,
                from_level,
                neighbor,
                nl,
                climb_limit,
                ignores_height,
                cost_cache,
            )
            if not trans.get("allowed", false):
                continue
            var neighbor_height: float = trans["height"]
            var ndist := CellUtil.heuristic(neighbor, target_cell)
            if ndist >= from_dist:
                # Strictly-improving only: a plateau or worsening neighbor is not a
                # greedy step — the caller falls back to A* instead of oscillating.
                continue
            if neighbor == target_cell and nl != target_level:
                # Arriving on the wrong surface of the target cell is not arrival;
                # stall and let A* resolve the target level.
                continue
            var step_cost: float = (
                neighbor_costs[i] * float(trans["cost_multiplier"])
                + absf(neighbor_height - from_height) * 0.5
                + (bib_penalty if trans["bib"] else 0.0)
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
                best_level = nl
                best_dist = ndist
                best_cost = step_cost
                best_align = align_dist

    return {"cell": best, "level": best_level}


## Cell-only wrapper around `try_greedy_step_detailed` for callers that ignore
## surface levels (level 0 default behavior is unchanged).
static func try_greedy_step(
    from_cell: Vector2i,
    target_cell: Vector2i,
    blocked_cells: Dictionary = {},
    locomotor: Locomotor = null,
    previous_cell: Vector2i = GREEDY_STALL,
    cost_cache: PathCostCache = null,
    terrain: Node = null,
    from_level: int = 0,
    target_level: int = 0,
) -> Vector2i:
    var step: Dictionary = try_greedy_step_detailed(
        from_cell,
        target_cell,
        blocked_cells,
        locomotor,
        previous_cell,
        cost_cache,
        terrain,
        from_level,
        target_level,
    )
    return step["cell"]


## Resolves one surface transition from `(cell, lvl)` to `(ncell, nl)` against the
## surface-stack height rules. Same-level transitions keep the existing
## climb-tolerance + terrain-figure behavior. A level change entering a deck
## (nl > lvl) is allowed only when `ncell` carries a deck at `nl` and the height
## step is within climb tolerance (matching-grade bridge ends and slopes);
## descending off a deck (nl < lvl) is allowed subject to the same grade gate.
## A level transition is costed from the Road row, not the destination figure.
## Returns {"allowed": bool, "height": float, "bib": bool, "cost_multiplier": float}.
static func _evaluate_transition(
    terrain: Node,
    locomotor: Locomotor,
    from_height: float,
    _cell: Vector2i,
    lvl: int,
    ncell: Vector2i,
    nl: int,
    climb_limit: float,
    ignores_height: bool,
    cost_cache: PathCostCache,
) -> Dictionary:
    var cost: Dictionary = _cell_cost(terrain, ncell, nl, cost_cache)
    var nheight: float = cost["height"]
    var land: String = cost["land"]
    if nl == lvl:
        if locomotor:
            if not ignores_height and absf(nheight - from_height) > climb_limit:
                return {"allowed": false}
            if not _is_terrain_passable(locomotor, land, ncell):
                return {"allowed": false}
        return {
            "allowed": true,
            "height": nheight,
            "bib": cost["bib"],
            "cost_multiplier": _cost_multiplier(locomotor, land, ncell) if locomotor else 1.0,
        }
    if nl > lvl:
        # Entering a higher surface must land on an actual deck at that level.
        if not (SpatialHash.instance and SpatialHash.instance.has_bridge_on_cell(ncell, nl)):
            return {"allowed": false}
    if locomotor:
        if not ignores_height and absf(nheight - from_height) > climb_limit:
            return {"allowed": false}
        if not _is_terrain_passable(locomotor, land, ncell):
            return {"allowed": false}
    return {
        "allowed": true,
        "height": nheight,
        "bib": cost["bib"],
        "cost_multiplier": _road_cost_multiplier(locomotor) if locomotor else 1.0,
    }


## Terrain passability for a unit's locomotor. Fly/hover pass everything; others
## pass only positive-speed land types. Intact ice provides footing on water,
## but only when the active game enables the breakable-ice mechanic.
static func _is_terrain_passable(locomotor: Locomotor, land: String, cell: Vector2i) -> bool:
    if locomotor.is_passable(land):
        return true
    if (
        land == "water"
        and _breakable_ice_enabled()
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
        and _breakable_ice_enabled()
        and SpatialHash.instance
        and SpatialHash.instance.has_intact_ice_on_cell(cell)
    ):
        return 1.0
    var mult: float = locomotor.get_speed_multiplier(land)
    return 1.0 / mult if mult > 0.0 else INF


## True when the active game enables the breakable-ice mechanic. Ice footing is
## only considered when this returns true; other games' water stays impassable.
static func _breakable_ice_enabled() -> bool:
    var main_loop := Engine.get_main_loop()
    if not main_loop:
        return false
    var gc: Node = main_loop.root.get_node_or_null("GameContext")
    return gc != null and gc.has_feature("breakable_ice")


## Cell-only wrapper around `find_path_detailed` for existing callers. Returns
## just the waypoint positions; level-0 searches are byte-identical to before.
static func find_path(
    start_world: Vector3,
    end_world: Vector3,
    blocked_cells: Dictionary = {},
    locomotor: Locomotor = null,
    ignore_bib_penalty: bool = false,
    cost_cache: PathCostCache = null,
    terrain: Node = null,
    start_level: int = 0,
    end_level: int = 0,
) -> PackedVector3Array:
    var result: Dictionary = find_path_detailed(
        start_world,
        end_world,
        blocked_cells,
        locomotor,
        ignore_bib_penalty,
        cost_cache,
        terrain,
        start_level,
        end_level,
    )
    return result["path"]


## Level-aware A* over `(cell, level)` nodes. Returns
## `{"path": PackedVector3Array, "levels": PackedInt32Array}` where each waypoint
## carries its surface Y and the parallel level sequence names the surface the
## mover stands on. `start_level`/`end_level` default to ground (0); a level-0
## search on a bridge-free map is byte-identical to the pre-level behavior.
static func find_path_detailed(
    start_world: Vector3,
    end_world: Vector3,
    blocked_cells: Dictionary = {},
    locomotor: Locomotor = null,
    ignore_bib_penalty: bool = false,
    cost_cache: PathCostCache = null,
    terrain: Node = null,
    start_level: int = 0,
    end_level: int = 0,
) -> Dictionary:
    find_path_call_count += 1
    # Resolve TerrainSystem once per path, not per neighbour. A reference may be
    # threaded in from the caller (batch-scoped) to skip the scene-tree lookup.
    if terrain == null:
        terrain = _get_terrain_system()
    var grid_cells: Vector2i = terrain.grid_cells if terrain else Vector2i(32, 32)
    var start_cell := CellUtil.world_to_cell(start_world, grid_cells)
    var end_cell := CellUtil.world_to_cell(end_world, grid_cells)

    if start_cell == end_cell:
        return {"path": PackedVector3Array(), "levels": PackedInt32Array()}

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

    var start_key := CellUtil.cell_level_key(start_cell, start_level)
    var goal_key := CellUtil.cell_level_key(end_cell, end_level)

    var open_heap: Array = [
        {
            "cell": start_cell,
            "level": start_level,
            "f": CellUtil.heuristic(start_cell, end_cell),
            "height": _cell_height(terrain, start_cell, start_level),
        }
    ]
    var open_lookup: Dictionary = {}
    open_lookup[start_key] = true
    var closed_set: Dictionary = {}
    var came_from: Dictionary = {}
    var g_score: Dictionary = {}
    var f_score: Dictionary = {}

    g_score[start_key] = 0.0
    f_score[start_key] = CellUtil.heuristic(start_cell, end_cell)

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
    var best_state: Vector3i = Vector3i(start_cell.x, start_cell.y, start_level)
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
        var current_level: int = current_entry["level"]
        var current_key: int = CellUtil.cell_level_key(current, current_level)
        open_lookup.erase(current_key)

        if closed_set.has(current_key):
            continue
        closed_set[current_key] = true
        iter += 1

        if current_key == goal_key:
            return _reconstruct_path_states(came_from, current_entry["state"], start_key, terrain)

        var h := CellUtil.heuristic(current, end_cell)
        if h < best_dist:
            best_dist = h
            best_state = Vector3i(current.x, current.y, current_level)
            stagnant = 0
        else:
            stagnant += 1

        if stagnant > STAGNANT_LIMIT or iter > MAX_ITER:
            return _path_or_fallback_states(came_from, start_key, best_state, terrain)

        # Height was already computed when this node was relaxed as a neighbor
        # and stored in its heap entry (see _heap_push) — no re-probe here.
        var current_height: float = current_entry["height"]

        for i in 8:
            var neighbor: Vector2i = current + neighbor_dirs[i]

            for nl in _surface_levels(terrain, neighbor):
                var nkey: int = CellUtil.cell_level_key(neighbor, nl)
                if blocked_cells.has(nkey):
                    continue

                var trans: Dictionary = _evaluate_transition(
                    terrain,
                    locomotor,
                    current_height,
                    current,
                    current_level,
                    neighbor,
                    nl,
                    climb_limit,
                    ignores_height,
                    cost_cache,
                )
                if not trans.get("allowed", false):
                    continue
                var neighbor_height: float = trans["height"]
                var height_cost: float = absf(neighbor_height - current_height) * 0.5
                var bib_cost: float = bib_penalty if trans["bib"] else 0.0
                var tentative_g: float = (
                    g_score.get(current_key, INF)
                    + neighbor_costs[i] * float(trans["cost_multiplier"])
                    + height_cost
                    + bib_cost
                )

                if tentative_g < g_score.get(nkey, INF):
                    came_from[nkey] = Vector3i(current.x, current.y, current_level)
                    g_score[nkey] = tentative_g
                    var nf: float = tentative_g + CellUtil.heuristic(neighbor, end_cell) * 1.2
                    f_score[nkey] = nf
                    if not open_lookup.has(nkey):
                        var nstate := Vector3i(neighbor.x, neighbor.y, nl)
                        _heap_push(open_heap, neighbor, nf, neighbor_height, nstate)
                        open_lookup[nkey] = true

    return _path_or_fallback_states(came_from, start_key, best_state, terrain)


static func _key_of_state(state: Vector3i) -> int:
    return CellUtil.cell_level_key(Vector2i(state.x, state.y), state.z)


static func _reconstruct_path_states(
    came_from: Dictionary, goal_state: Vector3i, start_key: int, terrain: Node
) -> Dictionary:
    var states: Array[Vector3i] = [goal_state]
    var key: int = _key_of_state(goal_state)
    while came_from.has(key):
        var prev: Vector3i = came_from[key]
        states.push_front(prev)
        key = _key_of_state(prev)

    if states.size() > 1 and _key_of_state(states[0]) == start_key:
        states.remove_at(0)

    var path := PackedVector3Array()
    var levels := PackedInt32Array()
    for state in states:
        var cell := Vector2i(state.x, state.y)
        var level: int = state.z
        var world: Vector3 = CellUtil.cell_to_world(cell)
        if terrain and terrain.has_method("get_cell_surface_height"):
            world.y = terrain.get_cell_surface_height(cell, level)
        path.append(world)
        levels.append(level)
    return {"path": path, "levels": levels}


static func _path_or_fallback_states(
    came_from: Dictionary, start_key: int, best_state: Vector3i, terrain: Node
) -> Dictionary:
    if _key_of_state(best_state) == start_key:
        return {"path": PackedVector3Array(), "levels": PackedInt32Array()}
    return _reconstruct_path_states(came_from, best_state, start_key, terrain)


static func _heap_push(
    heap: Array, cell: Vector2i, f: float, height: float, state: Vector3i
) -> void:
    heap.append({"cell": cell, "level": state.z, "f": f, "height": height, "state": state})
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
