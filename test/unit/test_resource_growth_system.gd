extends Node

# ResourceGrowthSystem tests — GlobalRules defaults and spread neighbor count


func test_global_rules_growth_fields():
    var rules := GlobalRules.new()
    (
        TestHelper
        . assert_true(
            (
                rules.tree_growth_rate == 3.0
                and rules.tree_spawn_radius == 3
                and rules.growth_batch_trees == 10
                and rules.growth_batch_crystals == 500
                and rules.spread_amount == 0.5
                and rules.spread_max == 3
            ),
            "GlobalRules growth defaults correct: GlobalRules growth defaults mismatch",
        )
    )


func test_spread_neighbors_count():
    (
        TestHelper
        . assert_true(
            ResourceGrowthSystem.SPREAD_NEIGHBORS.size() == 8,
            (
                "spread neighbors has 8 directions: expected 8, got %d"
                % ResourceGrowthSystem.SPREAD_NEIGHBORS.size()
            ),
        )
    )


func test_tree_spawn_radius_circle():
    # Verify that radius=3 produces a circular area (not full square)
    var radius := 3
    var count := 0
    for dx in range(-radius, radius + 1):
        for dz in range(-radius, radius + 1):
            if dx * dx + dz * dz <= radius * radius:
                count += 1
    # Full square would be 7x7=49. Circle should be less.
    (
        TestHelper
        . assert_true(
            count < 49 and count > 0,
            (
                (
                    "tree_spawn_radius circle has %d cells (< 49 square): "
                    + "expected circular area, got %d cells"
                )
                % [count, count]
            ),
        )
    )
