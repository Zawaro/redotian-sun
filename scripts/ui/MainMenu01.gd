extends Control

# Called when the node enters the scene tree for the first time.
# Main menu controller – handles button clicks and exit logic

const GAMEPLAY_MAP_SCENE: String = "res://scenes/maps/TestMap02.tscn"


func _input(event):
    if event is InputEventMouseButton and event.pressed:
        var mouse_pos = get_viewport().get_mouse_position()
        for item in _collect_menu_items(self):
            if item.get("is_disabled"):
                continue
            var lbl: Label = item.get_node_or_null("Text") as Label
            if lbl and lbl.get_global_rect().has_point(mouse_pos):
                _handle_click(lbl.text)


func _collect_menu_items(node: Node) -> Array:
    var items: Array = []
    if node != self and node.has_node("Text") and "is_disabled" in node:
        items.append(node)
    for child in node.get_children():
        items.append_array(_collect_menu_items(child))
    return items


func _handle_click(button_text: String) -> void:
    match button_text:
        "Exit":
            get_tree().quit()
        "New Campaign":
            get_tree().call_deferred("change_scene_to_file", GAMEPLAY_MAP_SCENE)
        _:
            # Placeholder for other buttons – currently just log
            print("Clicked button: ", button_text)
