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
# - Use ArtData fields: primary_fire_offset, barrel_length, sequence,
#   walk_frames, firing_frames, and the role-tagged animation clips, etc.

signal weapon_fired(weapon: WeaponData, target: Node3D)

## Instantiated for each shot when the weapon's projectile id resolves.
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/components/Projectile.tscn")

## World-space separation at which airborne attackers stop nudging each other.
const MIN_AIR_SEPARATION: float = 1.5

## Fallback logic rate: WeaponData.rate_of_fire is a rearm delay in logic
## frames; seconds_between_shots = rate_of_fire / rules.logic_fps, falling back
## to this when no rules are active.
const DEFAULT_LOGIC_FPS: float = 30.0

## Minimum seconds between chase re-plans; bounds re-plan cost to the enemy's
## actual motion rate (#284 budget) and stops target jitter from oscillating
## a MOVING leg.
const CHASE_REPLAN_MIN_INTERVAL: float = 0.15

## Backoff after a failed chase path, so an unreachable target does not retry
## pathfinding every physics tick.
const CHASE_RETRY_BACKOFF: float = 0.5

@export_group("Combat")
@export var weapons: Array[WeaponData] = []
@export var elite_weapons: Array[WeaponData] = []
@export var threat_posed: int = 0


## One firing channel per weapon mount group, or per body-mounted weapon. Each
## channel keeps its own cooldown and alignment state, so a unit can fire
## several weapons / turrets on independent schedules.
class FireChannel:
    var weapon: WeaponData = null
    ## Empty = body-mounted (whole body faces the target).
    var socket_ids: PackedStringArray = PackedStringArray()
    ## true = sockets yaw to aim; false = body must face the target.
    var yaw_free: bool = false
    var fire_mode: int = WeaponMountGroupData.FireMode.SALVO
    var fire_delay: float = 0.0
    var cooldown: float = 0.0
    var aimed: bool = false
    ## Wind-up accumulator for a SALVO fire_delay.
    var windup: float = 0.0
    ## Active STAGGER burst: index of the next socket to fire (-1 = none).
    var burst_index: int = -1
    var burst_timer: float = 0.0


var _channels: Array[FireChannel] = []
var _target: Node3D = null
var _attack_active: bool = false
var _rotation_completed: bool = false
var _mc_connected: bool = false
var _combat_move: bool = false
var _connected_health_target: Node3D = null
var _fire_count: int = 0
## Grid cell of the target when the current chase leg was planned. A leg is
## stale the moment the target leaves this cell, so the chase can re-plan
## obstacle-aware instead of walking a straight line through new blockers.
var _chase_leg_enemy_cell: Vector2i = Vector2i.ZERO
var _last_chase_replan_time: float = 0.0
var _chase_retry_after: float = 0.0
var _logged_unreachable: Node3D = null
## Sibling PowerComponent, resolved once — components attach before tree entry.
## Non-null only for entities that require power; the offline gate then holds
## fire while retaining the current target for seamless power restoration.
var _power_component: PowerComponent = null
var _power_resolved: bool = false
## Sibling TurretComponent, resolved once. Non-null only for entities whose art
## declares sockets; it owns the per-socket yaw used for aim and rendering.
var _turret: TurretComponent = null
var _turret_resolved: bool = false


func configure(data: EntityData) -> void:
    weapons = data.weapons
    elite_weapons = data.elite_weapons
    threat_posed = data.threat_posed
    _build_channels(data.resolved_mount_groups(), data.art_data)


## Rebuilds firing channels from the given mount groups. A weapon not covered by
## a group becomes a body-mounted channel. Empty groups = all weapons body-mounted.
func _build_channels(groups: Array[WeaponMountGroupData], art_data: ArtData) -> void:
    _channels.clear()
    var covered: Dictionary = {}
    for group in groups:
        if group == null or group.weapon_index < 0 or group.weapon_index >= weapons.size():
            continue
        var weapon := weapons[group.weapon_index]
        if weapon == null:
            continue
        var channel := FireChannel.new()
        channel.weapon = weapon
        channel.socket_ids = group.socket_ids
        channel.fire_mode = group.fire_mode
        channel.fire_delay = group.fire_delay
        channel.yaw_free = _sockets_yaw_free(group.socket_ids, art_data)
        covered[group.weapon_index] = true
        _channels.append(channel)
    for i in weapons.size():
        if covered.has(i) or weapons[i] == null:
            continue
        var body_channel := FireChannel.new()
        body_channel.weapon = weapons[i]
        _channels.append(body_channel)


## Legacy/test helper: builds body-mounted channels from `weapons` and resets
## cooldowns. Production path is configure() → _build_channels().
func _init_cooldowns() -> void:
    var none: Array[WeaponMountGroupData] = []
    _build_channels(none, null)


