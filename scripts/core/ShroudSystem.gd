extends Node

## Authoritative per-player fog-of-war grid — shroud / fog / visible.
## Simulation-only. Rendering and VisionComponent wiring are follow-up work.

signal state_changed(dirty: PackedInt32Array)

const STATE_SHROUD: int = 0
const STATE_FOG: int = 1
const STATE_VISIBLE: int = 2

const RESOLVE_INTERVAL: float = 0.25
const GROWTH_NEIGHBORS: Array[Vector2i] = [
    Vector2i(1, 0),
    Vector2i(-1, 0),
    Vector2i(0, 1),
    Vector2i(0, -1),
]

var _grid_size: Vector2i = Vector2i.ZERO
var _cell_count: int = 0
var _states: Dictionary = {}
var _temp_reveals: Array[Dictionary] = []
var _revealer_seq: int = 0
var _max_height_delta: float = 0.6
var _time: float = 0.0
var _resolve_timer: float = 0.0
var _growth_timer: float = 0.0

var _terrain: Node = null
var _team_cache: Dictionary = {}
var _emit_touched := PackedByteArray()


func _ready() -> void:
    _terrain = get_node_or_null("/root/TerrainSystem")
    if _terrain:
        _max_height_delta = TerrainSystem.HEIGHT_STEP * 0.75
        if not _terrain.grid_initialized.is_connected(_on_grid_initialized):
            _terrain.grid_initialized.connect(_on_grid_initialized)
        _init_grid(_terrain.grid_cells)


func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _time += delta
    _resolve_timer -= delta
    if _resolve_timer <= 0.0:
        _resolve_timer = RESOLVE_INTERVAL
        resolve_dirty()
    _tick_temp_reveals()
    _tick_growth(delta)


func _init_grid(grid_cells: Vector2i) -> void:
    # The terrain cell index space is the inscribed diamond, whose extent is
    # W+H cells per axis (e.g. grid_cells 50x50 -> cells 0..99). Sizing to the
    # raw grid_cells would track only the SW quadrant of the map.
    _grid_size = CellUtil.get_diamond_extent(grid_cells)
    _cell_count = _grid_size.x * _grid_size.y
    # Grid changes wipe all per-player state, including revealer registrations.
    # Unregistering a stale key afterwards is therefore a safe no-op — counts can
    # never leak from a grid that no longer exists.
    _states.clear()
    _temp_reveals.clear()
    _revealer_seq = 0
    _team_cache.clear()


func _on_grid_initialized() -> void:
    _terrain = get_node_or_null("/root/TerrainSystem")
    if _terrain:
        _init_grid(_terrain.grid_cells)


# ========================================
# Revealer registration
# ========================================


func register_revealer(
    player_id: int,
    center_cell: Vector2i,
    radius: int,
    viewer_height: float = 0.0,
    blocks_terrain: bool = true,
) -> int:
    _revealer_seq += 1
    var st := _state(player_id)
    st["revealers"][_revealer_seq] = {
        "center": center_cell,
        "radius": radius,
        "viewer_height": viewer_height,
        "blocks_terrain": blocks_terrain,
    }
    _stamp_reveal(st, center_cell, radius, viewer_height, blocks_terrain, 1)
    return _revealer_seq


func unregister_revealer(player_id: int, key: int) -> void:
    if not _states.has(player_id):
        return
    var st: Dictionary = _states[player_id]
    if not (st["revealers"] as Dictionary).has(key):
        return
    var info: Dictionary = (st["revealers"] as Dictionary)[key]
    (st["revealers"] as Dictionary).erase(key)
    _stamp_reveal(
        st,
        info["center"] as Vector2i,
        info["radius"] as int,
        info["viewer_height"] as float,
        info["blocks_terrain"] as bool,
        -1,
    )


func _stamp_reveal(
    st: Dictionary,
    center_cell: Vector2i,
    radius: int,
    viewer_height: float,
    blocks_terrain: bool,
    delta: int,
) -> void:
    if _cell_count <= 0 or _cell_index(center_cell) < 0:
        return
    var explored: PackedByteArray = st["explored"]
    var visible_count: PackedInt32Array = st["visible_count"]
    for cell in _shadowcast_cells(center_cell, radius, viewer_height, blocks_terrain):
        var idx := _cell_index(cell)
        if idx < 0 or not _revealable(cell):
            continue
        visible_count[idx] = maxi(visible_count[idx] + delta, 0)
        if delta > 0 and explored[idx] == 0:
            explored[idx] = 1
        _mark_dirty(st, idx)


# ========================================
# Shadowcasting (per-cell Bresenham LOS)
# ========================================


