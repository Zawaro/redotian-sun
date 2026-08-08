extends Node

# ShroudSystem tests — authoritative fog-of-war grid, shadowcasting, reveals,
# allied sharing, shroud growth, and fog-gated interaction.

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")

const GRID := Vector2i(50, 50)
const CENTER := Vector2i(40, 40)

var _ss: Node = null
var _ts: Node = null
var _sh: Node = null
var _pm: Node = null
var _sm: Node = null
var _fog_was: bool = false


func _ready() -> void:
    _ss = get_node_or_null("/root/ShroudSystem")
    _ts = get_node_or_null("/root/TerrainSystem")
    _sh = get_node_or_null("/root/SpatialHashSingleton")
    _pm = get_node_or_null("/root/PlayerManager")
    _sm = get_node_or_null("/root/SelectionManager")


func _guard() -> bool:
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return false
    return true


var _saved_insets := Vector4i(0, 0, 0, 0)


func _setup() -> void:
    _ts.init_grid(GRID.x, GRID.y)
    _saved_insets = Vector4i(
        BoundsSystem.left_inset,
        BoundsSystem.right_inset,
        BoundsSystem.top_inset,
        BoundsSystem.bottom_inset,
    )
    BoundsSystem.left_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.x
    BoundsSystem.right_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.y
    BoundsSystem.top_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.z
    BoundsSystem.bottom_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.w
    _restore_players()
    _sh._building_cells.clear()
    _fog_was = false
    var rules := GlobalRules.get_current()
    if rules:
        _fog_was = rules.fog_of_war
        rules.fog_of_war = false
    _ss.resolve_dirty()


func _teardown() -> void:
    BoundsSystem.left_inset = _saved_insets.x
    BoundsSystem.right_inset = _saved_insets.y
    BoundsSystem.top_inset = _saved_insets.z
    BoundsSystem.bottom_inset = _saved_insets.w
    var rules := GlobalRules.get_current()
    if rules:
        rules.fog_of_war = _fog_was
        rules.shroud_grows = false
    _restore_players()
    _sh._building_cells.clear()


func _restore_players() -> void:
    _pm._players.clear()
    _pm._local_player_id = 0
    _pm._init_defaults()


func _set_team(player_id: int, team_id: int) -> void:
    _pm.get_player_data(player_id).team_id = team_id


func _in_play(cell: Vector2i) -> bool:
    return BoundsSystem.is_in_play_area(cell)


func _set_fog(enabled: bool) -> void:
    var rules := GlobalRules.get_current()
    if rules:
        rules.fog_of_war = enabled


func _stamp_ridge_height(cell: Vector2i, height: int) -> void:
    var corners: Array[Vector2i] = [
        cell, cell + Vector2i(1, 0), cell + Vector2i(0, 1), cell + Vector2i(1, 1)
    ]
    for corner in corners:
        _ts._set_vertex_no_cascade(corner.x, corner.y, height)


# ========================================
# Grid init
# ========================================


func test_grid_init_all_shroud():
    if not _guard():
        return
    _setup()
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, CENTER) and not _ss.is_explored(0, CENTER),
            "fresh grid: cell is neither visible nor explored",
        )
    )
    _teardown()


func test_grid_reinit_clears_state():
    if not _guard():
        return
    _setup()
    var key: int = _ss.register_revealer(0, CENTER, 2, 0.0, true)
    TestHelper.assert_true(_ss.is_visible(0, CENTER), "revealer reveals before resize")
    _ts.init_grid(GRID.x + 10, GRID.y + 10)
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, CENTER) and not _ss.is_explored(0, CENTER),
            "grid resize clears per-player state",
        )
    )
    (
        TestHelper
        . assert_true(
            _ss._grid_size == GRID + Vector2i(10, 10),
            "grid size tracks terrain after resize",
        )
    )
    _teardown()


# ========================================
# Shadowcasting: hills, buildings, air
# ========================================


