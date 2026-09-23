extends Node

# Level-aware pathfinding: `(cell, level)` search nodes, surface-stack height
# transitions, road-costed bridge steps, under-deck ground paths, and
# `(cell, level)` cost-cache isolation. Fixtures register decks directly in the
# SpatialHash bridge registry (the group-scan rebuild is covered elsewhere).

const HEIGHT_STEP: float = 0.815

var _ts: Node = null
var _sh: Node = null


func _reset() -> void:
    if _sh:
        _sh._bridge_cells.clear()
    if _ts:
        _ts.init_grid(50, 50)
        _ts.clear()


func _wheel() -> Locomotor:
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "road": 1.25}
    wheel.climb_tolerance = 1
    return wheel


## Flattens a cell's 4 corners to `height` (raw steps) and invalidates the height
## snapshot so the direct `_vertex_grid` write is visible.
func _flatten(cell: Vector2i, height: int) -> void:
    for vx in [cell.x, cell.x + 1]:
        for vz in [cell.y, cell.y + 1]:
            _ts._vertex_grid[vx][vz] = height
    _ts.invalidate_height_snapshot()


## Registers a live deck surface at `level` with the given world height.
func _register_deck(cell: Vector2i, level: int, surface_height: float) -> void:
    _sh._bridge_cells[CellUtil.cell_level_key(cell, level)] = {
        "surface_height": surface_height,
        "is_end": false,
        "piece_id": "piece_%d" % level,
        "level": level,
    }


func _path_has_cell(path: PackedVector3Array, cell: Vector2i) -> bool:
    for wp in path:
        if CellUtil.world_to_cell(wp) == cell:
            return true
    return false


func _path_has_level(detailed: Dictionary, level: int) -> bool:
    for lvl in detailed["levels"]:
        if int(lvl) == level:
            return true
    return false


func test_path_crosses_level_one_deck_over_water() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset()
    var shore_a := Vector2i(24, 25)
    var water := Vector2i(25, 25)
    var shore_b := Vector2i(26, 25)
    # Flatten a three-cell corridor and paint the middle cell water.
    for cell: Vector2i in [shore_a, water, shore_b]:
        _flatten(cell, 0)
    _ts.set_land_type(water, "water")
    var start := CellUtil.cell_to_world(shore_a)
    var end := CellUtil.cell_to_world(shore_b)
    var wheel := _wheel()

    var no_deck: PackedVector3Array = Pathfinder.find_path(start, end, {}, wheel)
    TestHelper.assert_true(
        not _path_has_cell(no_deck, water), "uncovered water is not crossed by a wheeled unit"
    )

    # Low deck at level 1, at the ground grade: the only way across.
    _register_deck(water, 1, 0.0)
    var with_deck := Pathfinder.find_path_detailed(start, end, {}, wheel, false, null, _ts, 0, 0)
    TestHelper.assert_true(
        with_deck["path"].size() > 0, "a level-1 deck gives the wheeled unit a crossing"
    )
    TestHelper.assert_true(
        _path_has_cell(with_deck["path"], water), "wheeled path crosses the deck cell"
    )
    TestHelper.assert_true(
        _path_has_level(with_deck, 1), "the crossing waypoint reports the deck level"
    )
    _ts.set_land_type(water, "clear")
    _reset()


func test_wheeled_paths_under_high_deck_on_ground() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset()
    var shore_a := Vector2i(24, 25)
    var under := Vector2i(25, 25)
    var shore_b := Vector2i(26, 25)
    for cell: Vector2i in [shore_a, under, shore_b]:
        _flatten(cell, 0)
    # A high deck four steps above the passable ground; it must not block level 0.
    _register_deck(under, 1, 4.0 * HEIGHT_STEP)
    var detailed: Dictionary = Pathfinder.find_path_detailed(
        CellUtil.cell_to_world(shore_a),
        CellUtil.cell_to_world(shore_b),
        {},
        _wheel(),
        false,
        null,
        _ts,
        0,
        0
    )
    var path: PackedVector3Array = detailed["path"]
    TestHelper.assert_true(path.size() > 0, "ground path under a high deck exists")
    TestHelper.assert_true(_path_has_cell(path, under), "ground path uses the under-deck cell")
    # Every waypoint over the under-deck cell is at ground level.
    for i in path.size():
        if CellUtil.world_to_cell(path[i]) == under:
            TestHelper.assert_eq(int(detailed["levels"][i]), 0, "under-deck waypoint stays level 0")
            TestHelper.assert_true(
                is_equal_approx(path[i].y, 0.0), "under-deck waypoint Y is the ground surface"
            )
    _reset()


