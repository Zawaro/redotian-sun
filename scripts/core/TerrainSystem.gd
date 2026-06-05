extends Node

signal cell_changed(cell_key: String, cell_data: Dictionary)

const CELL_SIZE: float = 2.0
const HEIGHT_STEP: float = 0.815
const MAX_HEIGHT: int = 10
const DEFAULT_GRID_CELLS: int = 32

var grid_cells: int = DEFAULT_GRID_CELLS

var _vertex_grid: Array = []
var _cells: Dictionary = {}

var _corner_to_dir: Array[String] = ["west", "north", "south", "east"]

func _init() -> void:
    _init_vertex_grid()

func init_grid(cells: int) -> void:
    grid_cells = cells
    _init_vertex_grid()

func _init_vertex_grid() -> void:
    var v_count := grid_cells + 1
    _vertex_grid = []
    _vertex_grid.resize(v_count)
    for vx in v_count:
        var row: Array[int] = []
        row.resize(v_count)
        _vertex_grid[vx] = row

func _exit_tree() -> void:
    clear()

func clear() -> void:
    _init_vertex_grid()
    _cells.clear()

# ========================================
# Vertex API
# ========================================

func get_vertex(vx: int, vz: int) -> int:
    if vx < 0 or vx > grid_cells or vz < 0 or vz > grid_cells:
        return 0
    return _vertex_grid[vx][vz]

func set_vertex(vx: int, vz: int, height: int) -> void:
    if vx < 0 or vx > grid_cells or vz < 0 or vz > grid_cells:
        return
    _vertex_grid[vx][vz] = clampi(height, 0, MAX_HEIGHT)
    _cascade_from_vertices([Vector2i(vx, vz)])

func _set_vertex_no_cascade(vx: int, vz: int, height: int) -> void:
    _vertex_grid[vx][vz] = height

# ========================================
# Cell Painting API
# ========================================

func raise_cell(cell: Vector2i) -> void:
    var cx := cell.x
    var cz := cell.y
    if cx < 0 or cx >= grid_cells or cz < 0 or cz >= grid_cells:
        return
    var h_min := MAX_HEIGHT
    for vx in [cx, cx + 1]:
        for vz in [cz, cz + 1]:
            h_min = mini(h_min, _vertex_grid[vx][vz])
    var origins: Array[Vector2i] = []
    for vx in [cx, cx + 1]:
        for vz in [cz, cz + 1]:
            if _vertex_grid[vx][vz] == h_min and h_min < MAX_HEIGHT:
                _vertex_grid[vx][vz] += 1
                origins.append(Vector2i(vx, vz))
    if not origins.is_empty():
        _cascade_from_vertices(origins)

func lower_cell(cell: Vector2i) -> void:
    var cx := cell.x
    var cz := cell.y
    if cx < 0 or cx >= grid_cells or cz < 0 or cz >= grid_cells:
        return
    var h_max := 0
    for vx in [cx, cx + 1]:
        for vz in [cz, cz + 1]:
            h_max = maxi(h_max, _vertex_grid[vx][vz])
    var origins: Array[Vector2i] = []
    for vx in [cx, cx + 1]:
        for vz in [cz, cz + 1]:
            if _vertex_grid[vx][vz] == h_max and h_max > 0:
                _vertex_grid[vx][vz] -= 1
                origins.append(Vector2i(vx, vz))
    if not origins.is_empty():
        _cascade_from_vertices(origins)

# ========================================
# Cell Queries (from cache)
# ========================================

func get_cell(cell: Vector2i) -> Dictionary:
    var key := _cell_key(cell)
    return _cells.get(key, {})

func get_cell_at_world(world_pos: Vector3) -> Dictionary:
    var grid_half: float = float(grid_cells) * CELL_SIZE * 0.5
    var adjusted := Vector3(world_pos.x + grid_half, world_pos.y, world_pos.z + grid_half)
    var cell := Pathfinder.world_to_cell(adjusted)
    return get_cell(cell)

func get_height_at_world(world_pos: Vector3) -> float:
    var grid_half: float = float(grid_cells) * CELL_SIZE * 0.5
    var adjusted := Vector3(world_pos.x + grid_half, world_pos.y, world_pos.z + grid_half)
    var cell := Pathfinder.world_to_cell(adjusted)
    var data := get_cell(cell)
    if data.is_empty():
        return 0.0
    return data.get("height", 0) * HEIGHT_STEP

func get_height_at_world_smooth(world_pos: Vector3) -> float:
    var grid_half: float = float(grid_cells) * CELL_SIZE * 0.5
    var vx: float = (world_pos.x + grid_half) / CELL_SIZE
    var vz: float = (world_pos.z + grid_half) / CELL_SIZE
    var x0 := floori(vx)
    var x1 := x0 + 1
    var z0 := floori(vz)
    var z1 := z0 + 1
    var fx: float = vx - float(x0)
    var fz: float = vz - float(z0)
    var h00: float = float(get_vertex(x0, z0))
    var h10: float = float(get_vertex(x1, z0))
    var h01: float = float(get_vertex(x0, z1))
    var h11: float = float(get_vertex(x1, z1))
    var h0: float = h00 + (h10 - h00) * fx
    var h1: float = h01 + (h11 - h01) * fx
    return (h0 + (h1 - h0) * fz) * HEIGHT_STEP