func _shadowcast_cells(
    center_cell: Vector2i,
    radius: int,
    viewer_height: float,
    blocks_terrain: bool,
) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    if radius < 0:
        return out
    out.append(center_cell)
    for dx in range(-radius, radius + 1):
        for dy in range(-radius, radius + 1):
            if dx == 0 and dy == 0:
                continue
            # Euclidean disc: sight is radial, not a Chebyshev square.
            if dx * dx + dy * dy > radius * radius:
                continue
            var candidate := center_cell + Vector2i(dx, dy)
            if not _cell_reachable(center_cell, candidate, viewer_height, blocks_terrain):
                continue
            out.append(candidate)
    return out


func _cell_reachable(
    from_cell: Vector2i,
    to_cell: Vector2i,
    viewer_height: float,
    blocks_terrain: bool,
) -> bool:
    if _cell_index(to_cell) < 0 or not _revealable(to_cell):
        return false
    if not blocks_terrain:
        return true
    # Walk the line in place, early-exiting at the first blocker — no per-cell
    # Array allocation on the 60Hz re-stamp path. Endpoints are never checked:
    # from_cell is the viewer's own cell and to_cell is the destination.
    var x0: int = from_cell.x
    var y0: int = from_cell.y
    var x1: int = to_cell.x
    var y1: int = to_cell.y
    var dx: int = absi(x1 - x0)
    var dy: int = -absi(y1 - y0)
    var sx: int = 1 if x0 < x1 else -1
    var sy: int = 1 if y0 < y1 else -1
    var err: int = dx + dy
    while x0 != x1 or y0 != y1:
        var e2: int = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
        if x0 == x1 and y0 == y1:
            break
        if _cell_blocks(Vector2i(x0, y0), viewer_height):
            return false
    return true


func _cell_blocks(cell: Vector2i, viewer_height: float) -> bool:
    if _terrain and _terrain.get_cell_max_height(cell) > viewer_height + _max_height_delta:
        return true
    return false


# ========================================
# Queries
# ========================================


func is_visible(player_id: int, cell: Vector2i) -> bool:
    var idx := _cell_index(cell)
    if idx < 0 or not _revealable(cell):
        return false
    for pid in _allied_player_ids(player_id):
        if not _states.has(pid):
            continue
        var visible_count: PackedInt32Array = _states[pid]["visible_count"]
        if visible_count[idx] > 0:
            return true
    return false


func is_explored(player_id: int, cell: Vector2i) -> bool:
    var idx := _cell_index(cell)
    if idx < 0 or not _revealable(cell):
        return false
    for pid in _allied_player_ids(player_id):
        if not _states.has(pid):
            continue
        var explored: PackedByteArray = _states[pid]["explored"]
        if explored[idx] == 1:
            return true
    return false


func is_cell_visible_to_local(cell: Vector2i) -> bool:
    var local := PlayerManager.get_local_player_id()
    if is_visible(local, cell):
        return true
    if not is_explored(local, cell):
        return not is_shroud_enabled()
    return not is_fog_enabled()


## Reveal gate for an entity's render + command targeting. Buildings are
## revealed when ANY foundation cell has ever been explored (persists in fog);
## with shroud off every building is revealed. Non-buildings keep the single
## collapsed-cell gate so units still follow the shroud/fog toggle semantics.
func is_entity_revealed_to_local(entity: Node3D) -> bool:
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    if stats == null or stats.entity_type != EntityData.EntityType.BUILDING:
        return is_cell_visible_to_local(CellUtil.world_to_cell(entity.global_position))
    var foundation := Vector2i(1, 1)
    var fc := entity.get_node_or_null("FoundationComponent") as FoundationComponent
    if fc != null:
        foundation = fc.foundation
    var origin := CellUtil.world_to_cell_origin(entity.global_position, foundation)
    var local := PlayerManager.get_local_player_id()
    for dx in foundation.x:
        for dz in foundation.y:
            if is_explored(local, origin + Vector2i(dx, dz)):
                return true
    return not is_shroud_enabled()


func is_shroud_enabled() -> bool:
    var rules := GlobalRules.get_current()
    return rules != null and rules.shroud_enabled


func is_fog_enabled() -> bool:
    var rules := GlobalRules.get_current()
    return rules != null and rules.fog_of_war


func get_explored_percentage(player_id: int) -> float:
    if _cell_count <= 0:
        return 0.0
    var total := 0
    var explored_count := 0
    for x in _grid_size.x:
        for y in _grid_size.y:
            var cell := Vector2i(x, y)
            if not _revealable(cell):
                continue
            total += 1
            if is_explored(player_id, cell):
                explored_count += 1
    if total == 0:
        return 0.0
    return float(explored_count) / float(total)


