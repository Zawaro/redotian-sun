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

signal weapon_fired(weapon: WeaponData, target: Node3D)

@export_group("Combat")
@export var weapons: Array[WeaponData] = []
@export var elite_weapons: Array[WeaponData] = []
@export var turret: bool = false
@export var turret_anim: String = ""
@export var threat_posed: int = 0

var _current_weapon_index: int = 0
var _target: Node3D = null
var _cooldowns: Array = []
var _attack_active: bool = false
var _mc_connected: bool = false
var _combat_move: bool = false


func configure(data: EntityData) -> void:
    weapons = data.weapons
    elite_weapons = data.elite_weapons
    turret = data.turret
    turret_anim = data.turret_anim
    threat_posed = data.threat_posed
    _init_cooldowns()


func _init_cooldowns() -> void:
    _cooldowns.resize(weapons.size())
    for i in weapons.size():
        _cooldowns[i] = 0.0


func get_current_weapon() -> WeaponData:
    if weapons.is_empty():
        return null
    return weapons[_current_weapon_index]


func get_weapon_count() -> int:
    return weapons.size()


func cycle_weapon() -> void:
    if not weapons.is_empty():
        _current_weapon_index = (_current_weapon_index + 1) % weapons.size()


func set_target(entity: Node3D) -> void:
    _target = entity
    _attack_active = true
    _connect_mc_signal()
    _connect_health_signal()


func clear_target() -> void:
    _target = null
    _attack_active = false


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
    var stats := target.get_node_or_null("StatsComponent") as StatsComponent
    if stats and stats.player_id >= 0:
        if PlayerManager.is_enemy(stats.player_id, PlayerManager.get_local_player_id()):
            return CursorState.Type.ATTACK
    return CursorState.Type.DEFAULT


func get_order_for_target(
    target: Node3D,
    _target_cell: Vector2i,
    target_pos: Vector3,
    modifiers: Dictionary,
) -> OrderResult:
    if not target or weapons.is_empty():
        return null
    var force_attack: bool = modifiers.get(OrderResult.MOD_FORCE_ATTACK, false)
    var stats := target.get_node_or_null("StatsComponent") as StatsComponent
    if stats and stats.player_id >= 0:
        var local_id := PlayerManager.get_local_player_id()
        var is_enemy := PlayerManager.is_enemy(stats.player_id, local_id)
        if is_enemy or force_attack:
            var queued: bool = modifiers.get(OrderResult.MOD_QUEUED, false)
            return OrderResult.new(
                CursorState.Type.ATTACK,
                30,
                target,
                target_pos,
                queued,
                func(): _attack(target),
            )
    return null


func _attack(target: Node3D) -> void:
    set_target(target)


func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    if not _attack_active or not _target:
        return
    if not is_instance_valid(_target):
        clear_target()
        return
    if not _target.is_inside_tree():
        clear_target()
        return
    var weapon := get_current_weapon()
    if not weapon:
        clear_target()
        return
    var weapon_idx := _current_weapon_index
    if weapon_idx < _cooldowns.size():
        _cooldowns[weapon_idx] = maxf(_cooldowns[weapon_idx] - delta, 0.0)
    var range_world := weapon.attack_range * CellUtil.CELL_SIZE
    var distance := global_position.distance_to(_target.global_position)
    if distance <= range_world:
        if weapon_idx < _cooldowns.size() and _cooldowns[weapon_idx] <= 0.0:
            _fire_weapon(weapon, _target)
    else:
        _move_toward_target()


func _fire_weapon(weapon: WeaponData, target: Node3D) -> void:
    var health := target.get_node_or_null("HealthComponent") as HealthComponent
    if health:
        health.take_damage(weapon.damage, weapon.warhead)
    _cooldowns[_current_weapon_index] = 60.0 / weapon.rate_of_fire
    weapon_fired.emit(weapon, target)


func _move_toward_target() -> void:
    var entity := get_parent() as Node3D
    if not entity:
        return
    var mc := entity.get_node_or_null("MovementController") as MovementController
    if mc and not mc.is_moving():
        var weapon := get_current_weapon()
        if not weapon:
            return
        var range_world := weapon.attack_range * CellUtil.CELL_SIZE
        var to_target := _target.global_position - global_position
        var distance := to_target.length()
        if distance <= 0.01:
            return
        var angle := atan2(to_target.x, to_target.z)
        var stop_pos := (
            _target.global_position
            - Vector3(sin(angle) * range_world, 0.0, cos(angle) * range_world)
        )
        _combat_move = true
        mc.set_target_position(stop_pos)


func _connect_mc_signal() -> void:
    if _mc_connected:
        return
    var entity := get_parent() as Node3D
    if not entity:
        return
    var mc := entity.get_node_or_null("MovementController") as MovementController
    if mc:
        mc.arrived.connect(_on_movement_arrived)
        mc.movement_started.connect(_on_movement_started)
        _mc_connected = true


func _connect_health_signal() -> void:
    if not _target:
        return
    var hc := _target.get_node_or_null("HealthComponent") as HealthComponent
    if hc and not hc.health_zero.is_connected(_on_target_health_zero):
        hc.health_zero.connect(_on_target_health_zero)


func _on_target_health_zero() -> void:
    clear_target()


func _on_movement_arrived(_position: Vector3) -> void:
    pass


func _on_movement_started() -> void:
    if _combat_move:
        _combat_move = false
        return
    clear_target()
