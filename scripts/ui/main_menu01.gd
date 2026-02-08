extends Control


# Called when the node enters the scene tree for the first time.
# Main menu controller – handles button clicks and exit logic

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		for child in get_children():
			# Ensure we are dealing with a button instance that contains a Label named "Text"
			if child.is_inside_tree() and child.has_method("get_node"):
				var lbl = child.get_node_or_null("Text")
				if lbl and lbl.get_global_rect().has_point(mouse_pos):
					_handle_click(lbl.text)

func _handle_click(button_text: String) -> void:
	match button_text:
		"Exit":
			get_tree().quit()
		_:
			# Placeholder for other buttons – currently just log
			print("Clicked button: ", button_text)
