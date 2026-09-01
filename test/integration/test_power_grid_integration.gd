extends Node

# Power grid integration — real EntityFactory entities through the shared
# spawn funnel (the same order MapLoader starting bases and MCV deploys use:
# StatsComponent.player_id assigned before add_child). Destroying a plant
# pushes the grid into deficit; placing a plant recovers. Synchronous like the
# other integration suites: queue_free's deferred removal is modeled by an
# immediate free(), which fires the same node_removed PowerGrid listens to.

const BASE_PID := 901


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _grid() -> Node:
    return _tree().root.get_node_or_null("PowerGrid")


func _spawn(entity_id: String, pid: int) -> Node3D:
    var entity := EntityFactory.create_entity(entity_id)
    if entity == null:
        return null
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    stats.player_id = pid
    _tree().root.add_child(entity)
    return entity


func test_starting_base_shuts_down_on_plant_destruction():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var plant := _spawn("GDI_POWER_PLANT", BASE_PID)
    var radar := _spawn("GDI_RADAR", BASE_PID)
    if plant == null or radar == null:
        TestHelper.fail("GDI_POWER_PLANT / GDI_RADAR data missing")
        return
    var radar_pc := radar.get_node("PowerComponent") as PowerComponent
    var radar_rc := radar.get_node("RadarComponent") as RadarComponent
    # The data pass: radar requires power and drains 50 (from the .tres).
    TestHelper.assert_true(radar_pc.powered, "radar data pass: powered=true in .tres")
    TestHelper.assert_eq(radar_pc.power, -50, "radar data pass: power=-50 in .tres")
    TestHelper.assert_true(not grid.is_low_power(BASE_PID), "base starts healthy")
    TestHelper.assert_true(radar_rc.has_radar(), "radar online while healthy")
    # Destroy the plant — node_removed drops output to 0 -> deficit.
    plant.free()
    TestHelper.assert_true(grid.is_low_power(BASE_PID), "plant destruction causes deficit")
    TestHelper.assert_true(not radar_pc.is_online, "powered radar shuts down")
    TestHelper.assert_true(not radar_rc.has_radar(), "radar reports offline")
    TestHelper.assert_true(
        absf(grid.get_build_rate(BASE_PID) - 0.3) < 1e-6,
        "near-blackout build rate at worst coefficient"
    )
    # Place a fresh plant — recovery.
    var plant2 := _spawn("GDI_POWER_PLANT", BASE_PID)
    TestHelper.assert_true(not grid.is_low_power(BASE_PID), "recovered to healthy")
    TestHelper.assert_true(radar_pc.is_online, "radar powers back up")
    TestHelper.assert_true(radar_rc.has_radar(), "radar reports online again")
    TestHelper.assert_eq(grid.get_build_rate(BASE_PID), 1.0, "build rate restored")
    plant2.free()
    radar.free()
