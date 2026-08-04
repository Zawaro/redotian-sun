extends Node

# ExitComponent tests — positioning, facing, signal emission, free cell search

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
    TestHelper.assert_true(
        exit.exit_offset == Vector3(0, 0, 3), "exit_offset set correctly: exit_offset not set"
    )


func test_spawn_offset():
    var exit := _make_exit(Vector3(0, 0, 2), Vector3(1, 0, 0))
    TestHelper.assert_true(
        exit.spawn_offset == Vector3(1, 0, 0), "spawn_offset set correctly: spawn_offset not set"
    )


func test_exit_facing():
    var exit := _make_exit(Vector3(0, 0, 2), Vector3.ZERO, 180)
    TestHelper.assert_true(
        exit.exit_facing == 180, "exit_facing set correctly: exit_facing not set"
    )


func test_exit_delay():
    var exit := _make_exit(Vector3.ZERO, Vector3.ZERO, 0, 1.5)
    TestHelper.assert_true(exit.exit_delay == 1.5, "exit_delay set correctly: exit_delay not set")


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

    (
        TestHelper
        . assert_true(
            _unit_spawned_received and _spawned_unit == unit,
            "unit_spawned signal emitted correctly: unit_spawned signal not emitted",
        )
    )

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
    (
        TestHelper
        . assert_true(
            (
                exit.spawn_offset == Vector3(2, 0, 0)
                and exit.exit_offset == Vector3(0, 0, 4)
                and exit.exit_facing == 270
                and exit.exit_delay == 2.0
            ),
            "configure() copies fields from EntityData: configure() did not copy fields",
        )
    )


# --- Free cell tests ---


func test_is_cell_available_clear():
    var exit := _make_exit()
    add_child(exit)
    # A cell far from any building should be available
    var cell := Vector2i(999, 999)
    (
        TestHelper
        . assert_true(
            exit._is_cell_available(cell),
            (
                "_is_cell_available returns true for clear cell: "
                + "_is_cell_available returned false for clear cell"
            ),
        )
    )
    remove_child(exit)


func test_find_free_near_returns_input_when_available():
    var exit := _make_exit()
    add_child(exit)
    var cell := Vector2i(999, 999)
    var result: Vector2i = exit._find_free_near(cell)
    (
        TestHelper
        . assert_true(
            result == cell,
            (
                "_find_free_near returns input when cell is available: "
                + "_find_free_near changed an available cell"
            ),
        )
    )
    remove_child(exit)
