extends Node

# Turret system tests — socket schema, TurretComponent aim, per-mount combat
# channels, fire discipline, and muzzle placement. Node-tree / MultiMesh
# rendering is covered by test_unit_mesh_renderer and test_fog_ghosts.

const STATS_SCRIPT: GDScript = preload("res://scripts/components/StatsComponent.gd")


func _make_socket(
    socket_id: String,
    pivot_pos: Vector3 = Vector3.ZERO,
    yaw_free: bool = true,
    placeholder: Vector3 = Vector3(0.6, 0.4, 0.8),
    barrel: float = 0.0,
) -> SocketData:
    var socket := SocketData.new()
    socket.id = socket_id
    socket.pivot = Transform3D(Basis(), pivot_pos)
    socket.yaw_free = yaw_free
    socket.placeholder_size = placeholder
    socket.barrel_length = barrel
    return socket


func _make_weapon(damage: int = 10, range_cells: float = 5.0) -> WeaponData:
    var weapon := WeaponData.new()
    weapon.id = "TEST_WEAPON"
    weapon.damage = damage
    weapon.attack_range = range_cells
    weapon.rate_of_fire = 30.0
    weapon.warhead = "SA"
    return weapon


func _make_art(sockets: Array) -> ArtData:
    var art := ArtData.new()
    art.id = "TEST_ART"
    for socket in sockets:
        art.sockets.append(socket)
    return art


func _make_mount(
    weapon_index: int, socket_ids: Array, mode: int, delay: float
) -> WeaponMountGroupData:
    var group := WeaponMountGroupData.new()
    group.weapon_index = weapon_index
    group.socket_ids = PackedStringArray(socket_ids)
    group.fire_mode = mode
    group.fire_delay = delay
    return group


func _make_data(art: ArtData, weapons: Array, groups: Array = []) -> EntityData:
    var data := EntityData.new()
    data.id = "TEST_TURRET"
    data.entity_type = EntityData.EntityType.VEHICLE
    data.strength = 100
    data.owner = PackedStringArray(["GDI"])
    data.art_data = art
    for weapon in weapons:
        data.weapons.append(weapon)
    for group in groups:
        data.weapon_mount_groups.append(group)
    data.rotation_speed = 3600.0
    return data


## Builds entity + CombatComponent + TurretComponent + StatsComponent, no
## MovementController (body-facing exempt) unless a test adds one. The entity is
## added to the scene tree so global transforms resolve.
func _make_entity(data: EntityData) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TurretEntity"
    var turret := TurretComponent.new()
    turret.name = "TurretComponent"
    entity.add_child(turret)
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    entity.add_child(stats)
    _tree().root.add_child(entity)
    turret.configure(data)
    combat.configure(data)
    return entity


func _make_target() -> Node3D:
    var target := Node3D.new()
    target.name = "Target"
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = 1
    target.add_child(stats)
    _tree().root.add_child(target)
    return target


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


# --- 2.1 Socket data model ---


func test_socket_pivot_roundtrips_3d():
    var socket := _make_socket("main", Vector3(1.5, 2.25, -3.0))
    TestHelper.assert_eq(socket.pivot.origin, Vector3(1.5, 2.25, -3.0), "3D pivot preserved")
    TestHelper.assert_true(socket.yaw_free, "yaw_free defaults true")


func test_art_get_socket_unknown_returns_null():
    var art := _make_art([_make_socket("main")])
    TestHelper.assert_true(art.get_socket("main") != null, "known socket found")
    TestHelper.assert_eq(art.get_socket("left"), null, "unknown socket id returns null")


func test_art_empty_sockets_default():
    var art := ArtData.new()
    TestHelper.assert_eq(art.sockets.size(), 0, "sockets default empty")


# --- 2.2 Validation ---


func _has_error(errors: PackedStringArray, needle: String) -> bool:
    for err in errors:
        if needle in err:
            return true
    return false


