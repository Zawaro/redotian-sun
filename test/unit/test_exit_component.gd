extends Node

# ExitComponent tests — positioning, facing, signal emission, free cell search

const ExitComponentScript = preload("res://scripts/components/ExitComponent.gd")

var _test_passed := 0
var _test_failed := 0
var _unit_spawned_received := false
var _spawned_unit: Node3D = null


func _make_exit(
    exit_off: Vector3 = Vector3(0, 0, 2),
    spawn_off: Vector3 = Vector3(0, 0, 0),
    facing: int = 90,
    delay: float = 0.0
) -> ExitComponent:
    var exit := ExitComponent.new()
    exit.name = "ExitComponent"
    exit.exit_offset = exit_off
    exit.spawn_offset = spawn_off
    exit.exit_facing = facing
    exit.exit_delay = delay
    return exit


func _on_unit_spawned(unit: Node3D) -> void:
    _unit_spawned_received = true
    _spawned_unit = unit


# --- Basic tests ---


func test_exit_offset():
    var exit := _make_exit(Vector3(0, 0, 3))
    if exit.exit_offset == Vector3(0, 0, 3):
        _test_passed += 1
        print("    PASS: exit_offset set correctly")
    else:
        _test_failed += 1
        print("    FAIL: exit_offset not set")


func test_spawn_offset():
    var exit := _make_exit(Vector3(0, 0, 2), Vector3(1, 0, 0))
    if exit.spawn_offset == Vector3(1, 0, 0):
        _test_passed += 1
        print("    PASS: spawn_offset set correctly")
    else:
        _test_failed += 1
        print("    FAIL: spawn_offset not set")


func test_exit_facing():
    var exit := _make_exit(Vector3(0, 0, 2), Vector3.ZERO, 180)
    if exit.exit_facing == 180:
        _test_passed += 1
        print("    PASS: exit_facing set correctly")
    else:
        _test_failed += 1
        print("    FAIL: exit_facing not set")


func test_exit_delay():
    var exit := _make_exit(Vector3.ZERO, Vector3.ZERO, 0, 1.5)
    if exit.exit_delay == 1.5:
        _test_passed += 1
        print("    PASS: exit_delay set correctly")
    else:
        _test_failed += 1
        print("    FAIL: exit_delay not set")


func test_signal_emitted():
    var exit := _make_exit()
    exit.unit_spawned.connect(_on_unit_spawned)

    var unit := Node3D.new()
    unit.name = "TestUnit"
    add_child(unit)

    var building := Node3D.new()
    building.name = "TestBuilding"
    building.global_position = Vector3(0, 0, 0)
    add_child(building)
    building.add_child(exit)

    _unit_spawned_received = false
    _spawned_unit = null

    exit.on_unit_produced(unit)

    if _unit_spawned_received and _spawned_unit == unit:
        _test_passed += 1
        print("    PASS: unit_spawned signal emitted correctly")
    else:
        _test_failed += 1
        print("    FAIL: unit_spawned signal not emitted")

    building.remove_child(exit)
    remove_child(building)
    remove_child(unit)


func test_configure_from_entity_data():
    var exit := _make_exit()
    var data := EntityData.new()
    data.spawn_offset = Vector3(2, 0, 0)
    data.exit_offset = Vector3(0, 0, 4)
    data.exit_facing = 270
    data.exit_delay = 2.0
    exit.configure(data)
    if (
        exit.spawn_offset == Vector3(2, 0, 0)
        and exit.exit_offset == Vector3(0, 0, 4)
        and exit.exit_facing == 270
        and exit.exit_delay == 2.0
    ):
        _test_passed += 1
        print("    PASS: configure() copies fields from EntityData")
    else:
        _test_failed += 1
        print("    FAIL: configure() did not copy fields")


# --- Free cell tests ---


func test_is_cell_available_clear():
    var exit := _make_exit()
    add_child(exit)
    # A cell far from any building should be available
    var cell := Vector2i(999, 999)
    if exit._is_cell_available(cell):
        _test_passed += 1
        print("    PASS: _is_cell_available returns true for clear cell")
    else:
        _test_failed += 1
        print("    FAIL: _is_cell_available returned false for clear cell")
    remove_child(exit)


func test_find_free_near_returns_input_when_available():
    var exit := _make_exit()
    add_child(exit)
    var cell := Vector2i(999, 999)
    var result: Vector2i = exit._find_free_near(cell)
    if result == cell:
        _test_passed += 1
        print("    PASS: _find_free_near returns input when cell is available")
    else:
        _test_failed += 1
        print("    FAIL: _find_free_near changed an available cell")
    remove_child(exit)


# --- Run all tests ---


func run_tests():
    print("  ExitComponent tests:")
    test_exit_offset()
    test_spawn_offset()
    test_exit_facing()
    test_exit_delay()
    test_signal_emitted()
    test_configure_from_entity_data()
    test_is_cell_available_clear()
    test_find_free_near_returns_input_when_available()
    print("  Results: %d passed, %d failed" % [_test_passed, _test_failed])
