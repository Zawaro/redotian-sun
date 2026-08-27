class_name ProjectileController extends Area3D

## Runtime projectile: flies from the muzzle toward its target and detonates
## through the HitboxComponent pipeline. Flight behavior is picked from
## ProjectileData flags (teleport-detonate for invisible, straight/homing
## flight otherwise) — one controller, data-driven branches, mirroring how
## MovementController resolves locomotors.

## Emitted at the detonation point after damage has been forwarded.
signal impacted(position: Vector3)

## Close-proximity detonations snap the blast onto the victim center.
const SNAP_DISTANCE: float = 1.0

## Detonations within this radius of the victim snap onto its center.
const SNAP_RADIUS: float = SNAP_DISTANCE * 2.0

## ponytail: turn-rate scale is a tuning knob. ProjectileData.homing_turn_rate
## carries the TS ROT integer (8 on heatseekers); 60 deg/s per ROT unit gives
## a catchable homing arc. Tune here, not in the data files.
const TURN_RATE_DEG_PER_SEC_PER_UNIT: float = 60.0

var _data: ProjectileData
var _weapon: WeaponData
var _shooter: Node3D
var _shooter_player_id: int = -1
var _target: Node3D
var _last_known_target_pos: Vector3 = Vector3.ZERO
var _heading: Vector3 = Vector3.FORWARD
var _speed: float = 0.0
var _max_range: float = 0.0
var _traveled: float = 0.0
var _age_frames: int = 0
var _armed: bool = false
var _detonated: bool = false
var _prev_target_dist: float = -1.0
var _payload: Dictionary = {}
var _target_mask: int = 0

@onready var _cast: ShapeCast3D = $ShapeCast3D
@onready var _visual: Node3D = $Visual


## Configures the projectile before it enters the tree. Call once. Node
## children are applied in _ready, so setup only stores pure values.
func setup(data: ProjectileData, weapon: WeaponData, shooter: Node3D, target: Node3D) -> void:
    _data = data
    _weapon = weapon
    _shooter = shooter
    _target = target
    _speed = resolve_speed(data, weapon, GlobalRules.get_current())
    _max_range = weapon.attack_range * CellUtil.CELL_SIZE
    if target:
        _last_known_target_pos = target.global_position
    var shooter_stats := (
        shooter.get_node_or_null("StatsComponent") as StatsComponent if shooter else null
    )
    _shooter_player_id = shooter_stats.player_id if shooter_stats else -1
    if data.targets_ground:
        _target_mask |= HitboxComponent.LAYER_HITBOX_GROUND | HitboxComponent.LAYER_HITBOX_BUILDING
    if data.targets_air:
        _target_mask |= HitboxComponent.LAYER_HITBOX_AIR


## Speed precedence: ProjectileData.speed_override > WeaponData.speed > rules default.
static func resolve_speed(data: ProjectileData, weapon: WeaponData, rules: GlobalRules) -> float:
    if data and data.speed_override > 0.0:
        return data.speed_override
    if weapon and weapon.speed > 0.0:
        return weapon.speed
    if rules:
        return rules.default_projectile_speed
    return 0.0


func get_damage_info() -> Dictionary:
    return _payload


func _ready() -> void:
    _cast.collision_mask = _target_mask
    if _data.is_invisible:
        _visual.visible = false
        set_physics_process(false)
        _teleport_detonate()
        return
    _apply_tint()
    global_position = _shooter.global_position + _weapon.fire_offset
    _aim_heading_at_target()


## Points the heading at the target from the spawn position. Without this the
## heading stays at Vector3.FORWARD: non-guided projectiles fly pure -Z and
## guided ones instantly overshoot-detonate when the target starts out behind
## them (distance increases during the first frames).
func _aim_heading_at_target() -> void:
    if not is_instance_valid(_target):
        return
    var to_target := _target.global_position - global_position
    if not to_target.is_zero_approx():
        _heading = to_target.normalized()


func _physics_process(delta: float) -> void:
    if _detonated or is_queued_for_deletion() or not _data or not _weapon:
        return
    _age_frames += 1
    if _age_frames > _data.arm_delay:
        _armed = true
    var advance := _speed * delta
    _traveled += advance
    var target_pos := _last_known_target_pos
    var target_valid := is_instance_valid(_target)
    if target_valid:
        target_pos = _target.global_position
        _last_known_target_pos = target_pos
    if target_valid and _data.is_guided:
        _steer_toward(target_pos, delta)
    if not _armed:
        # Unarmed projectiles ignore every hitbox: no cast, no proximity.
        global_position += _heading * advance
        _update_visual_facing()
        return
    # Sweep the segment about to be traveled BEFORE moving, so fast
    # projectiles cannot tunnel through thin hitboxes.
    var hit_victim := _cast_along_motion(_heading * advance)
    if hit_victim:
        _detonate_on(hit_victim)
        return
    global_position += _heading * advance
    _update_visual_facing()
    if not target_valid:
        if global_position.distance_to(_last_known_target_pos) <= advance:
            queue_free()
        return
    var dist := global_position.distance_to(target_pos)
    if dist <= SNAP_DISTANCE:
        _detonate_on(_target)
        return
    if _prev_target_dist >= 0.0 and dist > _prev_target_dist:
        _detonate_on(_target)
        return
    _prev_target_dist = dist
    if _traveled >= _max_range:
        queue_free()


