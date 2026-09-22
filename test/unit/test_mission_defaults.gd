extends Node

# Mission/Campaign resource defaults and starting-credit precedence truth table.
# No singletons are mutated, so no snapshot/restore is needed.

const PLAYER_MANAGER_SCRIPT: GDScript = preload("res://scripts/core/PlayerManager.gd")


func test_mission_new_defaults() -> void:
    var mission := Mission.new()
    TestHelper.assert_eq(mission.starting_credits, -1, "starting_credits defaults to -1 (inherit)")
    TestHelper.assert_eq(mission.player_house, "", "player_house defaults to empty (inherit)")
    TestHelper.assert_eq(mission.home_cell, "", "home_cell defaults to empty (inherit)")
    TestHelper.assert_true(mission.show_briefing, "show_briefing defaults true")
    TestHelper.assert_eq(mission.next_mission_id, "", "next_mission_id defaults empty")
    TestHelper.assert_eq(mission.id, "", "id defaults empty")
    TestHelper.assert_eq(mission.map_path, "", "map_path defaults empty")


func test_mission_explicit_values_round_trip() -> void:
    var mission := Mission.new()
    mission.starting_credits = 50
    mission.player_house = "GDI"
    mission.home_cell = "49,63"
    mission.show_briefing = false
    mission.next_mission_id = "gdi02"
    TestHelper.assert_eq(mission.starting_credits, 50, "explicit starting_credits stored")
    TestHelper.assert_eq(mission.player_house, "GDI", "explicit player_house stored")
    TestHelper.assert_eq(mission.home_cell, "49,63", "explicit home_cell stored")
    TestHelper.assert_true(not mission.show_briefing, "explicit show_briefing stored")
    TestHelper.assert_eq(mission.next_mission_id, "gdi02", "explicit next_mission_id stored")


func test_campaign_first_mission() -> void:
    var campaign := Campaign.new()
    campaign.missions = PackedStringArray(["gdi01", "gdi02"])
    TestHelper.assert_eq(campaign.first_mission_id(), "gdi01", "first mission is the first entry")


func test_campaign_empty_has_no_first_mission() -> void:
    var campaign := Campaign.new()
    TestHelper.assert_eq(campaign.first_mission_id(), "", "empty campaign has no first mission")


func test_resolve_starting_credits_truth_table() -> void:
    var resolve: GDScript = PLAYER_MANAGER_SCRIPT
    TestHelper.assert_eq(
        resolve.resolve_starting_credits(50, 200, 10000),
        50,
        "mission value wins over map and global"
    )
    TestHelper.assert_eq(
        resolve.resolve_starting_credits(-1, 200, 10000), 200, "mission -1 falls to map override"
    )
    TestHelper.assert_eq(
        resolve.resolve_starting_credits(-1, -1, 10000), 10000, "mission and map -1 fall to global"
    )
    TestHelper.assert_eq(resolve.resolve_starting_credits(0, 200, 10000), 0, "mission 0 override")
    TestHelper.assert_eq(resolve.resolve_starting_credits(-1, 0, 10000), 0, "map 0 is an override")
    TestHelper.assert_eq(
        resolve.resolve_starting_credits(50, -1, 10000), 50, "mission wins when map inherits"
    )
    TestHelper.assert_eq(
        resolve.resolve_starting_credits(-5, -1, 10000),
        10000,
        "negative mission inherits to global"
    )
