class_name LandType extends Resource

@export_group("Land Type")
## Unique identifier for this terrain surface (e.g. "clear", "water").
@export var id: String = ""
## Human-readable name shown in UI tooltips.
@export var display_name: String = ""
## Display color for editor/debug visualization.
@export var color: Color = Color.WHITE
