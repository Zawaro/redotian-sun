extends Node

# Credit counter tick SFX tests — the sidebar credit counter steps toward its
# target balance and plays one tick per displayed step: ECON_INCOME while
# counting up, ECON_SPEND while counting down. Forced displays (scene ready)
# are silent and instant, other players' balances never animate or tick, and
# the animation completes even when the audio files are missing.
#
# Tests drive Sidebar._step_counter with synthetic deltas and run without
# awaiting frames, so _process never interleaves and counts are deterministic.
# Expected step sizes are derived independently (gap / 8 floored, clamped to
# at least 1), not copied from production code.

const SIDEBAR_SCENE: PackedScene = preload("res://scenes/ui/Sidebar.tscn")
const INCOME_STREAM_PATH: String = "res://external_assets/audio/credup1.ogg"
const SPEND_STREAM_PATH: String = "res://external_assets/audio/creddwn1.ogg"

var _em: Node = null
var _am: Node = null


func _ready() -> void:
    _em = get_node_or_null("/root/EconomyManager")
    _am = get_node_or_null("/root/AudioManager")


func _local_id() -> int:
    return PlayerManager.get_local_player_id()


func _make_sidebar() -> Control:
    var sidebar: Control = SIDEBAR_SCENE.instantiate()
    (Engine.get_main_loop() as SceneTree).root.add_child(sidebar)
    return sidebar


func _drop_sidebar(sidebar: Control) -> void:
    if sidebar and is_instance_valid(sidebar):
        sidebar.free()


func _label(sidebar: Control) -> Label:
    return sidebar.get_node("%CreditsLabel") as Label


func _count_audio_players() -> int:
    var count := 0
    for child in _am.get_children():
        if child is AudioStreamPlayer:
            count += 1
    return count


func _arm_retrigger() -> void:
    # Clear the per-id retrigger window so each driven step's play is observed.
    _am._last_played_at.clear()


func _last_player() -> AudioStreamPlayer:
    var children := _am.get_children()
    for i in range(children.size() - 1, -1, -1):
        if children[i] is AudioStreamPlayer:
            return children[i]
    return null


func test_ready_forces_display_silently():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    var before := _count_audio_players()
    var sidebar := _make_sidebar()
    var balance: int = _em.get_balance(_local_id())
    TestHelper.assert_true(_label(sidebar) != null, "Sidebar has a %CreditsLabel node")
    TestHelper.assert_eq(
        _label(sidebar).text, "$%d" % balance, "ready shows the current balance instantly"
    )
    TestHelper.assert_eq(_count_audio_players(), before, "forced display plays no tick sound")
    _drop_sidebar(sidebar)


func test_gain_animates_with_up_ticks():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    var sidebar := _make_sidebar()
    sidebar.call("_force_display_credits", 500)
    _em.credits_changed.emit(_local_id(), 1000, "harvest", "tiberium")

    # No instant write: the label still shows the old value until a step runs.
    TestHelper.assert_eq(_label(sidebar).text, "$500", "credit change does not jump the label")

    # Known example: gap 500, first step = floor(500 / 8) = 62.
    _arm_retrigger()
    var before := _count_audio_players()
    sidebar.call("_step_counter", 0.0)
    TestHelper.assert_eq(
        _label(sidebar).text, "$562", "first gain step advances by floor(500/8)=62"
    )
    TestHelper.assert_eq(_count_audio_players(), before + 1, "each gain step plays one tick")
    var player := _last_player()
    TestHelper.assert_true(player != null, "tick spawns an audio player")
    if player:
        TestHelper.assert_eq(player.get_bus(), "SFX", "up-tick routes to the SFX bus")
        (
            TestHelper
            . assert_true(
                player.stream != null and player.stream.resource_path == INCOME_STREAM_PATH,
                "up-tick plays the ECON_INCOME stream",
            )
        )

    # Drive to settle: one step per call while counting up, tick per step.
    var calls := 0
    while _label(sidebar).text != "$1000" and calls < 100:
        _arm_retrigger()
        sidebar.call("_step_counter", 0.0)
        calls += 1
    TestHelper.assert_eq(_label(sidebar).text, "$1000", "counter settles exactly at the target")
    TestHelper.assert_true(calls < 100, "gain burst animates sub-linearly, not one credit per step")

    # Settled: no further ticks.
    _arm_retrigger()
    before = _count_audio_players()
    sidebar.call("_step_counter", 0.1)
    TestHelper.assert_eq(_count_audio_players(), before, "settled counter plays no tick")
    _drop_sidebar(sidebar)


