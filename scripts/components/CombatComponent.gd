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

## World-space separation at which airborne attackers stop nudging each other.
const MIN_AIR_SEPARATION: float = 1.5

@export_group("Combat")
@export var weapons: Array[WeaponData] = []
@export var elite_weapons: Array[WeaponData] = []
@export var turret: bool = false
@export var turret_anim: String = ""
@export var threat_posed: int = 0

var _current_weapon_index: int = 0
var _target: Node3D = null
var _cooldowns: Array[float] = []
var _attack_active: bool = false
var _mc_connected: bool = false
var _combat_move: bool = false
var _connected_health_target: Node3D = null
var _fire_count: int = 0


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


func get_effective_damage(weapon: WeaponData) -> int:
    if not weapon:
        return 0
    var stats := get_parent().get_node_or_null("StatsComponent") as StatsComponent
    if not stats or stats.veteran_level <= 0:
        return weapon.damage
    var rules := GlobalRules.get_current()
    if not rules:
        return weapon.damage
    var mult := rules.get_veteran_combat_multiplier(stats.veteran_level)
    return roundi(weapon.damage * mult)


func get_weapon_count() -> int:
    return weapons.size()


func cycle_weapon() -> void:
    if not weapons.is_empty():
        _current_weapon_index = (_current_weapon_index + 1) % weapons.size()


func get_target() -> Node3D:
    return _target


func set_target(entity: Node3D) -> void:
    _target = entity
    _attack_active = true
    _connect_mc_signal()
    _connect_health_signal()
    var mc := get_parent().get_node_or_null("MovementController") as MovementController
    if mc:
        mc.cancel_move_retain_vertical()


func clear_target() -> void:
    _disconnect_health_signal()
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
    var weapon := get_current_weapon()
    if not weapon:
        clear_target()
        return
    var weapon_idx := _current_weapon_index
    if weapon_idx < _cooldowns.size():
        _cooldowns[weapon_idx] = maxf(_cooldowns[weapon_idx] - delta, 0.0)
    var range_world := weapon.attack_range * CellUtil.CELL_SIZE
    var to_target := _target.global_position - global_position
    var horizontal_distance := Vector3(to_target.x, 0.0, to_target.z).length()
    if horizontal_distance <= range_world:
        if weapon_idx < _cooldowns.size() and _cooldowns[weapon_idx] <= 0.0:
            _fire_weapon(weapon, _target)
    else:
        _move_toward_target()


func _fire_weapon(weapon: WeaponData, target: Node3D) -> void:
    var health := target.get_node_or_null("HealthComponent") as HealthComponent
    if not health:
        return
    var damage := get_effective_damage(weapon)
    var target_stats := target.get_node_or_null("StatsComponent") as StatsComponent
    var target_armor := target_stats.armor if target_stats else "none"
    var rules := GlobalRules.get_current()
    if rules:
        var mult := rules.get_warhead_armor_multiplier(weapon.warhead, target_armor)
        if mult > 0.0:
            damage = clampi(roundi(damage * mult), rules.min_damage, rules.max_damage)
        else:
            damage = 0
    health.take_damage(damage, weapon.warhead)
    _fire_count += 1
    var rof: float = maxf(weapon.rate_of_fire, 0.001)
    _cooldowns[_current_weapon_index] = 60.0 / rof
    _play_fire_sound(weapon)
    weapon_fired.emit(weapon, target)


func _play_fire_sound(weapon: WeaponData) -> void:
    var report := weapon.sound_report
    if report.is_empty():
        return
    var ids := report.split(",")
    var chosen := ids[randi() % ids.size()]
    AudioManager.play_sound(chosen.strip_edges(), global_position)


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
        var stop_pos: Vector3
        if mc.is_airborne_jumpjet():
            # Shortest air path: approach the target head-on to weapon range,
            # then nudge off any airborne jumpjets already there so the group
            # spreads dynamically instead of stacking on one point.
            var approach_dir := Vector3(to_target.x, 0.0, to_target.z).normalized()
            var base_pos := _target.global_position - approach_dir * range_world
            stop_pos = (
                base_pos
                + _air_repulsion(
                    entity.global_position, _nearby_airborne_jumpjets(entity), range_world
                )
            )
            # Never push an attacker out of firing range: pull any overshoot
            # back onto the range circle so it fires on arrival instead of
            # bouncing back to re-approach.
            var stop_offset := _target.global_position - stop_pos
            if stop_offset.length() > range_world:
                stop_pos = _target.global_position - stop_offset.normalized() * range_world
        else:
            var angle := atan2(to_target.x, to_target.z)
            stop_pos = (
                _target.global_position
                - Vector3(sin(angle) * range_world, 0.0, cos(angle) * range_world)
            )
        _combat_move = true
        mc.set_target_position(stop_pos, false, true)


## World-space positions of airborne jumpjets within the 3x3 cells around the
## entity, used to spread attacking jumpjets without hard reservation.
func _nearby_airborne_jumpjets(entity: Node3D) -> Array[Vector3]:
    var result: Array[Vector3] = []
    var cell := CellUtil.world_to_cell(entity.global_position)
    for dx in range(-1, 2):
        for dz in range(-1, 2):
            for entry in SpatialHash.instance.get_entries(cell + Vector2i(dx, dz)):
                var other := entry.node as Node3D
                if not is_instance_valid(other) or other == entity:
                    continue
                var other_mc := entry.mc as MovementController
                if other_mc and other_mc.is_airborne_jumpjet():
                    result.append(other.global_position)
    return result


## Push vector away from close airborne jumpjets, linearly tapering to zero at
## MIN_AIR_SEPARATION and capped so a cluster stays near attack range.
func _air_repulsion(from: Vector3, neighbors: Array[Vector3], range_world: float) -> Vector3:
    var push := Vector3.ZERO
    for other in neighbors:
        var diff := from - other
        diff.y = 0.0
        var dist := diff.length()
        if dist > 0.01 and dist < MIN_AIR_SEPARATION:
            push += diff / dist * (1.0 - dist / MIN_AIR_SEPARATION)
    var cap := minf(MIN_AIR_SEPARATION, range_world * 0.25)
    return push.limit_length(cap)


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
        mc.pathfinding_failed.connect(_on_pathfinding_failed)
        _mc_connected = true


func _connect_health_signal() -> void:
    if not _target:
        return
    if _connected_health_target == _target:
        return
    _disconnect_health_signal()
    _connected_health_target = _target
    var hc := _target.get_node_or_null("HealthComponent") as HealthComponent
    if hc:
        hc.health_zero.connect(_on_target_health_zero)


func _disconnect_health_signal() -> void:
    if not _connected_health_target or not is_instance_valid(_connected_health_target):
        _connected_health_target = null
        return
    var hc := _connected_health_target.get_node_or_null("HealthComponent") as HealthComponent
    if hc and hc.health_zero.is_connected(_on_target_health_zero):
        hc.health_zero.disconnect(_on_target_health_zero)
    _connected_health_target = null


func _on_target_health_zero() -> void:
    clear_target()


func _on_movement_arrived(_position: Vector3) -> void:
    pass


func _on_movement_started() -> void:
    if _combat_move:
        _combat_move = false
        return
    clear_target()


func _on_pathfinding_failed() -> void:
    # A failed move never emits movement_started, so clear the combat-approach
    # flag here to avoid it consuming a later move order's signal.
    _combat_move = false
