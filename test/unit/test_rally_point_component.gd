extends Node

# RallyPointComponent tests — set/clear, path storage

const RallyPointComponentScript = preload("res://scripts/components/RallyPointComponent.gd")

var _rally_changed_received := false
var _rally_point: Vector2i = Vector2i.ZERO


func _make_rally() -> Node:
    var rally := Node.new()
    rally.name = "RallyPointComponent"
    rally.set_script(RallyPointComponentScript)
    return rally


func _on_rally_changed(point: Vector2i) -> void:
    _rally_changed_received = true
    _rally_point = point


# --- Basic tests ---


func test_set_rally_point():
    var rally := _make_rally()
    rally.set_rally_point(Vector2i(5, 10))
    (
        TestHelper
        . assert_true(
            rally.rally_point == Vector2i(5, 10),
            "set_rally_point updates point: set_rally_point did not update point",
        )
    )


func test_clear_rally_point():
    var rally := _make_rally()
    rally.set_rally_point(Vector2i(5, 10))
    rally.clear_rally_point()
    (
        TestHelper
        . assert_true(
            rally.rally_point == Vector2i(-1, -1),
            "clear_rally_point resets to sentinel: clear_rally_point did not reset",
        )
    )


func test_has_rally_point():
    var rally := _make_rally()
    if not rally.has_rally_point():
        rally.set_rally_point(Vector2i(5, 10))
        (
            TestHelper
            . assert_true(
                rally.has_rally_point(),
                "has_rally_point works correctly: has_rally_point returned false after set",
            )
        )
    else:
        TestHelper.fail("has_rally_point should be false initially")


func test_signal_emitted():
    var rally := _make_rally()
    rally.rally_point_changed.connect(_on_rally_changed)

    _rally_changed_received = false
    _rally_point = Vector2i.ZERO

    rally.set_rally_point(Vector2i(3, 7))

    (
        TestHelper
        . assert_true(
            _rally_changed_received and _rally_point == Vector2i(3, 7),
            "rally_point_changed signal emitted: rally_point_changed signal not emitted",
        )
    )


func test_get_target_position():
    var rally := _make_rally()
    rally.set_rally_point(Vector2i(2, 3))
    var pos: Vector3 = rally.get_target_position()
    var expected: Vector3 = CellUtil.cell_to_world(Vector2i(2, 3))
    (
        TestHelper
        . assert_true(
            pos.is_equal_approx(expected),
            (
                (
                    "get_target_position returns correct world pos: "
                    + "get_target_position returned %s, expected %s"
                )
                % [pos, expected]
            ),
        )
    )