func test_small_gain_uses_min_step():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    var sidebar := _make_sidebar()
    sidebar.call("_force_display_credits", 1000)
    _em.credits_changed.emit(_local_id(), 1003, "harvest", "tiberium")

    # 3 / 8 = 0, clamped to MIN_STEP 1: three single-credit steps, one tick each.
    for expected in [1001, 1002, 1003]:
        _arm_retrigger()
        var before := _count_audio_players()
        sidebar.call("_step_counter", 0.0)
        TestHelper.assert_eq(_label(sidebar).text, "$%d" % expected, "small gain steps by MIN_STEP")
        TestHelper.assert_eq(_count_audio_players(), before + 1, "small gain step still ticks once")

    # Settled: no further ticks.
    _arm_retrigger()
    var before := _count_audio_players()
    sidebar.call("_step_counter", 0.0)
    TestHelper.assert_eq(_label(sidebar).text, "$1003", "small gain settles exactly at target")
    TestHelper.assert_eq(_count_audio_players(), before, "settled counter stays silent")
    _drop_sidebar(sidebar)


func test_spend_counts_down_slower():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    var sidebar := _make_sidebar()
    sidebar.call("_force_display_credits", 1000)
    _em.credits_changed.emit(_local_id(), 500, "build:gaweap", "tiberium")

    # Below the spend step interval: time accumulates but no step applies.
    _arm_retrigger()
    var before := _count_audio_players()
    sidebar.call("_step_counter", 0.04)
    TestHelper.assert_eq(_label(sidebar).text, "$1000", "spend does not step below its interval")
    TestHelper.assert_eq(_count_audio_players(), before, "spend does not tick below its interval")

    # At the interval: exactly one step. Known example: gap -500, floor(500/8)=62.
    _arm_retrigger()
    before = _count_audio_players()
    sidebar.call("_step_counter", 0.05)
    TestHelper.assert_eq(
        _label(sidebar).text, "$938", "first spend step advances by floor(500/8)=62"
    )
    TestHelper.assert_eq(_count_audio_players(), before + 1, "each spend step plays one tick")
    var player := _last_player()
    TestHelper.assert_true(player != null, "down-tick spawns an audio player")
    if player:
        TestHelper.assert_eq(player.get_bus(), "SFX", "down-tick routes to the SFX bus")
        (
            TestHelper
            . assert_true(
                player.stream != null and player.stream.resource_path == SPEND_STREAM_PATH,
                "down-tick plays the ECON_SPEND stream",
            )
        )
    _drop_sidebar(sidebar)


func test_other_player_events_stay_silent():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    var sidebar := _make_sidebar()
    sidebar.call("_force_display_credits", 1000)
    var before := _count_audio_players()
    _em.credits_changed.emit(_local_id() + 99, 5000, "harvest", "tiberium")
    for i in range(10):
        _arm_retrigger()
        sidebar.call("_step_counter", 1.0)
    TestHelper.assert_eq(
        _label(sidebar).text, "$1000", "other players' credit changes never animate the counter"
    )
    TestHelper.assert_eq(_count_audio_players(), before, "other players' credit changes never tick")
    _drop_sidebar(sidebar)