func test_hill_blocks_vision():
    if not _guard():
        return
    _setup()
    for z in range(40, 43):
        _stamp_ridge_height(Vector2i(40, z), 3)
    var key: int = _ss.register_revealer(0, Vector2i(40, 35), 12, 0.0, true)
    TestHelper.assert_true(_ss.is_visible(0, Vector2i(40, 35)), "revealer cell visible")
    TestHelper.assert_true(_ss.is_visible(0, Vector2i(40, 36)), "cell below wall visible")
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, Vector2i(40, 40)),
            "wall top not visible from below",
        )
    )
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, Vector2i(40, 45)),
            "cell behind wall is not visible from low ground",
        )
    )
    _ss.unregister_revealer(0, key)
    _teardown()


func test_high_ground_sees_over():
    if not _guard():
        return
    _setup()
    for z in range(40, 43):
        _stamp_ridge_height(Vector2i(40, z), 3)
    var viewer_height: float = TerrainSystem.HEIGHT_STEP * 3.0
    var key: int = _ss.register_revealer(0, Vector2i(40, 42), 12, viewer_height, true)
    (
        TestHelper
        . assert_true(
            _ss.is_visible(0, Vector2i(40, 45)),
            "high-ground revealer sees into the valley",
        )
    )
    _ss.unregister_revealer(0, key)
    _teardown()


func test_building_blocks_vision():
    if not _guard():
        return
    _setup()
    var building_cell := Vector2i(40, 40)
    _sh.register_building_cells([building_cell] as Array[Vector2i])
    var key: int = _ss.register_revealer(0, Vector2i(40, 35), 12, 0.0, true)
    TestHelper.assert_true(_ss.is_visible(0, building_cell), "building cell itself visible")
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, Vector2i(40, 45)),
            "cell behind building is not visible",
        )
    )
    _ss.unregister_revealer(0, key)
    _sh.unregister_building_cells([building_cell] as Array[Vector2i])
    _teardown()


func test_air_revealer_ignores_blockers():
    if not _guard():
        return
    _setup()
    var ridge := Vector2i(40, 40)
    _stamp_ridge_height(ridge, 3)
    _sh.register_building_cells([Vector2i(40, 42)] as Array[Vector2i])
    var key: int = _ss.register_revealer(0, Vector2i(40, 35), 10, 0.0, false)
    (
        TestHelper
        . assert_true(
            _ss.is_visible(0, Vector2i(40, 45)),
            "air revealer sees over ridge and building",
        )
    )
    TestHelper.assert_true(_ss.is_visible(0, Vector2i(40, 42)), "building cell visible to air")
    _ss.unregister_revealer(0, key)
    _sh.unregister_building_cells([Vector2i(40, 42)] as Array[Vector2i])
    _teardown()


# ========================================
# Ref counting
# ========================================


func test_overlapping_revealers_stack():
    if not _guard():
        return
    _setup()
    var a: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    var b: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    TestHelper.assert_true(_ss.is_visible(0, CENTER), "overlap visible")
    _ss.unregister_revealer(0, a)
    TestHelper.assert_true(_ss.is_visible(0, CENTER), "still visible while one revealer active")
    _ss.unregister_revealer(0, b)
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, CENTER) and _ss.is_explored(0, CENTER),
            "last revealer leaving reverts to fog, not shroud",
        )
    )
    _teardown()


func test_move_between_cells_no_leak():
    if not _guard():
        return
    _setup()
    var a: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    _ss.unregister_revealer(0, a)
    var b: int = _ss.register_revealer(0, CENTER + Vector2i(3, 0), 1, 0.0, true)
    TestHelper.assert_true(not _ss.is_visible(0, CENTER), "old cell loses visibility")
    TestHelper.assert_true(_ss.is_visible(0, CENTER + Vector2i(3, 0)), "new cell visible")
    TestHelper.assert_eq(
        _ss._states[0]["visible_count"][_ss._cell_index(CENTER)], 0, "no leaked count"
    )
    _ss.unregister_revealer(0, b)
    _teardown()


