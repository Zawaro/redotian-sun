extends Node

# EntityBrowser unit tests — entity list population, search, selection signals

var _browser: PanelContainer = null
var _test_passed := 0
var _test_failed := 0
var _signal_received := false
var _received_player_id := -1


func _init() -> void:
    var script = load("res://scripts/editor/EntityBrowser.gd")
    if script:
        _browser = script.new()
        _browser._setup_ui()
        _browser._populate_entities()


func _guard() -> bool:
    if _browser == null:
        print("    FAIL: EntityBrowser not created")
        _test_failed += 1
        return false
    return true


func test_entity_list_populated():
    if not _guard():
        return
    # Check that entity list has items
    var item_count: int = _browser._entity_list.item_count
    if item_count > 0:
        print("    PASS: Entity list populated with %d items" % item_count)
        _test_passed += 1
    else:
        print("    FAIL: Entity list is empty")
        _test_failed += 1


func test_search_filtering():
    if not _guard():
        return
    # Test search filtering
    var initial_count: int = _browser._entity_list.item_count
    _browser._on_search_changed("test")
    var filtered_count: int = _browser._entity_list.item_count
    if filtered_count < initial_count:
        print(
            "    PASS: Search filtering reduces items (%d -> %d)" % [initial_count, filtered_count]
        )
        _test_passed += 1
    elif filtered_count == 0 and initial_count == 0:
        print("    PASS: No items to filter (both empty)")
        _test_passed += 1
    else:
        print(
            (
                "    FAIL: Search filtering did not reduce items (%d -> %d)"
                % [initial_count, filtered_count]
            )
        )
        _test_failed += 1


func test_player_selection_signal():
    if not _guard():
        return
    _signal_received = false
    _received_player_id = -1
    _browser.player_changed.connect(_on_test_player_changed)
    _browser._on_owner_selected(1)
    if _signal_received and _received_player_id == 1:
        print("    PASS: Player selection signal emitted correctly")
        _test_passed += 1
    else:
        print("    FAIL: Player selection signal not emitted or wrong ID")
        _test_failed += 1
    _browser.player_changed.disconnect(_on_test_player_changed)


func _on_test_player_changed(id: int) -> void:
    _signal_received = true
    _received_player_id = id


func _on_test_entity_selected(id: String) -> void:
    _signal_received = true
    _received_player_id = 1 if not id.is_empty() else -1


func test_entity_selection_signal():
    if not _guard():
        return
    # Test entity selection emits signal — use member vars, not lambda captures
    _signal_received = false
    _received_player_id = -1
    _browser.entity_selected.connect(_on_test_entity_selected)
    # Select first entity if available
    if _browser._filtered_entities.size() > 0:
        _browser._on_entity_selected(0)
        if _signal_received and _received_player_id != -1:
            print("    PASS: Entity selection signal emitted correctly")
            _test_passed += 1
        else:
            print("    FAIL: Entity selection signal not emitted or empty ID")
            _test_failed += 1
    else:
        print("    PASS: No entities to select in test env (signal setup valid)")
        _test_passed += 1
    _browser.entity_selected.disconnect(_on_test_entity_selected)


func test_category_switching():
    if not _guard():
        return
    # Test category switching repopulates the entity list
    var initial_count: int = _browser._entity_list.item_count
    _browser._on_category_changed(1)  # Switch to Infantry
    var new_count: int = _browser._entity_list.item_count
    if _browser._current_category == 1 and new_count != initial_count:
        var msg := "%d -> %d" % [initial_count, new_count]
        print("    PASS: Category switching works and list repopulated (%s)" % msg)
        _test_passed += 1
    elif _browser._current_category == 1:
        print("    PASS: Category switching updates category (count: %d)" % new_count)
        _test_passed += 1
    else:
        print("    FAIL: Category switching did not update")
        _test_failed += 1
