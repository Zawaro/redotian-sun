extends Node

# Stacked extra-high decks (Phase 6): multiple deck levels over one XZ, each an
# independent surface and place-set bounded by TerrainSystem.MAX_HEIGHT, plus
# level-scoped cell reservation and sub-slot placement (tasks 1.5/1.6/6.1-6.4).
#
# Fixtures are StubBridge nodes under the scene root so SpatialHash's real
# "bridge" group rebuild registers them by `(cell, level)`. Expected values are
# derived from the authored deck heights and geometry, not from the code under
# test; each scoped assertion is preceded by its unscoped control so a broken
# level key cannot pass vacuously.


class StubBridge:
    extends Node3D
    var data: Dictionary = {}

    func get_bridge_cell_data() -> Dictionary:
        return data


const MAP: Vector2i = Vector2i(50, 50)
const HEIGHT_STEP: float = 0.815

# Corridor used by the pathing tests: all three cells inside the visible diamond.
const CORRIDOR: Array[Vector2i] = [Vector2i(25, 25), Vector2i(26, 25), Vector2i(27, 25)]

var _ts: Node = null
var _sh: Node = null
var _root: Node = null
var _spawned: Array[Node3D] = []


func _ensure_root() -> void:
    if _root == null:
        _root = Engine.get_main_loop().root


func _reset() -> void:
    if _ts != null:
        _ts.init_grid(MAP.x, MAP.y)
        _ts.clear()
    if _sh != null:
        _sh._bridge_cells.clear()
        _sh._blocked_cells.clear()
        _sh._building_cells.clear()
        _sh._shared_cell_counts.clear()
        _sh._grid.clear()
        _sh.clear_reservations()
    if CellReservation.instance:
        CellReservation.instance.clear()


## Registers a live deck at `level` with the given walkable height over `cell`.
func _register(cell: Vector2i, level: int, surface_height: float) -> StubBridge:
    _ensure_root()
    var bridge := StubBridge.new()
    bridge.data = {
        "surface_height": surface_height,
        "is_end": false,
        "piece_id": "stack_%d" % level,
        "level": level,
    }
    bridge.add_to_group("bridge")
    _root.add_child(bridge)
    bridge.global_position = CellUtil.cell_to_world(cell)
    _spawned.append(bridge)
    return bridge


func _clear_fixture() -> void:
    if _root != null:
        for bridge in _spawned:
            if is_instance_valid(bridge):
                _root.remove_child(bridge)
                bridge.free()
    _spawned.clear()
    if _sh != null:
        _sh.rebuild()


## Flattens a cell's four corners to `height` raw steps and invalidates the
## height snapshot so the direct write is visible to height queries.
func _flatten(cell: Vector2i, height: int) -> void:
    for vx in [cell.x, cell.x + 1]:
        for vz in [cell.y, cell.y + 1]:
            _ts._vertex_grid[vx][vz] = height
    _ts.invalidate_height_snapshot()


func _wheel() -> Locomotor:
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "road": 1.25, "bridge": 1.25}
    wheel.climb_tolerance = 1
    return wheel


func _path_states(detailed: Dictionary) -> Array[Vector3i]:
    var states: Array[Vector3i] = []
    var path: PackedVector3Array = detailed["path"]
    var levels: PackedInt32Array = detailed["levels"]
    for i in path.size():
        var cell := CellUtil.world_to_cell(path[i])
        states.append(Vector3i(cell.x, cell.y, levels[i]))
    return states


