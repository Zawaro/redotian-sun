extends Node

# Power grid tests — PowerComponent runtime state, PowerGrid aggregation,
# low-power boundary fan-out, build-rate interpolation.


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _grid() -> Node:
    var tree := _tree()
    if tree == null or tree.root == null:
        return null
    return tree.root.get_node_or_null("PowerGrid")


func _add_to_root(entity: Node) -> void:
    var tree := _tree()
    if tree == null or tree.root == null:
        TestHelper.fail("SceneTree unavailable for tree registration test")
        return
    tree.root.add_child(entity)


## Mirrors the spawn-path contract shared by BuildingManager, MapLoader and
## DeployComponent: StatsComponent.player_id is assigned before add_child.
func _make_building(power: int, pid: int, powered: bool = false) -> Node3D:
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.player_id = pid
    entity.add_child(stats)
    var pc := PowerComponent.new()
    pc.name = "PowerComponent"
    pc.power = power
    pc.powered = powered
    entity.add_child(pc)
    return entity


func _free(entity: Node) -> void:
    if is_instance_valid(entity):
        entity.free()


func _pc(entity: Node) -> PowerComponent:
    return entity.get_node("PowerComponent") as PowerComponent


# --- PowerComponent runtime state (task 1.2) ---


func test_set_online_emits_once_on_change():
    var pc := PowerComponent.new()
    var emissions: Array[bool] = []
    pc.power_state_changed.connect(func(online: bool) -> void: emissions.append(online))
    TestHelper.assert_true(pc.is_online, "starts online")
    pc.set_online(false)
    TestHelper.assert_true(not pc.is_online, "set_online(false) flips state")
    TestHelper.assert_eq(emissions, [false] as Array[bool], "one emission on change")
    pc.set_online(false)
    TestHelper.assert_eq(emissions.size(), 1, "no re-emit for unchanged state")
    pc.set_online(true)
    TestHelper.assert_eq(emissions, [false, true] as Array[bool], "recovery emits true")
    pc.free()


func test_runtime_state_independent_of_powered_data_flag():
    var data := EntityData.new()
    data.power = -50
    data.powered = true
    var pc := PowerComponent.new()
    pc.configure(data)
    TestHelper.assert_true(pc.is_powered(), "data flag: requires power")
    TestHelper.assert_true(pc.is_online, "runtime state starts online regardless of data flag")
    TestHelper.assert_eq(pc.get_power_output(), -50, "signed power preserved")
    pc.free()


# --- Aggregation (tasks 2.1 / 2.2) ---


func test_producer_and_consumer_sums():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var plant := _make_building(100, 0)
    var radar := _make_building(-50, 0)
    _add_to_root(plant)
    _add_to_root(radar)
    TestHelper.assert_eq(grid.get_output(0), 100, "output sums producers")
    TestHelper.assert_eq(grid.get_drain(0), 50, "drain sums |consumers|")
    _free(plant)
    _free(radar)
    TestHelper.assert_eq(grid.get_output(0), 0, "unregister removes producer contribution")
    TestHelper.assert_eq(grid.get_drain(0), 0, "unregister removes consumer contribution")


func test_per_player_isolation():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var p0_plant := _make_building(100, 0)
    var p0_radar := _make_building(-50, 0)
    var p1_drain := _make_building(-150, 1)
    _add_to_root(p0_plant)
    _add_to_root(p0_radar)
    _add_to_root(p1_drain)
    TestHelper.assert_true(not grid.is_low_power(0), "p0 healthy (100 vs 50)")
    TestHelper.assert_true(grid.is_low_power(1), "p1 in deficit (0 vs 150)")
    TestHelper.assert_eq(grid.get_output(1), 0, "p1 output isolated from p0")
    _free(p0_plant)
    _free(p0_radar)
    _free(p1_drain)


func test_factory_created_building_registers_with_owner():
    # MapLoader / deploy path: real EntityFactory entity, player assigned
    # before add_child — the shared spawn-path contract.
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var entity := EntityFactory.create_entity("GDI_POWER_PLANT")
    if entity == null:
        TestHelper.fail("GDI_POWER_PLANT data missing")
        return
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    stats.player_id = 7
    _add_to_root(entity)
    TestHelper.assert_eq(grid.get_output(7), 100, "factory entity registered under pid 7")
    entity.free()
    TestHelper.assert_eq(grid.get_output(7), 0, "freed entity unregisters")


func test_entities_without_power_component_ignored():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var plain := Node3D.new()
    _add_to_root(plain)
    TestHelper.assert_eq(grid.get_output(0), 0, "wall-like entity contributes nothing")
    _free(plain)


