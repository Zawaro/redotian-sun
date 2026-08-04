extends Node

# Entity placement integration tests — end-to-end workflow
# Tests the EntityPlacer sub-script with a real MapEditor instance.


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
        TestHelper.fail("Cannot load scripts")
        return
    placer._selected_entity_id = "TIBERIUM_RIPARIUS"
    placer._selected_player_id = 0
    var cell := Vector2i(5, 5)
    var key := str(cell.x) + "," + str(cell.y)
    placer._place_entity_on_cell(cell)
    if editor._painted_entities.has(key):
        TestHelper.assert_true(true, "Entity placement creates node")
        var entry: Dictionary = editor._painted_entities[key]
        var node: Node3D = entry.get("node")
        if node and is_instance_valid(node):
            node.queue_free()
        editor._painted_entities.erase(key)
    else:
        TestHelper.fail("Entity placement did not create entry")


func test_entity_stored_with_player_id():
    var result := _make_placer()
    var placer = result[0]
    var editor = result[1]
    if placer == null:
        TestHelper.fail("Cannot load scripts")
        return
    placer._selected_entity_id = "TIBERIUM_RIPARIUS"
    placer._selected_player_id = 1
    var cell := Vector2i(6, 6)
    var key := str(cell.x) + "," + str(cell.y)
    placer._place_entity_on_cell(cell)
    if editor._painted_entities.has(key):
        var data: Dictionary = editor._painted_entities[key].get("data", {})
        (
            TestHelper
            . assert_true(
                data.get("player_id") == 1,
                (
                    "Entity stored with correct player_id: "
                    + "Entity player_id is %s, expected 1" % str(data.get("player_id"))
                ),
            )
        )
        var node: Node3D = editor._painted_entities[key].get("node")
        if node and is_instance_valid(node):
            node.queue_free()
        editor._painted_entities.erase(key)
    else:
        TestHelper.fail("Entity not found in painted_entities")


func test_cannot_place_on_occupied_cell():
    var result := _make_placer()
    var placer = result[0]
    var editor = result[1]
    if placer == null:
        TestHelper.fail("Cannot load scripts")
        return
    placer._selected_entity_id = "TIBERIUM_RIPARIUS"
    placer._selected_player_id = 0
    var cell := Vector2i(7, 7)
    var key := str(cell.x) + "," + str(cell.y)
    placer._place_entity_on_cell(cell)
    var count_before: int = editor._painted_entities.size()
    placer._place_entity_on_cell(cell)
    var count_after: int = editor._painted_entities.size()
    (
        TestHelper
        . assert_true(
            count_before == count_after,
            "Cannot place on occupied cell: Second entity placed on occupied cell",
        )
    )
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
        TestHelper.fail("Cannot load scripts")
        return
    placer._selected_entity_id = ""
    placer._selected_player_id = 0
    var cell := Vector2i(8, 8)
    placer._place_entity_on_cell(cell)
    var key := str(cell.x) + "," + str(cell.y)
    if not editor._painted_entities.has(key):
        TestHelper.assert_true(true, "Empty entity_id blocked")
    else:
        TestHelper.fail("Entity placed with empty entity_id")
        var node: Node3D = editor._painted_entities[key].get("node")
        if node and is_instance_valid(node):
            node.queue_free()
        editor._painted_entities.erase(key)