## Task 6.1/6.3: two decks at levels 1 and 2 over one cell expose both levels,
## each resolving its own surface Y, over the ground.
func test_two_decks_over_one_cell_levels_and_heights() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear_fixture()
    _reset()
    var cell := Vector2i(30, 30)
    TestHelper.assert_true(CellUtil.is_in_diamond(cell, MAP), "fixture cell is inside the map")
    _flatten(cell, 0)

    # Control: with no deck, the cell exposes ground only.
    TestHelper.assert_eq(_sh.get_bridge_levels(cell).size(), 0, "control: no decks initially")
    TestHelper.assert_eq(_ts.get_cell_surface_levels(cell), [0], "control: ground-only stack")

    var lower := 3.0
    var upper := 6.0
    _register(cell, 1, lower)
    _register(cell, 2, upper)
    _sh.rebuild()

    var levels: Array[int] = _sh.get_bridge_levels(cell)
    TestHelper.assert_eq(levels.size(), 2, "two deck levels registered")
    if levels.size() == 2:
        TestHelper.assert_eq(levels[0], 1, "lowest deck is level 1")
        TestHelper.assert_eq(levels[1], 2, "upper deck is level 2")
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 1), lower), "level 1 resolves its Y"
    )
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_surface_height(cell, 2), upper), "level 2 resolves its Y"
    )
    (
        TestHelper
        . assert_true(
            not is_equal_approx(
                _ts.get_cell_surface_height(cell, 1), _ts.get_cell_surface_height(cell, 2)
            ),
            "the two decks have different surface heights",
        )
    )
    TestHelper.assert_eq(_ts.get_cell_surface_levels(cell), [0, 1, 2], "ground plus both decks")
    (
        TestHelper
        . assert_true(
            is_equal_approx(_ts.get_cell_surface_height(cell, 0), 0.0),
            "level 0 keeps the ground surface beneath the stack",
        )
    )
    _clear_fixture()


## Task 6.3: a unit on level 2 must not consume level 1's or level 0's places.
## Ground/level-1/level-2 place-sets are independent for both physical idle
## sharers (SpatialHash) and in-flight claims (CellReservation).
func test_upper_deck_places_do_not_consume_lower_levels() -> void:
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _clear_fixture()
    _reset()
    var cell := Vector2i(31, 31)
    var slots: int = CellSubPositions.get_slot_count()

    # Physical idle sharers counted at level 2 only.
    _sh._shared_cell_counts[CellUtil.cell_level_key(cell, 2)] = slots
    TestHelper.assert_eq(_sh.get_shared_cell_count(cell, 2), slots, "level 2 holds its occupants")
    TestHelper.assert_true(_sh.is_cell_full_for_shared(cell, 2), "level 2 is full")
    TestHelper.assert_eq(
        _sh.get_shared_cell_count(cell, 1), 0, "level 1 stays empty beneath level 2 occupancy"
    )
    TestHelper.assert_eq(
        _sh.get_shared_cell_count(cell, 0), 0, "level 0 stays empty beneath level 2 occupancy"
    )
    TestHelper.assert_true(
        not _sh.is_cell_full_for_shared(cell, 1), "level 1 is not full while level 2 is full"
    )
    TestHelper.assert_true(
        not _sh.is_cell_full_for_shared(cell, 0), "level 0 is not full while level 2 is full"
    )
    _sh._shared_cell_counts.clear()

    # In-flight sub-slot claims at level 2 only.
    var cr := CellReservation.instance
    if cr == null:
        TestHelper.fail("CellReservation not available")
        return
    cr.clear()
    var owners: Array[Node3D] = []
    for i in slots:
        var owner := Node3D.new()
        add_child(owner)
        owners.append(owner)
        cr.reserve_sub_slot(cell, owner, -1, 2)
    TestHelper.assert_eq(cr.get_claim_count(cell, 2), slots, "level 2 claims are counted")
    TestHelper.assert_true(cr.is_cell_full(cell, 2), "level 2 is full from claims")
    TestHelper.assert_eq(cr.get_claim_count(cell, 1), 0, "level 1 claims untouched")
    TestHelper.assert_eq(cr.get_claim_count(cell, 0), 0, "level 0 claims untouched")
    TestHelper.assert_eq(cr.get_available_sub_slot(cell, 1), 0, "level 1 has a free sub-slot")
    TestHelper.assert_eq(cr.get_available_sub_slot(cell, 0), 0, "level 0 has a free sub-slot")
    cr.clear()
    for owner in owners:
        owner.free()


