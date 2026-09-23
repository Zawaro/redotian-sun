extends Node

# SpatialHash tests — cell reservation logic

var _sh: Node = null
var _ts: Node = null
var _bridge_root: Node = null
var _spawned_bridges: Array[Node3D] = []

const WHEEL_LOCOMOTOR_PATH: String = "res://games/ts/locomotors/Wheel.tres"
const A_CELL: Vector2i = Vector2i(20, 20)
const MID_CELL: Vector2i = Vector2i(21, 20)
const B_CELL: Vector2i = Vector2i(22, 20)


class StubBridge:
    extends Node3D
    var data: Dictionary = {}

    func get_bridge_cell_data() -> Dictionary:
        return data


func test_reserve_cell_succeeds():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    TestHelper.assert_true(
        result == true, "reserve_cell succeeds on empty cell: expected true, got false"
    )


func test_reserve_cell_fails_when_taken():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    _sh.reserve_cell(cell)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    TestHelper.assert_true(
        result == false, "reserve_cell fails on already reserved cell: expected false, got true"
    )


func test_release_cell_frees():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.clear_reservations()
    var cell := Vector2i(10, 10)
    _sh.reserve_cell(cell)
    _sh.release_cell(cell)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    (
        TestHelper
        . assert_true(
            result == true,
            "release_cell frees the cell: expected true after release, got false",
        )
    )


func test_is_cell_blocked_reflects_blocked():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.clear_reservations()
    _sh._blocked_cells.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._blocked_cells[key] = true
    var idle: bool = _sh.is_cell_blocked(cell)
    var reserved: bool = _sh.reserve_cell(cell)
    _sh._blocked_cells.erase(key)
    (
        TestHelper
        . assert_true(
            idle == true and reserved == false,
            "is_cell_blocked reflects blocked state: idle=%s, reserved=%s" % [idle, reserved],
        )
    )


func test_register_building_cells():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._building_cells.clear()
    var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6)]
    _sh.register_building_cells(cells)
    var all_registered: bool = (
        _sh._building_cells.has(CellUtil.cell_key(Vector2i(5, 5)))
        and _sh._building_cells.has(CellUtil.cell_key(Vector2i(6, 5)))
        and _sh._building_cells.has(CellUtil.cell_key(Vector2i(5, 6)))
        and _sh._building_cells.has(CellUtil.cell_key(Vector2i(6, 6)))
    )
    _sh._building_cells.clear()
    TestHelper.assert_true(
        all_registered, "register_building_cells adds all cells: not all cells registered"
    )


func test_unregister_building_cells():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._building_cells.clear()
    var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
    _sh.register_building_cells(cells)
    _sh.unregister_building_cells(cells)
    var has_55: bool = _sh._building_cells.has(CellUtil.cell_key(Vector2i(5, 5)))
    var has_65: bool = _sh._building_cells.has(CellUtil.cell_key(Vector2i(6, 5)))
    var all_removed: bool = not has_55 and not has_65
    TestHelper.assert_true(
        all_removed,
        "unregister_building_cells removes all cells: cells still present after unregister"
    )


func test_get_blocked_cells_merges_building_and_blocked():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    _sh._blocked_cells[CellUtil.cell_key(Vector2i(10, 10))] = true
    var building_cells: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20)]
    _sh.register_building_cells(building_cells)
    var blocked: Dictionary = _sh.get_blocked_cells()
    var has_blocked: bool = blocked.has(CellUtil.cell_key(Vector2i(10, 10)))
    var has_building1: bool = blocked.has(CellUtil.cell_key(Vector2i(20, 20)))
    var has_building2: bool = blocked.has(CellUtil.cell_key(Vector2i(21, 20)))
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    (
        TestHelper
        . assert_true(
            has_blocked and has_building1 and has_building2,
            (
                "get_blocked_cells merges building and blocked cells: blocked=%s, b1=%s, b2=%s"
                % [has_blocked, has_building1, has_building2]
            ),
        )
    )


