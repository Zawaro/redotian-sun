extends Node

# Economy SFX wiring tests — credits_changed routes to AudioManager.play_sound
# with a distinct id per direction (income vs spend) via an explicit reason
# allowlist. Unknown/noise reasons (debug_menu) stay silent.

const LISTENER_PATH := "res://scripts/core/EconomyAudioListener.gd"

var _em: Node = null
var _am: Node = null


func _ready() -> void:
    if has_node("/root/EconomyManager"):
        _em = get_node("/root/EconomyManager")
    if has_node("/root/AudioManager"):
        _am = get_node("/root/AudioManager")


func _make_listener() -> Node:
    var script: GDScript = load(LISTENER_PATH)
    TestHelper.assert_true(script != null, "EconomyAudioListener script loadable")
    if not script or not _am:
        TestHelper.fail("listener or AudioManager unavailable")
        return null
    var listener: Node = script.new()
    # Add under the in-tree AudioManager autoload so _ready() wires the signal.
    _am.add_child(listener)
    return listener


func _drop_listener(listener: Node) -> void:
    if listener and is_instance_valid(listener):
        _am.remove_child(listener)
        listener.free()


func _count_audio_players() -> int:
    var count := 0
    for child in _am.get_children():
        if child is AudioStreamPlayer:
            count += 1
    return count


func _arm_retrigger() -> void:
    # Clear the per-id retrigger window so back-to-back test plays are observed.
    _am._last_played_at.clear()


func test_income_reasons_map_to_income_sound():
    if not _am:
        TestHelper.fail("AudioManager not injected")
        return
    var listener := _make_listener()
    if not listener:
        return
    TestHelper.assert_eq(
        listener.call("resolve_sound_id", "harvest"),
        "ECON_INCOME",
        "harvest dump maps to income sound"
    )
    TestHelper.assert_eq(
        listener.call("resolve_sound_id", "sell:gacnst"),
        "ECON_INCOME",
        "sell refund maps to income sound"
    )
    _drop_listener(listener)


func test_spend_reasons_map_to_spend_sound():
    if not _am:
        TestHelper.fail("AudioManager not injected")
        return
    var listener := _make_listener()
    if not listener:
        return
    TestHelper.assert_eq(
        listener.call("resolve_sound_id", "build:gacnst"),
        "ECON_SPEND",
        "building placement maps to spend sound"
    )
    TestHelper.assert_eq(
        listener.call("resolve_sound_id", "prod:mediumtank"),
        "ECON_SPEND",
        "production deduction maps to spend sound"
    )
    _drop_listener(listener)


func test_noise_reasons_stay_silent():
    if not _am:
        TestHelper.fail("AudioManager not injected")
        return
    var listener := _make_listener()
    if not listener:
        return
    TestHelper.assert_eq(
        listener.call("resolve_sound_id", "debug_menu"), "", "debug cheat credits stay silent"
    )
    TestHelper.assert_eq(
        listener.call("resolve_sound_id", "HARVEST"),
        "",
        "reason allowlist is case-sensitive: unknown casing stays silent"
    )
    TestHelper.assert_eq(listener.call("resolve_sound_id", "test"), "", "test reasons stay silent")
    TestHelper.assert_eq(listener.call("resolve_sound_id", ""), "", "empty reason stays silent")
    _drop_listener(listener)


func test_harvest_income_plays_sound_on_sfx_bus():
    if not _am:
        TestHelper.fail("AudioManager not injected")
        return
    var listener := _make_listener()
    if not listener:
        return
    _arm_retrigger()
    var before := _count_audio_players()
    _em.add(260, 500, "harvest")
    var after := _count_audio_players()
    TestHelper.assert_eq(after, before + 1, "income credit spawns one audio player")
    if after > before:
        var last := _am.get_children()[-1] as AudioStreamPlayer
        TestHelper.assert_true(last != null, "income player is a non-spatial AudioStreamPlayer")
        if last:
            TestHelper.assert_eq(last.get_bus(), "SFX", "income sound routes to SFX bus")
    _drop_listener(listener)


func test_production_deduction_plays_spend_sound_on_sfx_bus():
    if not _am:
        TestHelper.fail("AudioManager not injected")
        return
    var listener := _make_listener()
    if not listener:
        return
    _arm_retrigger()
    var before := _count_audio_players()
    # Seed credits with an unlisted reason so seeding itself stays silent.
    _em.add(261, 2000, "test")
    var deducted: bool = _em.deduct(261, 300, "prod:mediumtank")
    TestHelper.assert_true(deducted, "deduction succeeded so credits_changed fired")
    var after := _count_audio_players()
    TestHelper.assert_eq(after, before + 1, "spend deduction spawns one audio player")
    if after > before:
        var last := _am.get_children()[-1] as AudioStreamPlayer
        TestHelper.assert_true(last != null, "spend player is a non-spatial AudioStreamPlayer")
        if last:
            TestHelper.assert_eq(last.get_bus(), "SFX", "spend sound routes to SFX bus")
    _drop_listener(listener)


func test_debug_credits_stay_silent():
    if not _am:
        TestHelper.fail("AudioManager not injected")
        return
    var listener := _make_listener()
    if not listener:
        return
    _arm_retrigger()
    var before := _count_audio_players()
    _em.add(262, 100000, "debug_menu", "tiberium", true)
    TestHelper.assert_eq(_count_audio_players(), before, "debug credits spawn no player")
    _drop_listener(listener)


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
                ResourceLoader.exists(audio.path), "%s wav imported and loadable" % id
            )
            TestHelper.assert_true(not audio.is_spatial, "%s plays non-spatial" % id)