func test_animation_completes_with_missing_audio_file():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    var sidebar := _make_sidebar()
    sidebar.call("_force_display_credits", 500)
    _em.credits_changed.emit(_local_id(), 1000, "harvest", "tiberium")

    var saved: AudioData = _am._audio_cache.get("ECON_INCOME", null)
    _am._audio_cache["ECON_INCOME"] = null
    var before := _count_audio_players()
    var calls := 0
    while _label(sidebar).text != "$1000" and calls < 100:
        _arm_retrigger()
        sidebar.call("_step_counter", 0.05)
        calls += 1
    TestHelper.assert_eq(
        _label(sidebar).text, "$1000", "counter settles even when the tick id is missing"
    )
    TestHelper.assert_eq(
        _count_audio_players(), before, "missing audio file spawns no player (warn-and-continue)"
    )
    _am._audio_cache["ECON_INCOME"] = saved
    _drop_sidebar(sidebar)


func test_econ_sounds_declared_and_imported():
    if not _am:
        TestHelper.fail("AudioManager not injected")
        return
    for id in ["ECON_INCOME", "ECON_SPEND"]:
        var audio: AudioData = _am.get_audio_data(id)
        TestHelper.assert_true(audio != null, "%s registered from resources/audio scan" % id)
        if audio:
            TestHelper.assert_eq(audio.bus, "SFX", "%s declared on SFX bus" % id)
            TestHelper.assert_true(not audio.path.is_empty(), "%s has a stream path" % id)
            TestHelper.assert_true(
                ResourceLoader.exists(audio.path), "%s stream imported and loadable" % id
            )
            TestHelper.assert_true(not audio.is_spatial, "%s plays non-spatial" % id)
            TestHelper.assert_eq(
                audio.retrigger_ms, 50.0, "%s uses the snappy 50 ms retrigger override" % id
            )


# --- counter under real gradual production drain ---

const FACTORY_ID: String = "test_audio_barracks"


func _make_infantry(id: String, cost: int) -> EntityData:
    var data := EntityData.new()
    data.id = id
    data.entity_type = EntityData.EntityType.INFANTRY
    data.display_name = "Test Infantry"
    data.cost = cost
    data.build_time = 5.0
    data.buildable_queue = "InfantryType"
    data.buildable = true
    return data


func _ensure_local_factory(pid: int) -> void:
    var factory_data := EntityData.new()
    factory_data.id = FACTORY_ID
    factory_data.entity_type = EntityData.EntityType.BUILDING
    factory_data.display_name = "Test Barracks"
    factory_data.factory = "InfantryType"
    factory_data.buildable = true
    EntityFactory._entity_cache[FACTORY_ID] = factory_data
    var ps := _em.get_node_or_null("/root/PrerequisiteSystem")
    if ps:
        ps.register_building(pid, factory_data)


func _cleanup_local_factory(pid: int) -> void:
    var ps := _em.get_node_or_null("/root/PrerequisiteSystem")
    var factory_data: EntityData = EntityFactory._entity_cache.get(FACTORY_ID, null)
    if ps and factory_data:
        ps.unregister_building(pid, factory_data)
    EntityFactory._entity_cache.erase(FACTORY_ID)