func get_effective_state(local_player: int) -> PackedByteArray:
    var out := PackedByteArray()
    if _cell_count <= 0:
        return out
    out.resize(_cell_count)
    var team_ids := _allied_player_ids(local_player)
    for x in _grid_size.x:
        for y in _grid_size.y:
            var idx := _cell_index(Vector2i(x, y))
            if idx < 0 or not _revealable(Vector2i(x, y)):
                out[idx] = STATE_SHROUD
                continue
            var state := STATE_SHROUD
            for pid in team_ids:
                if not _states.has(pid):
                    continue
                var st: Dictionary = _states[pid]
                var explored: PackedByteArray = st["explored"]
                if explored[idx] == 0:
                    continue
                var visible_count: PackedInt32Array = st["visible_count"]
                if visible_count[idx] > 0:
                    state = STATE_VISIBLE
                    break
                state = STATE_FOG
            out[idx] = state
    return out


## Merged effective state for a single cell index, used by the renderer's
## incremental bake on the dirty cells emitted with `state_changed`. Matches
## `get_effective_state` per-cell semantics: STATE_SHROUD when no allied player
## has explored the cell.
func get_cell_effective_state(local_player: int, idx: int) -> int:
    if idx < 0 or idx >= _cell_count:
        return STATE_SHROUD
    var state := STATE_SHROUD
    for pid in _allied_player_ids(local_player):
        if not _states.has(pid):
            continue
        var st: Dictionary = _states[pid]
        var explored: PackedByteArray = st["explored"]
        if explored[idx] == 0:
            continue
        var visible_count: PackedInt32Array = st["visible_count"]
        if visible_count[idx] > 0:
            return STATE_VISIBLE
        state = STATE_FOG
    return state


# ========================================
# Exploration (triggers / reveals)
# ========================================


func explore_all(player_id: int) -> void:
    if _cell_count <= 0:
        return
    var st := _state(player_id)
    var explored: PackedByteArray = st["explored"]
    for x in _grid_size.x:
        for y in _grid_size.y:
            var cell := Vector2i(x, y)
            if not _revealable(cell):
                continue
            var idx := _cell_index(cell)
            if idx < 0:
                continue
            if explored[idx] == 0:
                explored[idx] = 1
            _mark_dirty(st, idx)


func explore_area(player_id: int, center_cell: Vector2i, radius: int) -> void:
    if radius < 0 or _cell_count <= 0:
        return
    _stamp_explored(_state(player_id), center_cell, radius)


func reveal_area(player_id: int, center_cell: Vector2i, radius: int, duration: float) -> void:
    var key := register_revealer(player_id, center_cell, radius, 0.0, false)
    _temp_reveals.append(
        {"player_id": player_id, "key": key, "expires": _time + maxf(duration, 0.0)}
    )


## Covers the player's shroud: all explored cells revert to unexplored (shroud),
## except cells currently within the sight radius of any allied/own revealer,
## which are re-explored in place. Visible counts are left untouched — active
## revealers keep those cells visible.
func cover_shroud(player_id: int) -> void:
    if _cell_count <= 0:
        return
    for pid in _allied_player_ids(player_id):
        if not _states.has(pid):
            continue
        var st := _state(pid)
        var explored: PackedByteArray = st["explored"]
        explored.fill(0)
        for key in st["revealers"]:
            var info: Dictionary = (st["revealers"] as Dictionary)[key]
            _stamp_explored(st, info["center"] as Vector2i, info["radius"] as int)
        for x in _grid_size.x:
            for y in _grid_size.y:
                var idx := _cell_index(Vector2i(x, y))
                if idx >= 0:
                    _mark_dirty(st, idx)
    resolve_dirty()


## Marks the cells within a revealer's radius as explored without touching
## visible counts (unlike `_stamp_reveal`). Uses air-style shadowcasting so
## terrain cannot re-shroud already-sighted cells during a cover.
func _stamp_explored(st: Dictionary, center_cell: Vector2i, radius: int) -> void:
    var explored: PackedByteArray = st["explored"]
    for cell in _shadowcast_cells(center_cell, radius, 0.0, false):
        var idx := _cell_index(cell)
        if idx < 0 or not _revealable(cell):
            continue
        if explored[idx] == 0:
            explored[idx] = 1
        _mark_dirty(st, idx)


func _tick_temp_reveals() -> void:
    var expired: Array[Dictionary] = []
    for entry in _temp_reveals:
        if _time >= entry["expires"]:
            unregister_revealer(entry["player_id"], entry["key"])
            expired.append(entry)
    for entry in expired:
        _temp_reveals.erase(entry)


# ========================================
# Shroud growth
# ========================================


func _tick_growth(delta: float) -> void:
    var rules := GlobalRules.get_current()
    if not rules or not rules.shroud_grows:
        _growth_timer = 0.0
        return
    _growth_timer -= delta
    if _growth_timer > 0.0:
        return
    _growth_timer = maxf(rules.shroud_growth_interval, 0.0)
    for player_id in _states:
        _grow_shroud(_states[player_id])


