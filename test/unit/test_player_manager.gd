extends Node

# PlayerManager unit tests — player registry, local player ID, team relationships

var _pm: Node = null


func _ready() -> void:
    _pm = get_node_or_null("/root/PlayerManager")


func _guard() -> bool:
    if _pm == null:
        TestHelper.fail("PlayerManager not injected")
        return false
    return true


func _cleanup() -> void:
    _pm._players.clear()
    _pm._local_player_id = 0
    _pm._init_defaults()


func test_get_local_player_id():
    if not _guard():
        return
    var id: int = _pm.get_local_player_id()
    (
        TestHelper
        . assert_true(
            id == 0,
            (
                "get_local_player_id returns default 0: get_local_player_id returned %d, expected 0"
                % id
            ),
        )
    )


func test_get_player_data_creates():
    if not _guard():
        return
    var data = _pm.get_player_data(99)
    (
        TestHelper
        . assert_true(
            data != null and data.player_id == 99,
            (
                "get_player_data lazy-creates with correct ID: "
                + "get_player_data did not create player 99"
            ),
        )
    )
    _cleanup()


func test_get_player_data_returns_same():
    if not _guard():
        return
    var a = _pm.get_player_data(42)
    var b = _pm.get_player_data(42)
    TestHelper.assert_true(
        a == b,
        "get_player_data returns same instance: get_player_data returned different instances"
    )
    _cleanup()


func test_is_enemy_different_teams():
    if not _guard():
        return
    var a = _pm.get_player_data(10)
    a.team_id = 1
    var b = _pm.get_player_data(11)
    b.team_id = 2
    (
        TestHelper
        . assert_true(
            _pm.is_enemy(10, 11),
            (
                "is_enemy returns true for different teams: "
                + "is_enemy returned false for different teams"
            ),
        )
    )
    _cleanup()


func test_is_enemy_same_team():
    if not _guard():
        return
    var a = _pm.get_player_data(20)
    a.team_id = 1
    var b = _pm.get_player_data(21)
    b.team_id = 1
    (
        TestHelper
        . assert_true(
            not _pm.is_enemy(20, 21),
            "is_enemy returns false for same team: is_enemy returned true for same team",
        )
    )
    _cleanup()


func test_get_all_players():
    if not _guard():
        return
    _pm.get_player_data(30)
    _pm.get_player_data(31)
    var all = _pm.get_all_players()
    (
        TestHelper
        . assert_true(
            all.size() == 4,
            (
                (
                    "get_all_players returns all 4 players (2 default + 2 created): "
                    + "get_all_players returned %d players, expected 4"
                )
                % all.size()
            ),
        )
    )
    _cleanup()


func test_get_players_by_team():
    if not _guard():
        return
    var a = _pm.get_player_data(40)
    a.team_id = 5
    var b = _pm.get_player_data(41)
    b.team_id = 5
    var c = _pm.get_player_data(42)
    c.team_id = 6
    var team5 = _pm.get_players_by_team(5)
    (
        TestHelper
        . assert_true(
            team5.size() == 2,
            (
                (
                    "get_players_by_team returns exactly 2 players for team 5: "
                    + "get_players_by_team returned %d players, expected 2"
                )
                % team5.size()
            ),
        )
    )
    _cleanup()