func test_unset_player_id_is_neutral():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    # StatsComponent defaults to player_id = -1 — must not pollute player -1
    # sums or any other player's state.
    var unowned := _make_building(100, -1)
    _add_to_root(unowned)
    TestHelper.assert_eq(grid.get_output(-1), 0, "unset owner never aggregated")
    TestHelper.assert_true(not grid.is_low_power(-1), "unset owner has no grid state")
    _free(unowned)


func test_map_editor_entities_skipped():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var editor_root := Node3D.new()
    editor_root.set_meta("is_map_editor", true)
    _add_to_root(editor_root)
    var entity := _make_building(100, 3)
    editor_root.add_child(entity)
    TestHelper.assert_eq(grid.get_output(3), 0, "entities under editor root not registered")
    entity.free()
    editor_root.free()
    TestHelper.assert_eq(grid.get_output(3), 0, "sums still clean after editor entity freed")


# --- Low-power boundary + signals (task 2.3) ---


func test_boundary_cross_fans_out_only_to_powered_structures():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var plant := _make_building(100, 0)
    var powered_consumer := _make_building(-150, 0, true)
    var plain_consumer := _make_building(-20, 0, false)
    var powered_pc := _pc(powered_consumer)
    var plain_pc := _pc(plain_consumer)
    _add_to_root(plant)
    TestHelper.assert_true(powered_pc.is_online, "starts online")
    _add_to_root(powered_consumer)
    TestHelper.assert_true(grid.is_low_power(0), "deficit after powered consumer lands")
    TestHelper.assert_true(not powered_pc.is_online, "powered structure shut down")
    TestHelper.assert_true(plain_pc.is_online, "non-powered structure untouched")
    _add_to_root(plain_consumer)
    TestHelper.assert_true(plain_pc.is_online, "still untouched after more drain")
    # Recovery: +100 producer brings sum to +30.
    var plant2 := _make_building(100, 0)
    _add_to_root(plant2)
    TestHelper.assert_true(not grid.is_low_power(0), "recovered")
    TestHelper.assert_true(powered_pc.is_online, "powered structure restored")
    _free(plant)
    _free(powered_consumer)
    _free(plain_consumer)
    _free(plant2)


func test_state_changed_signals_boundary_drift_and_silence():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var emissions: Array[int] = []
    var on_changed := func(pid: int) -> void: emissions.append(pid)
    grid.grid_state_changed.connect(on_changed)
    var plant := _make_building(100, 0)
    _add_to_root(plant)
    TestHelper.assert_eq(emissions.size(), 0, "healthy->healthy is a no-op (still 1.0 rate)")
    var small_consumer := _make_building(-50, 0)
    _add_to_root(small_consumer)
    TestHelper.assert_eq(emissions.size(), 0, "sum +50 still healthy at rate 1.0 — silent")
    var big_consumer := _make_building(-100, 0)
    _add_to_root(big_consumer)
    TestHelper.assert_eq(emissions, [0] as Array[int], "boundary crossing emits once")
    var more_drain := _make_building(-25, 0)
    _add_to_root(more_drain)
    TestHelper.assert_eq(emissions, [0, 0] as Array[int], "rate drift within low power emits")
    var zero_power := _make_building(0, 0)
    _add_to_root(zero_power)
    TestHelper.assert_eq(emissions.size(), 2, "power=0 building changes nothing — silent")
    _free(zero_power)
    TestHelper.assert_eq(emissions.size(), 2, "removing power=0 building — silent")
    _free(plant)
    TestHelper.assert_eq(emissions.size(), 3, "plant removal drifts ratio (100/175 -> 0/175)")
    _free(small_consumer)
    _free(big_consumer)
    TestHelper.assert_eq(emissions.size(), 3, "ratio stays 0 while output is 0 — silent")
    _free(more_drain)
    TestHelper.assert_eq(emissions.size(), 4, "final teardown recovers to healthy — emits")
    grid.grid_state_changed.disconnect(on_changed)


# --- Consumer fan-out: radar + animations (tasks 3.2 / 3.3) ---


func _make_radar_entity(online: bool = true, has_power: bool = true) -> Node3D:
    var entity := Node3D.new()
    if has_power:
        var pc := PowerComponent.new()
        pc.name = "PowerComponent"
        pc.power = -50
        pc.powered = true
        entity.add_child(pc)
        if not online:
            (entity.get_node("PowerComponent") as PowerComponent).set_online(false)
    var radar := RadarComponent.new()
    radar.name = "RadarComponent"
    radar.radar = true
    entity.add_child(radar)
    return entity


