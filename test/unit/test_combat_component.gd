extends Node

# CombatComponent tests — cursor resolution and order generation for targets

var _sm: Node = null
var _pm: Node = null
var _ts: Node = null


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


# --- get_cursor_for_target tests ---


func test_cursor_null_target_returns_default():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var cursor := cc.get_cursor_for_target(null, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "null target -> DEFAULT")
    entity.free()


func test_cursor_empty_weapons_returns_default():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(1)
    var cursor := cc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "no weapons -> DEFAULT")
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
    entity.free()
    target.free()


func test_cursor_neutral_target_returns_default():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(-1)
    var cursor := cc.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "neutral (player_id=-1) -> DEFAULT")
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
    entity.free()
    target.free()


# --- get_order_for_target tests ---


func test_order_null_target_returns_null():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var order := cc.get_order_for_target(null, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "null target -> null order")
    entity.free()


func test_order_empty_weapons_returns_null():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(1)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "no weapons -> null order")
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
    entity.free()
    target.free()


func test_order_neutral_returns_null():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target(-1)
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "neutral -> null order")
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
    entity.free()
    target.free()


func test_order_target_without_stats_returns_null():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := Node3D.new()
    target.name = "NoStatsTarget"
    var order := cc.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "target without StatsComponent -> null order")
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
    entity.free()


func test_get_current_weapon_with_weapons():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var weapon := cc.get_current_weapon()
    TestHelper.assert_true(weapon != null, "get_current_weapon returns weapon when weapons exist")
    TestHelper.assert_eq(weapon.id, "TEST_WEAPON", "get_current_weapon returns correct weapon")
    entity.free()


func test_get_current_weapon_empty_weapons():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var weapon := cc.get_current_weapon()
    TestHelper.assert_true(weapon == null, "get_current_weapon returns null when no weapons")
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
    entity.free()


func test_cycle_weapon_no_op_when_empty():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.cycle_weapon()
    TestHelper.assert_true(true, "cycle_weapon does not crash when weapons empty")
    entity.free()


func test_validate_no_weapons():
    var entity := _make_combat_entity(false, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var data := EntityData.new()
    data.id = "TEST_EMPTY"
    var errors := cc.validate(data)
    TestHelper.assert_true(errors.size() > 0, "validate reports error for no weapons")
    entity.free()


# --- Firing logic tests ---


func _make_target_with_health(
    player_id: int = 1, health: int = 100, armor: String = "none"
) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TargetEntity"
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = player_id
    stats.armor = armor
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
    entity.free()
    target.free()


func test_cooldown_blocks_fire():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    cc.set_target(target)
    cc._cooldowns = [5.0]
    var old_health: int = target.get_node("HealthComponent").current_health
    cc._physics_process(0.1)
    var new_health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(new_health, old_health, "cooldown blocks fire — health unchanged")
    entity.free()
    target.free()


func test_fire_deals_damage_in_range():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health, 100 - weapon.damage, "fire deals weapon.damage")
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
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


func test_weapon_fired_signal_emits():
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    var result := [false, null]
    cc.weapon_fired.connect(
        func(w: WeaponData, _t: Node3D):
            result[0] = true
            result[1] = w
    )
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    TestHelper.assert_true(result[0], "weapon_fired signal emitted")
    TestHelper.assert_eq(result[1], weapon, "signal passes weapon data")
    entity.free()
    target.free()


# --- Armor resolution (warhead vs armor) tests ---

var _real_rules: GlobalRules = null


func _inject_test_rules() -> void:
    var rules := GlobalRules.new()
    rules.min_damage = 1
    rules.max_damage = 1000
    for aid in ["none", "wood", "light", "heavy", "concrete"]:
        var at := ArmorType.new()
        at.id = aid
        rules.armor_types[aid] = at
    var sa := WarheadData.new()
    sa.id = "SA"
    sa.armor_damage_multipliers = {
        "none": 1.0, "wood": 0.6, "light": 0.4, "heavy": 0.25, "concrete": 0.1
    }
    rules.warheads["SA"] = sa
    var ap := WarheadData.new()
    ap.id = "AP"
    ap.armor_damage_multipliers = {
        "none": 0.25, "wood": 0.65, "light": 0.75, "heavy": 1.0, "concrete": 0.6
    }
    rules.warheads["AP"] = ap
    var mechanical := WarheadData.new()
    mechanical.id = "Mechanical"
    mechanical.armor_damage_multipliers = {
        "none": 0.0, "wood": 1.0, "light": 1.0, "heavy": 1.0, "concrete": 1.0
    }
    rules.warheads["Mechanical"] = mechanical
    var fire := WarheadData.new()
    fire.id = "Fire"
    fire.armor_damage_multipliers = {
        "none": 6.0, "wood": 1.48, "light": 0.59, "heavy": 0.06, "concrete": 0.02
    }
    rules.warheads["Fire"] = fire
    var main_loop := Engine.get_main_loop()
    var ef: Node = main_loop.root.get_node_or_null("EntityFactory") if main_loop else null
    if ef and ef.has_method("set_global_rules"):
        _real_rules = ef.get_global_rules()
        ef.set_global_rules(rules)


