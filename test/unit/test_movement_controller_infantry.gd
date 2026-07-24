extends Node

# MovementController infantry behavior tests

var _test_passed := 0
var _test_failed := 0


func test_crush_kills_enemy():
    var hc := HealthComponent.new()
    hc.max_health = 100
    hc.current_health = 100
    hc.kill()
    if hc.current_health == 0:
        _test_passed += 1
        print("    PASS: kill() sets health to 0")
    else:
        _test_failed += 1
        print("    FAIL: kill() did not set health to 0, got %d" % hc.current_health)
    hc.free()


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
        "node": friendly, "mc": null,
        "entity_type": EntityData.EntityType.INFANTRY,
        "player_id": 0,
    }
    sh._grid[key] = [entry]
    var enemies: Array = sh.get_crushable_enemies_on_cell(cell, 0)
    sh._grid.erase(key)
    if enemies.is_empty():
        _test_passed += 1
        print("    PASS: crusher does not kill friendly infantry")
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
        "node": enemy, "mc": null,
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