func test_counter_tracks_balance_during_gradual_production():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    # The test object is not in the tree (the runner injects autoload vars),
    # so resolve tree nodes through the in-tree _em, never via /root paths.
    var pm := _em.get_node_or_null("/root/ProductionManager")
    if not pm:
        TestHelper.fail("ProductionManager not injected")
        return
    var pid := _local_id()
    _ensure_local_factory(pid)
    var sidebar := _make_sidebar()
    # This test exercises the credit counter, not the production-overlay UI.
    # Disconnect the overlay signals: their handlers do absolute-path lookups
    # that are unreliable in the -s test harness and only add error noise.
    var pm_node := _em.get_node_or_null("/root/ProductionManager")
    if pm_node:
        pm_node.production_started.disconnect(sidebar._on_production_started)
        pm_node.production_progress.disconnect(sidebar._on_production_progress)
        pm_node.production_completed.disconnect(sidebar._on_production_completed)
        pm_node.production_cancelled.disconnect(sidebar._on_production_cancelled)
        pm_node.production_paused.disconnect(sidebar._on_production_paused)
    # Pin the balance regardless of what earlier suites left behind: known
    # start 5000, known drain 240 → known end 4760.
    _em.add(pid, 5000 - _em.get_balance(pid), "test")
    sidebar.call("_force_display_credits", 5000)

    var data := _make_infantry("test_audio_infantry", 600)
    TestHelper.assert_true(
        pm.start_production(pid, data), "production starts with a registered factory"
    )
    var key: String = pm.get_queue_key(pid, "InfantryType")

    # Simulate 2 seconds of building. Each frame, ProductionManager deducts
    # gradually (rate = cost / build_time = 120 credits/s here) and the sidebar
    # counter gets its delta — mirroring the two _process callbacks in-game.
    for i in range(120):
        pm._process(1.0 / 60.0)
        sidebar.call("_step_counter", 1.0 / 60.0)

    # Known example: 120 credits/s over 2 s = 240 credits drained.
    var balance: int = _em.get_balance(pid)
    TestHelper.assert_eq(balance, 4760, "gradual deduction drains cost/build_time per second")
    (
        TestHelper
        . assert_true(
            _label(sidebar).text.trim_prefix("$").to_int() < 5000,
            "counter counts down during continuous deduction, not only after the drain stops",
        )
    )

    # Liveness: once the drain stops, the counter settles at the real balance.
    var calls := 0
    while _label(sidebar).text != "$%d" % balance and calls < 200:
        sidebar.call("_step_counter", 0.05)
        calls += 1
    TestHelper.assert_eq(
        _label(sidebar).text, "$%d" % balance, "counter settles at the drained balance"
    )

    pm.cancel_production(pid, key, 0)
    _drop_sidebar(sidebar)
    _cleanup_local_factory(pid)


func test_spend_does_not_burst_after_sustained_income():
    if not _am or not _em:
        TestHelper.fail("AudioManager or EconomyManager not injected")
        return
    # Regression: the cadence accumulator grew unbounded while the counter was
    # in flight behind income (gain interval 0 never drains it). The first
    # spend frame then burned the stored time in one burst, collapsing the
    # count-down animation to a jump. Drive a large gain that keeps the
    # counter in flight for 30 frames, keep income arriving during the
    # animation, then spend.
    var sidebar := _make_sidebar()
    sidebar.call("_force_display_credits", 1000)
    var pid := _local_id()
    _em.credits_changed.emit(pid, 6000, "harvest", "tiberium")
    for i in range(1, 31):
        _em.credits_changed.emit(pid, 6000 + 100 * i, "harvest", "tiberium")
        sidebar.call("_step_counter", 1.0 / 60.0)
    # Known example: gain steps are clamped by MAX_STEP 143, so 30 frames of
    # counting up land exactly on 1000 + 30*143 = 5290.
    TestHelper.assert_eq(_label(sidebar).text, "$5290", "in-flight gain counts at the MAX_STEP cap")

    # Spend while the income animation is still catching up (gap 3710 to the
    # last target, now a -10 spend). First spend frame: delta 1/60 is below
    # the spend step interval, so the clamped accumulator applies no step —
    # the un-clamped version burst 10 steps and jumped straight to $5280.
    _em.credits_changed.emit(pid, 5280, "build:gaweap", "tiberium")
    sidebar.call("_step_counter", 1.0 / 60.0)
    (
        TestHelper
        . assert_eq(
            _label(sidebar).text,
            "$5290",
            "first spend frame after in-flight income applies no burst step",
        )
    )

    # Normal cadence from there: one step per spend interval until settled.
    var calls := 0
    while _label(sidebar).text != "$5280" and calls < 100:
        sidebar.call("_step_counter", 0.05)
        calls += 1
    TestHelper.assert_eq(_label(sidebar).text, "$5280", "counter settles at the spend target")
    _drop_sidebar(sidebar)