## A group's sockets are all rotatable, or the group is body-facing.
func _sockets_yaw_free(socket_ids: PackedStringArray, art_data: ArtData) -> bool:
    if socket_ids.is_empty() or art_data == null:
        return false
    for socket_id in socket_ids:
        var socket := art_data.get_socket(socket_id)
        if socket == null or not socket.yaw_free:
            return false
    return true


func get_current_weapon() -> WeaponData:
    if _channels.is_empty():
        return null
    return _channels[0].weapon


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


func get_target() -> Node3D:
    return _target


func set_target(entity: Node3D) -> void:
    _target = entity
    _attack_active = true
    _rotation_completed = false
    _chase_retry_after = 0.0
    _logged_unreachable = null
    _reset_channel_runtime()
    _connect_mc_signal()
    _connect_health_signal()
    var mc := get_parent().get_node_or_null("MovementController") as MovementController
    if mc:
        if mc.is_airborne_jumpjet():
            mc.cancel_move_retain_vertical()
        else:
            mc.stop()
    _move_toward_target(true)


func clear_target() -> void:
    _disconnect_health_signal()
    _target = null
    _attack_active = false
    _rotation_completed = false
    _logged_unreachable = null
    _reset_channel_runtime()


## Clears per-channel burst/wind-up state when the engagement changes.
func _reset_channel_runtime() -> void:
    for channel in _channels:
        channel.burst_index = -1
        channel.burst_timer = 0.0
        channel.windup = 0.0
        channel.aimed = false


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
    _resolve_siblings()
    if _power_component and not _power_component.is_online:
        # Powered down: hold fire and freeze the engagement — no acquisition,
        # no shots, no chase moves. The target is kept so restoration resumes.
        return
    if not _attack_active or not _target:
        return
    if not is_instance_valid(_target):
        clear_target()
        return
    if _channels.is_empty():
        clear_target()
        return
    if not _target_in_range():
        # Keep turrets trained on the target while closing, so they track
        # continuously instead of freezing until the target re-enters range.
        _aim_turrets(delta)
        _move_toward_target()
        return
    var close := _horizontal_distance() <= CellUtil.CELL_SIZE
    # Body-facing is evaluated once per tick for body/fixed channels so
    # face_toward is not advanced multiple times in one frame.
    var body_aligned := true
    if _needs_body_facing() and not close:
        body_aligned = _is_facing_target(delta)
    for channel in _channels:
        _tick_channel(channel, delta, body_aligned, close)


## Resolves sibling components once, lazily (components attach before tree entry).
func _resolve_siblings() -> void:
    if _turret_resolved and _power_resolved:
        return
    var parent := get_parent()
    if parent == null:
        return
    if not _turret_resolved:
        _turret_resolved = true
        _turret = parent.get_node_or_null("TurretComponent") as TurretComponent
    if not _power_resolved:
        _power_resolved = true
        _power_component = parent.get_node_or_null("PowerComponent") as PowerComponent


## Whether any channel requires the body to face the target.
func _needs_body_facing() -> bool:
    for channel in _channels:
        if not channel.yaw_free:
            return true
    return false


## Slews every yaw-free mount at the target. Used on the chase path (target out
## of range); in-range ticks aim via _tick_channel.
func _aim_turrets(delta: float) -> void:
    if _turret == null or not is_instance_valid(_target):
        return
    for channel in _channels:
        if not channel.yaw_free:
            continue
        for socket_id in channel.socket_ids:
            _turret.slew(socket_id, _target.global_position, delta)


func _horizontal_distance() -> float:
    if not is_instance_valid(_target):
        return INF
    var to_target := _target.global_position - global_position
    return Vector3(to_target.x, 0.0, to_target.z).length()


## In range of the longest-reaching weapon; each channel then checks its own
## weapon range inside _tick_channel.
func _target_in_range() -> bool:
    var weapon := _longest_range_weapon()
    if weapon == null:
        return false
    return _horizontal_distance() <= weapon.attack_range * CellUtil.CELL_SIZE


func _longest_range_weapon() -> WeaponData:
    var best: WeaponData = null
    for channel in _channels:
        if channel.weapon and (best == null or channel.weapon.attack_range > best.attack_range):
            best = channel.weapon
    return best


