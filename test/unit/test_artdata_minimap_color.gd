extends Node

# ArtData.minimap_color resolver — issue #178 minimap color rules.
# Rules: no authored color (alpha 0, e.g. TRANSPARENT default) → null = invisible;
# is_remappable + known owner → owner player's color; is_remappable + unknown
# owner → authored color fallback; otherwise authored color.

const UNTOUCHED_ART_PATH := "res://games/ts/art/vehicles/apc_art.tres"


func test_default_art_data_resolves_to_null():
    var art := ArtData.new()
    art.id = "TEST_DEFAULT"
    (
        TestHelper
        . assert_true(
            ArtData.minimap_color(art) == null,
            "fresh ArtData (TRANSPARENT default) is invisible on minimap",
        )
    )


func test_null_art_data_resolves_to_null():
    TestHelper.assert_true(
        ArtData.minimap_color(null) == null, "null ArtData is invisible on minimap"
    )


func test_authored_color_returned_when_not_remappable():
    var art := ArtData.new()
    art.id = "TEST_AUTHORED"
    art.color = Color.RED
    TestHelper.assert_eq(ArtData.minimap_color(art), Color.RED, "authored color used without remap")


func test_remappable_uses_owner_color_over_authored():
    var art := ArtData.new()
    art.id = "TEST_REMAP"
    art.color = Color.RED
    art.is_remappable = true
    TestHelper.assert_eq(
        ArtData.minimap_color(art, Color.BLUE),
        Color.BLUE,
        "remappable entity shows owner player color instead of authored color"
    )


func test_remappable_without_owner_falls_back_to_authored():
    var art := ArtData.new()
    art.id = "TEST_REMAP_NO_OWNER"
    art.color = Color.RED
    art.is_remappable = true
    TestHelper.assert_eq(
        ArtData.minimap_color(art, null),
        Color.RED,
        "remappable entity with unknown owner falls back to authored color"
    )


func test_zero_alpha_color_treated_as_absent():
    var art := ArtData.new()
    art.id = "TEST_ZERO_ALPHA"
    art.color = Color(1.0, 0.0, 0.0, 0.0)
    (
        TestHelper
        . assert_true(
            ArtData.minimap_color(art) == null,
            "fully transparent authored color counts as absent (invisible)",
        )
    )


func test_remappable_uses_owner_color_without_authored_color():
    # Remappable entities always take the side color; authoring a color on them
    # is redundant, so a missing authored color must not hide them.
    var art := ArtData.new()
    art.id = "TEST_REMAP_ABSENT"
    art.is_remappable = true
    TestHelper.assert_eq(
        ArtData.minimap_color(art, Color.BLUE),
        Color.BLUE,
        "remappable entity with an owner uses the side color without an authored color"
    )
    TestHelper.assert_true(
        ArtData.minimap_color(art) == null,
        "remappable entity with no owner and no authored color is not drawn"
    )


func test_existing_resources_without_color_stay_invisible():
    var art := load(UNTOUCHED_ART_PATH) as ArtData
    TestHelper.assert_true(art != null, "untouched art resource loads")
    TestHelper.assert_true(
        ArtData.minimap_color(art) == null,
        "art resources authored before the color property remain invisible on minimap"
    )


func test_playable_entity_art_uses_owner_color_not_authored():
    # art.ini: [E1] Remapable=yes, so the light infantry takes the owner's color
    # and carries no authored map color of its own.
    var art := load("res://games/ts/art/infantry/gdi_light_infantry_art.tres") as ArtData
    TestHelper.assert_true(art != null, "light infantry art loads")
    if art == null:
        return
    TestHelper.assert_true(art.is_remappable, "E1 is remappable per art.ini")
    TestHelper.assert_eq(
        ArtData.minimap_color(art, Color.BLUE),
        Color.BLUE,
        "remappable entity shows the owner side color"
    )
