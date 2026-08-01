extends Node

# CombatComponent tests — jumpjet attack zone retention, approach, and spread

var _sm: Node = null
var _pm: Node = null
var _test_passed := 0
var _test_failed := 0


func _make_weapon(damage: int = 10, range_cells: float = 5.0, warhead: String = "SA") -> WeaponData:
    var w := WeaponData.new()
    w.id = "TEST_WEAPON"
    w.damage = damage
    w.attack_range = range_cells
    w.rate_of_fire = 1.0
    w.warhead = warhead
    return w


func _make_combat_entity(has_weapon: bool = true, player_id: int = -1) -> Node3D:
    var entity := Node3D.new()
    entity.name = "CombatEntity"
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    if has_weapon:
        combat.weapons = [_make_weapon()]
        combat._init_cooldowns()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = player_id
    entity.add_child(stats)
    return entity


func _make_target(player_id: int) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TargetEntity"
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = player_id
    entity.add_child(stats)
    return entity


func _make_target_of_type(player_id: int, entity_type: int) -> Node3D:
    var entity := _make_target(player_id)
    var stats := entity.get_node("StatsComponent") as StatsComponent
    stats.entity_type = entity_type
    return entity


func _make_jumpjet_combat() -> Array:
    var entity := _make_combat_entity(true, 0)
    var mc := MovementController.new()
    mc.name = "MovementController"
    mc._is_jumpjet = true
    mc._is_infantry = true
    mc._locomotor_data = Locomotor.new()
    mc._locomotor_data.is_jumpjet = true
    entity.add_child(mc)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    return [entity, mc, cc]


func test_jumpjet_weapon_targets_ground_and_air():
    var data := load("res://resources/entities/infantry/gdi_jumpjet_infantry.tres") as EntityData
    TestHelper.assert_true(data != null, "jumpjet data loads")
    if data == null:
        _test_passed += TestHelper._passed
        _test_failed += TestHelper._failed
        TestHelper.reset()
        return
    TestHelper.assert_true(not data.weapons.is_empty(), "jumpjet has a weapon")
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = data.weapons
    cc._init_cooldowns()
    var ground_target := _make_target_of_type(local_id + 1, EntityData.EntityType.INFANTRY)
    ground_target.global_position = Vector3(4.0, 50.0, 0.0)
    var ground_order := cc.get_order_for_target(
        ground_target, Vector2i.ZERO, ground_target.global_position, {}
    )
    TestHelper.assert_true(ground_order != null, "jumpjet can order ground target")
    var air_target := _make_target_of_type(local_id + 1, EntityData.EntityType.AIRCRAFT)
    air_target.global_position = Vector3(4.0, 80.0, 0.0)
    var air_order := cc.get_order_for_target(
        air_target, Vector2i.ZERO, air_target.global_position, {}
    )
    TestHelper.assert_true(air_order != null, "jumpjet can order air target")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    ground_target.free()
    air_target.free()