func test_reserve_cell_fails_on_building_cell():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.clear_reservations()
    _sh._building_cells.clear()
    var cell := Vector2i(50, 50)
    var cells: Array[Vector2i] = [cell]
    _sh.register_building_cells(cells)
    var result: bool = _sh.reserve_cell(cell)
    _sh.clear_reservations()
    _sh._building_cells.clear()
    (
        TestHelper
        . assert_true(
            result == false,
            "reserve_cell fails on building cell: expected false for building cell, got true",
        )
    )


## Review P1-3: a `level > 0` reservation is refused unless a live deck exists at
## that level, so callers cannot claim empty air above a deckless cell. Level 0
## stays permissive (no deck required) so ground behavior is byte-identical.
func test_reserve_cell_above_ground_requires_deck():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _clear_bridge_fixture()
    _sh.clear_reservations()
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    var cell := Vector2i(12, 12)

    # Control: ground level 0 needs no deck and still succeeds on a deckless cell.
    TestHelper.assert_true(
        _sh.reserve_cell(cell, 0), "level 0 succeeds with no deck (ground unchanged)"
    )
    _sh.release_cell(cell, 0)

    # Level 1 over the same deckless cell must be refused and leave no key.
    TestHelper.assert_true(not _sh.reserve_cell(cell, 1), "level 1 with no deck is refused")
    (
        TestHelper
        . assert_true(
            not _sh.get_reserved().has(CellUtil.cell_level_key(cell, 1)),
            "refused level-1 reservation creates no key",
        )
    )

    # Register a real level-1 deck on the same cell: the reservation now succeeds.
    _span_level_bridge(cell, 1)
    _sh.rebuild()
    TestHelper.assert_true(
        _sh.has_bridge_on_cell(cell, 1), "fixture registered a live level-1 deck"
    )
    TestHelper.assert_true(_sh.reserve_cell(cell, 1), "level 1 succeeds once a deck exists")

    _sh.clear_reservations()
    _clear_bridge_fixture()
    _sh.rebuild()


func _span_level_bridge(cell: Vector2i, level: int) -> StubBridge:
    if _bridge_root == null:
        _bridge_root = Engine.get_main_loop().root
    var bridge := StubBridge.new()
    bridge.data = {
        "surface_height": 4.0 * float(level),
        "is_end": false,
        "piece_id": "res_%d" % level,
        "level": level,
    }
    bridge.add_to_group("bridge")
    _bridge_root.add_child(bridge)
    bridge.global_position = CellUtil.cell_to_world(cell)
    _spawned_bridges.append(bridge)
    return bridge


func _clear_bridge_fixture() -> void:
    if _bridge_root == null:
        return
    for node in _spawned_bridges:
        if is_instance_valid(node):
            _bridge_root.remove_child(node)
            node.free()
    _spawned_bridges.clear()


func _test_entity_on_cell(
    cell: Vector2i, mc: MovementController, expected: bool, label: String
) -> void:
    _sh._grid.clear()
    var key: int = CellUtil.cell_key(cell)
    if mc != null:
        _sh._grid[key] = [{"node": Node3D.new(), "mc": mc}]
    var result: bool = _sh.is_any_entity_on_cell(cell)
    _sh._grid.erase(key)
    if mc != null:
        mc.queue_free()
    (
        TestHelper
        . assert_true(
            result == expected,
            (
                "is_any_entity_on_cell %s: is_any_entity_on_cell %s — expected %s, got %s"
                % [label, label, expected, result]
            ),
        )
    )


func test_is_any_entity_on_cell_empty():
    _test_entity_on_cell(Vector2i(99, 99), null, false, "returns false for empty cell")


func test_is_any_entity_on_cell_with_idle_unit():
    var mc := MovementController.new()
    mc._state = MovementController.State.IDLE
    _test_entity_on_cell(Vector2i(10, 10), mc, true, "returns true for idle unit")


