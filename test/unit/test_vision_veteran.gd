extends Node

# VisionComponent veteran sight — effective radius reflects the rank.


func _make(sight: int) -> Array:
    var data := EntityData.new()
    data.id = "TEST_SCOUT"
    data.entity_type = EntityData.EntityType.VEHICLE
    data.sight = sight
    data.cost = 100
    var entity := Node3D.new()
    entity.name = "VisionVetEntity"
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.configure(data)
    var vision := VisionComponent.new()
    vision.name = "VisionComponent"
    vision.configure(data)
    entity.add_child(stats)
    entity.add_child(vision)
    Engine.get_main_loop().root.add_child(entity)
    return [entity, stats, vision]


func _drop(entity: Node3D) -> void:
    if is_instance_valid(entity):
        entity.get_parent().remove_child(entity)
        entity.free()


func test_rookie_radius_matches_base_sight():
    var t := _make(6)
    var vision: VisionComponent = t[2]
    TestHelper.assert_eq(vision._effective_sight(), 6, "rookie radius equals base sight")
    _drop(t[0])


func test_veteran_sight_widens_radius():
    var rules := GlobalRules.get_current()
    var saved := rules.veteran_sight
    rules.veteran_sight = 0.25
    var t := _make(6)
    var stats: StatsComponent = t[1]
    var vision: VisionComponent = t[2]
    stats.add_kill_experience(int(1.0 * stats.cost * rules.veteran_ratio))
    TestHelper.assert_eq(stats.veteran_level, 1, "unit promoted to veteran")
    TestHelper.assert_eq(vision._effective_sight(), 8, "veteran radius 6 * 1.25 rounds to 8")
    rules.veteran_sight = saved
    _drop(t[0])


func test_neutral_sight_leaves_radius_unchanged():
    var rules := GlobalRules.get_current()
    var t := _make(6)
    var stats: StatsComponent = t[1]
    var vision: VisionComponent = t[2]
    stats.add_kill_experience(int(2.0 * stats.cost * rules.veteran_ratio))
    TestHelper.assert_eq(stats.veteran_level, 2, "unit promoted to elite")
    TestHelper.assert_eq(
        vision._effective_sight(), 6, "neutral veteran_sight leaves the radius unchanged"
    )
    _drop(t[0])
