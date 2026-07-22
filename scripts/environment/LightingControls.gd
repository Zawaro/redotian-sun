extends Node3D
class_name LightingControls

## Sun settings — controls LightPivot rotation and DirectionalLight3D properties.
@export_range(0, 90) var sun_elevation: float = 36.0:
    set(value):
        sun_elevation = value
        _apply_sun()
@export_range(0, 360) var sun_rotation: float = 0.0:
    set(value):
        sun_rotation = value
        _apply_sun()
@export_range(0, 5) var sun_intensity: float = 1.0:
    set(value):
        sun_intensity = value
        _apply_sun()
@export var sun_color: Color = Color.WHITE:
    set(value):
        sun_color = value
        _apply_sun()
@export_range(0, 1) var shadow_strength: float = 0.9:
    set(value):
        shadow_strength = value
        _apply_shadow()

## Environment settings — controls WorldEnvironment properties.
@export_range(0, 2) var ambient_light: float = 1.0:
    set(value):
        ambient_light = value
        _apply_environment()
@export_range(0, 0.01) var fog_density: float = 0.001:
    set(value):
        fog_density = value
        _apply_environment()
@export_range(-1, 1) var sky_rotation: float = -0.18:
    set(value):
        sky_rotation = value
        _apply_environment()
@export_range(0, 2) var glow_intensity: float = 0.1:
    set(value):
        glow_intensity = value
        _apply_environment()

var _light_pivot: Node3D
var _directional_light: DirectionalLight3D
var _world_environment: WorldEnvironment
var _scene_defaults: Dictionary = {}


func _ready() -> void:
    _light_pivot = _find_node("LightPivot")
    if _light_pivot:
        _directional_light = (
            _light_pivot.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
        )
        var rot := _light_pivot.rotation
        sun_elevation = rad_to_deg(rot.x)
        sun_rotation = rad_to_deg(rot.y)
    var env_node := _find_node("WorldEnvironment")
    if env_node:
        _world_environment = env_node as WorldEnvironment
    _capture_scene_defaults()
    _apply_all()


func _find_node(node_name: String) -> Node:
    # Look in parent (MapBase01) for sibling nodes
    if get_parent():
        var node := get_parent().get_node_or_null(node_name)
        if node:
            return node
    # Fallback: search the scene tree
    return get_tree().get_first_node_in_group(node_name)


func _apply_all() -> void:
    _apply_sun()
    _apply_shadow()
    _apply_environment()


func _apply_sun() -> void:
    if not _light_pivot:
        return
    var elev_rad := deg_to_rad(sun_elevation)
    var rot_rad := deg_to_rad(sun_rotation)
    var z_rot := _light_pivot.rotation.z
    _light_pivot.rotation = Vector3(elev_rad, rot_rad, z_rot)
    if _directional_light:
        _directional_light.light_energy = sun_intensity
        _directional_light.light_color = sun_color


func _apply_shadow() -> void:
    if not _directional_light:
        return
    _directional_light.shadow_enabled = true
    _directional_light.shadow_opacity = shadow_strength
    _directional_light.shadow_blur = shadow_strength


func _apply_environment() -> void:
    if not _world_environment or not _world_environment.environment:
        return
    var env := _world_environment.environment
    env.ambient_light_energy = ambient_light
    env.fog_density = fog_density
    env.sky_rotation = Vector3(0.0, sky_rotation, 0.0)
    env.glow_intensity = glow_intensity


func _capture_scene_defaults() -> void:
    _scene_defaults = {
        "sun_elevation": sun_elevation,
        "sun_rotation": sun_rotation,
        "sun_intensity": sun_intensity,
        "sun_color": sun_color,
        "shadow_strength": shadow_strength,
        "ambient_light": ambient_light,
        "fog_density": fog_density,
        "sky_rotation": sky_rotation,
        "glow_intensity": glow_intensity,
    }


func get_defaults() -> Dictionary:
    return _scene_defaults.duplicate()