func test_is_any_entity_on_cell_with_moving_unit():
    var mc := MovementController.new()
    mc._state = MovementController.State.MOVING
    _test_entity_on_cell(Vector2i(10, 10), mc, true, "returns true for moving unit")


func test_is_any_entity_on_cell_resource_only():
    _sh._grid.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._grid[key] = [{"node": Node3D.new(), "mc": null}]
    var result: bool = _sh.is_any_entity_on_cell(cell)
    _sh._grid.erase(key)
    (
        TestHelper
        . assert_true(
            result == false,
            (
                "is_any_entity_on_cell returns false for resource-only cell: "
                + "expected false for resource-only cell, got true"
            ),
        )
    )


## Bridge regression: a deck occupant (level 1) must not make the same cell read
## as occupied at ground level, so ground building/deploy/transport still work
## under a bridge. Non-vacuity: the same entry IS found at its deck level and via
## the explicit any-level query.
func test_is_any_entity_on_cell_deck_only_ignores_ground():
    _sh._grid.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    var deck_mc := MovementController.new()
    _sh._grid[key] = [{"node": Node3D.new(), "mc": deck_mc, "level": 1}]

    var at_ground: bool = _sh.is_any_entity_on_cell(cell)
    var at_deck: bool = _sh.is_any_entity_on_cell(cell, 1)
    var any_level: bool = _sh.is_any_entity_on_cell(cell, -1)

    var ground_mc := MovementController.new()
    _sh._grid[key] = [{"node": Node3D.new(), "mc": ground_mc, "level": 0}]
    var ground_occ: bool = _sh.is_any_entity_on_cell(cell)

    _sh._grid.erase(key)
    deck_mc.queue_free()
    ground_mc.queue_free()

    TestHelper.assert_true(
        not at_ground, "deck-only occupant leaves ground cell unoccupied: expected false, got true"
    )
    TestHelper.assert_true(at_deck, "deck occupant is found at its level: expected true, got false")
    TestHelper.assert_true(
        any_level, "explicit -1 finds the deck occupant: expected true, got false"
    )
    TestHelper.assert_true(
        ground_occ, "ground occupant reads occupied by default: expected true, got false"
    )


func test_get_shared_cell_count_empty():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._shared_cell_counts.clear()
    var cell := Vector2i(50, 50)
    var count: int = _sh.get_shared_cell_count(cell)
    TestHelper.assert_true(
        count == 0, "get_shared_cell_count returns 0 for empty cell: expected 0, got %d" % count
    )


func test_get_shared_cell_count_with_entries():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._shared_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._shared_cell_counts[key] = 2
    var count: int = _sh.get_shared_cell_count(cell)
    _sh._shared_cell_counts.erase(key)
    TestHelper.assert_true(
        count == 2, "get_shared_cell_count returns correct count: expected 2, got %d" % count
    )


func test_is_cell_full_for_shared():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._shared_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._shared_cell_counts[key] = 3
    var full: bool = _sh.is_cell_full_for_shared(cell)
    _sh._shared_cell_counts.erase(key)
    (
        TestHelper
        . assert_true(
            full == true,
            (
                "is_cell_full_for_shared returns true at capacity: "
                + "expected true at capacity, got false"
            ),
        )
    )


func test_is_cell_not_full_for_shared():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._shared_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    _sh._shared_cell_counts[key] = 2
    var full: bool = _sh.is_cell_full_for_shared(cell)
    _sh._shared_cell_counts.erase(key)
    (
        TestHelper
        . assert_true(
            full == false,
            (
                "is_cell_full_for_shared returns false below capacity: "
                + "expected false below capacity, got true"
            ),
        )
    )


func test_get_crushable_enemies_empty():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._grid.clear()
    var cell := Vector2i(10, 10)
    var enemies: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    (
        TestHelper
        . assert_true(
            enemies.is_empty(),
            (
                (
                    "get_crushable_enemies returns empty for empty cell: "
                    + "expected empty array, got %d entries"
                )
                % enemies.size()
            ),
        )
    )


