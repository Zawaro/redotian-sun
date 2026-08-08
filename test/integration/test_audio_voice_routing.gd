extends Node

# Integration tests — voice event routing on selection/orders and weapon fire sound
# report parsing. Uses the real AudioManager autoload to observe playback decisions
# without relying on the audio driver.

var _am: Node = null
var _sm: Node = null

const TEST_TONE_PATH: String = "res://test/fixtures/audio/test_tone.wav"


func _ready() -> void:
    if has_node("/root/AudioManager"):
        _am = get_node("/root/AudioManager")
    if has_node("/root/SelectionManager"):
        _sm = get_node("/root/SelectionManager")


## Registers a committed-fixture tone + a voice set that routes every event to it,
## so playback assertions pass without the gitignored external_assets/ .ogg files.
func _register_test_voice() -> VoiceData:
    var voice := VoiceData.new()
    voice.id = "TEST_VOICE"
    voice.select = ["TEST_TONE"]
    voice.move = ["TEST_TONE"]
    voice.attack = ["TEST_TONE"]
    voice.die = ["TEST_TONE"]
    if _am:
        var audio := AudioData.new()
        audio.id = "TEST_TONE"
        audio.path = TEST_TONE_PATH
        audio.bus = "Voice"
        _am._audio_cache[audio.id] = audio
        _am._voice_cache[voice.id] = voice
    return voice


func _give_test_voice(entity: Node3D) -> void:
    var voice_comp := entity.get_node_or_null("VoiceComponent") as VoiceComponent
    if voice_comp:
        voice_comp.voice_data = _register_test_voice()


func _make_unit_with_voice(player_id: int = 0) -> Node3D:
    var entity := EntityFactory.create_entity("GDI_LIGHT_INFANTRY")
    if entity:
        _give_test_voice(entity)
        var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
        if stats:
            stats.player_id = player_id
    return entity


func test_select_voice_plays_for_local_unit():
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    var entity := _make_unit_with_voice(0)
    TestHelper.assert_true(entity != null, "unit created")
    if not entity or not _am:
        return
    var before := _am.get_child_count()
    var sc := entity.get_node_or_null("SelectComponent") as SelectComponent
    TestHelper.assert_true(sc != null, "unit has SelectComponent")
    if sc:
        _sm.select_entity(sc)
        (
            TestHelper
            . assert_true(
                _am.get_child_count() >= before + 1,
                "select voice playback spawned a player for local unit",
            )
        )
        _sm.remove_entity(sc)
    entity.queue_free()


func test_select_voice_silent_for_enemy_unit():
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    var entity := _make_unit_with_voice(1)
    TestHelper.assert_true(entity != null, "enemy unit created")
    if not entity or not _am:
        return
    var before := _am.get_child_count()
    var sc := entity.get_node_or_null("SelectComponent") as SelectComponent
    if sc:
        _sm.select_entity(sc)
        (
            TestHelper
            . assert_eq(
                _am.get_child_count(),
                before,
                "selecting an enemy unit plays no voice",
            )
        )
        _sm.remove_entity(sc)
    entity.queue_free()


func test_weapon_fire_parses_comma_report():
    # _play_fire_sound picks one id from a comma-separated report and routes it
    # through AudioManager. Both ids resolve to the committed fixture, so
    # playback spawns a player without the gitignored audio files.
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    _register_test_voice()
    var entity := Node3D.new()
    entity.name = "CombatEntity"
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    var weapon := WeaponData.new()
    weapon.id = "TEST_WEAPON"
    weapon.damage = 1
    weapon.attack_range = 1.0
    weapon.rate_of_fire = 1.0
    weapon.sound_report = "TEST_TONE,TEST_TONE"
    combat.weapons = [weapon]
    combat._init_cooldowns()
    var target := Node3D.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    health.max_health = 100
    health.current_health = 100
    target.add_child(health)
    entity.global_position = Vector3(1, 0, 1)

    var before := _am.get_child_count()
    combat._fire_weapon(weapon, target)
    (
        TestHelper
        . assert_true(
            _am.get_child_count() >= before + 1,
            "fire sound spawned a player from comma-separated report",
        )
    )
    entity.queue_free()
    target.queue_free()


func test_weapon_fire_empty_report_silent():
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    var entity := Node3D.new()
    entity.name = "CombatEntity"
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    var weapon := WeaponData.new()
    weapon.id = "TEST_WEAPON"
    weapon.damage = 1
    weapon.attack_range = 1.0
    weapon.rate_of_fire = 1.0
    weapon.sound_report = ""
    var target := Node3D.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    health.max_health = 100
    health.current_health = 100
    target.add_child(health)

    var before := _am.get_child_count()
    combat._fire_weapon(weapon, target)
    TestHelper.assert_eq(_am.get_child_count(), before, "empty report plays no sound")
    entity.queue_free()
    target.queue_free()


func test_group_select_plays_one_voice():
    # C&C rule: a multi-unit selection event plays exactly ONE select voice
    # (the NW-most unit), never one per unit.
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    var sm: Node = _sm
    var a := _make_unit_with_voice(0)
    var b := _make_unit_with_voice(0)
    var c := _make_unit_with_voice(0)
    a.global_position = Vector3(0, 0, 0)
    b.global_position = Vector3(5, 0, 0)
    c.global_position = Vector3(0, 0, 5)
    var sc_a := a.get_node_or_null("SelectComponent") as SelectComponent
    var sc_b := b.get_node_or_null("SelectComponent") as SelectComponent
    var sc_c := c.get_node_or_null("SelectComponent") as SelectComponent
    var before := _am.get_child_count()
    for sc in [sc_a, sc_b, sc_c]:
        sm.add_entity(sc)
    var after_add := _am.get_child_count()
    TestHelper.assert_eq(after_add, before, "add_entity alone plays no voice (deferred to event)")
    sm.play_select_voice_for_entities([sc_a, sc_b, sc_c])
    TestHelper.assert_eq(
        _am.get_child_count(), after_add + 1, "group select event plays exactly one voice"
    )
    for sc in [sc_a, sc_b, sc_c]:
        sm.remove_entity(sc)
    a.queue_free()
    b.queue_free()
    c.queue_free()


func test_northwest_most_picks_screen_top_unit():
    # With no camera in headless tests the picker falls back to world-space
    # ordering: smallest +Z (top-most), then largest +X (right-most).
    var sm: Node = _sm
    var a := _make_unit_with_voice(0)
    var b := _make_unit_with_voice(0)
    var c := _make_unit_with_voice(0)
    a.position = Vector3(0, 0, 0)
    b.position = Vector3(0, 0, 5)
    c.position = Vector3(7, 0, 2)
    var sc_a := a.get_node_or_null("SelectComponent") as SelectComponent
    var sc_b := b.get_node_or_null("SelectComponent") as SelectComponent
    var sc_c := c.get_node_or_null("SelectComponent") as SelectComponent
    var picked := sm.get_northwest_most([sc_a, sc_b, sc_c]) as SelectComponent
    TestHelper.assert_eq(picked, sc_a, "smallest +Z is top-most (NW-most)")
    var picked2 := sm.get_northwest_most([sc_b, sc_c]) as SelectComponent
    TestHelper.assert_eq(picked2, sc_c, "tie-break goes to largest +X (NE-most)")
    a.queue_free()
    b.queue_free()
    c.queue_free()
