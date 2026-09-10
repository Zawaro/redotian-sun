extends Node

# Minimap pure-helper tests: cell/texel mapping, terrain color precedence,
# fog composition, and overlay gating. Rendering/UI wiring is verified in-game.
# Color resolvers themselves are covered by test_terrain_minimap_color.gd and
# test_artdata_minimap_color.gd.

const DIM := 2
const BRIGHT := 2

const MINIMAP_SCENE: PackedScene = preload("res://scenes/ui/Minimap.tscn")


func test_scene_instantiates_as_control():
    var minimap := MINIMAP_SCENE.instantiate()
    TestHelper.assert_true(minimap is Minimap, "Minimap.tscn root uses the Minimap script")
    (
        TestHelper
        . assert_eq(
            (minimap as Control).mouse_filter,
            Control.MOUSE_FILTER_STOP,
            "minimap captures mouse input",
        )
    )
    (
        TestHelper
        . assert_eq(
            (minimap as Control).custom_minimum_size,
            Vector2(200, 200),
            "minimap is 200x200",
        )
    )
    minimap.free()


func _art(color: Color) -> TerrainArtData:
    var art := TerrainArtData.new()
    art.id = "TEST"
    art.color = color
    return art


func _land(color: Color) -> LandType:
    var land := LandType.new()
    land.id = "test"
    land.color = color
    return land


func test_cell_index_round_trip_square():
    for cell in [Vector2i(0, 0), Vector2i(5, 7), Vector2i(99, 99), Vector2i(0, 99)]:
        var index := Minimap.cell_to_index(cell, 100)
        TestHelper.assert_eq(Minimap.index_to_cell(index, 100), cell, "cell %s round-trips" % cell)


func test_cell_index_round_trip_rectangular_odd():
    for cell in [Vector2i(0, 0), Vector2i(3, 8), Vector2i(40, 12), Vector2i(40, 0)]:
        var index := Minimap.cell_to_index(cell, 41)
        TestHelper.assert_eq(
            Minimap.index_to_cell(index, 41), cell, "odd-width cell %s round-trips" % cell
        )


func test_cell_index_rejects_invalid():
    TestHelper.assert_eq(Minimap.cell_to_index(Vector2i(-1, 0), 10), -1, "negative x")
    TestHelper.assert_eq(Minimap.cell_to_index(Vector2i(0, -1), 10), -1, "negative y")
    TestHelper.assert_eq(Minimap.cell_to_index(Vector2i(0, 0), 0), -1, "zero width")
    TestHelper.assert_eq(Minimap.index_to_cell(-1, 10), Vector2i(-1, -1), "negative index")


func test_diamond_bounds_match_extent():
    var grid := Vector2i(4, 6)
    var extent := CellUtil.get_diamond_extent(grid)
    TestHelper.assert_eq(extent, Vector2i(10, 10), "extent = W+H")
    var inside := Vector2i(4, 4)
    TestHelper.assert_true(
        CellUtil.is_in_diamond(inside, grid), "extent centre cell is in the diamond"
    )
    TestHelper.assert_true(
        not CellUtil.is_in_diamond(Vector2i(0, 0), grid), "corner is outside the diamond"
    )


func test_resolve_land_type_id_excludes_resource_and_default():
    TestHelper.assert_eq(
        Minimap.resolve_land_type_id(""), "clear", "empty painted type falls back to clear"
    )
    (
        TestHelper
        . assert_eq(
            Minimap.resolve_land_type_id("resource"),
            "clear",
            "resource-derived land type is excluded from terrain colour",
        )
    )
    TestHelper.assert_eq(
        Minimap.resolve_land_type_id("road"), "road", "painted land type passes through"
    )


func test_terrain_color_precedence():
    var art_color := Color(0.1, 0.2, 0.3, 1.0)
    var land_color := Color(0.6, 0.5, 0.4, 1.0)
    var from_art: Variant = Minimap.shade_terrain(_art(art_color), _land(land_color), 0.0, 1.0, 1.0)
    TestHelper.assert_eq(from_art, art_color, "authored art color wins")

    var from_land: Variant = Minimap.shade_terrain(
        _art(Color(0, 0, 0, 0)), _land(land_color), 0.0, 1.0, 1.0
    )
    TestHelper.assert_eq(from_land, land_color, "transparent art falls back to land type color")

    var none: Variant = Minimap.shade_terrain(
        _art(Color(0, 0, 0, 0)), _land(Color(0, 0, 0, 0)), 0.0, 1.0, 1.0
    )
    TestHelper.assert_true(none == null, "no art and no land color resolves to null")