func test_get_crushable_enemies_filters_by_player():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._grid.clear()
    _sh._shared_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var cell_world := CellUtil.cell_to_world(cell)
    var key: int = CellUtil.cell_key(cell)
    var friendly := Node3D.new()
    friendly.name = "Friendly"
    var friendly_stats := StatsComponent.new()
    friendly_stats.name = "StatsComponent"
    friendly_stats.entity_type = EntityData.EntityType.INFANTRY
    friendly_stats.player_id = 0
    friendly_stats.crushable = true
    friendly.add_child(friendly_stats)
    add_child(friendly)
    var enemy := Node3D.new()
    enemy.name = "Enemy"
    var enemy_stats := StatsComponent.new()
    enemy_stats.name = "StatsComponent"
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = true
    enemy.add_child(enemy_stats)
    add_child(enemy)
    _sh._grid[key] = [
        {
            "node": friendly,
            "mc": null,
            "entity_type": EntityData.EntityType.INFANTRY,
            "player_id": 0,
        },
        {
            "node": enemy,
            "mc": null,
            "entity_type": EntityData.EntityType.INFANTRY,
            "player_id": 1,
        },
    ]
    var enemies: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _sh._grid.erase(key)
    _sh.set_process(true)
    _sh.set_physics_process(true)
    (
        TestHelper
        . assert_true(
            enemies.size() == 1 and enemies[0] == enemy,
            "get_crushable_enemies filters by player_id: expected 1 enemy, got %d" % enemies.size(),
        )
    )
    remove_child(friendly)
    remove_child(enemy)
    friendly.free()
    enemy.free()


func test_get_crushable_enemies_skips_non_crushable():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._grid.clear()
    _sh._shared_cell_counts.clear()
    var cell := Vector2i(10, 10)
    var key: int = CellUtil.cell_key(cell)
    var enemy := Node3D.new()
    enemy.name = "Enemy"
    var enemy_stats := StatsComponent.new()
    enemy_stats.name = "StatsComponent"
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = false
    enemy.add_child(enemy_stats)
    add_child(enemy)
    _sh._grid[key] = [
        {"node": enemy, "mc": null, "entity_type": EntityData.EntityType.INFANTRY, "player_id": 1},
    ]
    var enemies: Array = _sh.get_crushable_enemies_on_cell(cell, 0)
    _sh._grid.erase(key)
    _sh.set_process(true)
    _sh.set_physics_process(true)
    TestHelper.assert_true(
        enemies.is_empty(),
        "get_crushable_enemies skips non-crushable: non-crushable enemy was returned"
    )
    remove_child(enemy)
    enemy.free()


func test_vehicle_sharer_counted_when_idle():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entity := Node3D.new()
    entity.name = "VehicleSharer"
    entity.add_to_group("entities")
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.entity_type = EntityData.EntityType.VEHICLE
    entity.add_child(stats)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    mc._shares_cell = true
    _sh.add_child(entity)
    _sh.rebuild()
    var cell := CellUtil.world_to_cell(entity.global_position)
    var count: int = _sh.get_shared_cell_count(cell)
    var blocked: bool = _sh.is_cell_blocked(cell)
    _sh.remove_child(entity)
    entity.free()
    (
        TestHelper
        . assert_true(
            count == 1 and not blocked,
            (
                (
                    "non-infantry sharer counted in shared cells, not blocked: count=%d blocked=%s,"
                    + " expected 1/false"
                )
                % [count, str(blocked)]
            ),
        )
    )


func _make_grid_entity(entity_name: String) -> Node3D:
    var entity := Node3D.new()
    entity.name = entity_name
    entity.add_to_group("entities")
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.entity_type = EntityData.EntityType.VEHICLE
    stats.player_id = 0
    entity.add_child(stats)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    return entity