func test_unregister_unknown_key_noop():
    if not _guard():
        return
    _setup()
    var a: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    _ss.unregister_revealer(0, 999999)
    TestHelper.assert_true(_ss.is_visible(0, CENTER), "unknown unregister is a no-op")
    _ss.unregister_revealer(0, a)
    _teardown()


func test_explored_persistence_and_precedence():
    if not _guard():
        return
    _setup()
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, CENTER) and not _ss.is_explored(0, CENTER),
            "unexplored cell is neither visible nor explored",
        )
    )
    var a: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    TestHelper.assert_true(_ss.is_visible(0, CENTER) and _ss.is_explored(0, CENTER), "visible wins")
    _ss.unregister_revealer(0, a)
    (
        TestHelper
        . assert_true(
            not _ss.is_visible(0, CENTER) and _ss.is_explored(0, CENTER),
            "after revealer leaves: fog (explored) but not visible",
        )
    )
    _ss.resolve_dirty()
    var resolved: PackedByteArray = _ss._states[0]["resolved"]
    TestHelper.assert_eq(
        resolved[_ss._cell_index(CENTER)], _ss.STATE_FOG, "resolved state is fog after leave"
    )
    _teardown()


# ========================================
# Reveal limiter (blue visible bounds)
# ========================================


func test_reveal_clamped_at_play_edge():
    if not _guard():
        return
    _setup()
    var edge := Vector2i(26, 27)
    var outside := Vector2i(21, 22)
    TestHelper.assert_true(_in_play(edge), "edge center is in play area")
    TestHelper.assert_true(not _in_play(outside), "far corner is outside play area")
    var key: int = _ss.register_revealer(0, edge, 5, 0.0, true)
    TestHelper.assert_true(_ss.is_explored(0, edge), "in-play cell explored")
    (
        TestHelper
        . assert_true(
            not _ss.is_explored(0, outside),
            "out-of-play cell never explored even inside radius",
        )
    )
    _ss.unregister_revealer(0, key)
    _teardown()


func test_explore_all_respects_bounds():
    if not _guard():
        return
    _setup()
    _ss.explore_all(0)
    TestHelper.assert_true(_ss.is_explored(0, CENTER), "in-play cell explored by explore_all")
    (
        TestHelper
        . assert_true(
            not _ss.is_explored(0, Vector2i(0, 0)),
            "out-of-play cell not explored by explore_all",
        )
    )
    TestHelper.assert_eq(_ss.get_explored_percentage(0), 1.0, "percentage counts play area only")
    _teardown()


func test_percentage_zero_before_exploration():
    if not _guard():
        return
    _setup()
    TestHelper.assert_eq(_ss.get_explored_percentage(0), 0.0, "percentage zero before exploration")
    _teardown()


# ========================================
# Allied sharing
# ========================================


func test_allied_shares_vision():
    if not _guard():
        return
    _setup()
    _set_team(0, 1)
    _set_team(1, 1)
    var key: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    TestHelper.assert_true(_ss.is_visible(1, CENTER), "ally sees what teammate reveals")
    TestHelper.assert_true(_ss.is_explored(1, CENTER), "ally shares explored state")
    (
        TestHelper
        . assert_eq(
            _ss._states[1]["visible_count"][_ss._cell_index(CENTER)],
            0,
            "sharing does not mutate ally grid",
        )
    )
    _ss.unregister_revealer(0, key)
    _teardown()


func test_enemy_does_not_share_vision():
    if not _guard():
        return
    _setup()
    _set_team(0, 1)
    _set_team(1, 2)
    var key: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    TestHelper.assert_true(not _ss.is_visible(1, CENTER), "enemy does not see ally's reveal")
    TestHelper.assert_true(not _ss.is_explored(1, CENTER), "enemy does not share explored state")
    _ss.unregister_revealer(0, key)
    _teardown()


func test_per_player_isolation():
    if not _guard():
        return
    _setup()
    _set_team(0, 1)
    _set_team(1, 2)
    var key: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    TestHelper.assert_true(_ss.is_visible(0, CENTER), "player 0 sees own reveal")
    TestHelper.assert_true(not _ss.is_visible(1, CENTER), "player 1 unaffected")
    _ss.unregister_revealer(0, key)
    _teardown()