## Advances one channel: aim (every tick, so turrets track continuously), then
## fire subject to that channel's own cooldown, range, and fire discipline.
func _tick_channel(channel: FireChannel, delta: float, body_aligned: bool, close: bool) -> void:
    channel.cooldown = maxf(channel.cooldown - delta, 0.0)

    # Continue an in-flight STAGGER burst regardless of cooldown.
    if channel.burst_index >= 0:
        channel.burst_timer -= delta
        if channel.burst_timer <= 0.0:
            _fire_socket(channel, channel.burst_index)
            channel.burst_index += 1
            if channel.burst_index >= channel.socket_ids.size():
                channel.burst_index = -1
                channel.cooldown = _rof_seconds(channel.weapon)
            else:
                channel.burst_timer = maxf(channel.fire_delay, 0.0)
        return

    if channel.yaw_free and _turret:
        var aimed := true
        for socket_id in channel.socket_ids:
            if not _turret.slew(socket_id, _target.global_position, delta):
                aimed = false
        channel.aimed = aimed
    else:
        channel.aimed = body_aligned
    if close:
        channel.aimed = true

    if channel.cooldown > 0.0:
        channel.windup = 0.0
        return
    if not _channel_in_range(channel):
        return
    if not channel.aimed:
        channel.windup = 0.0
        return

    # SALVO wind-up before the volley.
    if channel.fire_mode == WeaponMountGroupData.FireMode.SALVO and channel.fire_delay > 0.0:
        channel.windup += delta
        if channel.windup < channel.fire_delay:
            return

    channel.windup = 0.0
    _fire_channel(channel)


func _channel_in_range(channel: FireChannel) -> bool:
    if channel.weapon == null:
        return false
    return _horizontal_distance() <= channel.weapon.attack_range * CellUtil.CELL_SIZE


## Fires a channel's socket(s) per its fire discipline. SALVO and single-socket
## groups fire immediately; STAGGER schedules the rest of the burst.
func _fire_channel(channel: FireChannel) -> void:
    if channel.socket_ids.is_empty():
        _fire_weapon(channel.weapon, _target)
        channel.cooldown = _rof_seconds(channel.weapon)
        return
    if channel.fire_mode == WeaponMountGroupData.FireMode.STAGGER and channel.socket_ids.size() > 1:
        _fire_socket(channel, 0)
        channel.burst_index = 1
        channel.burst_timer = maxf(channel.fire_delay, 0.0)
        return
    for i in channel.socket_ids.size():
        _fire_socket(channel, i)
    channel.cooldown = _rof_seconds(channel.weapon)


func _fire_socket(channel: FireChannel, index: int) -> void:
    var muzzle := Vector3.INF
    if _turret and index < channel.socket_ids.size():
        muzzle = _turret.get_muzzle_world_transform(channel.socket_ids[index]).origin
    _fire_weapon(channel.weapon, _target, muzzle)


func _rof_seconds(weapon: WeaponData) -> float:
    var rules := GlobalRules.get_current()
    var logic_fps: float = rules.logic_fps if rules else DEFAULT_LOGIC_FPS
    return maxf(weapon.rate_of_fire, 0.001) / logic_fps


## Body-facing gate for body-mounted / fixed-socket weapons. Returns true when
## the attacker is aligned (or exempt): no MovementController sibling (buildings,
## speed = 0) — exempt means rotation is complete, so fire is never gated —
## or idle / waiting, where the body slews via face_toward so blocked
## attackers keep shooting once aligned. A live MOVING / ROTATING leg owns
## the yaw, so the gate holds fire for those ticks instead; the shot comes
## after the leg ends and the body has slewed onto the target.
func _is_facing_target(delta: float) -> bool:
    var entity := get_parent() as Node3D
    if not entity:
        _rotation_completed = true
        return true
    var mc := entity.get_node_or_null("MovementController") as MovementController
    if not mc:
        _rotation_completed = true
        return true
    if mc.is_moving() and not mc.is_waiting():
        return false
    _rotation_completed = mc.face_toward(_target.global_position, delta)
    return _rotation_completed


func _fire_weapon(weapon: WeaponData, target: Node3D, muzzle_origin: Vector3 = Vector3.INF) -> void:
    if not muzzle_origin.is_finite():
        muzzle_origin = _body_muzzle_origin(weapon)
    var projectile_data: ProjectileData = _resolve_projectile(weapon)
    if projectile_data:
        _spawn_projectile(projectile_data, weapon, target, muzzle_origin)
    else:
        _apply_hitscan_damage(weapon, target)
    _fire_count += 1
    _play_fire_sound(weapon)
    weapon_fired.emit(weapon, target)


## Body-mounted muzzle: entity position offset by the weapon fire offset. FLH
## art data + turret-relative rotation belong to #326.
func _body_muzzle_origin(weapon: WeaponData) -> Vector3:
    var shooter := get_parent() as Node3D
    if shooter == null:
        return global_position + weapon.fire_offset
    return shooter.global_position + weapon.fire_offset


## Resolves weapon.projectile through the GlobalRules registry; null when the
## id is empty or unresolvable, which falls back to direct hitscan damage.
func _resolve_projectile(weapon: WeaponData) -> ProjectileData:
    if weapon.projectile.is_empty():
        return null
    var rules := GlobalRules.get_current()
    if not rules:
        return null
    return rules.get_projectile(weapon.projectile)


