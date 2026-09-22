class_name CampaignDialog
extends Control

## Campaign dialog — the main menu's campaign picker. Lists one row per
## CampaignCatalog campaign (display_name, falling back to id), remembers the
## selection, and starts the selected campaign's first mission through
## GameContext. Deliberately plain standard Buttons/VBox, matching BootScreen —
## visual theming arrives with the content packs. MissionBoot owns hiding the
## menu and loading the map once a mission starts; this dialog only opens the
## flow.
##
## The dialog starts life as a child of MainMenu01 so the menu can reference
## it, but opening it moves it out to the menu's parent: hiding the menu would
## otherwise hide the dialog with it (visibility is inherited).

signal campaign_started(campaign_id: String)

var _selected_id: String = ""
var _row_buttons: Dictionary = {}

@onready var _rows: VBoxContainer = %Rows
@onready var _start_button: Button = %StartButton


func _ready() -> void:
    visible = false
    _start_button.pressed.connect(start_selected)
    var back: Button = %BackButton
    back.pressed.connect(close)


## Opens the dialog: rebuilds rows from the catalog, disables Start until a
## campaign is picked, and hides the main menu so it cannot react to clicks
## aimed at the dialog.
func open() -> void:
    _populate()
    var menu := _main_menu()
    if menu:
        if menu.is_ancestor_of(self):
            var host := menu.get_parent()
            if host:
                reparent(host)
        menu.visible = false
    visible = true


## Closes the dialog and restores the main menu.
func close() -> void:
    visible = false
    var menu := _main_menu()
    if menu:
        menu.visible = true


## The currently selected campaign id, or "" when none is selected.
func selected_campaign_id() -> String:
    return _selected_id


## Remembers `campaign_id` as the selection and enables Start.
func select_campaign(campaign_id: String) -> void:
    _selected_id = campaign_id
    for id in _row_buttons:
        (_row_buttons[id] as Button).set_pressed_no_signal(id == campaign_id)
    _start_button.disabled = campaign_id.is_empty()


## Starts the selected campaign's first mission. Refuses (staying open) when no
## campaign is selected, its missions array is empty, or the first mission is
## not registered. Never loads a map — MissionBoot handles that.
func start_selected() -> void:
    var campaign: Campaign = CampaignCatalog.get_campaign(_selected_id)
    if campaign == null:
        return
    var first_id := campaign.first_mission_id()
    if first_id.is_empty():
        return
    GameContext.start_mission(first_id)
    var mission := GameContext.current_mission
    if mission == null or mission.id != first_id:
        return
    campaign_started.emit(_selected_id)
    visible = false


func _populate() -> void:
    for child in _rows.get_children():
        _rows.remove_child(child)
        child.queue_free()
    _row_buttons.clear()
    _selected_id = ""
    _start_button.disabled = true
    for campaign in CampaignCatalog.list_campaigns():
        var label := campaign.display_name
        if label.is_empty():
            label = campaign.id
        var button := Button.new()
        button.text = label
        button.toggle_mode = true
        button.pressed.connect(select_campaign.bind(campaign.id))
        _rows.add_child(button)
        _row_buttons[campaign.id] = button


## The MainMenu01 node, found as the parent or an ancestor sibling so the
## dialog works whether it is nested under the menu or has already been moved
## beside it.
func _main_menu() -> Control:
    var node := get_parent()
    while node != null:
        if node.has_method("_collect_menu_items"):
            return node as Control
        for sibling in node.get_children():
            if sibling != self and sibling.has_method("_collect_menu_items"):
                return sibling as Control
        node = node.get_parent()
    return null
