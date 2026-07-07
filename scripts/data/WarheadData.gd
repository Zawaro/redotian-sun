class_name WarheadData extends Resource

@export var id: String = ""
@export var damage_modifier: float = 1.0
@export var cell_spread: float = 0.0
@export var death_anim: String = ""


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("WarheadData: id is empty")
    if damage_modifier < 0.0:
        errors.append("%s: damage_modifier must be >= 0" % id)
    return errors