func _restore_rules() -> void:
    var main_loop := Engine.get_main_loop()
    var ef: Node = main_loop.root.get_node_or_null("EntityFactory") if main_loop else null
    if ef and ef.has_method("set_global_rules"):
        ef.set_global_rules(_real_rules)


func test_armor_sa_vs_heavy():
    _inject_test_rules()
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = [_make_weapon(100, 5.0, "SA")]
    cc._init_cooldowns()
    var target := _make_target_with_health(1, 1000, "heavy")
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health, 1000 - 25, "SA vs heavy (0.25) deals 25 damage")
    entity.free()
    target.free()
    _restore_rules()


func test_armor_ap_vs_heavy_full():
    _inject_test_rules()
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = [_make_weapon(100, 5.0, "AP")]
    cc._init_cooldowns()
    var target := _make_target_with_health(1, 1000, "heavy")
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health, 1000 - 100, "AP vs heavy (1.0) deals full damage")
    entity.free()
    target.free()
    _restore_rules()


func test_armor_sa_vs_concrete_min_floor():
    _inject_test_rules()
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = [_make_weapon(5, 5.0, "SA")]
    cc._init_cooldowns()
    var target := _make_target_with_health(1, 1000, "concrete")
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health, 1000 - 1, "SA vs concrete (0.1*5=0.5) floors to min_damage 1")
    entity.free()
    target.free()
    _restore_rules()


func test_armor_zero_damage_pairing():
    _inject_test_rules()
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = [_make_weapon(100, 5.0, "Mechanical")]
    cc._init_cooldowns()
    var target := _make_target_with_health(1, 1000, "none")
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health, 1000 - 0, "Mechanical vs none (0.0) deals 0 damage")
    entity.free()
    target.free()
    _restore_rules()


func test_armor_unknown_warhead_full():
    _inject_test_rules()
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = [_make_weapon(50, 5.0, "UnknownWH")]
    cc._init_cooldowns()
    var target := _make_target_with_health(1, 1000, "heavy")
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health, 1000 - 50, "unknown warhead deals full damage")
    entity.free()
    target.free()
    _restore_rules()


func test_armor_unknown_target_armor_full():
    _inject_test_rules()
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = [_make_weapon(50, 5.0, "SA")]
    cc._init_cooldowns()
    var target := _make_target_with_health(1, 1000, "flak")
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health, 1000 - 50, "unknown armor deals full damage")
    entity.free()
    target.free()
    _restore_rules()


func test_armor_fire_overkill_caps_at_max():
    _inject_test_rules()
    var entity := _make_combat_entity(true, 0)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    cc.weapons = [_make_weapon(500, 5.0, "Fire")]
    cc._init_cooldowns()
    var target := _make_target_with_health(1, 100000, "none")
    var weapon := cc.get_current_weapon()
    cc._fire_weapon(weapon, target)
    var health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(
        health, 100000 - 1000, "Fire vs none (6.0*500=3000) caps to max_damage 1000"
    )
    entity.free()
    target.free()
    _restore_rules()


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
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


# --- Player move cancels attack ---


func test_player_move_clears_attack_target():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    if SpatialHash.instance:
        SpatialHash.instance._grid.clear()
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._parent = entity
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    add_child(target)
    entity.global_position = Vector3(1, 0, 1)
    cc.set_target(target)
    TestHelper.assert_eq(cc._target, target, "target set before move")
    TestHelper.assert_true(cc._attack_active, "attack active before move")
    mc.set_target_position(Vector3(5, 0, 5))
    TestHelper.assert_eq(cc._target, null, "target cleared after player move")
    TestHelper.assert_eq(cc._attack_active, false, "attack inactive after player move")
    _ts.clear()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


func test_combat_move_preserves_attack_target():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(32, 32)
    if SpatialHash.instance:
        SpatialHash.instance._grid.clear()
    var entity := _make_combat_entity(true, 0)
    add_child(entity)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._parent = entity
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    add_child(target)
    entity.global_position = Vector3(1, 0, 1)
    cc.set_target(target)
    cc._combat_move = true
    mc.set_target_position(Vector3(5, 0, 5))
    TestHelper.assert_eq(cc._target, target, "target preserved after combat move")
    TestHelper.assert_true(cc._attack_active, "attack active after combat move")
    _ts.clear()
    remove_child(entity)
    remove_child(target)
    entity.free()
    target.free()


func _make_moving_ground_attacker(waypoint_dir: Vector3 = Vector3(1, 0, 0)) -> Array:
    # A ground unit mid-move on a per-cell player-move path (21 cells), in the
    # scene tree so global positions resolve. Returns [entity, mc, cc].
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return []
    _ts.init_grid(32, 32)
    if SpatialHash.instance:
        SpatialHash.instance._grid.clear()
    var root: Node = Engine.get_main_loop().root
    var entity := _make_combat_entity(true, 0)
    root.add_child(entity)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._parent = entity
    entity.global_position = Vector3(0, 0, 0)
    mc._state = MovementController.State.MOVING
    var waypoints := PackedVector3Array()
    for i in range(0, 21):
        waypoints.append(Vector3(i * 2.0, 0, 0) * waypoint_dir)
    mc._waypoints = waypoints
    var cc := entity.get_node("CombatComponent") as CombatComponent
    return [entity, mc, cc]


