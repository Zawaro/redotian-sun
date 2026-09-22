extends Node

# CampaignCatalog unit tests — fixture registration, earlier-vs-later root
# layering, missing-dir survival, idempotent registration, game-switch reset,
# unload, ordering, and null/empty lookups. GameContext is snapshotted and
# restored around every mutating test.

const CAMPAIGN_FIXTURE: String = "res://test/fixtures/campaigns/campaigns/"
const MISSION_FIXTURE: String = "res://test/fixtures/campaigns/missions/"
const CAMPAIGN_OVERRIDE: String = "res://test/fixtures/campaigns_override/campaigns/"
const MISSION_OVERRIDE: String = "res://test/fixtures/campaigns_override/missions/"
const MISSING_FIXTURE: String = "res://test/fixtures/does_not_exist/"

var _gc: Node = null
var _cc: Node = null


func _guard() -> bool:
    if _gc == null or _cc == null:
        TestHelper.fail("GameContext/CampaignCatalog not injected")
        return false
    return true


func _ids(campaigns: Array) -> Array[String]:
    var out: Array[String] = []
    for campaign in campaigns:
        out.append((campaign as Campaign).id)
    return out


func _register_fixture() -> void:
    _cc.reset_content()
    _cc.register_data_set(CAMPAIGN_FIXTURE, MISSION_FIXTURE)


func test_real_game_content_resolves() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    TestHelper.assert_true(_cc.get_campaign("gdi") != null, "ts campaign gdi resolves")
    TestHelper.assert_true(_cc.get_mission("gdi01") != null, "ts mission gdi01 resolves")
    var gdi: Campaign = _cc.get_campaign("gdi")
    if gdi:
        TestHelper.assert_eq(gdi.first_mission_id(), "gdi01", "gdi starts with gdi01")
    TestHelper.restore_game_context(_gc, snap)


func test_register_fixture_campaigns_and_missions() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_fixture()
    TestHelper.assert_true(_cc.get_campaign("alpha") != null, "fixture campaign loads")
    (
        TestHelper
        . assert_eq(
            (_cc.get_campaign("alpha") as Campaign).display_name,
            "Alpha Campaign",
            "fixture campaign fields load",
        )
    )
    TestHelper.assert_true(_cc.get_mission("alpha01") != null, "fixture mission loads")
    TestHelper.assert_true(
        _cc.get_campaign("beta") != null, "nested subdirectory campaign is discovered"
    )
    TestHelper.assert_true(
        _cc.get_mission("beta01") != null, "nested subdirectory mission is discovered"
    )
    TestHelper.restore_game_context(_gc, snap)


func test_later_root_overrides_id() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_fixture()
    _cc.register_data_set(CAMPAIGN_OVERRIDE, MISSION_OVERRIDE)
    var campaign: Campaign = _cc.get_campaign("alpha")
    var mission: Mission = _cc.get_mission("alpha01")
    TestHelper.assert_true(campaign != null, "overridden campaign id still resolves")
    if campaign:
        TestHelper.assert_eq(
            campaign.display_name, "Alpha Campaign Override", "later root wins the campaign id"
        )
    TestHelper.assert_true(mission != null, "overridden mission id still resolves")
    if mission:
        TestHelper.assert_eq(
            mission.display_name, "Alpha Mission Override", "later root wins the mission id"
        )
    TestHelper.restore_game_context(_gc, snap)


func test_register_is_idempotent_per_path() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_fixture()
    var size: int = _cc._data_sets.size()
    _cc.register_data_set(CAMPAIGN_FIXTURE, MISSION_FIXTURE)
    TestHelper.assert_eq(_cc._data_sets.size(), size, "same campaigns path not registered twice")
    TestHelper.restore_game_context(_gc, snap)


func test_missing_directory_warns_without_crash() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _cc.reset_content()
    _cc.register_data_set(MISSING_FIXTURE, MISSING_FIXTURE)
    TestHelper.assert_true(
        _cc._data_sets.has(MISSING_FIXTURE), "missing dir still registers, no crash"
    )
    TestHelper.assert_eq(_cc.list_campaigns().size(), 0, "no campaigns from a missing dir")
    TestHelper.assert_true(_cc.get_mission("gdi01") == null, "no missions from a missing dir")
    TestHelper.restore_game_context(_gc, snap)


func test_game_switch_reloads_campaigns() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_fixture()
    TestHelper.assert_true(_cc.get_campaign("alpha") != null, "fixture loaded before switch")
    _gc.select_game("ts")
    TestHelper.assert_true(_cc.get_campaign("alpha") == null, "old game's campaigns dropped")
    TestHelper.assert_true(_cc.get_mission("alpha01") == null, "old game's missions dropped")
    TestHelper.assert_true(_cc.get_campaign("gdi") != null, "new game's campaigns loaded")
    TestHelper.assert_true(_cc.get_mission("gdi01") != null, "new game's missions loaded")
    TestHelper.restore_game_context(_gc, snap)


func test_unload_empties_registry() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _gc.select_game("ts")
    TestHelper.assert_true(_cc.get_campaign("gdi") != null, "mission content present before unload")
    _gc.select_game("")
    TestHelper.assert_eq(_cc.list_campaigns().size(), 0, "unload clears the campaign registry")
    TestHelper.assert_true(_cc.get_mission("gdi01") == null, "unload clears the mission registry")
    TestHelper.restore_game_context(_gc, snap)


func test_list_campaigns_ordered() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_fixture()
    TestHelper.assert_eq(
        _ids(_cc.list_campaigns()), ["alpha", "beta", "zulu"], "campaigns listed by ascending id"
    )
    TestHelper.restore_game_context(_gc, snap)


func test_unknown_id_returns_null() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _register_fixture()
    TestHelper.assert_true(_cc.get_campaign("nope") == null, "unknown campaign id returns null")
    TestHelper.assert_true(_cc.get_mission("nope") == null, "unknown mission id returns null")
    TestHelper.restore_game_context(_gc, snap)


func test_empty_catalog_lists_nothing() -> void:
    if not _guard():
        return
    var snap := TestHelper.snapshot_game_context(_gc)
    _cc.reset_content()
    var campaigns: Array[Campaign] = _cc.list_campaigns()
    TestHelper.assert_eq(campaigns.size(), 0, "empty catalog has no campaigns")
    TestHelper.assert_true(_cc.get_campaign("gdi") == null, "empty catalog has no lookups")
    TestHelper.restore_game_context(_gc, snap)
