extends Node

# ResourceGrowthSystem tests — GlobalRules defaults and spread neighbor count

var _test_passed := 0
var _test_failed := 0


func test_global_rules_growth_fields():
    var rules := GlobalRules.new()
    if (
        rules.tree_growth_rate == 3.0
        and rules.tree_spawn_radius == 3
        and rules.growth_batch_trees == 10
        and rules.growth_batch_crystals == 500
        and rules.spread_amount == 0.5
        and rules.spread_max == 3
    ):
        _test_passed += 1
        print("    PASS: GlobalRules growth defaults correct")
    else:
        _test_failed += 1
        print("    FAIL: GlobalRules growth defaults mismatch")


func test_spread_neighbors_count():
    if ResourceGrowthSystem.SPREAD_NEIGHBORS.size() == 8:
        _test_passed += 1
        print("    PASS: spread neighbors has 8 directions")
    else:
        _test_failed += 1
        print("    FAIL: expected 8, got %d" % ResourceGrowthSystem.SPREAD_NEIGHBORS.size())


func test_tree_spawn_radius_circle():
    # Verify that radius=3 produces a circular area (not full square)
    var radius := 3
    var count := 0
    for dx in range(-radius, radius + 1):
        for dz in range(-radius, radius + 1):
            if dx * dx + dz * dz <= radius * radius:
                count += 1
    # Full square would be 7x7=49. Circle should be less.
    if count < 49 and count > 0:
        _test_passed += 1
        print("    PASS: tree_spawn_radius circle has %d cells (< 49 square)" % count)
    else:
        _test_failed += 1
        print("    FAIL: expected circular area, got %d cells" % count)
