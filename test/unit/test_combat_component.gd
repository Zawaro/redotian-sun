extends Node

# CombatComponent tests — cursor resolution and order generation for targets

var _sm: Node = null
var _pm: Node = null
var _test_passed := 0
var _test_failed := 0


func _make_weapon(damage: int = 10, range_cells: float = 5.0) -> WeaponData:
    var w := WeaponData.new()
    w.id = "TEST_WEAPON"
    w.damage = damage
    w.attack_range = range_cells
    w.rate_of_fire = 1.0
    return w


func _make_combat_entity(has_weapon: bool = true, player_id: int = -1) -> Node3D:
    var entity := Node3D.new()
    entity.name = "CombatEntity"
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    if has_weapon:
        combat.weapons = [_make_weapon()]
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


# --- get_cursor_for_target tests ---


func test_cursor_null_target_returns_default():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var cursor := cc.get_cursor_for_target(null, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "null target -> DEFAULT")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_cursor_empty_weapons_returns_default():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(1)
    var cursor := cc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "no weapons -> DEFAULT")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_cursor_enemy_returns_attack():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id + 1)
    var cursor := cc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.ATTACK, "enemy -> ATTACK")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_cursor_friendly_returns_default():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id)
    var cursor := cc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "friendly -> DEFAULT")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_cursor_neutral_target_returns_default():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(-1)
    var cursor := cc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "neutral (player_id=-1) -> DEFAULT")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_cursor_target_without_stats_returns_default():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := Node3D.new()
    target.name = "NoStatsTarget"
    var cursor := cc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(
        cursor, CursorState.Type.DEFAULT, "target without StatsComponent -> DEFAULT"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


# --- get_order_for_target tests ---


func test_order_null_target_returns_null():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var order := cc.get_order_for_target(null, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "null target -> null order")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_order_empty_weapons_returns_null():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(1)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "no weapons -> null order")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_enemy_returns_attack_order():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id + 1)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order != null, "enemy -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.ATTACK, "enemy order cursor -> ATTACK")
    TestHelper.assert_eq(order.priority, 30, "enemy order priority -> 30")
    TestHelper.assert_true(order.execute.is_valid(), "enemy order has valid execute callable")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_friendly_returns_null():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "friendly -> null order")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_neutral_returns_null():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(-1)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "neutral -> null order")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_force_attack_modifier_allows_friendly():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id)
    var modifiers := {OrderResult.MOD_FORCE_ATTACK: true}
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, modifiers)
    TestHelper.assert_true(order != null, "force_attack on friendly -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.ATTACK, "force_attack cursor -> ATTACK")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_queued_modifier_sets_queued_flag():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id + 1)
    var modifiers := {OrderResult.MOD_QUEUED: true}
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, modifiers)
    TestHelper.assert_true(order != null, "queued modifier -> order not null")
    TestHelper.assert_true(order.queued, "queued modifier -> order.queued = true")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_no_queued_modifier_sets_queued_false():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id + 1)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order != null, "no queued modifier -> order not null")
    TestHelper.assert_true(not order.queued, "no queued modifier -> order.queued = false")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_target_without_stats_returns_null():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := Node3D.new()
    target.name = "NoStatsTarget"
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "target without StatsComponent -> null order")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_stores_target_reference():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id + 1)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_eq(order.target, target, "order stores target reference")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_order_stores_target_pos():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(local_id + 1)
    var pos := Vector3(10.0, 0.0, 20.0)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, pos, {})
    TestHelper.assert_eq(order.target_pos, pos, "order stores target_pos")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


# --- configure tests ---


func test_configure_sets_weapons():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var data := EntityData.new()
    data.id = "TEST"
    data.weapons = [_make_weapon(20, 3.0)]
    cc.configure(data)
    TestHelper.assert_eq(cc.weapons.size(), 1, "configure sets weapons array")
    TestHelper.assert_eq(cc.weapons[0].damage, 20, "configure copies weapon data")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_get_current_weapon_with_weapons():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var weapon := cc.get_current_weapon()
    TestHelper.assert_true(weapon != null, "get_current_weapon returns weapon when weapons exist")
    TestHelper.assert_eq(weapon.id, "TEST_WEAPON", "get_current_weapon returns correct weapon")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_get_current_weapon_empty_weapons():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var weapon := cc.get_current_weapon()
    TestHelper.assert_true(weapon == null, "get_current_weapon returns null when no weapons")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_cycle_weapon_wraps_around():
    var entity := Node3D.new()
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    combat.weapons = [_make_weapon(10), _make_weapon(20)]
    combat.cycle_weapon()
    var current := combat.get_current_weapon()
    TestHelper.assert_eq(current.damage, 20, "cycle_weapon moves to next weapon")
    combat.cycle_weapon()
    current = combat.get_current_weapon()
    TestHelper.assert_eq(current.damage, 10, "cycle_weapon wraps around to first")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_cycle_weapon_no_op_when_empty():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.cycle_weapon()
    TestHelper.assert_true(true, "cycle_weapon does not crash when weapons empty")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


func test_validate_no_weapons():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var data := EntityData.new()
    data.id = "TEST_EMPTY"
    var errors := cc.validate(data)
    TestHelper.assert_true(errors.size() > 0, "validate reports error for no weapons")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()


