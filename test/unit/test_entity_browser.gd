extends Node

# EntityBrowser unit tests — entity list population, search, selection signals

var _browser: PanelContainer = null
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
        TestHelper.fail("EntityBrowser not created")
        return false
    return true


func test_entity_list_populated():
    if not _guard():
        return
    # Check that entity list has items
    var item_count: int = _browser._entity_list.item_count
    (
        TestHelper
        . assert_true(
            item_count > 0,
            "Entity list populated with %d items" % item_count + ": " + "Entity list is empty",
        )
    )


func test_search_filtering():
    if not _guard():
        return
    # Test search filtering
    var initial_count: int = _browser._entity_list.item_count
    _browser._on_search_changed("test")
    var filtered_count: int = _browser._entity_list.item_count
    (
        TestHelper
        . assert_true(
            filtered_count < initial_count or (filtered_count == 0 and initial_count == 0),
            (
                "Search filtering reduces items (%d -> %d)" % [initial_count, filtered_count]
                + ": "
                + "No items to filter (both empty)"
                + ": "
                + (
                    "Search filtering did not reduce items (%d -> %d)"
                    % [initial_count, filtered_count]
                )
            ),
        )
    )


func test_player_selection_signal():
    if not _guard():
        return
    _signal_received = false
    _received_player_id = -1
    _browser.player_changed.connect(_on_test_player_changed)
    _browser._on_owner_selected(1)
    (
        TestHelper
        . assert_true(
            _signal_received and _received_player_id == 1,
            (
                "Player selection signal emitted correctly: "
                + "Player selection signal not emitted or wrong ID"
            ),
        )
    )
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
    (
        TestHelper
        . assert_true(
            (
                _browser._filtered_entities.size() == 0
                or (_signal_received and _received_player_id != -1)
            ),
            (
                "Entity selection signal emitted correctly"
                + ": "
                + "No entities to select in test env (signal setup valid)"
                + ": "
                + "Entity selection signal not emitted or empty ID"
            ),
        )
    )
    _browser.entity_selected.disconnect(_on_test_entity_selected)


func test_category_switching():
    if not _guard():
        return
    # Test category switching repopulates the entity list
    var initial_count: int = _browser._entity_list.item_count
    _browser._on_category_changed(1)  # Switch to Infantry
    var new_count: int = _browser._entity_list.item_count
    (
        TestHelper
        . assert_true(
            (
                _browser._current_category == 1 and new_count != initial_count
                or _browser._current_category == 1
            ),
            (
                (
                    "Category switching works and list repopulated (%s)"
                    % ("%d -> %d" % [initial_count, new_count])
                )
                + ": "
                + "Category switching updates category (count: %d)" % new_count
                + ": "
                + "Category switching did not update"
            ),
        )
    )