func test_base_grade_cannot_climb_four_level_deck() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset()
    var base := Vector2i(25, 25)
    var deck_cell := Vector2i(25, 26)
    _flatten(base, 0)
    _flatten(deck_cell, 0)
    _register_deck(deck_cell, 1, 4.0 * HEIGHT_STEP)
    var wheel := _wheel()
    var refused: Dictionary = Pathfinder.try_greedy_step_detailed(
        base, deck_cell, {}, wheel, Pathfinder.GREEDY_STALL, null, _ts, 0, 1
    )
    TestHelper.assert_eq(
        refused["cell"], Pathfinder.GREEDY_STALL, "base grade cannot climb the +4 deck"
    )
    # Matching grade: raise the base cell to the deck grade and retry.
    _flatten(base, 4)
    var allowed: Dictionary = Pathfinder.try_greedy_step_detailed(
        base, deck_cell, {}, wheel, Pathfinder.GREEDY_STALL, null, _ts, 0, 1
    )
    TestHelper.assert_eq(allowed["cell"], deck_cell, "matching-grade ground admits the deck")
    TestHelper.assert_eq(int(allowed["level"]), 1, "the step lands on the deck level")
    _reset()


func test_bridge_step_costed_from_road_row() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset()
    var base := Vector2i(25, 25)
    var deck_cell := Vector2i(25, 26)
    _flatten(base, 0)
    _flatten(deck_cell, 0)
    # The deck lane resolves road, so the step is costed from the Road row
    # (2.0 -> cost 0.5), never the underlying terrain figure.
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "road": 2.0}
    wheel.climb_tolerance = 1
    _register_deck(deck_cell, 1, 0.0)
    var trans: Dictionary = Pathfinder._evaluate_transition(
        _ts, wheel, 0.0, base, 0, deck_cell, 1, wheel.climb_tolerance * HEIGHT_STEP, false, null
    )
    TestHelper.assert_true(trans["allowed"], "matching-grade deck step is allowed")
    TestHelper.assert_true(
        is_equal_approx(float(trans["cost_multiplier"]), 0.5),
        "deck step uses the Road multiplier (2.0 -> 0.5), not the ground figure"
    )
    _reset()


func test_cost_cache_is_isolated_per_level() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _reset()
    var cell := Vector2i(25, 25)
    _flatten(cell, 1)
    var deck: float = 4.0 * HEIGHT_STEP
    _register_deck(cell, 1, deck)
    TestHelper.assert_true(
        CellUtil.cell_level_key(cell, 0) != CellUtil.cell_level_key(cell, 1),
        "level keys are distinct"
    )
    var cache := Pathfinder.PathCostCache.new()
    var ground: Dictionary = Pathfinder._cell_cost(_ts, cell, 0, cache)
    var deck_cost: Dictionary = Pathfinder._cell_cost(_ts, cell, 1, cache)
    TestHelper.assert_true(
        is_equal_approx(float(ground["height"]), 1.0 * HEIGHT_STEP),
        "ground node height is the terrain, not the deck"
    )
    TestHelper.assert_true(
        is_equal_approx(float(deck_cost["height"]), deck), "deck node height is the deck"
    )
    TestHelper.assert_eq(ground["land"], "clear", "ground node keeps its land")
    TestHelper.assert_eq(deck_cost["land"], "road", "deck node resolves the deck land")
    TestHelper.assert_true(
        not is_equal_approx(float(ground["height"]), float(deck_cost["height"])),
        "the two levels never collide in the cache"
    )
    _reset()


func test_find_path_detailed_defaults_to_ground() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _reset()
    var wheel := _wheel()
    var detailed: Dictionary = Pathfinder.find_path_detailed(
        CellUtil.cell_to_world(Vector2i(20, 20)),
        CellUtil.cell_to_world(Vector2i(24, 24)),
        {},
        wheel
    )
    for lvl in detailed["levels"]:
        TestHelper.assert_eq(int(lvl), 0, "a default search stays on the ground level")
    _reset()
