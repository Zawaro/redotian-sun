extends Node

# Pathfinder smoke tests — pure static functions, no SceneTree deps
# Each test method returns true/false for pass/fail

var _test_passed := 0
var _test_failed := 0

const GC := Vector2i(50, 50)


func test_world_to_cell_origin():
    # Default grid 50×50, center=(W+H)/2=50. world (0,0,0) → cell (50, 50)
    var got: Vector2i = CellUtil.world_to_cell(Vector3.ZERO, GC)
    var expected: Vector2i = Vector2i(50, 50)
    if got == expected:
        _test_passed += 1
        print("    PASS: Vector3.ZERO → cell (50,50) (diamond center)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_world_to_cell_positive():
    # Default grid 50×50, center=(W+H)/2=50. world (5,0,5) → cell (52, 52)
    var got: Vector2i = CellUtil.world_to_cell(Vector3(5.0, 0.0, 5.0), GC)
    var expected: Vector2i = Vector2i(52, 52)
    if got == expected:
        _test_passed += 1
        print("    PASS: Vector3(5,0,5) → cell (52,52)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_world_to_cell_negative():
    # Default grid 50×50, center=(W+H)/2=50. world (-3,0,-3) → cell (48, 48)
    var got: Vector2i = CellUtil.world_to_cell(Vector3(-3.0, 0.0, -3.0), GC)
    var expected: Vector2i = Vector2i(48, 48)
    if got == expected:
        _test_passed += 1
        print("    PASS: Vector3(-3,0,-3) → cell (48,48)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_cell_to_world_origin():
    # Default grid 50×50, center=(W+H)/2=50. cell (0,0) → world (-99, 0, -99)
    var got: Vector3 = CellUtil.cell_to_world(Vector2i(0, 0), GC)
    var expected: Vector3 = Vector3(-99.0, 0.0, -99.0)
    if got == expected:
        _test_passed += 1
        print("    PASS: Cell (0,0) → world (-99,0,-99)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_cell_to_world_roundtrip():
    var cell: Vector2i = Vector2i(5, 3)
    var world: Vector3 = CellUtil.cell_to_world(cell, GC)
    var back: Vector2i = CellUtil.world_to_cell(world, GC)
    if back == cell:
        _test_passed += 1
        print("    PASS: cell→world→cell roundtrip")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [cell, back])


func test_cell_key_deterministic():
    var key1: int = CellUtil.cell_key(Vector2i(3, 5))
    var key2: int = CellUtil.cell_key(Vector2i(3, 5))
    if key1 == key2 and key1 != 0:
        _test_passed += 1
        print("    PASS: _cell_key deterministic, returns non-zero int")
    else:
        _test_failed += 1
        print("    FAIL: expected equal non-zero ints, got key1=%d key2=%d" % [key1, key2])
