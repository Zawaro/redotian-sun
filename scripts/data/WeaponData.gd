class_name WeaponData extends Resource

@export var id: String = ""
@export var damage: int = 0
@export var rate_of_fire: float = 1.0
@export var range: float = 1.0
@export var warhead: String = "HE"
@export var projectile: String = ""
@export var fire_flh: Vector3 = Vector3.ZERO
@export var barrel_length: float = 0.0
@export var anti_air: bool = false
@export var anti_ground: bool = true
@export var splash_radius: float = 0.0
@export var ammo: int = -1


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("WeaponData: id is empty")
    if damage < 0:
        errors.append("%s: damage must be >= 0" % id)
    if range <= 0.0:
        errors.append("%s: range must be > 0" % id)
    return errors