func test_radar_offline_reports_no_radar():
    var online := _make_radar_entity(true)
    var offline := _make_radar_entity(false)
    var bare := _make_radar_entity(true, false)
    var no_radar_cap := Node3D.new()
    var cap := RadarComponent.new()
    cap.name = "RadarComponent"
    cap.radar = false
    no_radar_cap.add_child(cap)
    TestHelper.assert_true(
        (online.get_node("RadarComponent") as RadarComponent).has_radar(), "online radar up"
    )
    TestHelper.assert_true(
        not (offline.get_node("RadarComponent") as RadarComponent).has_radar(),
        "powered-down radar reports offline"
    )
    TestHelper.assert_true(
        (bare.get_node("RadarComponent") as RadarComponent).has_radar(),
        "entity without PowerComponent unaffected"
    )
    TestHelper.assert_true(
        not (no_radar_cap.get_node("RadarComponent") as RadarComponent).has_radar(),
        "no radar capability reports false regardless of power"
    )
    _free(online)
    _free(offline)
    _free(bare)
    _free(no_radar_cap)


func test_powered_down_structure_pauses_active_anims():
    var entity := Node3D.new()
    var pc := PowerComponent.new()
    pc.name = "PowerComponent"
    pc.power = -50
    pc.powered = true
    entity.add_child(pc)
    var art_comp := Node3D.new()
    art_comp.name = "ArtComponent"
    art_comp.set_script(preload("res://scripts/components/ArtComponent.gd"))
    entity.add_child(art_comp)
    var art := art_comp as ArtComponent
    var data := EntityData.new()
    data.id = "TEST_POWERED_ART"
    var art_data := ArtData.new()
    art_data.id = "TEST_POWERED_ART"
    var anim := ActiveAnimData.new()
    anim.anim_name = "spin"
    anim.loop = true
    art_data.active_anims = [anim]
    data.art_data = art_data
    art.configure(data)
    var ap := art.get_node("AnimationPlayer") as AnimationPlayer
    var lib := AnimationLibrary.new()
    var spin := Animation.new()
    spin.length = 1.0
    lib.add_animation("spin", spin)
    ap.add_animation_library("", lib)
    # Model-load start path (placeholder path skips it, so start explicitly).
    art._start_active_anims_if_online()
    TestHelper.assert_true(ap.is_playing(), "active anim plays while online")
    TestHelper.assert_eq(ap.current_animation, "spin", "the active anim is the one playing")
    pc.set_online(false)
    TestHelper.assert_true(not ap.is_playing(), "power down pauses active anim")
    TestHelper.assert_eq(ap.current_animation, "spin", "paused anim stays assigned")
    pc.set_online(true)
    TestHelper.assert_true(ap.is_playing(), "power restore resumes active anim")
    _free(entity)


# --- Selected-producer power label (task 4.1, format per issue feedback) ---


func test_power_label_decision_logic():
    var overlay := _tree().root.get_node_or_null("SelectionOverlay")
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload missing")
        return
    var plant := _make_building(100, 0)
    var radar := _make_building(-50, 0)
    _add_to_root(plant)
    _add_to_root(radar)
    TestHelper.assert_eq(
        overlay._power_label_for(plant, true),
        "POWER = 100\nDRAIN = 50",
        "selected producer shows grid output and drain"
    )
    TestHelper.assert_eq(
        overlay._power_label_for(plant, false), "", "hover-only producer shows no label"
    )
    TestHelper.assert_eq(overlay._power_label_for(radar, true), "", "consumer shows no label")
    var zero := _make_building(0, 0)
    _add_to_root(zero)
    TestHelper.assert_eq(
        overlay._power_label_for(zero, true), "", "power=0 building shows no label"
    )
    _free(plant)
    _free(radar)
    _free(zero)


