extends Node

# Sidebar tabs are per-game data: declared tabs build in order, feature-gated
# tabs hide, absent-tab hotkeys are no-ops, and games may declare more tabs than
# the scene's button pool without unique-name collisions.

const SIDEBAR_SCENE := preload("res://scenes/ui/Sidebar.tscn")
const SidebarScript := preload("res://scripts/ui/Sidebar.gd")
const FIXTURES: String = "res://test/fixtures/gamectx"

var _gc: Node = null
var _sidebar: Control = null


func _ready() -> void:
    if has_node("/root/GameContext"):
        _gc = get_node("/root/GameContext")


func _register_def(id: String, tabs: Array) -> void:
    var def := GameDefinition.new()
    def.id = id
    def.rules = load(FIXTURES + "/rules.tres") as GlobalRules
    var typed: Array[Dictionary] = []
    for tab in tabs:
        typed.append(tab)
    def.sidebar_tabs = typed
    _gc._defs[id] = def


func _sidebar_instance() -> Control:
    if _sidebar == null:
        _sidebar = SIDEBAR_SCENE.instantiate() as Control
        Engine.get_main_loop().root.add_child(_sidebar)
    return _sidebar


func _free_sidebar() -> void:
    if is_instance_valid(_sidebar):
        _sidebar.free()
    _sidebar = null


func test_declared_tabs_build_in_order():
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_def(
        "tabs_order",
        [
            {"name": "Structures", "entity_types": ["BUILDING"]},
            {"name": "Troops", "entity_types": ["INFANTRY"]},
        ]
    )
    _gc.select_game("tabs_order")
    var sb := _sidebar_instance()
    TestHelper.assert_eq(sb.tab_buttons.size(), 2, "two declared tabs")
    TestHelper.assert_eq(sb.tab_buttons[0].text, "Structures", "first tab label")
    TestHelper.assert_eq(sb.tab_buttons[1].text, "Troops", "second tab label")
    _free_sidebar()
    TestHelper.restore_game_context(_gc, snap)


func test_feature_gated_tab_hidden():
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_def(
        "tabs_gate",
        [
            {"name": "Structures", "entity_types": ["BUILDING"]},
            {"name": "Superweapons", "entity_types": [], "requires_feature": "superweapons"},
        ]
    )
    _gc.select_game("tabs_gate")
    var sb := _sidebar_instance()
    TestHelper.assert_eq(sb.tab_buttons.size(), 1, "feature-gated tab hidden")
    TestHelper.assert_eq(sb.tab_buttons[0].text, "Structures", "remaining tab shown")
    _free_sidebar()
    TestHelper.restore_game_context(_gc, snap)


func test_absent_tab_hotkey_is_noop():
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_def("tabs_one", [{"name": "Structures", "entity_types": ["BUILDING"]}])
    _gc.select_game("tabs_one")
    var sb := _sidebar_instance()

    var absent := InputEventAction.new()
    absent.action = "tab_special"
    absent.pressed = true
    TestHelper.assert_eq(sb._hotkey_tab_index(absent), -1, "absent tab hotkey is a no-op")

    var present := InputEventAction.new()
    present.action = "tab_buildings"
    present.pressed = true
    TestHelper.assert_eq(sb._hotkey_tab_index(present), 0, "declared tab hotkey resolves")
    _free_sidebar()
    TestHelper.restore_game_context(_gc, snap)


func test_more_tabs_than_scene_buttons():
    var snap := TestHelper.snapshot_game_context(_gc)
    var tabs: Array = []
    for i in 6:
        tabs.append({"name": "Tab%d" % i, "entity_types": ["BUILDING"]})
    _register_def("tabs_six", tabs)
    _gc.select_game("tabs_six")
    var sb := _sidebar_instance()
    TestHelper.assert_eq(sb.tab_buttons.size(), 6, "six declared tabs build")
    var seen: Dictionary = {}
    for btn in sb.tab_buttons:
        TestHelper.assert_true(not seen.has(btn.name), "button name %s unique" % btn.name)
        seen[btn.name] = true
    TestHelper.assert_true(
        not sb.tab_buttons[5].unique_name_in_owner, "duplicated tab is not unique-named"
    )
    _free_sidebar()
    TestHelper.restore_game_context(_gc, snap)


func test_rank_follows_declared_tab_order():
    var aircraft := EntityData.new()
    aircraft.id = "a"
    aircraft.entity_type = EntityData.EntityType.AIRCRAFT
    var vehicle := EntityData.new()
    vehicle.id = "v"
    vehicle.entity_type = EntityData.EntityType.VEHICLE
    var tab_types: Array = [["AIRCRAFT"], ["VEHICLE"]]
    var sorted: Array = SidebarScript.sort_buildables([aircraft, vehicle], tab_types)
    TestHelper.assert_eq(sorted[0].id, "a", "declared first tab ranks first")
    TestHelper.assert_eq(sorted[1].id, "v", "declared second tab ranks second")
