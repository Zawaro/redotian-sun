extends Node

# VoiceComponent tests — attached only when voice_data present, holds the reference


func test_configure_sets_voice_data():
    var voice := VoiceData.new()
    voice.id = "GDI_INFANTRY"
    var data := EntityData.new()
    data.voice_data = voice

    var component := VoiceComponent.new()
    component.configure(data)
    TestHelper.assert_true(component.voice_data != null, "voice_data populated from configure")
    TestHelper.assert_eq(component.voice_data.id, "GDI_INFANTRY", "correct voice set held")


func test_configure_without_voice_data():
    var data := EntityData.new()
    var component := VoiceComponent.new()
    component.configure(data)
    TestHelper.assert_true(component.voice_data == null, "no voice_data when entity lacks it")


func test_entity_factory_attaches_voice_component():
    var entity := EntityFactory.create_entity("GDI_LIGHT_INFANTRY")
    TestHelper.assert_true(entity != null, "entity created")
    if entity:
        (
            TestHelper
            . assert_true(
                entity.get_node_or_null("VoiceComponent") != null,
                "GDI_LIGHT_INFANTRY has VoiceComponent",
            )
        )
        var voice := entity.get_node_or_null("VoiceComponent") as VoiceComponent
        TestHelper.assert_true(voice and voice.voice_data != null, "voice_data wired from .tres")
        entity.queue_free()


func test_entity_factory_omits_voice_component():
    var entity := EntityFactory.create_entity("CIV_BILLBOARD_ALKALINES_BATTERY")
    TestHelper.assert_true(entity != null, "entity created")
    if entity:
        (
            TestHelper
            . assert_true(
                entity.get_node_or_null("VoiceComponent") == null,
                "building without voice data has no VoiceComponent",
            )
        )
        entity.queue_free()


func test_nod_light_infantry_uses_infantry_voice():
    var entity := EntityFactory.create_entity("NOD_LIGHT_INFANTRY")
    TestHelper.assert_true(entity != null, "Nod light infantry created")
    if entity:
        var voice := entity.get_node_or_null("VoiceComponent") as VoiceComponent
        TestHelper.assert_true(voice != null, "Nod light infantry has VoiceComponent")
        (
            TestHelper
            . assert_true(
                voice and voice.voice_data and voice.voice_data.id == "GDI_INFANTRY",
                "Nod E1 shares the 15-Ixxx infantry voice set",
            )
        )
        entity.queue_free()


func test_nod_rocket_infantry_uses_15i_voice():
    var entity := EntityFactory.create_entity("NOD_ROCKET_INFANTRY")
    TestHelper.assert_true(entity != null, "Nod rocket infantry created")
    if entity:
        var voice := entity.get_node_or_null("VoiceComponent") as VoiceComponent
        TestHelper.assert_true(voice != null, "Nod rocket infantry has VoiceComponent")
        (
            TestHelper
            . assert_true(
                voice and voice.voice_data and voice.voice_data.id == "NOD_ROCKET_INFANTRY",
                "Nod E3 uses its 15-Ixxx voice set",
            )
        )
        entity.queue_free()


func test_nod_engineer_uses_engineer_voice():
    var entity := EntityFactory.create_entity("NOD_ENGINEER")
    TestHelper.assert_true(entity != null, "Nod engineer created")
    if entity:
        var voice := entity.get_node_or_null("VoiceComponent") as VoiceComponent
        TestHelper.assert_true(voice != null, "Nod engineer has VoiceComponent")
        (
            TestHelper
            . assert_true(
                voice and voice.voice_data and voice.voice_data.id == "GDI_ENGINEER",
                "Nod engineer shares the 19-Ixxx engineer voice set",
            )
        )
        entity.queue_free()