func test_art_validate_rejects_duplicate_socket_ids():
    var art := _make_art([_make_socket("main"), _make_socket("main")])
    var errors := art.validate()
    TestHelper.assert_true(_has_error(errors, "duplicate socket id"), "duplicate rejected")


func test_entity_validate_rejects_unknown_socket():
    var art := _make_art([_make_socket("main")])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["ghost"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var errors := data.validate()
    TestHelper.assert_true(_has_error(errors, "unknown socket"), "unknown socket rejected")


func test_entity_validate_rejects_out_of_range_weapon_index():
    var art := _make_art([_make_socket("main")])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(3, ["main"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var errors := data.validate()
    TestHelper.assert_true(_has_error(errors, "out of range"), "bad weapon index rejected")


func test_entity_validate_rejects_duplicate_weapon_index():
    var art := _make_art([_make_socket("a"), _make_socket("b")])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["a"], WeaponMountGroupData.FireMode.SALVO, 0.0),
        _make_mount(0, ["b"], WeaponMountGroupData.FireMode.SALVO, 0.0),
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var errors := data.validate()
    TestHelper.assert_true(_has_error(errors, "duplicate"), "duplicate weapon mount rejected")


# --- 2.3 Single-socket default / body-mounted ---


func test_single_socket_default_binds_all_weapons():
    var art := _make_art([_make_socket("main")])
    var data := _make_data(art, [_make_weapon(), _make_weapon()])
    var groups := data.resolved_mount_groups()
    TestHelper.assert_eq(groups.size(), 2, "one group per weapon for the lone socket")
    TestHelper.assert_eq(groups[0].socket_ids[0], "main", "bound to the lone socket")


func test_no_sockets_means_body_mounted():
    var art := _make_art([])
    var data := _make_data(art, [_make_weapon()])
    TestHelper.assert_eq(data.resolved_mount_groups().size(), 0, "no groups -> body mounted")


# --- 3.3 TurretComponent ---


func test_turret_slew_rate_and_threshold():
    var art := _make_art([_make_socket("main")])
    var data := _make_data(art, [_make_weapon()])
    data.rotation_speed = 180.0
    var entity := _make_entity(data)
    var turret := entity.get_node("TurretComponent") as TurretComponent
    var aligned: bool = turret.slew("main", Vector3(10, 0, 0), 0.25)
    TestHelper.assert_true(not aligned, "90-degree slew is not aligned after one 45-degree step")
    var steps := 1
    while not aligned and steps < 20:
        aligned = turret.slew("main", Vector3(10, 0, 0), 0.25)
        steps += 1
    TestHelper.assert_true(aligned, "converges to aligned within threshold")
    entity.free()


func test_turret_fixed_socket_never_yaws():
    var art := _make_art([_make_socket("fixed", Vector3.ZERO, false)])
    var data := _make_data(art, [_make_weapon()])
    var entity := _make_entity(data)
    var turret := entity.get_node("TurretComponent") as TurretComponent
    var aligned: bool = turret.slew("fixed", Vector3(10, 0, 0), 0.25)
    TestHelper.assert_true(aligned, "fixed socket reports aligned immediately")
    TestHelper.assert_eq(turret.get_yaw("fixed"), 0.0, "fixed socket yaw stays zero")
    entity.free()


func test_turret_sockets_yaw_independently():
    var art := _make_art(
        [
            _make_socket("left", Vector3(-1, 0, 0)),
            _make_socket("right", Vector3(1, 0, 0)),
        ]
    )
    var data := _make_data(art, [_make_weapon()])
    var entity := _make_entity(data)
    var turret := entity.get_node("TurretComponent") as TurretComponent
    turret.slew("left", Vector3(-10, 0, 0), 1.0)
    turret.slew("right", Vector3(10, 0, 0), 1.0)
    (
        TestHelper
        . assert_true(
            absf(angle_difference(turret.get_yaw("left"), turret.get_yaw("right"))) > 0.5,
            "sockets keep independent yaws",
        )
    )
    entity.free()


# --- 4.5 Combat per-mount channels ---


func _add_moving_mc(entity: Node3D) -> MovementController:
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._parent = entity
    mc._state = MovementController.State.MOVING
    mc._waypoints = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -20)])
    return mc


