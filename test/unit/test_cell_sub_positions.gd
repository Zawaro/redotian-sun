extends Node

# CellSubPositions tests — deterministic sub-slot positioning

var _test_passed := 0
var _test_failed := 0


func test_determinism():
    var cell := Vector2i(5, 10)
    var a: Array[Vector3] = CellSubPositions.get_sub_positions(cell)
    var b: Array[Vector3] = CellSubPositions.get_sub_positions(cell)
    var is_match := true
    for i in range(a.size()):
        if not a[i].is_equal_approx(b[i]):
            is_match = false
            break
    if is_match:
        _test_passed += 1
        print("    PASS: get_sub_positions is deterministic")
    else:
        _test_failed += 1
        print("    FAIL: get_sub_positions returns different results for same cell")


func test_slot_count():
    var cell := Vector2i(0, 0)
    var positions: Array[Vector3] = CellSubPositions.get_sub_positions(cell)
    if positions.size() == 3:
        _test_passed += 1
        print("    PASS: returns 3 slots")
    else:
        _test_failed += 1
        print("    FAIL: expected 3 slots, got %d" % positions.size())


func test_margin():
    var cell := Vector2i(7, 3)
    var positions: Array[Vector3] = CellSubPositions.get_sub_positions(cell)
    var half: float = CellUtil.CELL_SIZE * 0.5
    var min_pos: float = -half + CellSubPositions.MARGIN
    var max_pos: float = half - CellSubPositions.MARGIN
    var all_in_bounds := true
    for pos in positions:
        if pos.x < min_pos or pos.x > max_pos or pos.z < min_pos or pos.z > max_pos:
            all_in_bounds = false
            break
    if all_in_bounds:
        _test_passed += 1
        print("    PASS: all positions within margin")
    else:
        _test_failed += 1
        print("    FAIL: position outside margin bounds")


func test_spacing():
    var cell := Vector2i(2, 8)
    var positions: Array[Vector3] = CellSubPositions.get_sub_positions(cell)
    var min_dist := CellSubPositions.MIN_SLOT_DIST
    var all_spaced := true
    for i in range(positions.size()):
        for j in range(i + 1, positions.size()):
            if positions[i].distance_to(positions[j]) < min_dist:
                all_spaced = false
                break
    if all_spaced:
        _test_passed += 1
        print("    PASS: all slots at least %.1f apart" % min_dist)
    else:
        _test_failed += 1
        print("    FAIL: slots too close together")


func test_get_sub_position():
    var cell := Vector2i(3, 4)
    var pos: Vector3 = CellSubPositions.get_sub_position(cell, 0)
    var cell_world: Vector3 = CellUtil.cell_to_world(cell)
    var radius: float = (CellUtil.CELL_SIZE * 0.5 - CellSubPositions.MARGIN) * 0.7
    if pos.distance_to(cell_world) <= radius + 0.001:
        _test_passed += 1
        print("    PASS: get_sub_position returns position within cell slot radius")
    else:
        _test_failed += 1
        var msg := "dist=%.2f, radius=%.2f" % [pos.distance_to(cell_world), radius]
        print("    FAIL: get_sub_position too far from cell (%s)" % msg)


func test_different_cells_different_positions():
    var a: Array[Vector3] = CellSubPositions.get_sub_positions(Vector2i(0, 0))
    var b: Array[Vector3] = CellSubPositions.get_sub_positions(Vector2i(1, 0))
    var different := false
    for i in range(a.size()):
        if not a[i].is_equal_approx(b[i]):
            different = true
            break
    if different:
        _test_passed += 1
        print("    PASS: different cells produce different positions")
    else:
        _test_failed += 1
        print("    FAIL: different cells produced identical positions")
