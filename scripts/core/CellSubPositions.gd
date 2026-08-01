class_name CellSubPositions

const MARGIN: float = 0.15
const NUM_SLOTS: int = 3


## Resolves the per-cell shared-slot count: the GlobalRules value when rules are
## loaded, otherwise the NUM_SLOTS default (tests run without autoloads).
static func get_slot_count() -> int:
    var rules := GlobalRules.get_current()
    if rules and rules.shared_slots_per_cell >= 1:
        return rules.shared_slots_per_cell
    return NUM_SLOTS


## Minimum pairwise distance between sub-positions for a slot count. Chord length
## between adjacent vertices of the inscribed regular polygon; scale factor 0.69
## (vs 0.7 in get_sub_positions) gives floating-point tolerance.
static func min_slot_dist(slot_count: int = -1) -> float:
    var count: int = maxi(get_slot_count() if slot_count < 0 else slot_count, 1)
    return 2.0 * (CellUtil.CELL_SIZE * 0.5 - MARGIN) * 0.69 * sin(TAU / count / 2.0)


static func _hash_cell(cell: Vector2i) -> int:
    var h: int = cell.x * 73856093
    h = h ^ (cell.y * 19349663)
    return h


static func _mulberry32(seed_val: int) -> Callable:
    var s: Dictionary = {"v": seed_val & 0xFFFFFFFF}
    return func() -> float:
        s["v"] = (s["v"] + 0x6D2B79F5) & 0xFFFFFFFF
        var x: int = (s["v"] ^ (s["v"] >> 15)) * (s["v"] | 1)
        x = (x ^ (x >> 7)) * (x | 61)
        return float((x ^ (x >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func get_sub_positions(cell: Vector2i, slot_count: int = -1) -> Array[Vector3]:
    var count: int = maxi(get_slot_count() if slot_count < 0 else slot_count, 1)
    var seed_val := _hash_cell(cell)
    var rng := _mulberry32(seed_val)
    var half: float = CellUtil.CELL_SIZE * 0.5
    var radius: float = (half - MARGIN) * 0.7
    var base_angle: float = rng.call() * TAU
    var positions: Array[Vector3] = []
    for i in range(count):
        var angle: float = base_angle + i * (TAU / count)
        var x: float = cos(angle) * radius
        var z: float = sin(angle) * radius
        positions.append(Vector3(x, 0.0, z))
    return positions


static func get_sub_position(cell: Vector2i, slot: int, slot_count: int = -1) -> Vector3:
    var positions := get_sub_positions(cell, slot_count)
    return CellUtil.cell_to_world(cell) + positions[clampi(slot, 0, positions.size() - 1)]