func test_effective_state_union():
    if not _guard():
        return
    _setup()
    _set_team(0, 1)
    _set_team(1, 1)
    var key: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    _ss.explore_area(1, CENTER + Vector2i(0, 5), 1)
    var effective: PackedByteArray = _ss.get_effective_state(1)
    (
        TestHelper
        . assert_eq(
            effective[_ss._cell_index(CENTER)],
            _ss.STATE_VISIBLE,
            "effective state visible from ally reveal",
        )
    )
    (
        TestHelper
        . assert_eq(
            effective[_ss._cell_index(CENTER + Vector2i(0, 5))],
            _ss.STATE_FOG,
            "effective state fog from ally explore",
        )
    )
    (
        TestHelper
        . assert_eq(
            effective[_ss._cell_index(Vector2i(0, 0))],
            _ss.STATE_SHROUD,
            "effective state shroud outside play area",
        )
    )
    _ss.unregister_revealer(0, key)
    _teardown()


# ========================================
# Circular reveals
# ========================================


func test_explore_area_permanent():
    if not _guard():
        return
    _setup()
    _ss.explore_area(0, CENTER, 2)
    TestHelper.assert_true(_ss.is_explored(0, CENTER), "explore area marks explored")
    TestHelper.assert_true(not _ss.is_visible(0, CENTER), "explore area is fog, not visible")
    TestHelper.assert_true(_ss.is_explored(0, CENTER + Vector2i(2, 0)), "radius ring explored")
    _teardown()


func test_reveal_area_reverts_to_fog():
    if not _guard():
        return
    _setup()
    _ss.reveal_area(0, CENTER, 2, 0.1)
    TestHelper.assert_true(_ss.is_visible(0, CENTER), "reveal area visible while active")
    _ss._time += 1.0
    _ss._tick_temp_reveals()
    TestHelper.assert_true(not _ss.is_visible(0, CENTER), "reveal area expires")
    TestHelper.assert_true(_ss.is_explored(0, CENTER), "reverted to explored (fog), never shroud")
    _teardown()


func test_reveal_area_clamps_to_play_area():
    if not _guard():
        return
    _setup()
    var edge := Vector2i(26, 27)
    var outside := Vector2i(21, 22)
    _ss.reveal_area(0, edge, 5, 1.0)
    TestHelper.assert_true(_ss.is_visible(0, edge), "in-play reveal visible")
    TestHelper.assert_true(
        not _ss.is_explored(0, outside), "reveal area never touches out-of-play cells"
    )
    _teardown()


# ========================================
# Shroud growth
# ========================================


func test_growth_reverts_frontier_one_ring():
    if not _guard():
        return
    _setup()
    var rules := GlobalRules.get_current()
    rules.shroud_grows = true
    _ss.explore_area(0, CENTER, 3)
    var key: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    _ss._growth_timer = 0.0
    _ss._tick_growth(0.01)
    TestHelper.assert_true(_ss.is_explored(0, CENTER), "visible cell protected from growth")
    TestHelper.assert_true(
        _ss.is_explored(0, CENTER + Vector2i(1, 0)), "revealed neighbor protected"
    )
    (
        TestHelper
        . assert_true(
            not _ss.is_explored(0, CENTER + Vector2i(3, 0)),
            "outer frontier ring reverted to shroud",
        )
    )
    (
        TestHelper
        . assert_true(
            _ss.is_explored(0, CENTER + Vector2i(2, 0)),
            "inner non-visible ring not reverted in same tick",
        )
    )
    _ss.unregister_revealer(0, key)
    _teardown()


