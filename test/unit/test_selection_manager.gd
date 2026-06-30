extends Node

# SelectionManager tests — selection state management
# Note: selected_entities is Array[SelectComponent], so we can't mock with Node

var _sm: Node = null
var _test_passed := 0
var _test_failed := 0

func test_selected_entities_initially_empty():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    _sm.deselect_all()
    var count: int = _sm.selected_entities.size()
    if count == 0:
        _test_passed += 1
        print("    PASS: selected_entities initially empty")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % count)

func test_deselect_all_clears():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    _sm.deselect_all()
    var count: int = _sm.selected_entities.size()
    if count == 0:
        _test_passed += 1
        print("    PASS: deselect_all clears selection")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % count)

func test_select_entity_ignores_null():
    if _sm == null:
        _test_failed += 1
        print("    FAIL: SelectionManager not injected")
        return
    _sm.deselect_all()
    _sm.select_entity(null)
    var count: int = _sm.selected_entities.size()
    if count == 0:
        _test_passed += 1
        print("    PASS: select_entity ignores null")
    else:
        _test_failed += 1
        print("    FAIL: expected 0 after null, got %d" % count)