func test_reconcile_moves_entry_on_cell_change():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entity := _make_grid_entity("ReconcileMover")
    _sh.add_child(entity)
    _sh.rebuild()
    var cell_a := CellUtil.world_to_cell(entity.global_position)
    var cell_b := cell_a + Vector2i(2, 0)
    entity.global_position = CellUtil.cell_to_world(cell_b)
    _sh._reconcile()
    var moved: bool = (
        _sh.is_cell_blocked(cell_b)
        and not _sh.is_cell_blocked(cell_a)
        and not _sh.is_any_entity_on_cell(cell_a)
    )
    _sh.remove_child(entity)
    entity.free()
    _sh.rebuild()
    TestHelper.assert_true(
        moved, "reconcile moves an entry to its new cell: expected blocked at B, empty at A"
    )


func test_reconcile_flips_blocked_on_state_change():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entity := _make_grid_entity("ReconcileStater")
    _sh.add_child(entity)
    _sh.rebuild()
    var cell := CellUtil.world_to_cell(entity.global_position)
    var blocked_idle: bool = _sh.is_cell_blocked(cell)
    var mc: MovementController = entity.get_node("MovementController") as MovementController
    mc._state = MovementController.State.MOVING
    _sh._reconcile()
    var blocked_moving: bool = _sh.is_cell_blocked(cell)
    mc._state = MovementController.State.IDLE
    _sh._reconcile()
    var blocked_again: bool = _sh.is_cell_blocked(cell)
    _sh.remove_child(entity)
    entity.free()
    _sh.rebuild()
    (
        TestHelper
        . assert_true(
            blocked_idle and not blocked_moving and blocked_again,
            (
                "reconcile flips blocked on IDLE/MOVING transitions: idle=%s moving=%s idle2=%s"
                % [str(blocked_idle), str(blocked_moving), str(blocked_again)]
            ),
        )
    )


func test_reconcile_preserves_entry_order():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var e1 := _make_grid_entity("OrderFirst")
    var e2 := _make_grid_entity("OrderSecond")
    _sh.add_child(e1)
    _sh.add_child(e2)
    _sh.rebuild()
    var cell := CellUtil.world_to_cell(e1.global_position)
    e2.global_position = CellUtil.cell_to_world(cell + Vector2i(3, 3))
    _sh._reconcile()
    var after_away: Array = _sh.get_entries(cell).duplicate()
    e2.global_position = CellUtil.cell_to_world(cell)
    _sh._reconcile()
    var after_back: Array = _sh.get_entries(cell).duplicate()
    var order_ok: bool = (
        after_away.size() == 1
        and after_away[0]["node"] == e1
        and after_back.size() == 2
        and after_back[0]["node"] == e1
        and after_back[1]["node"] == e2
    )
    _sh.remove_child(e1)
    _sh.remove_child(e2)
    e1.free()
    e2.free()
    _sh.rebuild()
    TestHelper.assert_true(
        order_ok, "reconcile keeps remaining order and appends re-arrivals at the end"
    )


func test_reconcile_query_parity_with_rebuild():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entity := _make_grid_entity("Parity")
    _sh.add_child(entity)
    _sh.rebuild()
    var cell_b := CellUtil.world_to_cell(entity.global_position) + Vector2i(1, 1)
    entity.global_position = CellUtil.cell_to_world(cell_b)
    _sh._reconcile()
    var reconciled_size: int = _sh.get_entries(cell_b).size()
    _sh.rebuild()
    var rebuilt_size: int = _sh.get_entries(cell_b).size()
    _sh.remove_child(entity)
    entity.free()
    _sh.rebuild()
    TestHelper.assert_eq(
        reconciled_size, rebuilt_size, "reconcile and rebuild agree on entry count at moved cell"
    )