func test_growth_visible_cells_protected():
    if not _guard():
        return
    _setup()
    var rules := GlobalRules.get_current()
    rules.shroud_grows = true
    _ss.explore_area(0, CENTER, 3)
    var key: int = _ss.register_revealer(0, CENTER, 2, 0.0, true)
    _ss._growth_timer = 0.0
    _ss._tick_growth(0.01)
    (
        TestHelper
        . assert_true(
            _ss.is_explored(0, CENTER + Vector2i(2, 0)),
            "actively revealed ring protected",
        )
    )
    (
        TestHelper
        . assert_true(
            not _ss.is_explored(0, CENTER + Vector2i(3, 0)),
            "unwatched ring reverts",
        )
    )
    _ss.unregister_revealer(0, key)
    _teardown()


func test_growth_disabled_is_inert():
    if not _guard():
        return
    _setup()
    _ss.explore_area(0, CENTER, 3)
    _ss._growth_timer = 0.0
    _ss._tick_growth(0.01)
    TestHelper.assert_true(_ss.is_explored(0, CENTER + Vector2i(3, 0)), "no growth when disabled")
    _teardown()


# ========================================
# Incremental resolution
# ========================================


func test_resolve_noop_when_nothing_changed():
    if not _guard():
        return
    _setup()
    TestHelper.assert_eq(_ss.resolve_dirty(), 0, "no dirty cells -> no work")
    var key: int = _ss.register_revealer(0, CENTER, 1, 0.0, true)
    TestHelper.assert_true(_ss.resolve_dirty() > 0, "dirty cells resolved after register")
    TestHelper.assert_eq(_ss.resolve_dirty(), 0, "second resolve is clean")
    _ss.unregister_revealer(0, key)
    _teardown()


# ========================================
# Interaction filtering
# ========================================


func _make_weapon() -> WeaponData:
    var w := WeaponData.new()
    w.id = "TEST_WEAPON"
    w.damage = 10
    w.attack_range = 5.0
    w.rate_of_fire = 1.0
    return w


func _make_combat_entity(player_id: int) -> Node3D:
    var entity := Node3D.new()
    entity.name = "CombatEntity"
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    combat.weapons = [_make_weapon()]
    entity.add_child(combat)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
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


func _select_entity(entity: Node3D) -> void:
    _sm.deselect_all()
    _sm.add_child(entity)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    entity.add_child(sc)
    _sm.add_entity(sc)


func _orders_cursor_any(
    target: Node3D, cell: Vector2i, modifiers: Dictionary
) -> Array[OrderResult]:
    var pos: Vector3 = CellUtil.cell_to_world(cell)
    return OrderSystem.get_orders(target, cell, pos, modifiers)


func test_shrouded_enemy_falls_through_to_move():
    if not _guard():
        return
    _setup()
    _set_fog(true)
    var unit := _make_combat_entity(0)
    var target := _make_target(1)
    _select_entity(unit)
    target.global_position = CellUtil.cell_to_world(CENTER)
    target.position.y = 1.0
    add_child(target)
    var orders := _orders_cursor_any(target, CENTER, {})
    (
        TestHelper
        . assert_true(
            not orders.is_empty() and orders[0].cursor == CursorState.Type.MOVE,
            (
                "shrouded enemy produces move order, got %s"
                % [orders[0].cursor if orders else "empty"]
            ),
        )
    )
    target.queue_free()
    _teardown()


func test_revealed_enemy_is_attackable():
    if not _guard():
        return
    _setup()
    _set_fog(true)
    var unit := _make_combat_entity(0)
    var target := _make_target(1)
    _select_entity(unit)
    target.global_position = CellUtil.cell_to_world(CENTER)
    target.position.y = 1.0
    add_child(target)
    _ss.register_revealer(0, CENTER, 1, 0.0, true)
    var orders := _orders_cursor_any(target, CENTER, {})
    (
        TestHelper
        . assert_true(
            not orders.is_empty() and orders[0].cursor == CursorState.Type.ATTACK,
            (
                "revealed enemy produces attack order, got %s"
                % [orders[0].cursor if orders else "empty"]
            ),
        )
    )
    target.queue_free()
    _teardown()


