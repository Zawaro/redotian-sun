extends Node

# TerrainSystem tests — autoload singleton state management

var _ts: Node = null
var _test_passed := 0
var _test_failed := 0


func test_init_grid_sets_grid_cells():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(16)
    var got: int = _ts.grid_cells
    _ts.init_grid(32)  # restore
    if got == 16:
        _test_passed += 1
        print("    PASS: init_grid sets grid_cells to 16")
    else:
        _test_failed += 1
        print("    FAIL: expected grid_cells=16, got %d" % got)


func test_init_grid_resets_vertex_data():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32)
    _ts.set_vertex(5, 5, 7)
    var before: int = _ts.get_vertex(5, 5)
    _ts.init_grid(32)
    var after: int = _ts.get_vertex(5, 5)
    if before == 7 and after == 0:
        _test_passed += 1
        print("    PASS: init_grid resets vertex data")
    else:
        _test_failed += 1
        print("    FAIL: before=%d, after=%d" % [before, after])


func test_set_cell_stores_data():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32)
    var cell := Vector2i(2, 3)
    _ts.raise_cell(cell)
    var data: Dictionary = _ts.get_cell(cell)
    _ts.clear()
    if not data.is_empty() and data.has("height"):
        _test_passed += 1
        print("    PASS: raise_cell stores data with height")
    else:
        _test_failed += 1
        print("    FAIL: expected non-empty data, got %s" % data)


func test_get_cell_empty_for_unset():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32)
    var data: Dictionary = _ts.get_cell(Vector2i(99, 99))
    if data.is_empty():
        _test_passed += 1
        print("    PASS: get_cell returns empty for unset cell")
    else:
        _test_failed += 1
        print("    FAIL: expected empty, got %s" % data)


func test_clear_empties_cells():
    if _ts == null:
        _test_failed += 1
        print("    FAIL: TerrainSystem not injected")
        return
    _ts.init_grid(32)
    var cell := Vector2i(5, 5)
    _ts.raise_cell(cell)
    var before: Dictionary = _ts.get_cell(cell)
    _ts.clear()
    var after: Dictionary = _ts.get_cell(cell)
    if not before.is_empty() and after.is_empty():
        _test_passed += 1
        print("    PASS: clear empties cells")
    else:
        _test_failed += 1
        print("    FAIL: before_empty=%s, after_empty=%s" % [before.is_empty(), after.is_empty()])