func test_terrain_color_height_shading():
    var base := Color(0.5, 0.5, 0.5, 1.0)
    var low: Variant = Minimap.shade_terrain(_art(base), null, 0.0, 1.0, 2.0)
    var high: Variant = Minimap.shade_terrain(_art(base), null, 1.0, 1.0, 2.0)
    TestHelper.assert_eq(low, Color(0.5, 0.5, 0.5, 1.0), "flat ground uses low brightness")
    TestHelper.assert_eq(high, Color(1.0, 1.0, 1.0, 1.0), "max height uses high brightness")


func test_fog_factor_across_toggles():
    TestHelper.assert_eq(
        Minimap.fog_factor(Minimap.STATE_SHROUD, true, true), 0.0, "shroud is black"
    )
    (
        TestHelper
        . assert_eq(
            Minimap.fog_factor(Minimap.STATE_SHROUD, false, true),
            1.0,
            "shroud toggle off reveals shroud cells",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.fog_factor(Minimap.STATE_FOG, true, true),
            Minimap.FOG_DIM,
            "explored cell is dimmed when fog is on",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.fog_factor(Minimap.STATE_FOG, true, false),
            1.0,
            "explored cell is full when fog is off",
        )
    )
    TestHelper.assert_eq(
        Minimap.fog_factor(Minimap.STATE_VISIBLE, true, true), 1.0, "visible cell is full"
    )


func test_overlay_gating():
    var base := Color(0.2, 0.8, 0.2, 1.0)
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_color(base, Minimap.STATE_SHROUD, true, true),
            Color(0, 0, 0, 0),
            "shrouded overlay is omitted",
        )
    )
    var dimmed: Color = Minimap.overlay_color(base, Minimap.STATE_FOG, true, true)
    (
        TestHelper
        . assert_eq(
            dimmed,
            Color(
                base.r * Minimap.FOG_DIM, base.g * Minimap.FOG_DIM, base.b * Minimap.FOG_DIM, 1.0
            ),
            "fog overlay is dimmed",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_color(base, Minimap.STATE_VISIBLE, true, true),
            base,
            "visible overlay keeps full colour",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_color(base, Minimap.STATE_SHROUD, false, true),
            base,
            "shroud-off reveals overlays",
        )
    )


func test_size_for_play_area_preserves_map_aspect():
    (
        TestHelper
        . assert_eq(
            Minimap.size_for_play_area(Vector2i(100, 50), Vector4i.ZERO, 200.0),
            Vector2(200, 100),
            "wide map keeps W:H aspect",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.size_for_play_area(Vector2i(50, 100), Vector4i.ZERO, 200.0),
            Vector2(100, 200),
            "tall map keeps W:H aspect",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.size_for_play_area(Vector2i(80, 80), Vector4i.ZERO, 200.0),
            Vector2(200, 200),
            "square map is square",
        )
    )
    # Insets shrink the two play-diagonal spans asymmetrically: aspect becomes
    # (2W-left-right):(2H-top-bottom).
    var inset_size := Minimap.size_for_play_area(Vector2i(100, 50), Vector4i(5, 5, 4, 4), 200.0)
    (
        TestHelper
        . assert_true(
            inset_size.is_equal_approx(Vector2(200.0, 200.0 * 92.0 / 190.0)),
            "inset play diamond drives the aspect (got %s)" % inset_size,
        )
    )


func test_in_play_area_matches_diamond_without_insets():
    var grid := Vector2i(10, 10)
    for cell in [
        Vector2i(0, 0),
        Vector2i(5, 5),
        Vector2i(9, 9),
        Vector2i(0, 9),
        Vector2i(9, 0),
        Vector2i(3, 7),
        Vector2i(7, 3),
    ]:
        (
            TestHelper
            . assert_eq(
                Minimap.in_play_area(cell, grid, Vector4i.ZERO),
                CellUtil.is_in_diamond(cell, grid),
                "zero-inset play area matches the map diamond at %s" % cell,
            )
        )


func test_in_play_area_insets_shrink_to_subset():
    var grid := Vector2i(20, 20)
    var extent := CellUtil.get_diamond_extent(grid)
    var insets := Vector4i(3, 3, 2, 2)
    var diamond_count := 0
    var play_count := 0
    for y in extent.y:
        for x in extent.x:
            var cell := Vector2i(x, y)
            var in_diamond := CellUtil.is_in_diamond(cell, grid)
            var in_play := Minimap.in_play_area(cell, grid, insets)
            if in_diamond:
                diamond_count += 1
            if in_play:
                play_count += 1
                TestHelper.assert_true(
                    in_diamond, "play cell %s is always inside the map diamond" % cell
                )
    TestHelper.assert_true(play_count > 0, "inset play area is non-empty")
    TestHelper.assert_true(
        play_count < diamond_count, "insets shrink the play area below the full diamond"
    )


