@tool
class_name CombatComponent extends Node3D

# TODO: Combat system is incomplete. When implemented, this component needs to:
# - Resolve WeaponData.projectile → ProjectileData for trajectory/visuals
# - Resolve WeaponData.warhead → WarheadData for damage type, armor multipliers, effects
# - Handle negative WeaponData.damage as healing (call HealthComponent.heal())
# - Apply WeaponData.ambient_damage for continuous-damage weapons (sonic, flame)
# - Check ProjectileData.targets_air / targets_ground for valid targets
# - Use ProjectileData.homing_turn_rate, arm_delay, sub_projectile_count
# - Use WarheadData.armor_damage_multipliers for per-armor damage calculation
# - Apply WarheadData.sets_on_fire, WarheadData.rocks_target, WarheadData.produces_sparks
# - Use ArtData fields: primary_fire_offset, barrel_length, turret_offset, sequence,
#   walk_frames, firing_frames, buildup_name, door_anim, production_anim, etc.

@export var weapons: Array[WeaponData] = []
@export var elite_weapons: Array[WeaponData] = []
@export var turret: bool = false
@export var turret_anim: String = ""
@export var threat_posed: int = 0

var _current_weapon_index: int = 0


func configure(data: EntityData) -> void:
    weapons = data.weapons
    elite_weapons = data.elite_weapons
    turret = data.turret
    turret_anim = data.turret_anim
    threat_posed = data.threat_posed


func get_current_weapon() -> WeaponData:
    if weapons.is_empty():
        return null
    return weapons[_current_weapon_index]


func get_weapon_count() -> int:
    return weapons.size()


func cycle_weapon() -> void:
    if not weapons.is_empty():
        _current_weapon_index = (_current_weapon_index + 1) % weapons.size()


func validate(data: EntityData) -> PackedStringArray:
    var errors: PackedStringArray = []
    if data.weapons.is_empty():
        errors.append("CombatComponent: '%s' has no weapons" % data.id)
    for weapon in data.weapons:
        if weapon:
            var weapon_errors := weapon.validate()
            for err in weapon_errors:
                errors.append("CombatComponent: '%s' - %s" % [data.id, err])
    return errors


func get_cursor_for_target(target: Node3D, _target_cell: Vector2i) -> CursorState.Type:
    if not target or weapons.is_empty():
        return CursorState.Type.DEFAULT
    if target.is_in_group("enemy"):
        return CursorState.Type.ATTACK
    return CursorState.Type.DEFAULT
