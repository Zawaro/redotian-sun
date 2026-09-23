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


## Per-level sub-slot offsets for a cell. `level` is mixed into the seed so the
## same cell at different surface levels gets an independent place-set; level 0
## is byte-identical to the pre-level result (`level * prime` XORs to nothing).
## Callers that only know the cell keep passing `(cell, slot_count)`.
static func get_sub_positions(
    cell: Vector2i, slot_count: int = -1, level: int = 0
) -> Array[Vector3]:
    var count: int = maxi(get_slot_count() if slot_count < 0 else slot_count, 1)
    var seed_val := _hash_cell(cell) ^ (level * 0x9E3779B1)
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


## World position of a cell's `slot` at `level`. Level 0 is cell-center plus the
## in-plane offset exactly as before; a deck level (level > 0) is raised to that
## surface's walkable world Y so a deck unit books a place on the deck, not the
## ground beneath it.
static func get_sub_position(
    cell: Vector2i, slot: int, slot_count: int = -1, level: int = 0
) -> Vector3:
    var positions := get_sub_positions(cell, slot_count, level)
    var result := CellUtil.cell_to_world(cell) + positions[clampi(slot, 0, positions.size() - 1)]
    if level > 0:
        var terrain := _resolve_terrain()
        if terrain and terrain.has_method("get_cell_surface_height"):
            result.y = terrain.get_cell_surface_height(cell, level)
    return result


## TerrainSystem autoload, or null in editor/headless contexts without it. Resolved
## lazily so level-0 placement never touches the scene tree.
static func _resolve_terrain() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    if not tree:
        return null
    return tree.root.get_node_or_null("TerrainSystem")
