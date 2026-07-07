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


func test_register_building_cells():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._building_cells.clear()
    var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6)]
    _sh.register_building_cells(cells)
    var key55 := "5,5"
    var key65 := "6,5"
    var key56 := "5,6"
    var key66 := "6,6"
    var all_registered: bool = (
        _sh._building_cells.has(key55)
        and _sh._building_cells.has(key65)
        and _sh._building_cells.has(key56)
        and _sh._building_cells.has(key66)
    )
    _sh._building_cells.clear()
    if all_registered:
        _test_passed += 1
        print("    PASS: register_building_cells adds all cells")
    else:
        _test_failed += 1
        print("    FAIL: not all cells registered")


func test_unregister_building_cells():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._building_cells.clear()
    var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
    _sh.register_building_cells(cells)
    _sh.unregister_building_cells(cells)
    var key55 := "5,5"
    var key65 := "6,5"
    var has_55 := _sh._building_cells.has(key55)
    var has_65 := _sh._building_cells.has(key65)
    var all_removed: bool = not has_55 and not has_65
    if all_removed:
        _test_passed += 1
        print("    PASS: unregister_building_cells removes all cells")
    else:
        _test_failed += 1
        print("    FAIL: cells still present after unregister")


func test_get_blocked_cells_merges_building_and_blocked():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    _sh._blocked_cells["10,10"] = true
    var building_cells: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20)]
    _sh.register_building_cells(building_cells)
    var blocked: Dictionary = _sh.get_blocked_cells()
    var has_blocked: bool = blocked.has("10,10")
    var has_building1: bool = blocked.has("20,20")
    var has_building2: bool = blocked.has("21,20")
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    if has_blocked and has_building1 and has_building2:
        _test_passed += 1
        print("    PASS: get_blocked_cells merges building and blocked cells")
    else:
        _test_failed += 1
        print("    FAIL: blocked=%s, b1=%s, b2=%s" % [has_blocked, has_building1, has_building2])