## Regression (#295): a queue_free()'d entity stays in the global "entities"
## group until a frame tick, and rebuild() scans that group. Rebuild must skip
## entities pending deletion so dying units don't pollute the grid.
func test_rebuild_skips_queued_for_deletion_entities():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entity := _make_grid_entity("Doomed")
    _sh.add_child(entity)
    var cell := CellUtil.world_to_cell(entity.global_position)
    entity.queue_free()
    _sh.rebuild()
    var count: int = _sh.get_shared_cell_count(cell)
    var blocked: bool = _sh.is_cell_blocked(cell)
    (
        TestHelper
        . assert_eq(
            count,
            0,
            "queued-for-deletion entity is not counted in shared cells (got %s)" % count,
        )
    )
    TestHelper.assert_true(not blocked, "queued-for-deletion entity does not block its cell")


## Spec: deck and ground are independent occupancy levels. An idle non-sharing
## unit standing at level 1 must report blocked only at level 1.
func test_deck_occupant_does_not_block_ground():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entity := _make_grid_entity("DeckBlocker")
    _sh.add_child(entity)
    var mc := entity.get_node("MovementController") as MovementController
    mc._surface_level = 1
    _sh.rebuild()
    var cell := CellUtil.world_to_cell(entity.global_position)
    var deck_bound: bool = _sh.get_blocked_cells(1).has(CellUtil.cell_level_key(cell, 1))
    var ground_blocked_default: bool = _sh.is_cell_blocked(cell)
    var ground_in_level_zero: bool = _sh.get_blocked_cells(0).has(CellUtil.cell_level_key(cell, 0))
    _sh.remove_child(entity)
    entity.free()
    _sh.rebuild()
    TestHelper.assert_true(deck_bound, "level-1 occupant blocks the deck level")
    TestHelper.assert_true(
        not ground_blocked_default, "level-1 occupant does NOT block the ground (default level 0)"
    )
    TestHelper.assert_true(
        not ground_in_level_zero, "level-1 occupant absent from the level-0 blocked set"
    )


## Spec: ground and deck are independent occupancy levels. An idle non-sharing
## unit standing at level 0 must report blocked only at level 0.
func test_ground_occupant_does_not_block_deck():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entity := _make_grid_entity("GroundBlocker")
    _sh.add_child(entity)
    _sh.rebuild()
    var cell := CellUtil.world_to_cell(entity.global_position)
    var ground_blocked: bool = _sh.is_cell_blocked(cell)
    var deck_in_level_one: bool = _sh.get_blocked_cells(1).has(CellUtil.cell_level_key(cell, 1))
    var deck_blocked: bool = _sh.is_cell_blocked(cell, 1)
    _sh.remove_child(entity)
    entity.free()
    _sh.rebuild()
    TestHelper.assert_true(ground_blocked, "level-0 occupant blocks the ground (default)")
    TestHelper.assert_true(
        not deck_in_level_one, "level-0 occupant absent from the level-1 blocked set"
    )
    TestHelper.assert_true(not deck_blocked, "level-0 occupant does NOT block the deck level")


## Spec scenario "Default level is ground": the no-arg query and no-arg helpers
## return level-0 results identical to the pre-level behavior.
func test_default_level_zero_blocking_unchanged():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    var cell := Vector2i(30, 30)
    var key: int = CellUtil.cell_key(cell)
    _sh._blocked_cells[key] = true
    var no_arg: Dictionary = _sh.get_blocked_cells()
    var level_zero: Dictionary = _sh.get_blocked_cells(0)
    var level_one: Dictionary = _sh.get_blocked_cells(1)
    var building: Array[Vector2i] = [Vector2i(31, 30)]
    _sh.register_building_cells(building)
    var building_key: int = CellUtil.cell_key(Vector2i(31, 30))
    var has_building_ground: bool = _sh.get_blocked_cells(0).has(building_key)
    var has_building_deck: bool = _sh.get_blocked_cells(1).has(building_key)
    var is_blocked_default: bool = _sh.is_cell_blocked(cell)
    var is_blocked_deck: bool = _sh.is_cell_blocked(cell, 1)
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    (
        TestHelper
        . assert_true(
            no_arg.has(key) and level_zero.has(key),
            "no-arg and level-0 get_blocked_cells both contain the ground blocker",
        )
    )
    TestHelper.assert_true(not level_one.has(key), "level-1 query excludes the ground blocker")
    TestHelper.assert_true(is_blocked_default, "is_cell_blocked defaults to level 0")
    TestHelper.assert_true(
        not is_blocked_deck, "is_cell_blocked(cell, 1) false for a ground blocker"
    )
    (
        TestHelper
        . assert_true(
            has_building_ground and not has_building_deck,
            "building cells merge into level 0 only (buildings are ground-only)",
        )
    )


