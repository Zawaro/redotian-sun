extends Node

## MissionBoot — the boot seam that turns an active Mission into a running map.
## A direct child of MainScene's root: connects the mission signal, applies the
## mission's overrides, and hosts MissionMap inside the Gameplay node. Also
## consumes the --mission CLI flag after autoloads are ready (D7).

const MISSION_MAP_SCENE: PackedScene = preload("res://scenes/maps/MissionMap.tscn")


func _ready() -> void:
    GameContext.mission_started.connect(_on_mission_started)
    var mission_id := _consume_mission_args(OS.get_cmdline_args(), OS.get_cmdline_user_args())
    if not mission_id.is_empty():
        GameContext.start_mission(mission_id)


## The --mission id from engine args, falling back to user args. Static-like pure
## helper so tests can drive it without real process args.
func _consume_mission_args(args: PackedStringArray, user_args: PackedStringArray) -> String:
    var mission_id := GameContext.extract_mission_id(args)
    if mission_id.is_empty():
        mission_id = GameContext.extract_mission_id(user_args)
    return mission_id


func _on_mission_started(mission: Mission) -> void:
    var gameplay := _find_gameplay()
    if gameplay == null:
        push_error("MissionBoot: no Gameplay node; cannot load mission '%s'" % mission.id)
        return
    for child in gameplay.get_children():
        child.queue_free()
    var map: Node = MISSION_MAP_SCENE.instantiate()
    gameplay.add_child(map)
    _hide_menu_overlays()
    PlayerManager.begin_mission(mission, map.find_child("MapConfig", true, false))


## Hides the menu overlays so a booted mission is the only visible surface.
## Covers the --mission launch path where BootScreen would otherwise occlude it.
func _hide_menu_overlays() -> void:
    var root := _scene_root()
    if root == null:
        return
    for overlay_name in ["MainMenu01", "BootScreen"]:
        var overlay := root.find_child(overlay_name, true, false) as CanvasItem
        if overlay:
            overlay.visible = false


func _find_gameplay() -> Node:
    var root := _scene_root()
    if root == null:
        return null
    return root.get_node_or_null("Gameplay")


## The scene that owns this node, with a fallback for a detached current scene.
func _scene_root() -> Node:
    var tree := get_tree()
    if tree and tree.current_scene:
        return tree.current_scene
    return get_parent()
