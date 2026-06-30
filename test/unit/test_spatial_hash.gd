extends Node

# SpatialHash tests — cell reservation logic

var _sh: Node = null
var _test_passed := 0
var _test_failed := 0

func test_reserve_cell_succeeds():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    if result == true:
        _test_passed += 1
        print("    PASS: reserve_cell succeeds on empty cell")
    else:
        _test_failed += 1
        print("    FAIL: expected true, got false")

func test_reserve_cell_fails_when_taken():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    _sh.reserve_cell(cell)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    if result == false:
        _test_passed += 1
        print("    PASS: reserve_cell fails on already reserved cell")
    else:
        _test_failed += 1
        print("    FAIL: expected false, got true")

func test_release_cell_frees():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    _sh.reserve_cell(cell)
    _sh.release_cell(cell)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    if result == true:
        _test_passed += 1
        print("    PASS: release_cell frees the cell")
    else:
        _test_failed += 1
        print("    FAIL: expected true after release, got false")

func test_is_cell_idle_reflects_blocked():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh.clear_reservations()
    _sh._blocked_cells.clear()
    var cell := Vector2i(10, 10)
    var key: String = "%d,%d" % [cell.x, cell.y]
    _sh._blocked_cells[key] = true
    var idle: bool = _sh.is_cell_idle(cell)
    var reserved: bool = _sh.reserve_cell(cell)
    _sh._blocked_cells.erase(key)
    if idle == true and reserved == false:
        _test_passed += 1
        print("    PASS: is_cell_idle reflects blocked state")
    else:
        _test_failed += 1
        print("    FAIL: idle=%s, reserved=%s" % [idle, reserved])
