class_name CellUtil

const CELL_SIZE: float = 2.0
const SQRT2: float = 1.41421356237
const CELL_KEY_OFFSET: int = 512


# Centered coordinate system: diamond center at world origin (0,0,0).
# cell_to_world returns coords centered at origin using (W+H)/2 offset.
# grid_cells defaults to TerrainSystem.grid_cells when omitted.
static func world_to_cell(world_pos: Vector3, grid_cells: Vector2i = Vector2i.ZERO) -> Vector2i:
    var gc := _resolve_grid_cells(grid_cells)
    var center: float = float(gc.x + gc.y) * 0.5
    var vx := floori(world_pos.x / CELL_SIZE + center)
    var vz := floori(world_pos.z / CELL_SIZE + center)
    return Vector2i(vx, vz)


static func cell_to_world(cell: Vector2i, grid_cells: Vector2i = Vector2i.ZERO) -> Vector3:
    var gc := _resolve_grid_cells(grid_cells)
    var center: float = float(gc.x + gc.y) * 0.5
    var cx := (cell.x + 0.5 - center) * CELL_SIZE
    var cz := (cell.y + 0.5 - center) * CELL_SIZE
    return Vector3(cx, 0.0, cz)


static func _resolve_grid_cells(grid_cells: Vector2i) -> Vector2i:
    if grid_cells != Vector2i.ZERO:
        return grid_cells
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if not tree:
        return Vector2i(50, 50)
    var ts: Node = tree.root.get_node_or_null("TerrainSystem")
    if ts:
        return ts.grid_cells
    return Vector2i(50, 50)


static func cell_key(cell: Vector2i) -> int:
    return (cell.x + CELL_KEY_OFFSET) << 16 | (cell.y + CELL_KEY_OFFSET) & 0xFFFF


static func cell_key_str(cell: Vector2i) -> String:
    return str(cell.x) + "," + str(cell.y)


static func heuristic(a: Vector2i, b: Vector2i) -> float:
    var dx: float = abs(float(a.x - b.x))
    var dy: float = abs(float(a.y - b.y))
    return max(dx, dy) + (SQRT2 - 1.0) * min(dx, dy)


static func cell_origin_to_world(
    origin: Vector2i, footprint: Vector2i, grid_cells: Vector2i = Vector2i.ZERO
) -> Vector3:
    var gc: Vector2i = _resolve_grid_cells(grid_cells)
    var center: float = float(gc.x + gc.y) * 0.5
    var cx: float = (origin.x + footprint.x * 0.5 - center) * CELL_SIZE
    var cz: float = (origin.y + footprint.y * 0.5 - center) * CELL_SIZE
    return Vector3(cx, 0.0, cz)


static func world_to_cell_origin(
    world_pos: Vector3, footprint: Vector2i, grid_cells: Vector2i = Vector2i.ZERO
) -> Vector2i:
    var gc: Vector2i = _resolve_grid_cells(grid_cells)
    var center: float = float(gc.x + gc.y) * 0.5
    return Vector2i(
        roundi(world_pos.x / CELL_SIZE + center - footprint.x * 0.5),
        roundi(world_pos.z / CELL_SIZE + center - footprint.y * 0.5)
    )


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
    var w: int = grid_cells.x
    var h: int = grid_cells.y
    if w <= 0 or h <= 0:
        return false
    var sum: int = cell.x + cell.y + 1
    var difference: int = cell.x - cell.y
    return sum >= w and sum < w + 2 * h and difference >= -w and difference < w


static func get_diamond_extent(grid_cells: Vector2i) -> Vector2i:
    var extent: int = maxi(grid_cells.x + grid_cells.y, 1)
    return Vector2i(extent, extent)
