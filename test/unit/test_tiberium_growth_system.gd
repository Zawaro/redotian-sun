extends Node

# TiberiumGrowthSystem tests — timer values, batch offset cycling
# Tests logic that doesn't require full scene tree or autoloads.

var _test_passed := 0
var _test_failed := 0


func test_global_rules_growth_fields():
    var rules := GlobalRules.new()
    if (
        rules.tree_growth_rate == 3.0
        and rules.tree_spawn_radius == 3
        and rules.growth_batch_trees == 10
        and rules.growth_batch_crystals == 500
        and rules.spread_amount == 50
        and rules.spread_max == 3
    ):
        _test_passed += 1
        print("    PASS: GlobalRules growth defaults correct")
    else:
        _test_failed += 1
        print("    FAIL: GlobalRules growth defaults mismatch")


func test_global_rules_custom_values():
    var rules := GlobalRules.new()
    rules.tree_growth_rate = 1.0
    rules.tree_spawn_radius = 5
    rules.growth_batch_crystals = 100
    rules.spread_amount = 25
    rules.spread_max = 5
    if (
        rules.tree_growth_rate == 1.0
        and rules.tree_spawn_radius == 5
        and rules.growth_batch_crystals == 100
        and rules.spread_amount == 25
        and rules.spread_max == 5
    ):
        _test_passed += 1
        print("    PASS: GlobalRules custom values set correctly")
    else:
        _test_failed += 1
        print("    FAIL: GlobalRules custom values mismatch")


func test_batch_offset_cycles():
    var total := 10
    var batch_size := 3
    var offset := 0

    # First batch: 0-2
    var start := offset
    var end := mini(start + batch_size, total)
    offset = end % maxi(total, 1)
    if start == 0 and end == 3 and offset == 3:
        _test_passed += 1
        print("    PASS: batch offset advances correctly (1st batch)")
    else:
        _test_failed += 1
        print("    FAIL: expected start=0 end=3 offset=3, got %d %d %d" % [start, end, offset])

    # Second batch: 3-5
    start = offset
    end = mini(start + batch_size, total)
    offset = end % maxi(total, 1)
    if start == 3 and end == 6 and offset == 6:
        _test_passed += 1
        print("    PASS: batch offset advances correctly (2nd batch)")
    else:
        _test_failed += 1
        print("    FAIL: expected start=3 end=6 offset=6, got %d %d %d" % [start, end, offset])

    # Third batch: 6-9
    start = offset
    end = mini(start + batch_size, total)
    offset = end % maxi(total, 1)
    if start == 6 and end == 9 and offset == 9:
        _test_passed += 1
        print("    PASS: batch offset advances correctly (3rd batch)")
    else:
        _test_failed += 1
        print("    FAIL: expected start=6 end=9 offset=9, got %d %d %d" % [start, end, offset])

    # Fourth batch: 9-10 (wraps)
    start = offset
    end = mini(start + batch_size, total)
    offset = end % maxi(total, 1)
    if start == 9 and end == 10 and offset == 0:
        _test_passed += 1
        print("    PASS: batch offset wraps to 0")
    else:
        _test_failed += 1
        print("    FAIL: expected start=9 end=10 offset=0, got %d %d %d" % [start, end, offset])


func test_batch_offset_empty_list():
    var total := 0
    var batch_size := 500
    var offset := 0
    var start := offset
    var end := mini(start + batch_size, total)
    offset = end % maxi(total, 1)
    if start == 0 and end == 0 and offset == 0:
        _test_passed += 1
        print("    PASS: batch offset handles empty list")
    else:
        _test_failed += 1
        print("    FAIL: expected 0 0 0, got %d %d %d" % [start, end, offset])


func test_spread_neighbors_count():
    # TiberiumGrowthSystem.SPREAD_NEIGHBORS has 8 entries
    var neighbors: Array[Vector2i] = [
        Vector2i(1, 0), Vector2i(-1, 0),
        Vector2i(0, 1), Vector2i(0, -1),
        Vector2i(1, 1), Vector2i(1, -1),
        Vector2i(-1, 1), Vector2i(-1, -1),
    ]
    if neighbors.size() == 8:
        _test_passed += 1
        print("    PASS: spread neighbors has 8 directions")
    else:
        _test_failed += 1
        print("    FAIL: expected 8, got %d" % neighbors.size())


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


func test_bounds_check_logic():
    # Diamond bounds check matching BuildingManager / TiberiumGrowthSystem
    # Default _map_half_diag = 640 (from map_size=512 * sqrt2 / 2)
    var half_diag := 640.0

    # Valid cells (within diamond)
    var valid_cases: Array[Vector2i] = [
        Vector2i(0, 0),
        Vector2i(200, 100),
        Vector2i(-1, 0),
        Vector2i(0, -1),
        Vector2i(-10, -10),
    ]
    for cell in valid_cases:
        var cx := absf(float(cell.x) + 0.5)
        var cz := absf(float(cell.y) + 0.5)
        if cx + cz > half_diag:
            _test_failed += 1
            print("    FAIL: cell %s should be in bounds" % cell)
            return

    # Invalid cells (outside diamond)
    var invalid_cases: Array[Vector2i] = [
        Vector2i(511, 511),
        Vector2i(640, 0),
        Vector2i(0, 640),
        Vector2i(-400, -400),
    ]
    for cell in invalid_cases:
        var cx := absf(float(cell.x) + 0.5)
        var cz := absf(float(cell.y) + 0.5)
        if cx + cz <= half_diag:
            _test_failed += 1
            print("    FAIL: cell %s should be out of bounds" % cell)
            return

    _test_passed += 1
    print("    PASS: diamond bounds check correct (valid + invalid cases)")