func get_normal_at_world(world_pos: Vector3) -> Vector3:
    var grid_half: float = float(grid_cells) * CELL_SIZE * 0.5
    var vx: float = (world_pos.x + grid_half) / CELL_SIZE
    var vz: float = (world_pos.z + grid_half) / CELL_SIZE
    var x0 := floori(vx)
    var x1 := x0 + 1
    var z0 := floori(vz)
    var z1 := z0 + 1
    var h00: float = float(get_vertex(x0, z0)) * HEIGHT_STEP
    var h10: float = float(get_vertex(x1, z0)) * HEIGHT_STEP
    var h01: float = float(get_vertex(x0, z1)) * HEIGHT_STEP
    var edge_x := Vector3(CELL_SIZE, h10 - h00, 0.0)
    var edge_z := Vector3(0.0, h01 - h00, CELL_SIZE)
    return edge_z.cross(edge_x).normalized()

func get_all_cells() -> Dictionary:
    return _cells.duplicate()

func compute_and_emit_cell(cell: Vector2i) -> void:
    var key := _cell_key(cell)
    _cells[key] = _compute_cell_from_vertices(cell)
    cell_changed.emit(key, _cells[key])

func calculate_cell_mesh(cell: Vector2i) -> Dictionary:
    return _compute_cell_from_vertices(cell)

# ========================================
# Cascade (4-directional vertex-to-vertex)
# ========================================

func _cascade_from_vertices(origins: Array[Vector2i]) -> void:
    var queue: Array[Vector2i] = origins.duplicate()
    var visited: Dictionary = {}
    var affected_cells: Dictionary = {}

    for v in origins:
        visited[_vkey(v)] = true
        _add_cells_for_vertex(v.x, v.y, affected_cells)

    while not queue.is_empty():
        var cur: Vector2i = queue.pop_front()
        var cur_h: int = _vertex_grid[cur.x][cur.y]

        var neighbors: Array[Vector2i] = [
            Vector2i(cur.x, cur.y - 1),
            Vector2i(cur.x, cur.y + 1),
            Vector2i(cur.x - 1, cur.y),
            Vector2i(cur.x + 1, cur.y),
        ]
        for nbr in neighbors:
            var nkey := _vkey(nbr)
            if visited.has(nkey):
                continue
            visited[nkey] = true
            if nbr.x < 0 or nbr.x > grid_cells or nbr.y < 0 or nbr.y > grid_cells:
                continue

            var nbr_h: int = _vertex_grid[nbr.x][nbr.y]
            var diff: int = cur_h - nbr_h

            if diff > 1:
                _vertex_grid[nbr.x][nbr.y] = nbr_h + 1
                _add_cells_for_vertex(nbr.x, nbr.y, affected_cells)
                queue.append(nbr)
            elif diff < -1:
                _vertex_grid[nbr.x][nbr.y] = nbr_h - 1
                _add_cells_for_vertex(nbr.x, nbr.y, affected_cells)
                queue.append(nbr)

    for key in affected_cells:
        _recompute_cell(key)

    for key in affected_cells:
        var data: Dictionary = _cells.get(key, {}) as Dictionary
        if not data.is_empty():
            cell_changed.emit(key, data)

func _add_cells_for_vertex(vx: int, vz: int, cells: Dictionary) -> void:
    for cx in [vx - 1, vx]:
        if cx < 0 or cx >= grid_cells:
            continue
        for cz in [vz - 1, vz]:
            if cz < 0 or cz >= grid_cells:
                continue
            cells[_cell_key(Vector2i(cx, cz))] = true

func _recompute_cell(key: String) -> void:
    var parts: PackedStringArray = key.split(",")
    if parts.size() != 2:
        return
    var cell := Vector2i(int(parts[0]), int(parts[1]))
    _cells[key] = _compute_cell_from_vertices(cell)

# ========================================
# Cell Type From Vertices
# ========================================

