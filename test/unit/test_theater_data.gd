extends Node

# Light TheaterData: a tag with id/display_name only.
# No terrain_objects, no art_data, no land-type field, no get_terrain_object —
# the catalog is global and the game-wide default land type lives in
# TerrainSystem.DEFAULT_LAND_TYPE.


func test_temperate_is_light_tag():
    var theater := load("res://resources/theaters/temperate.tres") as TheaterData
    TestHelper.assert_true(theater != null, "temperate.tres loads")
    if theater == null:
        _finish()
        return
    TestHelper.assert_eq(theater.id, "temperate", "theater id")
    TestHelper.assert_eq(theater.display_name, "Temperate", "theater display name")
    TestHelper.assert_true(
        not theater.get_property_list().any(
            func(prop: Dictionary) -> bool: return String(prop.name) == "default_land_type"
        ),
        "no default_land_type property",
    )
    TestHelper.assert_true(not theater.has_method("get_terrain_object"), "no get_terrain_object")
    TestHelper.assert_true(
        not theater.get_property_list().any(
            func(prop: Dictionary) -> bool: return String(prop.name) == "terrain_objects"
        ),
        "no terrain_objects property",
    )
    TestHelper.assert_true(
        not theater.get_property_list().any(
            func(prop: Dictionary) -> bool: return String(prop.name) == "art_data"
        ),
        "no art_data property",
    )


func _finish() -> void:
    pass