## Task 1.6: the same cell's sub-slot sets are independent per level, and a deck
## slot uses the deck surface Y while level 0 keeps the pre-level ground position.
func test_sub_slots_are_level_scoped() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear_fixture()
    _reset()
    var cell := Vector2i(32, 32)
    _flatten(cell, 0)
    var deck_y := 4.0 * HEIGHT_STEP
    _register(cell, 1, deck_y)
    _sh.rebuild()

    var ground: Array[Vector3] = CellSubPositions.get_sub_positions(cell, -1, 0)
    var deck: Array[Vector3] = CellSubPositions.get_sub_positions(cell, -1, 1)
    TestHelper.assert_eq(ground.size(), deck.size(), "both levels expose the same slot count")
    var differ := false
    for i in ground.size():
        if not ground[i].is_equal_approx(deck[i]):
            differ = true
            break
    TestHelper.assert_true(differ, "level-1 offsets differ from the ground offsets")

    var ground_pos: Vector3 = CellSubPositions.get_sub_position(cell, 0, -1, 0)
    var deck_pos: Vector3 = CellSubPositions.get_sub_position(cell, 0, -1, 1)
    (
        TestHelper
        . assert_true(
            is_equal_approx(ground_pos.y, CellUtil.cell_to_world(cell).y),
            "level 0 sub-slot keeps the pre-level ground Y",
        )
    )
    (
        TestHelper
        . assert_true(
            is_equal_approx(deck_pos.y, _ts.get_cell_surface_height(cell, 1)),
            "level 1 sub-slot sits on the deck surface Y",
        )
    )
    (
        TestHelper
        . assert_true(
            not is_equal_approx(deck_pos.y, ground_pos.y),
            "deck sub-slot Y differs from the ground sub-slot Y",
        )
    )
    _clear_fixture()


## Task 1.5: reservation is scoped to (cell, level); a deck reservation does not
## block the ground and vice versa, while the same level still refuses a double
## reservation. Each level > 0 claim now requires a live deck at that level
## (review P1-3), so decks are authored at levels 1 and 2 first.
func test_reserve_cell_is_level_scoped() -> void:
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _clear_fixture()
    _reset()
    _sh.clear_reservations()
    var cell := Vector2i(33, 33)
    _register(cell, 1, 3.0)
    _register(cell, 2, 6.0)
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 1), "fixture: level-1 deck exists")
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 2), "fixture: level-2 deck exists")
    TestHelper.assert_true(_sh.reserve_cell(cell, 1), "reserve level 1 succeeds")
    TestHelper.assert_true(_sh.reserve_cell(cell, 0), "level 1 reservation leaves ground free")
    TestHelper.assert_true(_sh.reserve_cell(cell, 2), "level 1 reservation leaves level 2 free")
    TestHelper.assert_true(
        not _sh.reserve_cell(cell, 1), "control: same (cell, level) cannot be reserved twice"
    )
    TestHelper.assert_true(
        _sh.get_reserved().has(CellUtil.cell_key(cell)), "level 0 reservation keys the cell"
    )
    TestHelper.assert_true(
        _sh.get_reserved().has(CellUtil.cell_level_key(cell, 1)), "level 1 reservation is keyed"
    )
    _sh.release_cell(cell, 1)
    TestHelper.assert_true(_sh.reserve_cell(cell, 1), "released level 1 can be reserved again")
    (
        TestHelper
        . assert_true(
            _sh.get_reserved().has(CellUtil.cell_key(cell)),
            "releasing level 1 does not release the ground reservation",
        )
    )
    _sh.clear_reservations()
    _clear_fixture()


