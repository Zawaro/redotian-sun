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
