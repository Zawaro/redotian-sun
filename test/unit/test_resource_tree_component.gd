extends Node

# ResourceTreeComponent tests — configure, _random_cell_in_radius


func _make_tree_comp() -> ResourceTreeComponent:
    return ResourceTreeComponent.new()


func test_configure_sets_fields():
    var tree := _make_tree_comp()
    var data := EntityData.new()
    data.spawned_entity_id = "TIBERIUM_RIPARIUS"
    data.radius_cells = 10
    data.resource_type_id = "tiberium_blue"
    data.node_count = 8
    data.spawn_strength = 0.7
    data.max_spawn_strength = 1.0
    data.resource_regrowth_rate = 1.5
    tree.configure(data)
    (
        TestHelper
        . assert_true(
            (
                tree.spawned_entity_id == "TIBERIUM_RIPARIUS"
                and tree.radius_cells == 10
                and tree.resource_type_id == "tiberium_blue"
                and tree.node_count == 8
                and tree.spawn_strength == 0.7
                and tree.max_spawn_strength == 1.0
                and tree.regrowth_rate == 1.5
            ),
            "configure sets all fields: configure fields mismatch",
        )
    )


func test_configure_default_values():
    var tree := _make_tree_comp()
    (
        TestHelper
        . assert_true(
            (
                tree.spawned_entity_id == ""
                and tree.radius_cells == 8
                and tree.node_count == 12
                and tree.spawn_strength == 0.5
                and tree.max_spawn_strength == 1.0
            ),
            "default values correct: default values mismatch",
        )
    )


func test_random_cell_in_radius_within_bounds():
    var tree := _make_tree_comp()
    var center := Vector2i(50, 50)
    var radius := 8
    for i in 100:
        var cell := tree._random_cell_in_radius(center, radius)
        var dx: float = float(cell.x - center.x)
        var dz: float = float(cell.y - center.y)
        var dist := sqrt(dx * dx + dz * dz)
        if dist > float(radius) + 1.0:
            TestHelper.fail("cell %s is outside radius %d (dist=%.1f)" % [cell, radius, dist])
            return
    TestHelper.assert_true(true, "random_cell_in_radius stays within bounds (100 samples)")


func test_random_cell_in_radius_zero_radius():
    var tree := _make_tree_comp()
    var center := Vector2i(10, 10)
    var cell := tree._random_cell_in_radius(center, 0)
    (
        TestHelper
        . assert_true(
            cell == center,
            "zero radius returns center cell: expected %s, got %s" % [center, cell],
        )
    )