func test_force_fire_into_shroud_gated():
    if not _guard():
        return
    _setup()
    _set_fog(true)
    var unit := _make_combat_entity(0)
    var target := _make_target(1)
    _select_entity(unit)
    target.global_position = CellUtil.cell_to_world(CENTER)
    target.position.y = 1.0
    add_child(target)
    var orders := _orders_cursor_any(target, CENTER, {OrderResult.MOD_FORCE_ATTACK: true})
    var is_attack := false
    for order in orders:
        if order.cursor == CursorState.Type.ATTACK:
            is_attack = true
    TestHelper.assert_true(not is_attack, "force-fire into shroud is gated (no attack order)")
    target.queue_free()
    _teardown()


func test_shrouded_resource_not_targetable():
    if not _guard():
        return
    _setup()
    _set_fog(true)
    var unit := _make_combat_entity(0)
    var target := _make_target(-1)
    target.add_to_group("drag_selectable")
    _select_entity(unit)
    target.global_position = CellUtil.cell_to_world(CENTER)
    target.position.y = 1.0
    add_child(target)
    var orders := _orders_cursor_any(target, CENTER, {})
    var is_harvest := false
    for order in orders:
        if order.cursor == CursorState.Type.HARVEST:
            is_harvest = true
    (
        TestHelper
        . assert_true(
            not orders.is_empty() and not is_harvest,
            "shrouded resource is not targetable for harvest",
        )
    )
    target.queue_free()
    _teardown()


func test_shrouded_entity_not_selectable():
    if not _guard():
        return
    _setup()
    _set_fog(true)
    var target := _make_target(-1)
    target.global_position = CellUtil.cell_to_world(CENTER)
    target.position.y = 1.0
    add_child(target)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    target.add_child(sc)
    _sm.deselect_all()
    _sm.select_entity(sc)
    (
        TestHelper
        . assert_true(
            not _sm.is_entity_selected(sc),
            "shrouded entity cannot be selected when fog is on",
        )
    )
    target.queue_free()
    _teardown()


func test_selectable_when_revealed_or_fog_off():
    if not _guard():
        return
    _setup()
    var target := _make_target(-1)
    target.global_position = CellUtil.cell_to_world(CENTER)
    target.position.y = 1.0
    add_child(target)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    target.add_child(sc)
    _sm.deselect_all()
    _sm.select_entity(sc)
    (
        TestHelper
        . assert_true(
            _sm.is_entity_selected(sc),
            "entity selectable when fog is off",
        )
    )
    _sm.remove_entity(sc)
    target.queue_free()
    _teardown()


func test_filter_disabled_without_fog():
    if not _guard():
        return
    _setup()
    var unit := _make_combat_entity(0)
    var target := _make_target(1)
    _select_entity(unit)
    target.global_position = CellUtil.cell_to_world(CENTER)
    target.position.y = 1.0
    add_child(target)
    var orders := _orders_cursor_any(target, CENTER, {})
    (
        TestHelper
        . assert_true(
            not orders.is_empty() and orders[0].cursor == CursorState.Type.ATTACK,
            "enemy attackable when fog is off",
        )
    )
    target.queue_free()
    _teardown()


# ========================================
# SpatialHash helper + GlobalRules defaults
# ========================================


func test_is_building_cell():
    if not _guard():
        return
    _setup()
    var cell := Vector2i(42, 42)
    TestHelper.assert_true(not _sh.is_building_cell(cell), "non-building cell false")
    _sh.register_building_cells([cell] as Array[Vector2i])
    TestHelper.assert_true(_sh.is_building_cell(cell), "building cell true")
    _sh.unregister_building_cells([cell] as Array[Vector2i])
    TestHelper.assert_true(not _sh.is_building_cell(cell), "unregistered building cell false")
    _teardown()


func test_global_rules_fog_defaults():
    var rules := GlobalRules.get_current()
    if rules == null:
        TestHelper.fail("GlobalRules not available")
        return
    TestHelper.assert_true(rules.fog_of_war == false, "fog_of_war defaults false")
    TestHelper.assert_true(rules.shroud_grows == false, "shroud_grows defaults false")
    TestHelper.assert_eq(rules.shroud_growth_interval, 10.0, "shroud_growth_interval defaults 10.0")
