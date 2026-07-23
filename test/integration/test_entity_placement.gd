extends Node

# Entity placement integration tests — end-to-end workflow
# Tests the EntityPlacer sub-script with a real MapEditor instance.

var _test_passed := 0
var _test_failed := 0


func _make_placer() -> Array:
    # Returns [EntityPlacer, editor]
    var editor_script = load("res://scripts/editor/MapEditor.gd")
    var placer_script = load("res://scripts/editor/EntityPlacer.gd")
    if editor_script == null or placer_script == null:
        return [null, null]
    var editor = editor_script.new()
    var placer = placer_script.new()
    placer.editor = editor
    return [placer, editor]


func test_entity_placement_creates_node():
    var result := _make_placer()
    var placer = result[0]
    var editor = result[1]
    if placer == null:
        print("    FAIL: Cannot load scripts")
        _test_failed += 1
        return
    placer._selected_entity_id = "TIBERIUM_RIPARIUS"
    placer._selected_player_id = 0
    var cell := Vector2i(5, 5)
    var key := str(cell.x) + "," + str(cell.y)
    placer._place_entity_on_cell(cell)
    if editor._painted_entities.has(key):
        print("    PASS: Entity placement creates node")
        _test_passed += 1
        var entry: Dictionary = editor._painted_entities[key]
        var node: Node3D = entry.get("node")
        if node and is_instance_valid(node):
            node.queue_free()
        editor._painted_entities.erase(key)
    else:
        print("    FAIL: Entity placement did not create entry")
        _test_failed += 1


func test_entity_stored_with_player_id():
    var result := _make_placer()
    var placer = result[0]
    var editor = result[1]
    if placer == null:
        print("    FAIL: Cannot load scripts")
        _test_failed += 1
        return
    placer._selected_entity_id = "TIBERIUM_RIPARIUS"
    placer._selected_player_id = 1
    var cell := Vector2i(6, 6)
    var key := str(cell.x) + "," + str(cell.y)
    placer._place_entity_on_cell(cell)
    if editor._painted_entities.has(key):
        var data: Dictionary = editor._painted_entities[key].get("data", {})
        if data.get("player_id") == 1:
            print("    PASS: Entity stored with correct player_id")
            _test_passed += 1
        else:
            print("    FAIL: Entity player_id is %s, expected 1" % str(data.get("player_id")))
            _test_failed += 1
        var node: Node3D = editor._painted_entities[key].get("node")
        if node and is_instance_valid(node):
            node.queue_free()
        editor._painted_entities.erase(key)
    else:
        print("    FAIL: Entity not found in painted_entities")
        _test_failed += 1


func test_cannot_place_on_occupied_cell():
    var result := _make_placer()
    var placer = result[0]
    var editor = result[1]
    if placer == null:
        print("    FAIL: Cannot load scripts")
        _test_failed += 1
        return
    placer._selected_entity_id = "TIBERIUM_RIPARIUS"
    placer._selected_player_id = 0
    var cell := Vector2i(7, 7)
    var key := str(cell.x) + "," + str(cell.y)
    placer._place_entity_on_cell(cell)
    var count_before: int = editor._painted_entities.size()
    placer._place_entity_on_cell(cell)
    var count_after: int = editor._painted_entities.size()
    if count_before == count_after:
        print("    PASS: Cannot place on occupied cell")
        _test_passed += 1
    else:
        print("    FAIL: Second entity placed on occupied cell")
        _test_failed += 1
    if editor._painted_entities.has(key):
        var node: Node3D = editor._painted_entities[key].get("node")
        if node and is_instance_valid(node):
            node.queue_free()
        editor._painted_entities.erase(key)


func test_empty_entity_id_blocked():
    var result := _make_placer()
    var placer = result[0]
    var editor = result[1]
    if placer == null:
        print("    FAIL: Cannot load scripts")
        _test_failed += 1
        return
    placer._selected_entity_id = ""
    placer._selected_player_id = 0
    var cell := Vector2i(8, 8)
    placer._place_entity_on_cell(cell)
    var key := str(cell.x) + "," + str(cell.y)
    if not editor._painted_entities.has(key):
        print("    PASS: Empty entity_id blocked")
        _test_passed += 1
    else:
        print("    FAIL: Entity placed with empty entity_id")
        _test_failed += 1
        var node: Node3D = editor._painted_entities[key].get("node")
        if node and is_instance_valid(node):
            node.queue_free()
        editor._painted_entities.erase(key)


func print_summary():
    print("\n=== Entity Placement Integration Test Summary ===")
    print("Passed: %d" % _test_passed)
    print("Failed: %d" % _test_failed)
    print("Total: %d" % (_test_passed + _test_failed))
    if _test_failed == 0:
        print("ALL TESTS PASSED")
    else:
        print("SOME TESTS FAILED")