# --- Firing logic tests ---


func _make_target_with_health(player_id: int = 1, health: int = 100) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TargetEntity"
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = player_id
    entity.add_child(stats)
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = health
    hc.current_health = health
    entity.add_child(hc)
    return entity


func test_set_target_stores_reference():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1)
    cc.set_target(target)
    TestHelper.assert_eq(cc._target, target, "set_target stores reference")
    TestHelper.assert_true(cc._attack_active, "set_target sets _attack_active")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_clear_target_clears_reference():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1)
    cc.set_target(target)
    cc.clear_target()
    TestHelper.assert_eq(cc._target, null, "clear_target nulls reference")
    TestHelper.assert_eq(cc._attack_active, false, "clear_target clears _attack_active")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    entity.free()
    target.free()


func test_cooldown_blocks_fire():
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    add_child(target)
    target.global_position = Vector3(0, 0, 0)
    entity.global_position = Vector3(0, 0, 0)
    cc.set_target(target)
    cc._cooldowns[0] = 5.0
    var old_health: int = target.get_node("HealthComponent").current_health
    cc._physics_process(0.1)
    var new_health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(new_health, old_health, "cooldown blocks fire — health unchanged")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


func test_fire_deals_damage_in_range():
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    add_child(target)
    target.global_position = Vector3(0, 0, 0)
    entity.global_position = Vector3(0, 0, 0)
    cc.set_target(target)
    cc._cooldowns[0] = 0.0
    cc._physics_process(0.01)
    var health: int = target.get_node("HealthComponent").current_health
    var weapon := cc.get_current_weapon()
    TestHelper.assert_eq(health, 100 - weapon.damage, "fire deals weapon.damage")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


func test_target_invalidated_no_crash():
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1)
    add_child(target)
    cc.set_target(target)
    remove_child(target)
    target.free()
    cc._physics_process(0.1)
    cc._physics_process(0.1)
    TestHelper.assert_eq(cc._target, null, "invalid target cleared")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    entity.free()


func test_target_death_clears_target():
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 10)
    add_child(target)
    target.global_position = Vector3(0, 0, 0)
    entity.global_position = Vector3(0, 0, 0)
    cc.set_target(target)
    var weapon := cc.get_current_weapon()
    target.get_node("HealthComponent").take_damage(weapon.damage)
    TestHelper.assert_eq(cc._target, null, "dead target cleared via health_zero signal")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


func test_weapon_fired_signal_emits():
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    add_child(target)
    target.global_position = Vector3(0, 0, 0)
    entity.global_position = Vector3(0, 0, 0)
    var signal_received := false
    var signal_weapon: WeaponData = null
    cc.weapon_fired.connect(
        func(w: WeaponData, _t: Node3D): signal_received = true; signal_weapon = w
    )
    cc.set_target(target)
    cc._cooldowns[0] = 0.0
    cc._physics_process(0.01)
    TestHelper.assert_true(signal_received, "weapon_fired signal emitted")
    TestHelper.assert_eq(signal_weapon, cc.get_current_weapon(), "signal passes weapon data")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


# --- OrderResolver integration: selected units + enemy click ---


func test_order_resolver_returns_attack_for_enemy_with_selection():
    var pm := get_node_or_null("/root/PlayerManager")
    var local_id: int = pm.get_local_player_id() if pm else 0
    var entity := _make_combat_entity(true, local_id)
    add_child(entity)
    var select_comp := SelectComponent.new()
    select_comp.name = "SelectComponent"
    entity.add_child(select_comp)
    var sm := get_node_or_null("/root/SelectionManager")
    if sm:
        sm.add_entity(select_comp)
    var target := _make_target(local_id + 1)
    add_child(target)
    var results := OrderResolver.resolve_all(
        [select_comp], target, Vector2i.ZERO, target.global_position, {}
    )
    TestHelper.assert_true(results.size() > 0, "enemy target returns order")
    var best: OrderResult = results[0]
    TestHelper.assert_eq(best.cursor, CursorState.Type.ATTACK, "cursor -> ATTACK")
    TestHelper.assert_true(best.execute.is_valid(), "execute callable valid")
    if sm:
        sm.deselect_all()
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


# --- Player move cancels attack ---


func test_player_move_clears_attack_target():
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    add_child(target)
    cc.set_target(target)
    TestHelper.assert_eq(cc._target, target, "target set before move")
    TestHelper.assert_true(cc._attack_active, "attack active before move")
    mc.set_target_position(Vector3(100, 0, 100))
    TestHelper.assert_eq(cc._target, null, "target cleared after player move")
    TestHelper.assert_eq(cc._attack_active, false, "attack inactive after player move")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


func test_combat_move_preserves_attack_target():
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    add_child(target)
    target.global_position = Vector3(0, 0, 0)
    entity.global_position = Vector3(0, 0, 0)
    cc.set_target(target)
    cc._combat_move = true
    mc.set_target_position(Vector3(100, 0, 100))
    TestHelper.assert_eq(cc._target, target, "target preserved after combat move")
    TestHelper.assert_true(cc._attack_active, "attack active after combat move")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()