func test_jumpjet_attack_interrupts_airborne_move():
    var root: Node = Engine.get_main_loop().root
    var pair: Array = _make_jumpjet_combat()
    var entity: Node3D = pair[0]
    var mc: MovementController = pair[1]
    var cc: CombatComponent = pair[2]
    root.add_child(entity)
    mc._parent = entity
    mc._state = MovementController.State.MOVING
    mc._vertical_state = MovementController.VerticalState.AIR
    mc._land_on_arrival = true
    var target := _make_target(1)
    root.add_child(target)
    target.global_position = Vector3(20.0, 0.0, 0.0)
    cc.set_target(target)
    var state: int = mc._state
    var zone: int = mc._vertical_state
    var land: bool = mc._land_on_arrival
    root.remove_child(entity)
    root.remove_child(target)
    entity.free()
    target.free()
    TestHelper.assert_eq(state, MovementController.State.IDLE, "attack interrupts the move")
    TestHelper.assert_eq(zone, MovementController.VerticalState.AIR, "air zone retained")
    TestHelper.assert_eq(land, false, "pending landing cancelled")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_jumpjet_attack_approaches_nearest_point():
    var root: Node = Engine.get_main_loop().root
    var pair: Array = _make_jumpjet_combat()
    var entity: Node3D = pair[0]
    var mc: MovementController = pair[1]
    var cc: CombatComponent = pair[2]
    root.add_child(entity)
    mc._parent = entity
    mc._state = MovementController.State.IDLE
    mc._vertical_state = MovementController.VerticalState.AIR
    entity.global_position = Vector3(0.0, 0.0, 0.0)
    var target := _make_target(1)
    root.add_child(target)
    target.global_position = Vector3(30.0, 0.0, 0.0)
    var weapon := cc.get_current_weapon()
    var range_world := weapon.attack_range * CellUtil.CELL_SIZE
    cc.set_target(target)
    cc._move_toward_target()
    var dest: Vector3 = mc._waypoints[mc._waypoints.size() - 1]
    var hybrid: bool = mc._hybrid_active
    var zone: int = mc._vertical_state
    root.remove_child(entity)
    root.remove_child(target)
    entity.free()
    target.free()
    (
        TestHelper
        . assert_true(
            absf(dest.x - (30.0 - range_world)) < 0.8,
            "airborne attacker stops at weapon range on the approach side",
        )
    )
    TestHelper.assert_true(
        dest.x < 30.0 - range_world + 0.5, "attacker does not go around to the far side"
    )
    TestHelper.assert_eq(hybrid, true, "attack keeps the fly path")
    TestHelper.assert_eq(zone, MovementController.VerticalState.AIR, "attacks from the air")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_jumpjet_air_repulsion_pushes_away():
    var root: Node = Engine.get_main_loop().root
    var pair: Array = _make_jumpjet_combat()
    var entity: Node3D = pair[0]
    var cc: CombatComponent = pair[2]
    root.add_child(entity)
    var no_push: Vector3 = cc._air_repulsion(Vector3.ZERO, [], 10.0)
    var close_push: Vector3 = cc._air_repulsion(Vector3.ZERO, [Vector3(0.2, 0.0, 0.0)], 10.0)
    var far_push: Vector3 = cc._air_repulsion(Vector3.ZERO, [Vector3(2.0, 0.0, 0.0)], 10.0)
    var capped_push: Vector3 = cc._air_repulsion(
        Vector3.ZERO, [Vector3.ZERO, Vector3(0.05, 0.0, 0.05)], 10.0
    )
    root.remove_child(entity)
    entity.free()
    TestHelper.assert_true(no_push == Vector3.ZERO, "no neighbors -> no push")
    TestHelper.assert_true(close_push.x < -0.1, "close neighbor pushes away from it")
    TestHelper.assert_true(close_push.length() <= 1.5, "push is capped at MIN_AIR_SEPARATION")
    TestHelper.assert_eq(far_push, Vector3.ZERO, "neighbor beyond separation -> no push")
    TestHelper.assert_true(capped_push.length() <= 1.5, "combined push stays bounded")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_jumpjet_attack_repulsion_separates_two():
    var root: Node = Engine.get_main_loop().root
    var pair1: Array = _make_jumpjet_combat()
    var first: Node3D = pair1[0]
    var mc1: MovementController = pair1[1]
    var cc1: CombatComponent = pair1[2]
    root.add_child(first)
    mc1._parent = first
    mc1._state = MovementController.State.IDLE
    mc1._vertical_state = MovementController.VerticalState.AIR
    first.global_position = Vector3(0.0, 0.0, 0.0)
    first.add_to_group("entities")
    var pair2: Array = _make_jumpjet_combat()
    var second: Node3D = pair2[0]
    var mc2: MovementController = pair2[1]
    var cc2: CombatComponent = pair2[2]
    root.add_child(second)
    mc2._parent = second
    mc2._state = MovementController.State.IDLE
    mc2._vertical_state = MovementController.VerticalState.AIR
    second.global_position = Vector3(0.2, 0.0, 0.0)
    second.add_to_group("entities")
    SpatialHash.instance.rebuild()
    var target := _make_target(1)
    root.add_child(target)
    target.global_position = Vector3(30.0, 0.0, 0.0)
    cc1.set_target(target)
    cc2.set_target(target)
    cc1._move_toward_target()
    cc2._move_toward_target()
    var dest1: Vector3 = mc1._waypoints[mc1._waypoints.size() - 1]
    var dest2: Vector3 = mc2._waypoints[mc2._waypoints.size() - 1]
    var range_world: float = cc1.get_current_weapon().attack_range * CellUtil.CELL_SIZE
    first.remove_from_group("entities")
    second.remove_from_group("entities")
    SpatialHash.instance.rebuild()
    root.remove_child(first)
    root.remove_child(second)
    root.remove_child(target)
    first.free()
    second.free()
    target.free()
    var in_range1: bool = Vector2(dest1.x - 30.0, dest1.z).length() <= range_world + 0.01
    var in_range2: bool = Vector2(dest2.x - 30.0, dest2.z).length() <= range_world + 0.01
    TestHelper.assert_true(in_range1, "first attacker stays within weapon range")
    TestHelper.assert_true(in_range2, "second attacker stays within weapon range")
    TestHelper.assert_true(
        dest1.distance_to(dest2) > 0.5, "two attackers nudge apart instead of stacking"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
