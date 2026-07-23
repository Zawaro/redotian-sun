extends Node

# RallyPointComponent tests — set/clear, path storage

const RallyPointComponentScript = preload("res://scripts/components/RallyPointComponent.gd")

var _test_passed := 0
var _test_failed := 0
var _rally_changed_received := false
var _rally_path: Array[Vector2i] = []


func _make_rally() -> Node:
    var rally := Node.new()
    rally.name = "RallyPointComponent"
    rally.set_script(RallyPointComponentScript)
    return rally


func _on_rally_changed(path: Array[Vector2i]) -> void:
    _rally_changed_received = true
    _rally_path = path


# --- Basic tests ---


func test_set_rally_point():
    var rally := _make_rally()
    rally.set_rally_point(Vector2i(5, 10))
    if rally.rally_path == [Vector2i(5, 10)]:
        _test_passed += 1
        print("    PASS: set_rally_point updates path")
    else:
        _test_failed += 1
        print("    FAIL: set_rally_point did not update path")


func test_clear_rally_point():
    var rally := _make_rally()
    rally.set_rally_point(Vector2i(5, 10))
    rally.clear_rally_point()
    if rally.rally_path.is_empty():
        _test_passed += 1
        print("    PASS: clear_rally_point clears path")
    else:
        _test_failed += 1
        print("    FAIL: clear_rally_point did not clear path")


func test_has_rally_point():
    var rally := _make_rally()
    if not rally.has_rally_point():
        rally.set_rally_point(Vector2i(5, 10))
        if rally.has_rally_point():
            _test_passed += 1
            print("    PASS: has_rally_point works correctly")
        else:
            _test_failed += 1
            print("    FAIL: has_rally_point returned false after set")
    else:
        _test_failed += 1
        print("    FAIL: has_rally_point should be false initially")


func test_signal_emitted():
    var rally := _make_rally()
    rally.rally_point_changed.connect(_on_rally_changed)

    _rally_changed_received = false
    _rally_path = []

    rally.set_rally_point(Vector2i(3, 7))

    if _rally_changed_received and _rally_path == [Vector2i(3, 7)]:
        _test_passed += 1
        print("    PASS: rally_point_changed signal emitted")
    else:
        _test_failed += 1
        print("    FAIL: rally_point_changed signal not emitted")


func test_get_target_position():
    var rally := _make_rally()
    rally.set_rally_point(Vector2i(2, 3))
    var pos: Vector3 = rally.get_target_position()
    # cell_to_world: Vector3((cell.x + 0.5) * cs, 0.0, (cell.y + 0.5) * cs)
    # cs = 2.0, so (2.5 * 2.0, 0.0, 3.5 * 2.0) = (5.0, 0.0, 7.0)
    if pos.is_equal_approx(Vector3(5.0, 0.0, 7.0)):
        _test_passed += 1
        print("    PASS: get_target_position returns correct world pos")
    else:
        _test_failed += 1
        print("    FAIL: get_target_position returned %s" % pos)


# --- Run all tests ---


func run_tests():
    print("  RallyPointComponent tests:")
    test_set_rally_point()
    test_clear_rally_point()
    test_has_rally_point()
    test_signal_emitted()
    test_get_target_position()
    print("  Results: %d passed, %d failed" % [_test_passed, _test_failed])