## Task 6.4: a deck at MAX_HEIGHT is refused (no surface created); MAX_HEIGHT-1,
## which is representable, is accepted.
func test_deck_at_max_height_is_refused() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear_fixture()
    _reset()
    var accepted := Vector2i(34, 34)
    var refused := Vector2i(36, 34)
    TestHelper.assert_true(CellUtil.is_in_diamond(accepted, MAP), "accepted cell is inside the map")
    TestHelper.assert_true(CellUtil.is_in_diamond(refused, MAP), "refused cell is inside the map")
    var top := TerrainSystem.MAX_HEIGHT

    _register(accepted, top - 1, 2.0)
    _register(refused, top, 5.0)
    _sh.rebuild()

    # Control: the boundary-1 fixture is representable, proving the fixture works.
    TestHelper.assert_true(
        _sh.has_bridge_on_cell(accepted, top - 1), "level MAX_HEIGHT-1 is accepted"
    )
    TestHelper.assert_eq(
        _ts.get_land_type(accepted, top - 1), "bridge", "MAX_HEIGHT-1 has a surface"
    )
    TestHelper.assert_true(not _sh.has_bridge_on_cell(refused, top), "level MAX_HEIGHT is refused")
    TestHelper.assert_eq(
        _sh.get_bridge_levels(refused).size(), 0, "no deck registered at MAX_HEIGHT"
    )
    TestHelper.assert_eq(_ts.get_land_type(refused, top), "", "MAX_HEIGHT reports no surface")
    TestHelper.assert_eq(
        _ts.get_cell_surface_levels(refused), [0], "refused cell keeps the ground-only stack"
    )
    _clear_fixture()


## Task 6.3: level-1, level-2, and ground paths over the same corridor are all
## valid simultaneously, and a blocker on one level detours only that level.
func test_pathfinder_traverses_stacked_decks_independently() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear_fixture()
    _reset()
    for cell in CORRIDOR:
        _flatten(cell, 0)
    # Level 1 four steps up and level 2 eight steps up: a ground start cannot
    # climb either (grade gate), so each path stays on its own surface.
    var level1_y := 4.0 * HEIGHT_STEP
    var level2_y := 8.0 * HEIGHT_STEP
    for cell in CORRIDOR:
        _register(cell, 1, level1_y)
        _register(cell, 2, level2_y)
    _sh.rebuild()

    var wheel := _wheel()
    var start := CellUtil.cell_to_world(CORRIDOR[0])
    var goal := CellUtil.cell_to_world(CORRIDOR[2])
    var mid := CORRIDOR[1]

    var ground := _path_states(
        Pathfinder.find_path_detailed(start, goal, {}, wheel, false, null, _ts, 0, 0)
    )
    var deck1 := _path_states(
        Pathfinder.find_path_detailed(start, goal, {}, wheel, false, null, _ts, 1, 1)
    )
    var deck2 := _path_states(
        Pathfinder.find_path_detailed(start, goal, {}, wheel, false, null, _ts, 2, 2)
    )
    # Control: all three routes cross the mid cell on their own level.
    TestHelper.assert_true(ground.has(Vector3i(mid.x, mid.y, 0)), "baseline ground crosses mid")
    TestHelper.assert_true(deck1.has(Vector3i(mid.x, mid.y, 1)), "baseline level 1 crosses mid")
    TestHelper.assert_true(deck2.has(Vector3i(mid.x, mid.y, 2)), "baseline level 2 crosses mid")

    # A ground blocker detours only the ground route.
    var ground_block: Dictionary = {CellUtil.cell_level_key(mid, 0): true}
    var ground_detour := _path_states(
        Pathfinder.find_path_detailed(start, goal, ground_block, wheel, false, null, _ts, 0, 0)
    )
    var deck1_after_ground_block := _path_states(
        Pathfinder.find_path_detailed(start, goal, ground_block, wheel, false, null, _ts, 1, 1)
    )
    var deck2_after_ground_block := _path_states(
        Pathfinder.find_path_detailed(start, goal, ground_block, wheel, false, null, _ts, 2, 2)
    )
    (
        TestHelper
        . assert_true(
            not ground_detour.has(Vector3i(mid.x, mid.y, 0)),
            "ground blocker removes the level-0 passage",
        )
    )
    (
        TestHelper
        . assert_true(
            deck1_after_ground_block.has(Vector3i(mid.x, mid.y, 1)),
            "ground blocker leaves the level-1 passage",
        )
    )
    (
        TestHelper
        . assert_true(
            deck2_after_ground_block.has(Vector3i(mid.x, mid.y, 2)),
            "ground blocker leaves the level-2 passage",
        )
    )

    # A level-1 blocker detours only the level-1 route.
    var deck1_block: Dictionary = {CellUtil.cell_level_key(mid, 1): true}
    var ground_after_deck1_block := _path_states(
        Pathfinder.find_path_detailed(start, goal, deck1_block, wheel, false, null, _ts, 0, 0)
    )
    var deck1_detour := _path_states(
        Pathfinder.find_path_detailed(start, goal, deck1_block, wheel, false, null, _ts, 1, 1)
    )
    var deck2_after_deck1_block := _path_states(
        Pathfinder.find_path_detailed(start, goal, deck1_block, wheel, false, null, _ts, 2, 2)
    )
    (
        TestHelper
        . assert_true(
            not deck1_detour.has(Vector3i(mid.x, mid.y, 1)),
            "level-1 blocker removes the level-1 passage",
        )
    )
    (
        TestHelper
        . assert_true(
            ground_after_deck1_block.has(Vector3i(mid.x, mid.y, 0)),
            "level-1 blocker leaves the ground passage",
        )
    )
    (
        TestHelper
        . assert_true(
            deck2_after_deck1_block.has(Vector3i(mid.x, mid.y, 2)),
            "level-1 blocker leaves the level-2 passage",
        )
    )
    _clear_fixture()