## Spec: `get_entries(cell, level)` and `is_any_entity_on_cell(cell, level)` are
## level-scoped; the no-arg forms keep matching any level.
func test_get_entries_and_any_entity_level_scoped():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh._grid.clear()
    var cell := Vector2i(40, 40)
    var key: int = CellUtil.cell_key(cell)
    var mc_ground := MovementController.new()
    var mc_deck := MovementController.new()
    var node_ground := Node3D.new()
    var node_deck := Node3D.new()
    _sh._grid[key] = [
        {"node": node_ground, "mc": mc_ground, "level": 0},
        {"node": node_deck, "mc": mc_deck, "level": 1},
    ]
    var entries_ground: Array = _sh.get_entries(cell, 0)
    var entries_deck: Array = _sh.get_entries(cell, 1)
    var entries_any: Array = _sh.get_entries(cell)
    var any_ground: bool = _sh.is_any_entity_on_cell(cell, 0)
    var any_deck: bool = _sh.is_any_entity_on_cell(cell, 1)
    var any_default: bool = _sh.is_any_entity_on_cell(cell)
    # Drop the deck entry, leaving ground only: the deck query must go false.
    _sh._grid[key] = [{"node": node_ground, "mc": mc_ground, "level": 0}]
    var any_deck_after_remove: bool = _sh.is_any_entity_on_cell(cell, 1)
    var any_ground_after_remove: bool = _sh.is_any_entity_on_cell(cell, 0)
    _sh._grid.erase(key)
    mc_ground.free()
    mc_deck.free()
    node_ground.free()
    node_deck.free()
    (
        TestHelper
        . assert_true(
            entries_ground.size() == 1 and int(entries_ground[0]["level"]) == 0,
            "get_entries(cell, 0) returns only the ground occupant",
        )
    )
    (
        TestHelper
        . assert_true(
            entries_deck.size() == 1 and int(entries_deck[0]["level"]) == 1,
            "get_entries(cell, 1) returns only the deck occupant",
        )
    )
    TestHelper.assert_true(entries_any.size() == 2, "get_entries(cell) returns both levels")
    (
        TestHelper
        . assert_true(
            any_ground and any_deck and any_default,
            "is_any_entity_on_cell finds occupants at the queried and any level",
        )
    )
    (
        TestHelper
        . assert_true(
            not any_deck_after_remove and any_ground_after_remove,
            "level query is exact: a ground-only occupant does not answer the deck query",
        )
    )


