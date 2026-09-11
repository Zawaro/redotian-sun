extends Node

# RadarSystem tests — per-player availability aggregation, event-driven power
# flips, edge-triggered signal emission, and the debug override.
#
# Availability tests use non-power-requiring radars (`powered = false`) so the
# global PowerGrid never forces them offline on the empty test grid; the power
# test sets up a healthy grid and flips the component directly.


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _system() -> Node:
    var tree := _tree()
    if tree == null or tree.root == null:
        return null
    return tree.root.get_node_or_null("RadarSystem")


func _add_to_root(entity: Node) -> void:
    var tree := _tree()
    if tree == null or tree.root == null:
        TestHelper.fail("SceneTree unavailable for tree registration test")
        return
    tree.root.add_child(entity)


func _make_producer(pid: int, power: int = 100) -> Node3D:
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = pid
    entity.add_child(stats)
    var pc := PowerComponent.new()
    pc.name = "PowerComponent"
    pc.power = power
    pc.powered = false
    entity.add_child(pc)
    _add_to_root(entity)
    return entity


## Mirrors the spawn-path contract: StatsComponent.player_id is assigned before
## add_child. `powered` marks whether PowerGrid may force this radar offline.
func _make_radar(pid: int, powered: bool = false, cap: bool = true) -> Node3D:
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = pid
    entity.add_child(stats)
    var pc := PowerComponent.new()
    pc.name = "PowerComponent"
    pc.power = -50
    pc.powered = powered
    entity.add_child(pc)
    var radar := RadarComponent.new()
    radar.name = "RadarComponent"
    radar.radar = cap
    entity.add_child(radar)
    _add_to_root(entity)
    return entity


func _free(entity: Node) -> void:
    if is_instance_valid(entity):
        entity.free()


func test_placement_makes_player_available_and_removal_clears():
    var system := _system()
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    var radar := _make_radar(0)
    TestHelper.assert_true(system.player_has_radar(0), "radar placement makes player available")
    TestHelper.assert_eq(system.get_online_count(0), 1, "one online radar counted")
    _free(radar)
    TestHelper.assert_true(not system.player_has_radar(0), "last radar removal clears availability")
    TestHelper.assert_eq(system.get_online_count(0), 0, "count returns to zero")
    system.force_online = false


func test_second_radar_does_not_reemit_availability():
    var system := _system()
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    var emissions: Array[int] = []
    var on_changed := func(pid: int) -> void: emissions.append(pid)
    system.radar_availability_changed.connect(on_changed)
    var first := _make_radar(5)
    TestHelper.assert_eq(emissions, [5] as Array[int], "first radar emits once")
    var second := _make_radar(5)
    TestHelper.assert_eq(emissions.size(), 1, "second radar for an available player is silent")
    TestHelper.assert_eq(system.get_online_count(5), 2, "both radars counted")
    _free(first)
    TestHelper.assert_eq(emissions.size(), 1, "losing one of two radars stays available — silent")
    _free(second)
    TestHelper.assert_eq(emissions, [5, 5] as Array[int], "losing the last radar emits")
    system.radar_availability_changed.disconnect(on_changed)
    system.force_online = false


func test_per_player_isolation():
    var system := _system()
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    var p0 := _make_radar(0)
    var p1 := _make_radar(1, false, false)
    TestHelper.assert_true(system.player_has_radar(0), "p0 has radar")
    TestHelper.assert_true(not system.player_has_radar(1), "p1 has none")
    _free(p0)
    _free(p1)
    system.force_online = false


func test_entities_without_radar_component_ignored():
    var system := _system()
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    var plain := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = 0
    plain.add_child(stats)
    _add_to_root(plain)
    TestHelper.assert_true(not system.player_has_radar(0), "non-radar entity contributes nothing")
    _free(plain)
    system.force_online = false


func test_power_flip_updates_availability_and_emits():
    var system := _system()
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    var pid := 9
    # Healthy grid so the power-requiring radar registers online, then flip the
    # component directly (what PowerGrid's deficit fan-out does).
    var plant := _make_producer(pid)
    var radar := _make_radar(pid, true)
    var pc := radar.get_node("PowerComponent") as PowerComponent
    var emissions: Array[int] = []
    var on_changed := func(current: int) -> void: emissions.append(current)
    system.radar_availability_changed.connect(on_changed)
    TestHelper.assert_true(system.player_has_radar(pid), "available while powered")
    emissions.clear()
    pc.set_online(false)
    TestHelper.assert_true(not system.player_has_radar(pid), "powered down clears availability")
    TestHelper.assert_eq(emissions, [pid] as Array[int], "loss emits once")
    pc.set_online(true)
    TestHelper.assert_true(system.player_has_radar(pid), "recovery restores availability")
    TestHelper.assert_eq(emissions, [pid, pid] as Array[int], "recovery emits once")
    _free(radar)
    _free(plant)
    system.radar_availability_changed.disconnect(on_changed)
    system.force_online = false


func test_override_forces_availability_then_restores():
    var system := _system()
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    TestHelper.assert_true(not system.player_has_radar(1234), "no radar and no override")
    system.force_online = true
    TestHelper.assert_true(system.player_has_radar(1234), "override forces availability")
    system.force_online = false
    TestHelper.assert_true(
        not system.player_has_radar(1234), "override off restores computed value"
    )
