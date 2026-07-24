class_name CellUtil

const CELL_SIZE: float = 2.0
const SQRT2: float = 1.41421356237
const CELL_KEY_OFFSET: int = 512


static func world_to_cell(world_pos: Vector3) -> Vector2i:
    return Vector2i(floori(world_pos.x / CELL_SIZE), floori(world_pos.z / CELL_SIZE))


static func cell_to_world(cell: Vector2i) -> Vector3:
    return Vector3((cell.x + 0.5) * CELL_SIZE, 0.0, (cell.y + 0.5) * CELL_SIZE)


static func cell_key(cell: Vector2i) -> int:
    return (cell.x + CELL_KEY_OFFSET) << 16 | (cell.y + CELL_KEY_OFFSET) & 0xFFFF


static func cell_key_str(cell: Vector2i) -> String:
    return str(cell.x) + "," + str(cell.y)


static func heuristic(a: Vector2i, b: Vector2i) -> float:
    var dx: float = abs(float(a.x - b.x))
    var dy: float = abs(float(a.y - b.y))
    return max(dx, dy) + (SQRT2 - 1.0) * min(dx, dy)


static func cell_origin_to_world(origin: Vector2i, footprint: Vector2i) -> Vector3:
    var center_x := (origin.x + footprint.x * 0.5) * CELL_SIZE
    var center_z := (origin.y + footprint.y * 0.5) * CELL_SIZE
    return Vector3(center_x, 0.0, center_z)


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
