extends Label


func _process(_delta):
    set_text("FPS %d" % Engine.get_frames_per_second())
    var debug_menu := get_tree().get_first_node_in_group("debug_menu")
    if debug_menu and debug_menu._is_open:
        position.x = 420.0
    else:
        position.x = 0.0