func test_yaw_free_mount_fires_while_body_moves():
    var art := _make_art([_make_socket("main", Vector3(1, 0, 0))])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["main"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target()
    target.position = Vector3(10, 0, 0)
    var fired := [0]
    combat.weapon_fired.connect(func(_w: WeaponData, _t: Node3D) -> void: fired[0] += 1)
    combat.set_target(target)
    _add_moving_mc(entity)
    combat._physics_process(0.1)
    TestHelper.assert_true(fired[0] > 0, "turreted mount fires while the body is moving")
    entity.free()
    target.free()


func test_body_mounted_holds_fire_while_moving():
    var art := _make_art([])
    var data := _make_data(art, [_make_weapon()])
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target()
    target.position = Vector3(10, 0, 0)
    var fired := [0]
    combat.weapon_fired.connect(func(_w: WeaponData, _t: Node3D) -> void: fired[0] += 1)
    combat.set_target(target)
    _add_moving_mc(entity)
    combat._physics_process(0.1)
    TestHelper.assert_eq(fired[0], 0, "body-mounted weapon holds fire while the body is moving")
    entity.free()
    target.free()


func test_fixed_socket_weapon_holds_fire_while_moving():
    var art := _make_art([_make_socket("rail", Vector3(1, 0, 0), false)])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["rail"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target()
    target.position = Vector3(10, 0, 0)
    var fired := [0]
    combat.weapon_fired.connect(func(_w: WeaponData, _t: Node3D) -> void: fired[0] += 1)
    combat.set_target(target)
    _add_moving_mc(entity)
    combat._physics_process(0.1)
    TestHelper.assert_eq(fired[0], 0, "fixed-socket weapon forces body facing and holds fire")
    entity.free()
    target.free()


func test_salvo_fires_all_sockets_same_tick():
    var art := _make_art(
        [_make_socket("l", Vector3(-1, 0, 0)), _make_socket("r", Vector3(1, 0, 0))]
    )
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["l", "r"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target()
    target.position = Vector3(0, 0, -10)
    var fired := [0]
    combat.weapon_fired.connect(func(_w: WeaponData, _t: Node3D) -> void: fired[0] += 1)
    combat.set_target(target)
    combat._physics_process(0.05)
    TestHelper.assert_eq(fired[0], 2, "salvo fires both sockets on the same tick")
    entity.free()
    target.free()


func test_stagger_spaces_socket_shots():
    var art := _make_art(
        [_make_socket("l", Vector3(-1, 0, 0)), _make_socket("r", Vector3(1, 0, 0))]
    )
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["l", "r"], WeaponMountGroupData.FireMode.STAGGER, 0.3)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target()
    target.position = Vector3(0, 0, -10)
    var fired := [0]
    combat.weapon_fired.connect(func(_w: WeaponData, _t: Node3D) -> void: fired[0] += 1)
    combat.set_target(target)
    combat._physics_process(0.05)
    TestHelper.assert_eq(fired[0], 1, "stagger opens with one shot")
    combat._physics_process(0.29)
    TestHelper.assert_eq(fired[0], 1, "second socket waits for the full delay")
    combat._physics_process(0.02)
    TestHelper.assert_eq(fired[0], 2, "second socket fires after the delay")
    entity.free()
    target.free()


func test_independent_groups_fire_separately():
    var art := _make_art([_make_socket("a"), _make_socket("b")])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["a"], WeaponMountGroupData.FireMode.SALVO, 0.0),
        _make_mount(1, ["b"], WeaponMountGroupData.FireMode.SALVO, 0.0),
    ]
    var data := _make_data(art, [_make_weapon(), _make_weapon()], groups)
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    TestHelper.assert_eq(combat._channels.size(), 2, "one channel per group")
    entity.free()


