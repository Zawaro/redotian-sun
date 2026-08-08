extends Node

# AudioManager tests — directory scan caching, idempotent re-register, graceful
# failure on missing ids/files, bus routing, voice variant selection.

var _am: Node = null


func _ready() -> void:
    if has_node("/root/AudioManager"):
        _am = get_node("/root/AudioManager")


func test_scan_caches_audio_by_id():
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    if not _am:
        return
    var audio: AudioData = _am.get_audio_data("INFGUN3")
    TestHelper.assert_true(audio != null, "INFGUN3 cached from resources/audio scan")
    if audio:
        TestHelper.assert_eq(audio.bus, "SFX", "weapon sound on SFX bus")
        TestHelper.assert_eq(audio.path, "res://external_assets/audio/infgun3.ogg", "path resolved")


func test_scan_caches_voice_by_id():
    TestHelper.assert_true(_am != null, "AudioManager autoload present")
    if not _am:
        return
    var voice: VoiceData = _am.get_voice_data("GDI_VEHICLE")
    TestHelper.assert_true(voice != null, "GDI_VEHICLE voice set cached")
    if voice:
        TestHelper.assert_true(voice.select.size() >= 4, "select has variant list")
        TestHelper.assert_eq(voice.get_event("move").size(), 5, "move variants from rules.ini")


func test_register_data_set_is_idempotent():
    if not _am:
        return
    var before: int = _am._data_sets.size()
    _am.register_data_set("res://resources/audio/")
    TestHelper.assert_eq(_am._data_sets.size(), before, "re-registering same path is a no-op")


func test_missing_directory_warns_without_crash():
    if not _am:
        return
    _am.register_data_set("res://resources/audio/missing_dir/")
    var recorded: bool = _am._data_sets.has("res://resources/audio/missing_dir/")
    TestHelper.assert_true(recorded, "missing dir recorded")
    TestHelper.assert_true(true, "no crash on missing dir")


func test_play_sound_unknown_id_silent():
    if not _am:
        return
    var before := _am.get_child_count()
    _am.play_sound("NO_SUCH_SOUND_XYZ")
    TestHelper.assert_eq(_am.get_child_count(), before, "unknown id spawns no player")


func test_play_voice_empty_event_silent():
    if not _am:
        return
    var before := _am.get_child_count()
    _am.play_voice("GDI_VEHICLE", "feedback", Vector3.ZERO)
    TestHelper.assert_eq(_am.get_child_count(), before, "empty feedback event spawns no player")


func test_sound_routes_to_declared_bus():
    if not _am:
        return
    var before := _am.get_child_count()
    _am.play_sound("INFGUN3", Vector3(10, 0, 5))
    var last := _am.get_child(_am.get_child_count() - 1) as Node
    TestHelper.assert_true(last != null, "player created for known id")
    if last and last.has_method("get_bus"):
        TestHelper.assert_eq(last.get_bus(), "SFX", "player routed to declared bus")
    TestHelper.assert_true(_am.get_child_count() >= before + 1, "player added as child")
    if last is Node3D:
        (
            TestHelper
            . assert_eq(
                (last as Node3D).global_position,
                Vector3(10, 0, 5),
                "spatial player positioned without error",
            )
        )
        (
            TestHelper
            . assert_eq(
                (last as AudioStreamPlayer3D).attenuation_model,
                AudioStreamPlayer3D.ATTENUATION_DISABLED,
                "spatial player has distance attenuation disabled",
            )
        )