func _grow_shroud(st: Dictionary) -> void:
    var explored: PackedByteArray = st["explored"]
    var visible_count: PackedInt32Array = st["visible_count"]
    var revert: Array[int] = []
    for x in _grid_size.x:
        for y in _grid_size.y:
            var cell := Vector2i(x, y)
            var idx := _cell_index(cell)
            if idx < 0 or not _revealable(cell):
                continue
            if explored[idx] == 0 or visible_count[idx] > 0:
                continue
            if _has_shroud_neighbor(cell, explored):
                revert.append(idx)
    for idx in revert:
        explored[idx] = 0
        _mark_dirty(st, idx)


func _has_shroud_neighbor(cell: Vector2i, explored: PackedByteArray) -> bool:
    for offset in GROWTH_NEIGHBORS:
        var neighbor := cell + offset
        var idx := _cell_index(neighbor)
        if idx < 0 or not _revealable(neighbor):
            return true
        if explored[idx] == 0:
            return true
    return false


# ========================================
# Incremental resolution
# ========================================


func resolve_dirty() -> int:
    var processed := 0
    var local_player := PlayerManager.get_local_player_id()
    var allied := _allied_player_ids(local_player)
    if _emit_touched.size() != _cell_count:
        _emit_touched.resize(_cell_count)
        _emit_touched.fill(0)
    else:
        _emit_touched.fill(0)
    var emit_dirty := PackedInt32Array()
    for player_id in _states:
        var st: Dictionary = _states[player_id]
        var dirty: Array = st["dirty"]
        if dirty.is_empty():
            continue
        var is_allied := allied.has(player_id)
        var touched: PackedByteArray = st["touched"]
        var resolved: PackedByteArray = st["resolved"]
        var explored: PackedByteArray = st["explored"]
        var visible_count: PackedInt32Array = st["visible_count"]
        for idx in dirty:
            touched[idx] = 0
            if explored[idx] == 0:
                resolved[idx] = STATE_SHROUD
            elif visible_count[idx] > 0:
                resolved[idx] = STATE_VISIBLE
            else:
                resolved[idx] = STATE_FOG
            processed += 1
            # Only cells whose change can affect the local player's merged view
            # (allied players) reach the renderer's incremental bake.
            if is_allied and _emit_touched[idx] == 0:
                _emit_touched[idx] = 1
                emit_dirty.append(idx)
        dirty.clear()
    if processed > 0:
        state_changed.emit(emit_dirty)
    return processed


# ========================================
# Helpers
# ========================================


func _state(player_id: int) -> Dictionary:
    if not _states.has(player_id):
        var explored := PackedByteArray()
        var visible_count := PackedInt32Array()
        var resolved := PackedByteArray()
        var touched := PackedByteArray()
        explored.resize(_cell_count)
        visible_count.resize(_cell_count)
        resolved.resize(_cell_count)
        touched.resize(_cell_count)
        var st := {
            "explored": explored,
            "visible_count": visible_count,
            "resolved": resolved,
            "touched": touched,
            "dirty": [],
            "revealers": {},
        }
        _states[player_id] = st
    return _states[player_id]


func _allied_player_ids(player_id: int) -> Array[int]:
    var cached: Dictionary = _team_cache.get(player_id, {})
    if not cached.is_empty() and _team_cache_valid(cached):
        return cached["ids"]
    var data := PlayerManager.get_player_data(player_id)
    var ids: Array[int] = []
    var teams: Array[int] = []
    for p in PlayerManager.get_players_by_team(data.team_id):
        ids.append(p.player_id)
        teams.append(p.team_id)
    _team_cache[player_id] = {"ids": ids, "teams": teams}
    return ids


## Live-validates a cached allied team so direct team_id mutations (tests,
## rare runtime re-teams) are picked up without an allocation on the hot path.
func _team_cache_valid(cached: Dictionary) -> bool:
    var ids: Array = cached["ids"]
    var teams: Array = cached["teams"]
    if ids.size() != teams.size():
        return false
    for i in ids.size():
        if PlayerManager.get_player_data(ids[i]).team_id != teams[i]:
            return false
    return true


func _revealable(cell: Vector2i) -> bool:
    return BoundsSystem.is_in_play_area(cell)


func _cell_index(cell: Vector2i) -> int:
    if cell.x < 0 or cell.y < 0 or cell.x >= _grid_size.x or cell.y >= _grid_size.y:
        return -1
    return cell.y * _grid_size.x + cell.x


func _mark_dirty(st: Dictionary, idx: int) -> void:
    var touched: PackedByteArray = st["touched"]
    if touched[idx] == 0:
        touched[idx] = 1
        (st["dirty"] as Array).append(idx)
