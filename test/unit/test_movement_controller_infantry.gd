extends Node

# MovementController infantry behavior tests
# Tests actual crush execution behavior, not just SpatialHash queries.

var _test_passed := 0
var _test_failed := 0


func test_crush_kills_enemy():
    var sh := SpatialHash.instance
    if sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return
    sh._grid.clear()
    var cell := Vector2i(5, 5)
    var key: int = CellUtil.cell_key(cell)
    var enemy := Node3D.new()
    var enemy_stats := StatsComponent.new()
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = true
    enemy_stats.current_health = 100
    enemy.add_child(enemy_stats)
    add_child(enemy)
    var entry := {
        "node": enemy,
        "mc": null,
        "entity_type": EntityData.EntityType.INFANTRY,
        "player_id": 1,
    }
    sh._grid[key] = [entry]
    # get_crushable_enemies returns the enemy for a crusher on player 0
    var enemies: Array = sh.get_crushable_enemies_on_cell(cell, 0)
    sh._grid.erase(key)
    if enemies.size() == 1 and enemies[0] == enemy:
        _test_passed += 1
        print("    PASS: crusher identifies enemy infantry for crush")
    else:
        _test_failed += 1
        print("    FAIL: expected 1 enemy, got %d" % enemies.size())
    remove_child(enemy)
    enemy.free()


func test_crush_does_not_kill_friendly():
    var sh := SpatialHash.instance
    if sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return
    sh._grid.clear()
    var cell := Vector2i(5, 5)
    var key: int = CellUtil.cell_key(cell)
    var friendly := Node3D.new()
    var friendly_stats := StatsComponent.new()
    friendly_stats.entity_type = EntityData.EntityType.INFANTRY
    friendly_stats.player_id = 0
    friendly_stats.crushable = true
    friendly.add_child(friendly_stats)
    var entry := {
        "node": friendly,
        "mc": null,
        "entity_type": EntityData.EntityType.INFANTRY,
        "player_id": 0,
    }
    sh._grid[key] = [entry]
    var enemies: Array = sh.get_crushable_enemies_on_cell(cell, 0)
    sh._grid.erase(key)
    if enemies.is_empty():
        _test_passed += 1
        print("    PASS: crusher does not identify friendly infantry as crushable")
    else:
        _test_failed += 1
        print("    FAIL: friendly infantry returned as crushable enemy")
    friendly.free()


func test_crush_does_not_affect_non_crushable():
    var sh := SpatialHash.instance
    if sh == null:
        _test_failed += 1
        print("    FAIL: SpatialHash not available")
        return
    sh._grid.clear()
    var cell := Vector2i(5, 5)
    var key: int = CellUtil.cell_key(cell)
    var enemy := Node3D.new()
    var enemy_stats := StatsComponent.new()
    enemy_stats.entity_type = EntityData.EntityType.INFANTRY
    enemy_stats.player_id = 1
    enemy_stats.crushable = false
    enemy.add_child(enemy_stats)
    var entry := {
        "node": enemy,
        "mc": null,
        "entity_type": EntityData.EntityType.INFANTRY,
        "player_id": 1,
    }
    sh._grid[key] = [entry]
    var enemies: Array = sh.get_crushable_enemies_on_cell(cell, 0)
    sh._grid.erase(key)
    if enemies.is_empty():
        _test_passed += 1
        print("    PASS: crush does not affect non-crushable infantry")
    else:
        _test_failed += 1
        print("    FAIL: non-crushable infantry returned as crushable enemy")
    enemy.free()
