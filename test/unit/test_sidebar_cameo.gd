extends Node

# _pack_words_to_end packs words toward the LAST line so the fullest line
# sits at the bottom of the cameo (spec ui-typography, "Word packing prefers
# the last line"). Measured Tiny5 widths at TINY5_CAMEO_SIZE (14px):
# "NOD" = 26px, "POWER" = 46px, "PLANT" = 40px, "NOD POWER" = 75px,
# "POWER PLANT" = 90px, "NOD POWER PLANT" = 119px.

const SIDEBAR_SCRIPT: GDScript = preload("res://scripts/ui/Sidebar.gd")


func _sidebar() -> Control:
    return SIDEBAR_SCRIPT.new() as Control


func test_long_name_packs_fullest_words_into_last_line():
    var sidebar := _sidebar()
    # 105px fits "POWER PLANT" (90px) but not the full name (119px) —
    # so the last line takes both words and "NOD" moves up alone.
    (
        TestHelper
        . assert_eq(
            sidebar._pack_words_to_end("NOD POWER PLANT", 105.0),
            "NOD\nPOWER PLANT",
            "packing fills the last line first",
        )
    )
    sidebar.free()


func test_name_fitting_width_stays_single_line():
    var sidebar := _sidebar()
    # 121px is the real cameo inner width; "NOD POWER PLANT" (119px) fits.
    (
        TestHelper
        . assert_eq(
            sidebar._pack_words_to_end("NOD POWER PLANT", 121.0),
            "NOD POWER PLANT",
            "no break when the whole name fits",
        )
    )
    sidebar.free()


func test_single_word_name_passes_through():
    var sidebar := _sidebar()
    (
        TestHelper
        . assert_eq(
            sidebar._pack_words_to_end("SILO", 10.0),
            "SILO",
            "one-word names never wrap",
        )
    )
    sidebar.free()


func test_narrow_width_stacks_one_word_per_line_from_the_end():
    var sidebar := _sidebar()
    # 70px: "POWER PLANT" (90) overflows, "NOD POWER" (75) also overflows,
    # so from the end each line takes one word → "NOD\nPOWER\nPLANT".
    (
        TestHelper
        . assert_eq(
            sidebar._pack_words_to_end("NOD POWER PLANT", 70.0),
            "NOD\nPOWER\nPLANT",
            "narrow width stacks one word per line from the end",
        )
    )
    sidebar.free()


func _count_cameo_rects(btn: Button) -> int:
    var count := 0
    for child in btn.get_children():
        if child is TextureRect:
            count += 1
    return count


func test_cameo_texture_added_when_art_has_cameo_path():
    var sidebar := _sidebar()
    var btn := Button.new()
    var art := ArtData.new()
    art.cameo_path = "res://games/ts/assets/cameos/nod_power_plant_icon01.png"

    sidebar._add_cameo_texture(btn, art)

    TestHelper.assert_eq(_count_cameo_rects(btn), 1, "cameo path adds exactly one TextureRect")
    var rect := btn.get_child(0) as TextureRect
    TestHelper.assert_true(rect.texture != null, "cameo texture is loaded, not null")
    (
        TestHelper
        . assert_true(
            rect.mouse_filter == Control.MOUSE_FILTER_IGNORE,
            "cameo texture ignores mouse so clicks reach the button",
        )
    )
    btn.free()
    sidebar.free()


func test_cameo_texture_skipped_for_empty_path_and_null_art():
    var sidebar := _sidebar()
    var btn := Button.new()

    sidebar._add_cameo_texture(btn, null)
    TestHelper.assert_eq(_count_cameo_rects(btn), 0, "null art_data adds no texture")

    var art := ArtData.new()
    sidebar._add_cameo_texture(btn, art)
    TestHelper.assert_eq(_count_cameo_rects(btn), 0, "empty cameo_path adds no texture")
    btn.free()
    sidebar.free()


func test_nod_power_plant_art_wires_model_and_cameo_paths():
    var art: ArtData = load("res://games/ts/art/structures/nod/nod_power_plant_art.tres")
    TestHelper.assert_true(art != null, "nod power plant art resource loads")
    TestHelper.assert_eq(
        art.model_path, "res://games/ts/assets/models/nod_power_plant01.gltf", "model path wired"
    )
    TestHelper.assert_eq(
        art.cameo_path,
        "res://games/ts/assets/cameos/nod_power_plant_icon01.png",
        "cameo path wired"
    )
    TestHelper.assert_true(ResourceLoader.exists(art.model_path), "model file exists")
    TestHelper.assert_true(ResourceLoader.exists(art.cameo_path), "cameo file exists")
