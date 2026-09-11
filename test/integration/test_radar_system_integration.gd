extends Node

# Radar integration — real EntityFactory entities (the same shared spawn funnel
# MapLoader starting bases and MCV deploys use). A base with a radar and a
# plant reads radar-available; destroying the plant drops it into deficit and
# clears availability; a new plant restores it; destroying the radar clears it.
# Synchronous like the other integration suites: free() fires the same
# node_removed RadarSystem/PowerGrid listen to.

const BASE_PID := 911


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _system() -> Node:
    return _tree().root.get_node_or_null("RadarSystem")


func _spawn(entity_id: String, pid: int) -> Node3D:
    var entity := EntityFactory.create_entity(entity_id)
    if entity == null:
        return null
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    stats.player_id = pid
    _tree().root.add_child(entity)
    return entity


func test_player_radar_availability_tracks_power_and_lifecycle():
    var system := _system()
    if system == null:
        TestHelper.fail("RadarSystem autoload missing")
        return
    system.force_online = false
    var plant := _spawn("GDI_POWER_PLANT", BASE_PID)
    var radar := _spawn("GDI_RADAR", BASE_PID)
    if plant == null or radar == null:
        TestHelper.fail("GDI_POWER_PLANT / GDI_RADAR data missing")
        return
    TestHelper.assert_true(
        system.player_has_radar(BASE_PID), "radar available while the base is healthy"
    )
    var emissions: Array[int] = []
    var on_changed := func(pid: int) -> void: emissions.append(pid)
    system.radar_availability_changed.connect(on_changed)
    # Destroy the plant -> deficit -> powered radar shuts down.
    plant.free()
    TestHelper.assert_true(
        not system.player_has_radar(BASE_PID), "powered-down radar clears availability"
    )
    TestHelper.assert_true(emissions.has(BASE_PID), "availability loss emitted")
    emissions.clear()
    # Fresh plant -> recovery.
    var plant2 := _spawn("GDI_POWER_PLANT", BASE_PID)
    TestHelper.assert_true(system.player_has_radar(BASE_PID), "recovery restores availability")
    TestHelper.assert_true(emissions.has(BASE_PID), "availability gain emitted")
    # Destroy the radar itself -> no radar structure left.
    radar.free()
    TestHelper.assert_true(
        not system.player_has_radar(BASE_PID), "destroying the radar clears availability"
    )
    plant2.free()
    system.radar_availability_changed.disconnect(on_changed)
    system.force_online = false