func test_ground_attack_in_range_stops_and_fires():
    # A ground unit mid-move must abandon the old destination on an in-range
    # attack, stop the move (settling within a cell), and fire (#195).
    var setup: Array = _make_moving_ground_attacker()
    if setup.is_empty():
        return
    var entity: Node3D = setup[0]
    var mc: MovementController = setup[1]
    var cc: CombatComponent = setup[2]
    var root: Node = Engine.get_main_loop().root
    var target := _make_target_with_health(1, 100)
    root.add_child(target)
    target.global_position = Vector3(3.0, 0.0, 0.0)
    var old_dest: Vector3 = mc.get_target_position()
    cc.set_target(target)
    var collapsed_dest: Vector3 = mc.get_target_position()
    var abandoned: bool = collapsed_dest.distance_to(old_dest) > 5.0
    cc._physics_process(0.1)
    var health: int = target.get_node("HealthComponent").current_health
    var fired: bool = health < 100
    var still_attacking: bool = cc._target == target
    root.remove_child(entity)
    root.remove_child(target)
    entity.free()
    target.free()
    TestHelper.assert_true(abandoned, "in-range attack abandons old move destination")
    TestHelper.assert_true(fired, "in-range attack fires after stopping")
    TestHelper.assert_true(still_attacking, "attack target preserved after stopping")


func test_ground_attack_out_of_range_supersedes_move():
    # A ground unit mid-move heading elsewhere (along Z) must drop that
    # destination on an out-of-range attack and immediately head along a fresh
    # approach path into range (#256).
    var setup: Array = _make_moving_ground_attacker(Vector3(0, 0, 1))
    if setup.is_empty():
        return
    var entity: Node3D = setup[0]
    var mc: MovementController = setup[1]
    var cc: CombatComponent = setup[2]
    var root: Node = Engine.get_main_loop().root
    var target := _make_target_with_health(1, 100)
    root.add_child(target)
    target.global_position = Vector3(40.0, 0.0, 0.0)
    var old_dest: Vector3 = mc.get_target_position()
    cc.set_target(target)
    var new_dest: Vector3 = mc.get_target_position()
    var weapon := cc.get_current_weapon()
    var range_world := weapon.attack_range * CellUtil.CELL_SIZE
    var in_range_of_target: bool = (
        Vector2(new_dest.x - 40.0, new_dest.z).length() <= range_world + 0.5
    )
    var abandoned: bool = new_dest.distance_to(old_dest) > 5.0
    var target_preserved: bool = cc._target == target
    root.remove_child(entity)
    root.remove_child(target)
    entity.free()
    target.free()
    TestHelper.assert_true(abandoned, "out-of-range attack abandons old move destination")
    TestHelper.assert_true(
        in_range_of_target, "new destination is an approach point within weapon range"
    )
    TestHelper.assert_true(target_preserved, "attack target preserved after superseding move")


func test_range_ignores_vertical_separation():
    var root: Node = Engine.get_main_loop().root
    var entity := _make_combat_entity(true, 0)
    root.add_child(entity)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    root.add_child(target)
    entity.global_position = Vector3(0, 0, 0)
    target.global_position = Vector3(4.0, 50.0, 0.0)
    cc.set_target(target)
    var old_health: int = target.get_node("HealthComponent").current_health
    cc._physics_process(0.1)
    var new_health: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_true(
        new_health < old_health, "vertical separation does not block firing when XZ in range"
    )
    root.remove_child(entity)
    root.remove_child(target)
    entity.free()
    target.free()


func test_range_horizontal_distance_used():
    var root: Node = Engine.get_main_loop().root
    var entity := _make_combat_entity(true, 0)
    root.add_child(entity)
    var cc := entity.get_node("CombatComponent") as CombatComponent
    var target := _make_target_with_health(1, 100)
    root.add_child(target)
    entity.global_position = Vector3(0, 0, 0)
    var weapon := cc.get_current_weapon()
    var range_world := weapon.attack_range * CellUtil.CELL_SIZE
    target.global_position = Vector3(range_world + 1.0, 0.0, 0.0)
    cc.set_target(target)
    cc._physics_process(0.1)
    var health_out: int = target.get_node("HealthComponent").current_health
    target.get_node("HealthComponent").current_health = 100
    target.global_position = Vector3(range_world - 1.0, 0.0, 0.0)
    cc.set_target(target)
    cc._physics_process(0.1)
    var health_in: int = target.get_node("HealthComponent").current_health
    TestHelper.assert_eq(health_out, 100, "out of XZ range does not fire")
    TestHelper.assert_true(health_in < 100, "within XZ range fires")
    root.remove_child(entity)
    root.remove_child(target)
    entity.free()
    target.free()
