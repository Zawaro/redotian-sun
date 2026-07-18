class_name ArtData extends Resource

@export var id: String = ""
@export var is_voxel: bool = false
@export var is_remapable: bool = false
@export var foundation: Vector2i = Vector2i(1, 1)
@export var height: float = 1.0
@export var turret_offset: float = 0.0
@export var barrel_length: float = 0.0
@export var primary_fire_flh: Vector3 = Vector3.ZERO
@export var secondary_fire_flh: Vector3 = Vector3.ZERO
@export var model_path: String = ""
@export var texture_path: String = ""
@export var cameo_path: String = ""
@export var buildup_scene: String = ""
@export var active_anims: Array[ActiveAnimData] = []
@export var new_theater: bool = false
@export var flat: bool = false
@export var extra_damage_stage: bool = false
@export var terrain_palette: bool = false
@export var placeholder_size: Vector3 = Vector3.ZERO
@export var outline_2d_size: Vector2 = Vector2.ZERO
## Number of cargo/passenger pips to display on the selection overlay (0 = use default).
@export var pip_count: int = 0
@export var demand_load: bool = false
## Whether this entity's material emits light (triggers bloom/glow).
@export var emission_enabled: bool = false
## Color of emitted light. Only used when emission_enabled is true.
@export var emission_color: Color = Color.BLACK
## Multiplier for emission brightness. Values > 1.0 trigger bloom.
## Only used when emission_enabled is true.
@export var emission_energy_multiplier: float = 1.0
## Whether this entity spawns an OmniLight3D for environmental illumination.
@export var point_light_enabled: bool = false
## Color of the point light. Only used when point_light_enabled is true.
@export var point_light_color: Color = Color.WHITE
## Brightness of the point light. Only used when point_light_enabled is true.
@export var point_light_energy: float = 1.0
## Maximum distance the point light reaches. Only used when point_light_enabled is true.
@export var point_light_range: float = 5.0
## Falloff sharpness. Higher = sharper falloff. Only used when point_light_enabled is true.
@export var point_light_attenuation: float = 2.0


func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("ArtData: id is empty")
    for anim in active_anims:
        if anim and anim.anim_name.is_empty():
            errors.append("%s: active_anim has empty anim_name" % id)
    return errors
