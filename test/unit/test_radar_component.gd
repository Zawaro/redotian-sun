extends Node

# RadarComponent tests — effective radar state, power-driven flip signal, and
# silent seeding for components that arrive already powered down.


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _add_to_root(entity: Node) -> void:
    var tree := _tree()
    if tree == null or tree.root == null:
        TestHelper.fail("SceneTree unavailable for tree registration test")
        return
    tree.root.add_child(entity)


## Mirrors the spawn path: StatsComponent/player assignment and data configure
## happen before add_child. Power is set offline before the tree entry so the
## radar's _ready seeds from the real state.
func _make(has_power: bool = true, online: bool = true, cap: bool = true) -> Node3D:
    var entity := Node3D.new()
    if has_power:
        var pc := PowerComponent.new()
        pc.name = "PowerComponent"
        pc.power = -50
        pc.powered = true
        entity.add_child(pc)
        if not online:
            pc.set_online(false)
    var radar := RadarComponent.new()
    radar.name = "RadarComponent"
    radar.radar = cap
    entity.add_child(radar)
    _add_to_root(entity)
    return entity


func _free(entity: Node) -> void:
    if is_instance_valid(entity):
        entity.free()


func test_power_flip_emits_radar_state_once_each():
    var entity := _make(true, true)
    var rc := entity.get_node("RadarComponent") as RadarComponent
    var pc := entity.get_node("PowerComponent") as PowerComponent
    var emissions: Array[bool] = []
    rc.radar_state_changed.connect(func(active: bool) -> void: emissions.append(active))
    TestHelper.assert_true(rc.has_radar(), "online radar available")
    pc.set_online(false)
    TestHelper.assert_true(not rc.has_radar(), "powered-down radar unavailable")
    TestHelper.assert_eq(emissions, [false] as Array[bool], "one offline emission")
    pc.set_online(false)
    TestHelper.assert_eq(emissions.size(), 1, "no re-emit for unchanged power")
    pc.set_online(true)
    TestHelper.assert_eq(emissions, [false, true] as Array[bool], "recovery emits true")
    _free(entity)


func test_initial_powered_down_seeds_without_signal():
    # A radar registered into an active deficit: power is already offline when
    # the component enters the tree, so it starts inactive silently.
    var entity := _make(true, false)
    var rc := entity.get_node("RadarComponent") as RadarComponent
    var pc := entity.get_node("PowerComponent") as PowerComponent
    var emissions: Array[bool] = []
    rc.radar_state_changed.connect(func(active: bool) -> void: emissions.append(active))
    TestHelper.assert_true(not rc.has_radar(), "seeded inactive")
    TestHelper.assert_true(emissions.is_empty(), "no spurious flip on seed")
    pc.set_online(true)
    TestHelper.assert_eq(emissions, [true] as Array[bool], "recovery emits one flip")
    _free(entity)


func test_no_power_component_stays_available_and_silent():
    var entity := _make(false, true)
    var rc := entity.get_node("RadarComponent") as RadarComponent
    var emissions: Array[bool] = []
    rc.radar_state_changed.connect(func(active: bool) -> void: emissions.append(active))
    TestHelper.assert_true(rc.has_radar(), "entity without PowerComponent is always powered")
    TestHelper.assert_true(emissions.is_empty(), "nothing to flip without a power signal")
    _free(entity)


func test_no_capability_reports_false_regardless_of_power():
    var entity := _make(true, true, false)
    var rc := entity.get_node("RadarComponent") as RadarComponent
    var pc := entity.get_node("PowerComponent") as PowerComponent
    var emissions: Array[bool] = []
    rc.radar_state_changed.connect(func(active: bool) -> void: emissions.append(active))
    TestHelper.assert_true(not rc.has_radar(), "radar=false never reports capability")
    pc.set_online(false)
    TestHelper.assert_true(not rc.has_radar(), "still false when powered down")
    TestHelper.assert_true(emissions.is_empty(), "no flip without capability")
    _free(entity)