func test_index_pixel_round_trip():
    var map := Vector2i(12, 7)
    var insets := Vector4i(2, 3, 1, 2)
    var size := Minimap.size_for_play_area(map, insets, 200.0)
    for index in [Vector2(0, 0), Vector2(12, 7), Vector2(3.5, 11.25), Vector2(18, 1)]:
        var pixel := Minimap.index_to_pixel(index, map, insets, size)
        var back := Minimap.pixel_to_index(pixel, map, insets, size)
        TestHelper.assert_true(
            back.is_equal_approx(index), "index %s round-trips through pixel space" % index
        )


func _index_for(b: float, a: float, w: float, h: float) -> Vector2:
    return Vector2((b + a + w + h) * 0.5, (a + w + h - b) * 0.5)


func test_play_diamond_vertices_map_to_control_corners():
    # Play-diamond corners in the (b = x - y, a = x + y - (W+H)) frame map to the
    # control corners through the 45-degree transform; insets crop the rim.
    var map := Vector2i(8, 5)
    var insets := Vector4i(2, 3, 1, 2)
    var size := Minimap.size_for_play_area(map, insets, 200.0)
    var w := float(map.x)
    var h := float(map.y)
    var b_lo := -w + float(insets.x)
    var b_hi := w - float(insets.y)
    var a_lo := -h + float(insets.z)
    var a_hi := h - float(insets.w)
    var vertices := [
        _index_for(b_lo, a_lo, w, h),
        _index_for(b_hi, a_lo, w, h),
        _index_for(b_hi, a_hi, w, h),
        _index_for(b_lo, a_hi, w, h),
    ]
    var expected := [
        Vector2(0, 0),
        Vector2(size.x, 0),
        Vector2(size.x, size.y),
        Vector2(0, size.y),
    ]
    for i in vertices.size():
        var got := Minimap.index_to_pixel(vertices[i], map, insets, size)
        (
            TestHelper
            . assert_true(
                got.is_equal_approx(expected[i]),
                "play vertex %s maps to corner %s (got %s)" % [vertices[i], expected[i], got],
            )
        )


func test_overlay_stamp_cells_uses_footprint():
    var grid := Vector2i(100, 100)
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_stamp_cells(Vector2i(1, 1), Vector2i(50, 50), grid),
            PackedInt32Array([5050]),
            "a unit occupies one texel",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_stamp_cells(Vector2i(2, 2), Vector2i(50, 50), grid),
            PackedInt32Array([5050, 5051, 5150, 5151]),
            "a 2x2 building occupies four texels",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_stamp_cells(Vector2i(4, 3), Vector2i(10, 10), grid).size(),
            12,
            "a 4x3 building occupies twelve texels",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_stamp_cells(Vector2i(3, 3), Vector2i(99, 99), grid).size(),
            1,
            "footprint stamping clips at the texture edge",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.overlay_stamp_cells(Vector2i(3, 1), Vector2i(99, 0), grid),
            PackedInt32Array([99]),
            "a footprint crossing the right edge does not wrap to the next row",
        )
    )


func test_clip_segment_to_rect():
    var rect := Rect2(0.0, 0.0, 10.0, 10.0)

    var inside := Minimap.clip_segment_to_rect(Vector2(2, 4), Vector2(8, 4), rect)
    TestHelper.assert_eq(inside.size(), 2, "fully inside keeps the segment")
    TestHelper.assert_eq(inside[0], Vector2(2, 4), "inside start is unchanged")
    TestHelper.assert_eq(inside[1], Vector2(8, 4), "inside end is unchanged")

    var partial := Minimap.clip_segment_to_rect(Vector2(-5, 4), Vector2(5, 4), rect)
    TestHelper.assert_eq(partial.size(), 2, "partially outside yields a clipped segment")
    TestHelper.assert_eq(partial[0], Vector2(0, 4), "start clamps to the left edge")
    TestHelper.assert_eq(partial[1], Vector2(5, 4), "inside end is kept")

    var crossing := Minimap.clip_segment_to_rect(Vector2(-5, 5), Vector2(15, 5), rect)
    TestHelper.assert_eq(crossing[0], Vector2(0, 5), "crossing start clamps left")
    TestHelper.assert_eq(crossing[1], Vector2(10, 5), "crossing end clamps right")

    (
        TestHelper
        . assert_eq(
            Minimap.clip_segment_to_rect(Vector2(-10, 4), Vector2(-5, 4), rect).size(),
            0,
            "fully outside is empty",
        )
    )
    (
        TestHelper
        . assert_eq(
            Minimap.clip_segment_to_rect(Vector2(2, -5), Vector2(8, -5), rect).size(),
            0,
            "parallel outside is empty",
        )
    )