## Invisible family: no flight. Jump onto the victim and detonate at once —
## the same tick the legacy hitscan path applied damage, so behavior is
## preserved exactly. No physics-frame dependency.
func _teleport_detonate() -> void:
    if is_instance_valid(_target):
        global_position = _target.global_position
        _last_known_target_pos = global_position
        _detonate_on(_target)
    else:
        queue_free()


## Turns the heading toward the target, capped by the data's turn rate.
func _steer_toward(target_pos: Vector3, delta: float) -> void:
    var desired := (target_pos - global_position).normalized()
    if desired.is_zero_approx():
        return
    var angle := _heading.angle_to(desired)
    if angle <= 0.001:
        _heading = desired
        return
    var max_angle := deg_to_rad(_data.homing_turn_rate * TURN_RATE_DEG_PER_SEC_PER_UNIT) * delta
    if max_angle <= 0.0 or angle <= max_angle:
        _heading = desired
        return
    _heading = _heading.slerp(desired, max_angle / angle).normalized()


## Sweeps the collision shape along this frame's motion; returns the closest
## valid victim entity, or null. Segment casts cannot be tunneled through.
func _cast_along_motion(motion: Vector3) -> Node3D:
    if motion.is_zero_approx():
        return null
    _cast.target_position = motion
    _cast.force_shapecast_update()
    var best: Node3D = null
    var best_dist := motion.length() + 0.001
    for i in _cast.get_collision_count():
        var collider: Object = _cast.get_collider(i)
        var area := collider as Area3D
        if not area:
            continue
        var entity := area.get_parent() as Node3D
        if not entity or not _is_valid_victim(entity):
            continue
        var point: Vector3 = _cast.get_collision_point(i)
        var dist := global_position.distance_to(point)
        if dist < best_dist:
            best_dist = dist
            best = entity
    return best


## Shooter and same-team victims are immune; enemies, neutrals, and statless
## nodes detonate the projectile normally.
func _is_valid_victim(entity: Node3D) -> bool:
    if entity == _shooter:
        return false
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    if stats and stats.player_id >= 0 and _shooter_player_id >= 0:
        if not PlayerManager.is_enemy(_shooter_player_id, stats.player_id):
            return false
    return true


## Applies the payload to the victim through the HitboxComponent pipeline,
## emits impacted, and frees the projectile. Detonations within a cell of the
## victim snap the blast onto the victim's center so hits read as hits.
func _detonate_on(victim: Node3D) -> void:
    if _detonated:
        return
    _detonated = true
    var final_pos := global_position
    if (
        is_instance_valid(victim)
        and global_position.distance_to(victim.global_position) <= SNAP_RADIUS
    ):
        final_pos = victim.global_position
    _payload = {
        "amount": _compute_damage_for(victim),
        "type": _weapon.warhead,
        "source": _shooter,
        "position": final_pos,
    }
    if is_instance_valid(victim):
        var hitbox := victim.get_node_or_null("HitboxComponent") as HitboxComponent
        if hitbox:
            hitbox.receive_damage_source(self)
        else:
            var health := victim.get_node_or_null("HealthComponent") as HealthComponent
            if health:
                health.take_damage(_payload["amount"], _payload["type"])
    impacted.emit(final_pos)
    queue_free()


## Mirrors the legacy hitscan math: shooter veteran boost via the dispatcher's
## CombatComponent (accessed untyped to avoid a circular class reference),
## then the shared warhead armor multiplier and clamps in GlobalRules.
func _compute_damage_for(victim: Node3D) -> int:
    var damage := _weapon.damage
    if _shooter:
        var combat_node: Node = _shooter.get_node_or_null("CombatComponent")
        if combat_node and combat_node.has_method("get_effective_damage"):
            damage = combat_node.call("get_effective_damage", _weapon)
    var victim_stats := victim.get_node_or_null("StatsComponent") as StatsComponent
    var victim_armor := victim_stats.armor if victim_stats else "none"
    return GlobalRules.compute_warhead_damage(damage, _weapon.warhead, victim_armor)


func _apply_tint() -> void:
    var mesh := _visual as MeshInstance3D
    if not mesh:
        return
    var mat := mesh.get_surface_override_material(0) as StandardMaterial3D
    if mat:
        mat.albedo_color = _data.tint_color


## Faces the visual along the heading. Near-vertical headings are skipped:
## look_at cannot resolve an up vector parallel to the view direction (AA
## engaging a target directly overhead).
func _update_visual_facing() -> void:
    if not _data.rotates_to_face or _heading.is_zero_approx():
        return
    if absf(_heading.y) > 0.999:
        return
    var to := global_position + _heading
    if global_position.distance_squared_to(to) <= 0.0001:
        return
    _visual.look_at(to, Vector3.UP)
