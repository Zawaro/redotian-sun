extends Node

# Pathfinder smoke tests — pure static functions, no SceneTree deps
# Each test method returns true/false for pass/fail

const GC := Vector2i(50, 50)


func test_world_to_cell_origin():
    # Default grid 50×50, center=(W+H)/2=50. world (0,0,0) → cell (50, 50)
    var got: Vector2i = CellUtil.world_to_cell(Vector3.ZERO, GC)
    var expected: Vector2i = Vector2i(50, 50)
    (
        TestHelper
        . assert_true(
            got == expected,
            "Vector3.ZERO → cell (50,50) (diamond center): expected %s, got %s" % [expected, got],
        )
    )


func test_world_to_cell_positive():
    # Default grid 50×50, center=(W+H)/2=50. world (5,0,5) → cell (52, 52)
    var got: Vector2i = CellUtil.world_to_cell(Vector3(5.0, 0.0, 5.0), GC)
    var expected: Vector2i = Vector2i(52, 52)
    (
        TestHelper
        . assert_true(
            got == expected,
            "Vector3(5,0,5) → cell (52,52): expected %s, got %s" % [expected, got],
        )
    )


func test_world_to_cell_negative():
    # Default grid 50×50, center=(W+H)/2=50. world (-3,0,-3) → cell (48, 48)
    var got: Vector2i = CellUtil.world_to_cell(Vector3(-3.0, 0.0, -3.0), GC)
    var expected: Vector2i = Vector2i(48, 48)
    (
        TestHelper
        . assert_true(
            got == expected,
            "Vector3(-3,0,-3) → cell (48,48): expected %s, got %s" % [expected, got],
        )
    )


func test_cell_to_world_origin():
    # Default grid 50×50, center=(W+H)/2=50. cell (0,0) → world (-99, 0, -99)
    var got: Vector3 = CellUtil.cell_to_world(Vector2i(0, 0), GC)
    var expected: Vector3 = Vector3(-99.0, 0.0, -99.0)
    (
        TestHelper
        . assert_true(
            got == expected,
            "Cell (0,0) → world (-99,0,-99): expected %s, got %s" % [expected, got],
        )
    )


func test_cell_to_world_roundtrip():
    var cell: Vector2i = Vector2i(5, 3)
    var world: Vector3 = CellUtil.cell_to_world(cell, GC)
    var back: Vector2i = CellUtil.world_to_cell(world, GC)
    TestHelper.assert_true(
        back == cell, "cell→world→cell roundtrip: expected %s, got %s" % [cell, back]
    )


func test_cell_key_deterministic():
    var key1: int = CellUtil.cell_key(Vector2i(3, 5))
    var key2: int = CellUtil.cell_key(Vector2i(3, 5))
    (
        TestHelper
        . assert_true(
            key1 == key2 and key1 != 0,
            (
                "_cell_key deterministic, returns non-zero int: expected equal non-zero ints, "
                + "got key1=%d key2=%d" % [key1, key2]
            ),
        )
    )
