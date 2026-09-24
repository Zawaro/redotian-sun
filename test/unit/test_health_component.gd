extends Node

# HealthComponent kill attribution — attacker recording and killed signal.


func _make_health(health: int = 100) -> HealthComponent:
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = health
    hc.current_health = health
    return hc


func test_fatal_hit_records_source_and_emits_killed():
    var hc := _make_health()
    var killer := Node3D.new()
    var seen: Array[Node3D] = []
    hc.killed.connect(func(k: Node3D) -> void: seen.append(k))
    hc.take_damage(200, "", killer)
    TestHelper.assert_eq(hc.last_attacker, killer, "last_attacker recorded")
    TestHelper.assert_eq(seen, [killer], "killed emitted with the source")
    killer.free()
    hc.free()


func test_non_lethal_damage_emits_no_kill():
    var hc := _make_health()
    var killer := Node3D.new()
    var seen: Array = []
    hc.killed.connect(func(_k: Node3D) -> void: seen.append(_k))
    hc.take_damage(10, "", killer)
    TestHelper.assert_true(seen.is_empty(), "killed not emitted while alive")
    TestHelper.assert_eq(hc.last_attacker, killer, "attacker still recorded")
    killer.free()
    hc.free()


func test_killerless_death_still_fires_health_zero():
    var hc := _make_health()
    var zero_seen: Array = []
    var killed_seen: Array = []
    hc.health_zero.connect(func() -> void: zero_seen.append(true))
    hc.killed.connect(func(k: Node3D) -> void: killed_seen.append(k))
    hc.take_damage(200)
    TestHelper.assert_true(not zero_seen.is_empty(), "health_zero fires without a source")
    TestHelper.assert_eq(killed_seen, [null], "killed emits null when killerless")
    hc.free()


func test_existing_health_zero_listener_unaffected():
    var hc := _make_health()
    var zero_seen: Array = []
    hc.health_zero.connect(func() -> void: zero_seen.append(true))
    hc.take_damage(200, "", Node3D.new())
    TestHelper.assert_true(not zero_seen.is_empty(), "health_zero listener runs on credited death")
    hc.free()


func test_kill_records_source():
    var hc := _make_health()
    var crusher := Node3D.new()
    var seen: Array[Node3D] = []
    hc.killed.connect(func(k: Node3D) -> void: seen.append(k))
    hc.kill(crusher)
    TestHelper.assert_eq(hc.current_health, 0, "kill zeroes health")
    TestHelper.assert_eq(seen, [crusher], "kill credits the given source")
    crusher.free()
    hc.free()


func test_corpse_ignores_further_damage():
    var hc := _make_health()
    var first := Node3D.new()
    var second := Node3D.new()
    var killed_seen: Array = []
    var zero_seen: Array = []
    hc.killed.connect(func(k: Node3D) -> void: killed_seen.append(k))
    hc.health_zero.connect(func() -> void: zero_seen.append(true))
    hc.take_damage(200, "", first)
    hc.take_damage(50, "", second)
    TestHelper.assert_eq(killed_seen, [first], "killed emits exactly once per death")
    TestHelper.assert_eq(zero_seen.size(), 1, "health_zero emits exactly once per death")
    TestHelper.assert_eq(hc.last_attacker, first, "later hit cannot overwrite the killer")
    first.free()
    second.free()
    hc.free()


func test_kill_on_corpse_is_noop():
    var hc := _make_health()
    var killed_seen: Array = []
    hc.killed.connect(func(k: Node3D) -> void: killed_seen.append(k))
    hc.kill()
    hc.kill()
    TestHelper.assert_eq(killed_seen.size(), 1, "repeated kill is idempotent")
    hc.free()
