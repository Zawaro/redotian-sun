extends PanelContainer

## Entity browser panel for MapEditor — provides entity type selection,
## player assignment, and search functionality.

signal entity_selected(entity_id: String)
signal player_changed(player_id: int)

var _category_tabs: TabBar
var _owner_dropdown: OptionButton
var _search_bar: LineEdit
var _entity_list: ItemList
var _entities: Array[EntityData] = []
var _filtered_entities: Array[EntityData] = []
var _current_category: int = 0

const CATEGORIES: Dictionary = {
    "Buildings": EntityData.EntityType.BUILDING,
    "Infantry": EntityData.EntityType.INFANTRY,
    "Vehicles": EntityData.EntityType.VEHICLE,
    "Aircraft": EntityData.EntityType.AIRCRAFT,
    "Naval": EntityData.EntityType.VEHICLE,  # Naval uses VEHICLE type for now
}


func _ready() -> void:
    _setup_ui()
    _populate_entities()


func _setup_ui() -> void:
    custom_minimum_size = Vector2(250, 500)
    size_flags_horizontal = Control.SIZE_SHRINK_END
    size_flags_vertical = Control.SIZE_EXPAND_FILL

    var vbox := VBoxContainer.new()
    vbox.name = "VBox"
    add_child(vbox)

    # Category tabs
    _category_tabs = TabBar.new()
    _category_tabs.name = "CategoryTabs"
    for cat_name in CATEGORIES.keys():
        _category_tabs.add_tab(cat_name)
    _category_tabs.tab_changed.connect(_on_category_changed)
    vbox.add_child(_category_tabs)

    # Owner dropdown
    var owner_hbox := HBoxContainer.new()
    owner_hbox.name = "OwnerRow"
    vbox.add_child(owner_hbox)

    var owner_label := Label.new()
    owner_label.text = "Owner:"
    owner_hbox.add_child(owner_label)

    _owner_dropdown = OptionButton.new()
    _owner_dropdown.name = "OwnerDropdown"
    _owner_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _owner_dropdown.add_item("Player 0", 0)
    _owner_dropdown.add_item("Player 1", 1)
    _owner_dropdown.item_selected.connect(_on_owner_selected)
    owner_hbox.add_child(_owner_dropdown)

    # Search bar
    _search_bar = LineEdit.new()
    _search_bar.name = "SearchBar"
    _search_bar.placeholder_text = "Search entity... (CTRL+F)"
    _search_bar.text_changed.connect(_on_search_changed)
    vbox.add_child(_search_bar)

    # Entity list
    _entity_list = ItemList.new()
    _entity_list.name = "EntityList"
    _entity_list.custom_minimum_size = Vector2(0, 200)
    _entity_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _entity_list.allow_reselect = true
    _entity_list.item_selected.connect(_on_entity_selected)
    vbox.add_child(_entity_list)


func _populate_entities() -> void:
    var cat_name: String = CATEGORIES.keys()[_current_category]
    var entity_type: EntityData.EntityType = CATEGORIES[cat_name]
    _entities = EntityFactory.get_all_by_type(entity_type)
    if _entities.is_empty():
        push_warning("EntityBrowser: No entities found for category %s" % cat_name)
    _refresh_list()


func _refresh_list(filter: String = "") -> void:
    _entity_list.clear()
    _filtered_entities.clear()
    for entity in _entities:
        if entity.id.is_empty():
            continue
        if (
            filter.is_empty()
            or entity.display_name.containsn(filter)
            or entity.id.containsn(filter)
        ):
            _entity_list.add_item("%s (%s)" % [entity.display_name, entity.id])
            _filtered_entities.append(entity)


func _on_category_changed(tab: int) -> void:
    _current_category = tab
    _populate_entities()


func _on_owner_selected(index: int) -> void:
    player_changed.emit(index)


func _on_search_changed(text: String) -> void:
    _refresh_list(text)


func _on_entity_selected(index: int) -> void:
    if index >= 0 and index < _filtered_entities.size():
        var entity_id: String = _filtered_entities[index].id
        if not entity_id.is_empty():
            entity_selected.emit(entity_id)


func set_player_count(count: int) -> void:
    _owner_dropdown.clear()
    for i in range(count):
        _owner_dropdown.add_item("Player %d" % i, i)
