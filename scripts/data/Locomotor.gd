class_name Locomotor extends Resource

@export_group("Locomotor")
## Unique identifier (e.g. "Foot", "Track", "Ship").
@export var id: String = ""
## Terrain speed multipliers per land type id (0.0/absent = impassable, 1.0 = full, 1.2 = bonus).
@export var terrain_speeds: Dictionary = {}
## Max height levels a unit can ascend/descend in one cell transition.
@export var climb_tolerance: int = 1
## Crushable categories this locomotor can crush (documentation; actual crush is per-entity).
@export var crushes: PackedStringArray = []

@export_group("Behavior Flags")
## Hover: ignores slope coefficients, floats above terrain.
@export var is_hover: bool = false
## Fly: air-only, ignores terrain and height restrictions.
@export var is_fly: bool = false
## Jumpjet: walks by foot, flies when the target is far or unreachable by walk.
@export var is_jumpjet: bool = false
## Subterranean: travels on the surface, digs when the target is far or unreachable.
@export var is_subterranean: bool = false

@export_group("Hybrid Thresholds")
## Hover height in world units; 0 = use GlobalRules.hover_height.
@export var hover_height_override: float = 0.0
## Jumpjet flies when the straight-line distance exceeds this (world units);
## 0 = fly only when walking is impossible.
@export var jumpjet_fly_distance: float = 0.0
## Jumpjet flight altitude above terrain, in terrain height units
## (each = TerrainSystem.HEIGHT_STEP world units); default 6.0 = 6 height levels.
@export var jumpjet_target_height: float = 6.0
## Subterranean digs when the straight-line distance exceeds this (world units);
## 0 = dig only when surface travel is impossible.
@export var subterranean_dig_distance: float = 0.0


## Whether this locomotor can traverse a cell of the given land type. Fly and
## hover pass everything; others only pass land types with a positive speed.
func is_passable(land_type_id: String) -> bool:
    if is_fly or is_hover:
        return true
    return terrain_speeds.get(land_type_id, 0.0) > 0.0


## Speed multiplier for a land type. Land types absent from the table are full
## speed (1.0) when passability was already allowed elsewhere.
func get_speed_multiplier(land_type_id: String) -> float:
    if not terrain_speeds.has(land_type_id):
        return 1.0
    return terrain_speeds[land_type_id]
