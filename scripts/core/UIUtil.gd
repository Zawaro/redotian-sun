class_name UIUtil

## Static utilities for UI overlap detection.
## Use these instead of per-component UI checks.


## Returns true if the mouse is hovering over any Control node.
static func is_mouse_over_ui() -> bool:
    var vp: Viewport = Engine.get_main_loop().root.get_viewport()
    return vp.gui_get_hovered_control() != null


## Returns true if the mouse is over the Sidebar panel.
static func is_mouse_over_sidebar() -> bool:
    var sidebar := find_sidebar()
    if not sidebar:
        return false
    var vp: Viewport = Engine.get_main_loop().root.get_viewport()
    return sidebar.get_global_rect().has_point(vp.get_mouse_position())


## Returns true if the mouse is over the DebugMenu panel.
static func is_mouse_over_debug_menu() -> bool:
    var tree := Engine.get_main_loop() as SceneTree
    if not tree:
        return false
    var debug_menu := tree.get_first_node_in_group("debug_menu")
    if not debug_menu or not debug_menu.get("_is_open"):
        return false
    var content = debug_menu.get("content")
    if not content:
        return false
    var vp: Viewport = Engine.get_main_loop().root.get_viewport()
    return content.get_global_rect().has_point(vp.get_mouse_position())


## Walks up the parent chain from a node, checking if it is inside a
## named ancestor. Useful for checking hovered control ancestry.
static func is_inside_node(node: Node, ancestor_name: String) -> bool:
    while is_instance_valid(node):
        if node.name == ancestor_name:
            return true
        node = node.get_parent()
    return false


## Finds the Sidebar Control node in the current scene tree.
static func find_sidebar() -> Node:
    var tree := Engine.get_main_loop() as SceneTree
    if not tree or not tree.current_scene:
        return null
    return _find_recursive(tree.current_scene, "Sidebar")


static func _find_recursive(node: Node, target_name: String) -> Node:
    if node.name == target_name and node is Control:
        return node
    for child in node.get_children():
        var result := _find_recursive(child, target_name)
        if result:
            return result
    return null
