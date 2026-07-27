class_name CellUtil

const CELL_SIZE: float = 2.0
const SQRT2: float = 1.41421356237
const CELL_KEY_OFFSET: int = 512


# Grid is shifted into the +XZ quadrant: cell c spans world [(c+1)*CS, (c+2)*CS],
# so its center is at (c+1.5)*CS and world_to_cell subtracts the 1-cell origin shift.
static func world_to_cell(world_pos: Vector3) -> Vector2i:
    return Vector2i(floori(world_pos.x / CELL_SIZE) - 1, floori(world_pos.z / CELL_SIZE) - 1)


static func cell_to_world(cell: Vector2i) -> Vector3:
    return Vector3((cell.x + 1.5) * CELL_SIZE, 0.0, (cell.y + 1.5) * CELL_SIZE)


static func cell_key(cell: Vector2i) -> int:
    return (cell.x + CELL_KEY_OFFSET) << 16 | (cell.y + CELL_KEY_OFFSET) & 0xFFFF


static func cell_key_str(cell: Vector2i) -> String:
    return str(cell.x) + "," + str(cell.y)


static func heuristic(a: Vector2i, b: Vector2i) -> float:
    var dx: float = abs(float(a.x - b.x))
    var dy: float = abs(float(a.y - b.y))
    return max(dx, dy) + (SQRT2 - 1.0) * min(dx, dy)


static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i) -> Vector3:
    # Footprint center; +1 is the same origin shift cell_to_world applies.
    var cx := (origin.x + footprint.x * 0.5 + 1.0) * CELL_SIZE
    var cz := (origin.y + footprint.y * 0.5 + 1.0) * CELL_SIZE
    return Vector3(cx, 0.0, cz)


static func get_max_height(origin: Vector2i, footprint: Vector2i, get_height: Callable) -> float:
    var max_h := 0.0
    for dx in footprint.x:
        for dz in footprint.y:
            var cell := origin + Vector2i(dx, dz)
            var h: float = get_height.call(cell)
            max_h = maxf(max_h, h)
    return max_h


static func spiral_first_free(center: Vector2i, max_radius: int, is_occupied: Callable) -> Vector2i:
    if not is_occupied.call(center):
        return center
    for radius in range(1, max_radius + 1):
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                if abs(dx) != radius and abs(dz) != radius:
                    continue
                var cell := center + Vector2i(dx, dz)
                if not is_occupied.call(cell):
                    return cell
    return center


static func is_in_diamond(cell: Vector2i, grid_cells: Vector2i) -> bool:
    var w: float = float(grid_cells.x)
    var h: float = float(grid_cells.y)
    if w <= 0.0 or h <= 0.0:
        return false
    var cx: float = float(cell.x) + 0.5
    var cz: float = float(cell.y) + 0.5
    # Diamond inscribed in (W+H)*CS square, tips at midpoints of square edges.
    # Vertices: (W,0), (0,W), (W+H,H), (H,W+H) in cell coords.
    # Edge constraints (derived from inward normals):
    if cx + cz < w:
        return false
    if cx - cz > w:
        return false
    if cx + cz > w + h * 2.0:
        return false
    if cx - cz < -w:
        return false
    return true


static func get_diamond_extent(grid_cells: Vector2i) -> Vector2i:
    var extent: int = maxi(grid_cells.x + grid_cells.y, 1)
    return Vector2i(extent, extent)