# --- Continuous aim (chase / move / idle) ---


func _add_mc_with_destination(entity: Node3D, dest: Vector3) -> MovementController:
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._parent = entity
    mc._state = MovementController.State.MOVING
    mc._waypoints = PackedVector3Array([Vector3.ZERO, dest])
    return mc


func test_turret_tracks_target_while_chasing():
    var art := _make_art([_make_socket("main")])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["main"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon(10, 2.0)], groups)
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var turret := entity.get_node("TurretComponent") as TurretComponent
    var target := _make_target()
    target.position = Vector3(100, 0, 0)
    combat.set_target(target)
    combat._physics_process(0.1)
    (
        TestHelper
        . assert_true(
            absf(turret.get_yaw("main")) > 0.1,
            "turret tracks an out-of-range target while closing",
        )
    )
    entity.free()
    target.free()


func test_turret_faces_movement_destination_without_target():
    var art := _make_art([_make_socket("main")])
    var data := _make_data(art, [_make_weapon()])
    var entity := _make_entity(data)
    var turret := entity.get_node("TurretComponent") as TurretComponent
    _add_mc_with_destination(entity, Vector3(20, 0, 0))
    turret._physics_process(0.1)
    (
        TestHelper
        . assert_true(
            turret.get_yaw("main") < -0.1,
            "turret faces the movement destination when it has no target",
        )
    )
    entity.free()


