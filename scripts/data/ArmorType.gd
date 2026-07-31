class_name ArmorType extends Resource

@export_group("Armor Type")
## Unique identifier for this armor type (e.g. "heavy").
@export var id: String = ""
## Human-readable name shown in UI tooltips.
@export var display_name: String = ""
## Display color for debug/UI elements (armor type overlays, debug visualization).
@export var color: Color = Color.WHITE
