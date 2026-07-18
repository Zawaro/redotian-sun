extends Node

# PlayerManager unit tests — player registry, local player ID, team relationships

var _pm: Node = null
var _test_passed := 0
var _test_failed := 0


func _ready() -> void:
    _pm = get_node_or_null("/root/PlayerManager")


func _guard() -> bool:
    if _pm == null:
        print("    FAIL: PlayerManager not injected")
        _test_failed += 1
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
    if id >= 0:
        print("    PASS: get_local_player_id returns valid ID")
        _test_passed += 1
    else:
        print("    FAIL: get_local_player_id returned %d" % id)
        _test_failed += 1


func test_get_player_data_creates():
    if not _guard():
        return
    var data = _pm.get_player_data(99)
    if data != null and data.player_id == 99:
        print("    PASS: get_player_data lazy-creates with correct ID")
        _test_passed += 1
    else:
        print("    FAIL: get_player_data did not create player 99")
        _test_failed += 1
    _cleanup()


func test_get_player_data_returns_same():
    if not _guard():
        return
    var a = _pm.get_player_data(42)
    var b = _pm.get_player_data(42)
    if a == b:
        print("    PASS: get_player_data returns same instance")
        _test_passed += 1
    else:
        print("    FAIL: get_player_data returned different instances")
        _test_failed += 1
    _cleanup()


func test_is_enemy_different_teams():
    if not _guard():
        return
    var a = _pm.get_player_data(10)
    a.team_id = 1
    var b = _pm.get_player_data(11)
    b.team_id = 2
    if _pm.is_enemy(10, 11):
        print("    PASS: is_enemy returns true for different teams")
        _test_passed += 1
    else:
        print("    FAIL: is_enemy returned false for different teams")
        _test_failed += 1
    _cleanup()


func test_is_enemy_same_team():
    if not _guard():
        return
    var a = _pm.get_player_data(20)
    a.team_id = 1
    var b = _pm.get_player_data(21)
    b.team_id = 1
    if not _pm.is_enemy(20, 21):
        print("    PASS: is_enemy returns false for same team")
        _test_passed += 1
    else:
        print("    FAIL: is_enemy returned true for same team")
        _test_failed += 1
    _cleanup()


func test_get_all_players():
    if not _guard():
        return
    _pm.get_player_data(30)
    _pm.get_player_data(31)
    var all = _pm.get_all_players()
    if all.size() >= 2:
        print("    PASS: get_all_players returns multiple players")
        _test_passed += 1
    else:
        print("    FAIL: get_all_players returned %d players" % all.size())
        _test_failed += 1
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
    if team5.size() >= 2:
        print("    PASS: get_players_by_team returns correct players")
        _test_passed += 1
    else:
        print("    FAIL: get_players_by_team returned %d players" % team5.size())
        _test_failed += 1
    _cleanup()