## Spec scenarios: a blocked ground cell still routes around while the deck over
## the same XZ stays free, and a blocked deck routes around while the ground
## stays free. Exercised through the real level-aware A* with the blocked keys
## `get_blocked_cells(level)` produces.
func test_level_scoped_blocking_routes_by_surface():
    if _sh == null or _ts == null:
        TestHelper.fail("SpatialHash/TerrainSystem not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._blocked_cells.clear()
    _sh._building_cells.clear()
    _sh._shared_cell_counts.clear()
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_bridge_fixture(0)
    var bridges: Array[Node3D] = []
    for cell in [A_CELL, MID_CELL, B_CELL]:
        bridges.append(_spawn_level_bridge(cell))
    _sh.rebuild()

    var wheel := load(WHEEL_LOCOMOTOR_PATH) as Locomotor
    var start := CellUtil.cell_to_world(A_CELL)
    var goal := CellUtil.cell_to_world(B_CELL)
    var mid_ground := Vector3i(MID_CELL.x, MID_CELL.y, 0)
    var mid_deck := Vector3i(MID_CELL.x, MID_CELL.y, 1)

    # Baseline: both surfaces have a direct corridor through the mid cell.
    var ground_open := _path_states(
        Pathfinder.find_path_detailed(start, goal, {}, wheel, false, null, _ts, 0, 0)
    )
    var deck_open := _path_states(
        Pathfinder.find_path_detailed(start, goal, {}, wheel, false, null, _ts, 1, 1)
    )
    TestHelper.assert_true(
        ground_open.has(mid_ground), "baseline ground path crosses the mid cell at level 0"
    )
    TestHelper.assert_true(
        deck_open.has(mid_deck), "baseline deck path crosses the mid cell at level 1"
    )

    # A ground blocker detours the ground path but leaves the deck free.
    var ground_block: Dictionary = {CellUtil.cell_level_key(MID_CELL, 0): true}
    var ground_around := _path_states(
        Pathfinder.find_path_detailed(start, goal, ground_block, wheel, false, null, _ts, 0, 0)
    )
    var deck_through := _path_states(
        Pathfinder.find_path_detailed(start, goal, ground_block, wheel, false, null, _ts, 1, 1)
    )
    TestHelper.assert_true(
        not ground_around.has(mid_ground), "ground blocker forces the level-0 path around the cell"
    )
    TestHelper.assert_true(
        deck_through.has(mid_deck), "ground blocker leaves the level-1 deck path through the cell"
    )

    # A deck blocker detours the deck path but leaves the ground free.
    var deck_block: Dictionary = {CellUtil.cell_level_key(MID_CELL, 1): true}
    var ground_through := _path_states(
        Pathfinder.find_path_detailed(start, goal, deck_block, wheel, false, null, _ts, 0, 0)
    )
    var deck_around := _path_states(
        Pathfinder.find_path_detailed(start, goal, deck_block, wheel, false, null, _ts, 1, 1)
    )
    TestHelper.assert_true(
        ground_through.has(mid_ground), "deck blocker leaves the level-0 path through the cell"
    )
    TestHelper.assert_true(
        not deck_around.has(mid_deck), "deck blocker removes the level-1 passage through the cell"
    )

    for bridge in bridges:
        bridge.get_parent().remove_child(bridge)
        bridge.free()
    _sh.rebuild()
    _ts.init_grid(50, 50)
    _ts.clear()


func _flatten_bridge_fixture(grade: int) -> void:
    for vx in range(A_CELL.x - 2, B_CELL.x + 3):
        for vz in range(A_CELL.y - 2, A_CELL.y + 3):
            _ts._set_vertex_no_cascade(vx, vz, grade)
    _ts.invalidate_height_snapshot()


func _spawn_level_bridge(cell: Vector2i) -> StubBridge:
    var bridge := StubBridge.new()
    bridge.data = {
        "surface_height": 4.0 * _ts.HEIGHT_STEP,
        "is_end": false,
        "piece_id": "p",
        "level": 1,
    }
    bridge.add_to_group("bridge")
    Engine.get_main_loop().root.add_child(bridge)
    bridge.global_position = CellUtil.cell_to_world(cell)
    return bridge


func _path_states(result: Dictionary) -> Array[Vector3i]:
    var states: Array[Vector3i] = []
    var path: PackedVector3Array = result["path"]
    var levels: PackedInt32Array = result["levels"]
    for i in path.size():
        var cell := CellUtil.world_to_cell(path[i])
        states.append(Vector3i(cell.x, cell.y, levels[i]))
    return states
