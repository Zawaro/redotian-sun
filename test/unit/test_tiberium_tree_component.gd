extends Node

# TiberiumTreeComponent tests — configure, _random_cell_in_radius

var _test_passed := 0
var _test_failed := 0


func _make_tree_comp() -> TiberiumTreeComponent:
    return TiberiumTreeComponent.new()


func test_configure_sets_fields():
    var tree := _make_tree_comp()
    var data := EntityData.new()
    data.spawned_entity_id = "TIB"
    data.radius_cells = 10
    data.tiberium_type = 1
    data.node_count = 8
    data.amount_per_node = 200
    data.max_amount_per_node = 400
    data.tiberium_regrowth_rate = 1.5
    tree.configure(data)
    if (
        tree.spawned_entity_id == "TIB"
        and tree.radius_cells == 10
        and tree.tiberium_type == 1
        and tree.node_count == 8
        and tree.amount_per_node == 200
        and tree.max_amount_per_node == 400
        and tree.regrowth_rate == 1.5
    ):
        _test_passed += 1
        print("    PASS: configure sets all fields")
    else:
        _test_failed += 1
        print("    FAIL: configure fields mismatch")


func test_configure_default_values():
    var tree := _make_tree_comp()
    if (
        tree.spawned_entity_id == ""
        and tree.radius_cells == 8
        and tree.node_count == 12
        and tree.amount_per_node == 300
        and tree.max_amount_per_node == 300
    ):
        _test_passed += 1
        print("    PASS: default values correct")
    else:
        _test_failed += 1
        print("    FAIL: default values mismatch")


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
            _test_failed += 1
            print("    FAIL: cell %s is outside radius %d (dist=%.1f)" % [cell, radius, dist])
            return
    _test_passed += 1
    print("    PASS: random_cell_in_radius stays within bounds (100 samples)")


func test_random_cell_in_radius_zero_radius():
    var tree := _make_tree_comp()
    var center := Vector2i(10, 10)
    var cell := tree._random_cell_in_radius(center, 0)
    if cell == center:
        _test_passed += 1
        print("    PASS: zero radius returns center cell")
    else:
        _test_failed += 1
        print("    FAIL: expected %s, got %s" % [center, cell])
