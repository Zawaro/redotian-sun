extends Node

# AudioData / VoiceData resource tests — defaults, event lookup, variant arrays


func test_audio_data_defaults():
    var audio := AudioData.new()
    TestHelper.assert_eq(audio.bus, "SFX", "default bus is SFX")
    TestHelper.assert_eq(audio.priority, 10, "default priority is 10")
    TestHelper.assert_true(audio.is_spatial, "default is spatial")
    TestHelper.assert_eq(audio.volume_db, 0.0, "default volume is 0 dB")


func test_audio_data_serialized_fields():
    var audio := AudioData.new()
    audio.id = "INFGUN3"
    audio.path = "res://external_assets/audio/infgun3.ogg"
    audio.bus = "Voice"
    audio.priority = 100
    audio.volume_db = -3.0
    audio.is_spatial = false
    TestHelper.assert_eq(audio.id, "INFGUN3", "id round-trips")
    TestHelper.assert_eq(audio.bus, "Voice", "bus round-trips")
    TestHelper.assert_eq(audio.priority, 100, "priority round-trips")
    TestHelper.assert_eq(audio.volume_db, -3.0, "volume round-trips")
    TestHelper.assert_true(not audio.is_spatial, "spatial flag round-trips")


func test_voice_data_event_lookup():
    var voice := VoiceData.new()
    voice.id = "GDI_INFANTRY"
    voice.select = ["15-I000", "15-I002", "15-I008"]
    voice.move = ["15-I018", "15-I024"]
    TestHelper.assert_eq(voice.get_event("select").size(), 3, "select variants returned")
    TestHelper.assert_eq(voice.get_event("move").size(), 2, "move variants returned")
    TestHelper.assert_eq(voice.get_event("attack").size(), 0, "empty event returns empty array")
    TestHelper.assert_eq(voice.get_event("unknown").size(), 0, "unknown event returns empty array")


func test_voice_data_events_hold_string_ids():
    var voice := VoiceData.new()
    voice.attack = ["25-I014", "25-I022"]
    for id in voice.get_event("attack"):
        TestHelper.assert_eq(typeof(id), TYPE_STRING, "each variant is a string id")