## Task 6.2: a step between stacked levels is allowed only within the mover's
## climb tolerance — a matching-grade upper-deck entry is admitted, a four-step
## jump is refused.
func test_stacked_level_transition_respects_grade() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear_fixture()
    _reset()
    var from_cell := Vector2i(25, 25)
    var to_cell := Vector2i(25, 26)
    _flatten(from_cell, 0)
    _flatten(to_cell, 0)
    var wheel := _wheel()
    var step_limit: float = float(wheel.climb_tolerance) * HEIGHT_STEP

    # Matching grade: level-1 source and level-2 destination at the same height.
    _register(from_cell, 1, 2.0 * HEIGHT_STEP)
    _register(to_cell, 2, 2.0 * HEIGHT_STEP)
    _sh.rebuild()
    var allowed: Dictionary = Pathfinder.try_greedy_step_detailed(
        from_cell, to_cell, {}, wheel, Pathfinder.GREEDY_STALL, null, _ts, 1, 2
    )
    TestHelper.assert_eq(
        allowed["cell"], to_cell, "matching-grade level 1 -> level 2 step is allowed"
    )
    TestHelper.assert_eq(int(allowed["level"]), 2, "the step lands on the upper deck")
    _clear_fixture()

    # Four-step jump: same fixture, destination deck raised beyond tolerance.
    _reset()
    _flatten(from_cell, 0)
    _flatten(to_cell, 0)
    _register(from_cell, 1, 2.0 * HEIGHT_STEP)
    _register(to_cell, 2, 2.0 * HEIGHT_STEP + 4.0 * HEIGHT_STEP)
    _sh.rebuild()
    TestHelper.assert_true(
        4.0 * HEIGHT_STEP > step_limit, "fixture step exceeds the mover's climb tolerance"
    )
    var refused: Dictionary = Pathfinder.try_greedy_step_detailed(
        from_cell, to_cell, {}, wheel, Pathfinder.GREEDY_STALL, null, _ts, 1, 2
    )
    TestHelper.assert_eq(
        refused["cell"], Pathfinder.GREEDY_STALL, "four-step level 1 -> level 2 step is refused"
    )
    _clear_fixture()
