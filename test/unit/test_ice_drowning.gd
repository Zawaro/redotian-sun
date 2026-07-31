extends Node

# Ice entity: weight damage, one-time per entry, break -> drown occupants, passability revert

var _sh: Node = null
var _test_passed := 0
var _test_failed := 0


func _make_ice(cell: Vector2i, strength: int = 50) -> Node3D:
    var ice := Node3D.new()
    ice.global_position = CellUtil.cell_to_world(cell)
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = strength
    hc.current_health = strength
    ice.add_child(hc)
    return ice


func _make_mc(weight: float) -> MovementController:
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.weight = weight
    entity.add_child(stats)
    var mc := MovementController.new()
    entity.add_child(mc)
    mc._parent = entity
    mc._weight = weight
    mc._ice_cracking_weight = 2.0
    return mc


func test_heavy_unit_damages_ice():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    var cell := Vector2i(30, 30)
    var ice := _make_ice(cell)
    _sh._ice_cells[CellUtil.cell_key(cell)] = [ice]
    var mc := _make_mc(3.0)
    mc._damage_ice(cell)
    var hc := ice.get_node_or_null("HealthComponent") as HealthComponent
    var remaining: int = hc.current_health
    _sh._ice_cells.erase(CellUtil.cell_key(cell))
    ice.free()
    mc.get_parent().queue_free()
    TestHelper.assert_eq(remaining, 47, "weight 3.0 deals 3 damage to ice")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_light_unit_damages_nothing():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    var cell := Vector2i(30, 31)
    var ice := _make_ice(cell)
    _sh._ice_cells[CellUtil.cell_key(cell)] = [ice]
    var mc := _make_mc(0.5)
    mc._damage_ice(cell)
    var hc := ice.get_node_or_null("HealthComponent") as HealthComponent
    var remaining: int = hc.current_health
    _sh._ice_cells.erase(CellUtil.cell_key(cell))
    ice.free()
    mc.get_parent().queue_free()
    TestHelper.assert_eq(remaining, 50, "below cracking threshold deals no damage")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_break_reverts_passability():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    var cell := Vector2i(30, 32)
    var ice := _make_ice(cell, 10)
    _sh._ice_cells[CellUtil.cell_key(cell)] = [ice]
    TestHelper.assert_true(_sh.has_intact_ice_on_cell(cell), "intact ice provides footing on water")
    var hc := ice.get_node_or_null("HealthComponent") as HealthComponent
    hc.take_damage(10)
    var intact: bool = _sh.has_intact_ice_on_cell(cell)
    _sh._ice_cells.erase(CellUtil.cell_key(cell))
    ice.free()
    TestHelper.assert_eq(intact, false, "broken ice no longer provides footing")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_break_drowns_occupant():
    if _sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not injected")
        return
    var cell := Vector2i(30, 33)
    var ice := _make_ice(cell)
    var ice_comp := IceComponent.new()
    ice.add_child(ice_comp)

    var occupant := Node3D.new()
    occupant.global_position = CellUtil.cell_to_world(cell)
    var occupant_hc := HealthComponent.new()
    occupant_hc.name = "HealthComponent"
    occupant_hc.max_health = 100
    occupant_hc.current_health = 100
    occupant.add_child(occupant_hc)
    var occupant_mc := MovementController.new()
    occupant_mc.name = "MovementController"
    occupant.add_child(occupant_mc)

    var neighbor := Node3D.new()
    neighbor.global_position = CellUtil.cell_to_world(cell + Vector2i(1, 0))
    var neighbor_hc := HealthComponent.new()
    neighbor_hc.name = "HealthComponent"
    neighbor_hc.max_health = 100
    neighbor_hc.current_health = 100
    neighbor.add_child(neighbor_hc)

    _sh._grid[CellUtil.cell_key(cell)] = [
        {
            "node": occupant,
            "mc": occupant_mc,
            "entity_type": EntityData.EntityType.VEHICLE,
            "player_id": 0,
        },
    ]
    _sh._grid[CellUtil.cell_key(cell + Vector2i(1, 0))] = [
        {"node": neighbor, "mc": null, "entity_type": -1, "player_id": -1},
    ]

    var root: Node = Engine.get_main_loop().root
    root.add_child(ice)
    root.add_child(occupant)
    root.add_child(neighbor)
    (ice.get_node_or_null("HealthComponent") as HealthComponent).kill()

    var drowned: int = occupant_hc.current_health
    var neighbor_ok: int = neighbor_hc.current_health

    root.remove_child(ice)
    root.remove_child(occupant)
    root.remove_child(neighbor)
    ice.free()
    occupant.free()
    neighbor.free()
    _sh._grid.erase(CellUtil.cell_key(cell))
    _sh._grid.erase(CellUtil.cell_key(cell + Vector2i(1, 0)))
    TestHelper.assert_eq(drowned, 0, "occupant drowns when ice breaks")
    TestHelper.assert_eq(neighbor_ok, 100, "adjacent unit survives")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