# --- Build rate (task 2.4) ---
func test_build_rate_interpolation():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    TestHelper.assert_eq(grid.get_build_rate(42), 1.0, "unknown player -> full rate")
    # Healthy: 100 output vs 50 drain.
    var plant := _make_building(100, 42)
    var consumer := _make_building(-50, 42)
    _add_to_root(plant)
    _add_to_root(consumer)
    TestHelper.assert_eq(grid.get_build_rate(42), 1.0, "healthy grid -> full rate")
    _free(consumer)
    # Mild deficit: 130 output vs 150 drain -> near best coefficient.
    var mild := _make_building(30, 42)
    var heavy := _make_building(-150, 42)
    _add_to_root(mild)
    _add_to_root(heavy)
    var expected_mild := 0.3 + (0.75 - 0.3) * (130.0 / 150.0)
    TestHelper.assert_true(
        absf(grid.get_build_rate(42) - expected_mild) < 1e-6,
        "mild deficit interpolates toward best: got %s" % grid.get_build_rate(42)
    )
    _free(mild)
    # Near blackout: 100 output vs 150 drain -> near worst coefficient.
    var expected_blackout := 0.3 + (0.75 - 0.3) * (100.0 / 150.0)
    TestHelper.assert_true(
        absf(grid.get_build_rate(42) - expected_blackout) < 1e-6,
        "near blackout interpolates toward worst: got %s" % grid.get_build_rate(42)
    )
    _free(heavy)
    _free(plant)
    TestHelper.assert_eq(grid.get_build_rate(42), 1.0, "drain=0 after teardown -> full rate")


func test_build_rate_full_blackout_hits_worst():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var consumer := _make_building(-100, 43)
    _add_to_root(consumer)
    TestHelper.assert_eq(grid.get_build_rate(43), 0.3, "zero output -> worst coefficient")
    _free(consumer)


# --- Registering structures into an existing grid state (review fixes) ---


func test_powered_structure_registered_during_deficit_starts_offline():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var pid := 77
    # 100 output vs 150 drain: an active deficit the new registration does
    # NOT cure — the joined powered structure must start offline.
    var producer := _make_building(100, pid)
    var drain := _make_building(-150, pid)
    _add_to_root(producer)
    _add_to_root(drain)
    TestHelper.assert_true(grid.is_low_power(pid), "precondition: grid is in deficit")
    var emissions: Array[bool] = []
    var consumer := _make_building(-50, pid, true)
    var pc := _pc(consumer)
    pc.power_state_changed.connect(func(online: bool) -> void: emissions.append(online))
    _add_to_root(consumer)
    TestHelper.assert_true(
        not pc.is_online, "powered structure registered into a deficit starts offline"
    )
    TestHelper.assert_eq(emissions, [false] as Array[bool], "exactly one offline emission")
    TestHelper.assert_true(grid.is_low_power(pid), "the deficit persists after the registration")
    _free(producer)
    _free(drain)
    _free(consumer)


func test_powered_structure_registered_on_healthy_grid_stays_online():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var pid := 78
    var emissions: Array[bool] = []
    var plant := _make_building(100, pid, true)
    var pc := _pc(plant)
    pc.power_state_changed.connect(func(online: bool) -> void: emissions.append(online))
    _add_to_root(plant)
    TestHelper.assert_true(pc.is_online, "healthy grid keeps the new structure online")
    TestHelper.assert_true(emissions.is_empty(), "no emission without a state change")
    _free(plant)


func test_unpowered_structure_registered_during_deficit_untouched():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var pid := 79
    var consumer := _make_building(-50, pid)
    _add_to_root(consumer)
    TestHelper.assert_true(grid.is_low_power(pid), "precondition: grid is in deficit")
    var plain := _make_building(0, pid, false)
    var pc := _pc(plain)
    _add_to_root(plain)
    TestHelper.assert_true(
        pc.is_online, "non-powered structures are never fanned out, even in a deficit"
    )
    _free(consumer)
    _free(plain)


func test_tiny_rate_drift_emits_below_approx_tolerance():
    var grid := _grid()
    if grid == null:
        TestHelper.fail("PowerGrid autoload missing")
        return
    var pid := 80
    var emissions: Array[int] = []
    grid.grid_state_changed.connect(
        func(p: int) -> void:
            if p == pid:
                emissions.append(p)
    )
    # 1 output vs 35 * 150 drain: one more consumer shifts the rate by a
    # relative ~8e-6 — under is_equal_approx's 1e-5 tolerance, so this add
    # regressed to silence when drift was compared approximately.
    var producer := _make_building(1, pid)
    _add_to_root(producer)
    var consumers: Array[Node] = []
    for i in 35:
        var c := _make_building(-150, pid)
        consumers.append(c)
        _add_to_root(c)
    emissions.clear()
    var extra := _make_building(-150, pid)
    _add_to_root(extra)
    TestHelper.assert_true(
        emissions.size() == 1, "sub-tolerance rate drift still emits grid_state_changed"
    )
    TestHelper.assert_true(grid.is_low_power(pid), "precondition held: grid stayed low power")
    _free(producer)
    for c in consumers:
        _free(c)
    _free(extra)