func test_attack_target_overrides_movement_destination():
    var art := _make_art([_make_socket("main")])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["main"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var turret := entity.get_node("TurretComponent") as TurretComponent
    # Movement destination is +X; combat target is dead ahead (-Z).
    _add_mc_with_destination(entity, Vector3(20, 0, 0))
    var target := _make_target()
    target.position = Vector3(0, 0, -10)
    combat.set_target(target)
    combat._physics_process(1.0)
    turret._physics_process(0.1)
    (
        TestHelper
        . assert_true(
            absf(turret.get_yaw("main")) < 0.1,
            "combat target aim overrides the movement destination",
        )
    )
    entity.free()
    target.free()


func test_idle_turret_realigns_to_forward():
    var art := _make_art([_make_socket("main")])
    var data := _make_data(art, [_make_weapon()])
    var entity := _make_entity(data)
    var turret := entity.get_node("TurretComponent") as TurretComponent
    # A turret left pointing sideways from a previous engagement.
    turret._yaws["main"] = -PI / 2.0
    turret._physics_process(0.1)
    (
        TestHelper
        . assert_true(
            absf(turret.get_yaw("main")) < 0.1,
            "idle turret realigns to chassis forward",
        )
    )
    entity.free()


# --- 5.2 Muzzle placement ---


func test_turret_muzzle_offset_and_yaw():
    var art := _make_art([_make_socket("main", Vector3(2, 0, 0), true, Vector3.ONE, 1.0)])
    var data := _make_data(art, [_make_weapon()])
    var entity := _make_entity(data)
    var turret := entity.get_node("TurretComponent") as TurretComponent
    var muzzle := turret.get_muzzle_world_transform("main")
    (
        TestHelper
        . assert_true(
            muzzle.origin.is_equal_approx(Vector3(2, 0, -1)),
            "muzzle sits at pivot + barrel along the socket forward axis",
        )
    )
    entity.free()


func test_body_muzzle_uses_entity_and_fire_offset():
    var art := _make_art([])
    var weapon := _make_weapon()
    weapon.fire_offset = Vector3(0.5, 0.25, -1.0)
    var data := _make_data(art, [weapon])
    var entity := _make_entity(data)
    entity.position = Vector3(3, 0, 4)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    TestHelper.assert_eq(
        combat._body_muzzle_origin(weapon), Vector3(3.5, 0.25, 3.0), "body muzzle = entity + FLH"
    )
    entity.free()


# --- 7.2 Structure turret path ---


func test_structure_turret_yaws_and_fires_off_facing():
    var art := _make_art([_make_socket("main", Vector3(0, 0.5, 0), true)])
    var groups: Array[WeaponMountGroupData] = [
        _make_mount(0, ["main"], WeaponMountGroupData.FireMode.SALVO, 0.0)
    ]
    var data := _make_data(art, [_make_weapon()], groups)
    data.entity_type = EntityData.EntityType.BUILDING
    data.speed = 0.0
    var entity := _make_entity(data)
    entity.position = Vector3(50, 0, 50)
    var turret := entity.get_node("TurretComponent") as TurretComponent
    TestHelper.assert_eq(turret._node_turrets.size(), 1, "building builds a node-tree turret")
    turret._physics_process(0.0)
    var mesh_instance: MeshInstance3D = turret._node_turrets["main"]
    (
        TestHelper
        . assert_true(
            mesh_instance.global_transform.origin.is_equal_approx(Vector3(50, 0.5, 50)),
            "structure turret mesh inherits the entity transform (not a detached root)",
        )
    )
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target()
    target.position = Vector3(60, 0, 50)
    var fired := [0]
    combat.weapon_fired.connect(func(_w: WeaponData, _t: Node3D) -> void: fired[0] += 1)
    combat.set_target(target)
    combat._physics_process(0.1)
    TestHelper.assert_true(fired[0] > 0, "structure turret fires at an off-facing target")
    TestHelper.assert_true(absf(turret.get_yaw("main")) > 0.1, "structure turret yawed to target")
    entity.free()
    target.free()


# --- 8.3 Turretless regression ---


func test_turretless_vehicle_fires_body_mounted():
    var art := _make_art([])
    var data := _make_data(art, [_make_weapon()])
    var entity := _make_entity(data)
    var combat := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target()
    target.position = Vector3(5, 0, 0)
    var fired := [0]
    combat.weapon_fired.connect(func(_w: WeaponData, _t: Node3D) -> void: fired[0] += 1)
    combat.set_target(target)
    combat._physics_process(0.05)
    TestHelper.assert_true(fired[0] > 0, "turretless unit fires as before (no MC -> exempt)")
    entity.free()
    target.free()


# --- 8.1 / 8.2 Authored data ---


func test_mammoth_mk2_wires_sockets_and_mounts():
    var art := load("res://games/ts/art/vehicles/gdi_mammoth_mk2_art.tres") as ArtData
    TestHelper.assert_true(art != null, "mammoth art loads")
    TestHelper.assert_eq(art.sockets.size(), 5, "five sockets")
    var rotatable := 0
    var fixed := 0
    for socket in art.sockets:
        if socket.yaw_free:
            rotatable += 1
        else:
            fixed += 1
    TestHelper.assert_eq(rotatable, 3, "three rotatable sockets")
    TestHelper.assert_eq(fixed, 2, "two fixed sockets")
    var data := load("res://games/ts/entities/vehicles/gdi_mammoth_mk2.tres") as EntityData
    TestHelper.assert_true(data != null, "mammoth data loads")
    TestHelper.assert_eq(data.weapon_mount_groups.size(), 2, "two mount groups")
    var errors := data.validate()
    TestHelper.assert_eq(errors.size(), 0, "mammoth data validates: %s" % str(errors))


func test_deployed_tick_tank_has_socket():
    var art := load("res://games/ts/art/structures/nod/nod_deployed_tick_tank_art.tres") as ArtData
    TestHelper.assert_true(art != null, "deployed tick tank art loads")
    TestHelper.assert_eq(art.sockets.size(), 1, "one socket")
    TestHelper.assert_true(art.sockets[0].yaw_free, "socket is rotatable")
    var data := (
        load("res://games/ts/entities/structures/nod/nod_deployed_tick_tank.tres") as EntityData
    )
    TestHelper.assert_true(data != null, "deployed tick tank data loads")
    TestHelper.assert_eq(
        data.resolved_mount_groups().size(), 1, "single socket defaults the weapon mount"
    )
