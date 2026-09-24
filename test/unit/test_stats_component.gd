extends Node

# StatsComponent rank derivation, trainable defaults and identity helpers.


func _make_stats(entity_type: int, cost: int) -> StatsComponent:
    var data := EntityData.new()
    data.id = "TEST"
    data.entity_type = entity_type
    data.cost = cost
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.configure(data)
    return stats


func _rules() -> GlobalRules:
    var rules := GlobalRules.get_current()
    if rules == null:
        TestHelper.fail("GlobalRules not available in test environment")
    return rules


func test_new_entity_is_rookie():
    var stats := _make_stats(EntityData.EntityType.INFANTRY, 100)
    TestHelper.assert_eq(stats.experience, 0.0, "new entity experience 0")
    TestHelper.assert_eq(stats.veteran_level, 0, "new entity rookie")
    stats.free()


func test_experience_crossing_veteran_threshold():
    var rules := _rules()
    if rules == null:
        return
    var stats := _make_stats(EntityData.EntityType.INFANTRY, 100)
    # Each credited cost of `cost * ratio` adds exactly 1.0 experience.
    stats.add_kill_experience(int(0.9 * 100.0 * rules.veteran_ratio))
    TestHelper.assert_eq(stats.veteran_level, 0, "0.9 experience stays rookie")
    stats.add_kill_experience(int(0.3 * 100.0 * rules.veteran_ratio))
    TestHelper.assert_eq(stats.veteran_level, 1, "1.2 experience is veteran")
    stats.free()


func test_experience_crossing_elite_threshold():
    var rules := _rules()
    if rules == null:
        return
    var stats := _make_stats(EntityData.EntityType.INFANTRY, 100)
    stats.add_kill_experience(int(1.9 * 100.0 * rules.veteran_ratio))
    TestHelper.assert_eq(stats.veteran_level, 1, "1.9 experience stays veteran")
    stats.add_kill_experience(int(0.2 * 100.0 * rules.veteran_ratio))
    TestHelper.assert_eq(stats.veteran_level, 2, "2.1 experience is elite")
    stats.free()


func test_experience_is_capped():
    var rules := _rules()
    if rules == null:
        return
    var stats := _make_stats(EntityData.EntityType.INFANTRY, 1)
    stats.add_kill_experience(1000000)
    TestHelper.assert_eq(
        stats.experience, float(rules.veteran_cap), "experience clamped to veteran_cap"
    )
    stats.free()


func test_veterancy_changed_emitted_once_on_promotion():
    var rules := _rules()
    if rules == null:
        return
    var stats := _make_stats(EntityData.EntityType.INFANTRY, 100)
    var seen: Array[int] = []
    stats.veterancy_changed.connect(func(level: int) -> void: seen.append(level))
    stats.add_kill_experience(int(1.0 * 100.0 * rules.veteran_ratio))
    stats.add_kill_experience(int(1.0 * 100.0 * rules.veteran_ratio))
    TestHelper.assert_eq(seen, [1, 2], "promotion emits veteran then elite")
    stats.add_kill_experience(int(1.0 * 100.0 * rules.veteran_ratio))
    TestHelper.assert_eq(seen, [1, 2], "no re-emit while rank unchanged")
    stats.free()


func test_trainable_defaults_by_type():
    var inf := _make_stats(EntityData.EntityType.INFANTRY, 100)
    var veh := _make_stats(EntityData.EntityType.VEHICLE, 100)
    var air := _make_stats(EntityData.EntityType.AIRCRAFT, 100)
    var bld := _make_stats(EntityData.EntityType.BUILDING, 100)
    TestHelper.assert_true(inf.trainable, "infantry trainable by default")
    TestHelper.assert_true(veh.trainable, "vehicle trainable by default")
    TestHelper.assert_true(air.trainable, "aircraft trainable by default")
    TestHelper.assert_true(not bld.trainable, "building not trainable by default")
    inf.free()
    veh.free()
    air.free()
    bld.free()


func test_non_unit_non_building_not_trainable():
    var terrain := _make_stats(EntityData.EntityType.TERRAIN, 100)
    var overlay := _make_stats(EntityData.EntityType.OVERLAY, 100)
    TestHelper.assert_true(not terrain.trainable, "terrain is not trainable")
    TestHelper.assert_true(not overlay.trainable, "overlay is not trainable")
    terrain.free()
    overlay.free()


func test_building_can_opt_into_trainable():
    var data := EntityData.new()
    data.id = "DEFENSE"
    data.entity_type = EntityData.EntityType.BUILDING
    data.trainable = true
    var stats := StatsComponent.new()
    stats.configure(data)
    TestHelper.assert_true(stats.trainable, "building with trainable=true is trainable")
    stats.free()


func test_entity_type_predicates():
    var inf := _make_stats(EntityData.EntityType.INFANTRY, 100)
    var bld := _make_stats(EntityData.EntityType.BUILDING, 100)
    var air := _make_stats(EntityData.EntityType.AIRCRAFT, 100)
    TestHelper.assert_true(inf.is_unit(), "infantry is a unit")
    TestHelper.assert_true(inf.is_infantry(), "infantry predicate")
    TestHelper.assert_true(not inf.is_aircraft(), "infantry is not aircraft")
    TestHelper.assert_true(air.is_aircraft(), "aircraft predicate")
    TestHelper.assert_true(air.is_unit(), "aircraft is a unit")
    TestHelper.assert_true(not bld.is_unit(), "building is not a unit")
    TestHelper.assert_true(bld.is_structure(), "building is a structure")
    inf.free()
    bld.free()
    air.free()


func test_initial_veteran_creates_elites():
    var rules := GlobalRules.get_current()
    if rules == null:
        TestHelper.fail("GlobalRules not available in test environment")
        return
    var saved_flag := rules.initial_veteran
    var saved_cap := rules.veteran_cap
    # Elite must not depend on veteran_cap (rank sources ignore the cap).
    rules.veteran_cap = 1
    rules.initial_veteran = true
    var unit := _make_stats(EntityData.EntityType.INFANTRY, 100)
    var building := _make_stats(EntityData.EntityType.BUILDING, 100)
    TestHelper.assert_eq(unit.veteran_level, 2, "initial_veteran creates units elite")
    TestHelper.assert_eq(building.veteran_level, 2, "initial_veteran ignores the trainable gate")
    rules.initial_veteran = saved_flag
    rules.veteran_cap = saved_cap
    unit.free()
    building.free()


func test_default_start_is_rookie():
    var stats := _make_stats(EntityData.EntityType.INFANTRY, 100)
    TestHelper.assert_eq(stats.veteran_level, 0, "default start is rookie")
    stats.free()
