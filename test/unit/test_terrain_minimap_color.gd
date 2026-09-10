extends Node

# TerrainArtData.minimap_color / shade_map_color — issue #178 terrain map color.
# The terrain element's authored color wins; the cell's LandType color is the
# fallback. Height + theater shading scales the resolved base color.

var _ts: Node = null


func test_no_inputs_resolves_to_null():
    (
        TestHelper
        . assert_true(
            TerrainArtData.minimap_color(null, null) == null,
            "cell with neither land type nor art color has no map color",
        )
    )


func test_art_color_wins_over_land_type():
    var art := TerrainArtData.new()
    art.color = Color.BLUE
    var land_type := LandType.new()
    land_type.color = Color.RED
    (
        TestHelper
        . assert_eq(
            TerrainArtData.minimap_color(art, land_type),
            Color.BLUE,
            "terrain element color is the source; land type does not override it",
        )
    )


func test_land_type_is_fallback_when_art_color_absent():
    var art := TerrainArtData.new()
    var land_type := LandType.new()
    land_type.color = Color.RED
    (
        TestHelper
        . assert_eq(
            TerrainArtData.minimap_color(art, land_type),
            Color.RED,
            "unpainted element falls back to the cell's LandType color",
        )
    )


func test_art_color_used_without_land_type():
    var art := TerrainArtData.new()
    art.color = Color(0.2, 0.8, 0.2)
    (
        TestHelper
        . assert_eq(
            TerrainArtData.minimap_color(art, null),
            Color(0.2, 0.8, 0.2),
            "element color is used when the cell has no land type",
        )
    )


func test_all_transparent_resolves_to_null():
    var art := TerrainArtData.new()
    var land_type := LandType.new()
    land_type.color = Color(0.0, 0.0, 0.0, 0.0)
    (
        TestHelper
        . assert_true(
            TerrainArtData.minimap_color(art, land_type) == null,
            "cell with no authored color at all is not drawn",
        )
    )


func test_shade_uses_low_brightness_at_ground_level():
    var base := Color(0.5, 0.5, 0.5)
    var shaded := TerrainArtData.shade_map_color(base, 0.0, 1.0, 2.0)
    TestHelper.assert_eq(shaded, Color(0.5, 0.5, 0.5), "flat ground uses low brightness")


func test_shade_uses_high_brightness_at_max_height():
    var base := Color(0.5, 0.5, 0.5)
    var shaded := TerrainArtData.shade_map_color(base, 1.0, 1.0, 2.0)
    TestHelper.assert_eq(shaded, Color(1.0, 1.0, 1.0), "max height uses high brightness")


func test_shade_brightens_monotonically_with_height():
    var base := Color(0.4, 0.4, 0.4)
    var low := TerrainArtData.shade_map_color(base, 0.25, 1.0, 2.0)
    var mid := TerrainArtData.shade_map_color(base, 0.5, 1.0, 2.0)
    var high := TerrainArtData.shade_map_color(base, 0.75, 1.0, 2.0)
    TestHelper.assert_true(low.r < mid.r, "higher ground is brighter (low < mid)")
    TestHelper.assert_true(mid.r < high.r, "higher ground is brighter (mid < high)")


func test_shade_clamps_and_preserves_alpha():
    var base := Color(0.5, 0.5, 0.5, 0.4)
    var below := TerrainArtData.shade_map_color(base, -1.0, 1.0, 2.0)
    var above := TerrainArtData.shade_map_color(base, 5.0, 1.0, 2.0)
    TestHelper.assert_eq(below, Color(0.5, 0.5, 0.5, 0.4), "height below 0 clamps to low")
    TestHelper.assert_eq(above, Color(1.0, 1.0, 1.0, 0.4), "height above 1 clamps to high")
    TestHelper.assert_true(is_equal_approx(above.a, 0.4), "alpha is preserved by shading")


func test_authored_land_types_are_visible():
    var clear_type := load("res://games/ts/land_types/clear.tres") as LandType
    TestHelper.assert_true(clear_type != null, "clear land type loads")
    if clear_type == null:
        return
    (
        TestHelper
        . assert_true(
            clear_type.color.a > 0.0,
            "authored land types carry a visible minimap color",
        )
    )


func test_theater_brightness_range_is_sane():
    var theater := load("res://games/ts/theaters/temperate.tres") as TheaterData
    TestHelper.assert_true(theater != null, "temperate theater loads")
    if theater == null:
        return
    (
        TestHelper
        . assert_true(
            theater.high_radar_brightness > theater.low_radar_brightness,
            "theater radar brightness rises with height",
        )
    )


func test_cell_height_ratio_spans_zero_to_one():
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    var flat: float = _ts.get_cell_height_ratio(Vector2i(40, 40))
    TestHelper.assert_true(flat >= 0.0 and flat <= 1.0, "height ratio stays within 0..1")