func _spawn_projectile(
    data: ProjectileData, weapon: WeaponData, target: Node3D, muzzle_origin: Vector3
) -> void:
    var shooter := get_parent() as Node3D
    if not shooter:
        return
    var projectile := PROJECTILE_SCENE.instantiate() as ProjectileController
    if not projectile:
        return
    projectile.setup(data, weapon, shooter, target)
    projectile.set_spawn_origin(muzzle_origin)
    var container: Node = null
    var tree := shooter.get_tree()
    if tree:
        container = tree.current_scene
    if not container:
        container = shooter.get_parent()
    if not container:
        push_error("CombatComponent: no container for projectile spawn — shot consumed")
        projectile.free()
        return
    container.add_child(projectile)


func _apply_hitscan_damage(weapon: WeaponData, target: Node3D) -> void:
    var health := target.get_node_or_null("HealthComponent") as HealthComponent
    if not health:
        return
    var target_stats := target.get_node_or_null("StatsComponent") as StatsComponent
    var target_armor := target_stats.armor if target_stats else "none"
    var damage := GlobalRules.compute_warhead_damage(
        get_effective_damage(weapon), weapon.warhead, target_armor
    )
    health.take_damage(damage, weapon.warhead)


func _play_fire_sound(weapon: WeaponData) -> void:
    var report := weapon.sound_report
    if report.is_empty():
        return
    AudioManager.play_report(report.split(",", false), global_position)


func _move_toward_target(force: bool = false) -> void:
    var entity := get_parent() as Node3D
    if not entity:
        return
    var mc := entity.get_node_or_null("MovementController") as MovementController
    if not mc:
        return
    if not force and not _should_replan(mc):
        return
    var weapon := _longest_range_weapon()
    if not weapon:
        return
    var range_world := weapon.attack_range * CellUtil.CELL_SIZE
    var to_target := _target.global_position - global_position
    var horizontal_distance := Vector3(to_target.x, 0.0, to_target.z).length()
    if horizontal_distance <= range_world:
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
            + _air_repulsion(entity.global_position, _nearby_airborne_jumpjets(entity), range_world)
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
        # A chase stop can land inside a building footprint when the enemy hugs
        # a wall: relocate to the nearest passable cell so the destination is
        # never blocked before the move is even issued.
        stop_pos = CellUtil.cell_to_world(
            mc.find_nearest_free_cell(CellUtil.world_to_cell(stop_pos))
        )
        # Relocation can push the stop beyond weapon range (short-range units).
        # Pull it back inside the range circle so the attacker fires on arrival
        # instead of idling out of range and re-planning forever. If it still
        # cannot be kept in range and passable, back off like a failed path.
        var re_to_target := _target.global_position - stop_pos
        var re_dist := Vector3(re_to_target.x, 0.0, re_to_target.z).length()
        if re_dist > range_world + 0.01:
            var approach := Vector3(to_target.x, 0.0, to_target.z).normalized()
            var inner := maxf(range_world - CellUtil.CELL_SIZE, range_world * 0.5)
            stop_pos = _target.global_position - approach * inner
            stop_pos = CellUtil.cell_to_world(
                mc.find_nearest_free_cell(CellUtil.world_to_cell(stop_pos))
            )
            var re2 := (
                Vector3(
                    _target.global_position.x - stop_pos.x,
                    0.0,
                    _target.global_position.z - stop_pos.z,
                )
                . length()
            )
            if re2 > range_world + 0.01:
                _chase_retry_after = _now() + CHASE_RETRY_BACKOFF
                return
    _combat_move = true
    _chase_leg_enemy_cell = CellUtil.world_to_cell(_target.global_position)
    _last_chase_replan_time = _now()
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
    _chase_retry_after = _now() + CHASE_RETRY_BACKOFF
    if is_instance_valid(_target) and _logged_unreachable != _target:
        _logged_unreachable = _target
        push_warning(
            (
                "[CombatComponent] chase pathfinding failed; target unreachable (retry in %.2fs)"
                % CHASE_RETRY_BACKOFF
            )
        )


## Whether a fresh approach move may be issued right now. Always true when the
## controller is idle or waiting; for a real MOVING/ROTATING leg only when the
## target has left the cell the leg was planned against (stale geometry) and the
## re-plan throttle has elapsed. False during the failed-path retry backoff.
func _should_replan(mc: MovementController) -> bool:
    var now := _now()
    if now < _chase_retry_after:
        return false
    if not is_instance_valid(_target):
        return false
    if not mc.is_moving() or mc.is_waiting():
        return true
    if now - _last_chase_replan_time < CHASE_REPLAN_MIN_INTERVAL:
        return false
    return CellUtil.world_to_cell(_target.global_position) != _chase_leg_enemy_cell


func _now() -> float:
    return Time.get_ticks_msec() / 1000.0