func _compute_cell_from_vertices(cell: Vector2i) -> Dictionary:
    var cx := cell.x
    var cz := cell.y

    var h: Array[int] = [
        _vertex_grid[cx][cz],
        _vertex_grid[cx + 1][cz],
        _vertex_grid[cx][cz + 1],
        _vertex_grid[cx + 1][cz + 1],
    ]

    var h_min := mini(mini(h[0], h[1]), mini(h[2], h[3]))
    var h_max := maxi(maxi(h[0], h[1]), maxi(h[2], h[3]))
    var rel: Array[int] = []
    for i in 4:
        rel.append(h[i] - h_min)

    var max_rel := 0
    var raised_count := 0
    var raised_indices: Array[int] = []
    var low_index := -1
    var max_idx := 0
    for i in 4:
        if rel[i] > max_rel:
            max_rel = rel[i]
            max_idx = i
        if rel[i] > 0:
            raised_count += 1
            raised_indices.append(i)
        else:
            low_index = i

    var result: Dictionary
    if raised_count == 0:
        result = _make_clear(h_min)
    elif raised_count == 4:
        result = _make_clear(h_min + 1)
    elif max_rel >= 2:
        result = _make_slope(4, _rotate_dir_cw(_corner_to_dir[max_idx]), h_min)
    elif raised_count == 1:
        result = _make_slope(2, _corner_to_dir[raised_indices[0]], h_min)
    elif raised_count == 3:
        result = _make_slope(3, _corner_to_dir[low_index], h_min)
    else:
        var a := raised_indices[0]
        var b := raised_indices[1]
        if _is_adjacent_corners(a, b):
            result = _make_slope(1, _edge_to_dir(a, b), h_min)
        elif (a == 0 and b == 3) or (a == 3 and b == 0):
            result = _make_slope(5, "west", h_min)
        else:
            result = _make_slope(6, "east", h_min)

    result["max_height"] = h_max
    return result

func _is_adjacent_corners(a: int, b: int) -> bool:
    var pairs: Array[Array] = [
        [0, 1], [0, 2], [1, 3], [2, 3],
    ]
    for pair in pairs:
        if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
            return true
    return false

func _edge_to_dir(a: int, b: int) -> String:
    if (a == 0 and b == 1) or (a == 1 and b == 0):
        return "north"
    if (a == 0 and b == 2) or (a == 2 and b == 0):
        return "west"
    if (a == 1 and b == 3) or (a == 3 and b == 1):
        return "east"
    if (a == 2 and b == 3) or (a == 3 and b == 2):
        return "south"
    return "north"

# ========================================
# JSON Import / Export
# ========================================

func export_to_json(path: String) -> void:
    var vertices: Dictionary = {}
    var v_count := grid_cells + 1
    for vx in v_count:
        for vz in v_count:
            var h: int = _vertex_grid[vx][vz]
            if h != 0:
                vertices[_vkey(Vector2i(vx, vz))] = h

    var data: Dictionary = {
        "version": 2,
        "grid_cells": grid_cells,
        "vertices": vertices,
        "cells": _cells.duplicate(),
    }
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()

func import_from_json(path: String) -> void:
    var old_keys: Array = _cells.keys().duplicate() as Array
    for key in old_keys:
        cell_changed.emit(key, {})
    _cells.clear()
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if not file:
        return
    var json: JSON = JSON.new()
    var error: Error = json.parse(file.get_as_text())
    file.close()
    if error != OK:
        return
    var data: Variant = json.data
    if not data is Dictionary:
        return

    var json_grid_cells: int = int(data.get("grid_cells", grid_cells))
    init_grid(json_grid_cells)

    var vertices: Dictionary = data.get("vertices", {})
    for vkey in vertices:
        var parts: PackedStringArray = vkey.split(",")
        if parts.size() == 2:
            var vx := int(parts[0])
            var vz := int(parts[1])
            if vx >= 0 and vx <= grid_cells and vz >= 0 and vz <= grid_cells:
                _vertex_grid[vx][vz] = clampi(vertices[vkey], 0, MAX_HEIGHT)

    var center: float = float(grid_cells) * 0.5
    for cx in grid_cells:
        for cz in grid_cells:
            var cell_x: float = float(cx) + 0.5
            var cell_z: float = float(cz) + 0.5
            if center > 0.0:
                if absf(cell_x - center) / center + absf(cell_z - center) / center >= 1.0:
                    continue
            var key := _cell_key(Vector2i(cx, cz))
            _cells[key] = _compute_cell_from_vertices(Vector2i(cx, cz))

    for key in _cells:
        cell_changed.emit(key, _cells[key])

# ========================================
# Helpers
# ========================================

func _make_clear(height: int) -> Dictionary:
    return { "height": height, "type": "clear", "variant": 1, "direction": "", "rotation": 0.0 }

func _make_slope(variant: int, direction: String, height: int) -> Dictionary:
    return { "height": height, "type": "slope", "variant": variant, "direction": direction, "rotation": _direction_to_rotation(direction) }

func _direction_to_rotation(dir: String) -> float:
    match dir:
        "north":
            return 0.0
        "south":
            return 180.0
        "east":
            return 270.0
        "west":
            return 90.0
    return 0.0

func _rotate_dir_cw(dir: String) -> String:
    match dir:
        "north":
            return "east"
        "east":
            return "south"
        "south":
            return "west"
        "west":
            return "north"
    return "north"

func _cell_key(cell: Vector2i) -> String:
    return str(cell.x) + "," + str(cell.y)

func _vkey(v: Vector2i) -> String:
    return str(v.x) + "," + str(v.y)
