extends Node

# Pathfinder smoke tests — pure static functions, no SceneTree deps
# Each test method returns true/false for pass/fail

var _test_passed := 0
var _test_failed := 0


func test_world_to_cell_origin():
    var got: Vector2i = Pathfinder.world_to_cell(Vector3.ZERO)
    var expected: Vector2i = Vector2i(0, 0)
    if got == expected:
        _test_passed += 1
        print("    PASS: Vector3.ZERO → cell (0,0)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_world_to_cell_positive():
    var got: Vector2i = Pathfinder.world_to_cell(Vector3(5.0, 0.0, 5.0))
    var expected: Vector2i = Vector2i(2, 2)
    if got == expected:
        _test_passed += 1
        print("    PASS: Vector3(5,0,5) → cell (2,2)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_world_to_cell_negative():
    var got: Vector2i = Pathfinder.world_to_cell(Vector3(-3.0, 0.0, -3.0))
    var expected: Vector2i = Vector2i(-2, -2)
    if got == expected:
        _test_passed += 1
        print("    PASS: Vector3(-3,0,-3) → cell (-2,-2)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_cell_to_world_origin():
    var got: Vector3 = Pathfinder.cell_to_world(Vector2i(0, 0))
    var expected: Vector3 = Vector3(1.0, 0.0, 1.0)
    if got == expected:
        _test_passed += 1
        print("    PASS: Cell (0,0) → world (1,0,1)")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [expected, got])


func test_cell_to_world_roundtrip():
    var cell: Vector2i = Vector2i(5, 3)
    var world: Vector3 = Pathfinder.cell_to_world(cell)
    var back: Vector2i = Pathfinder.world_to_cell(world)
    if back == cell:
        _test_passed += 1
        print("    PASS: cell→world→cell roundtrip")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [cell, back])


func test_cell_key_deterministic():
    var key1: int = Pathfinder._cell_key(Vector2i(3, 5))
    var key2: int = Pathfinder._cell_key(Vector2i(3, 5))
    if key1 == key2 and key1 != 0:
        _test_passed += 1
        print("    PASS: _cell_key deterministic, returns non-zero int")
    else:
        _test_failed += 1
        print("    FAIL: expected equal non-zero ints, got key1=%d key2=%d" % [key1, key2])
