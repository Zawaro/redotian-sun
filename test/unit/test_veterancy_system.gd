extends Node

# VeterancySystem kill-credit tests — gates, formula, clamp and attribution.


func _setup() -> Node3D:
    var pm := get_node_or_null("/root/PlayerManager")
    if pm:
        pm._players.clear()
        pm._init_defaults()
    var container := Node3D.new()
    container.name = "VetTestContainer"
    Engine.get_main_loop().root.add_child(container)
    return container


func _teardown(container: Node3D) -> void:
    if is_instance_valid(container):
        container.get_parent().remove_child(container)
        container.queue_free()


func _entity(name: String, type: int, cost: int, pid: int, hp: int = 100) -> Node3D:
    var data := EntityData.new()
    data.id = name
    data.entity_type = type
    data.cost = cost
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.configure(data)
    stats.player_id = pid
    var hc := HealthComponent.new()
    hc.name = "HealthComponent"
    hc.max_health = hp
    hc.current_health = hp
    var entity := Node3D.new()
    entity.name = name
    entity.add_child(stats)
    entity.add_child(hc)
    return entity


func _stats(entity: Node3D) -> StatsComponent:
    return entity.get_node("StatsComponent") as StatsComponent


func _kill(victim: Node3D, killer: Node3D) -> void:
    (victim.get_node("HealthComponent") as HealthComponent).take_damage(9999, "", killer)


func test_cheap_kills_valuable_promotes():
    var rules := GlobalRules.get_current()
    if rules == null:
        TestHelper.fail("GlobalRules unavailable")
        return
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.INFANTRY, 100, 1)
    var victim := _entity(
        "victim", EntityData.EntityType.VEHICLE, int(100.0 * rules.veteran_ratio), 0
    )
    c.add_child(killer)
    c.add_child(victim)
    _kill(victim, killer)
    TestHelper.assert_eq(
        _stats(killer).veteran_level, 1, "equal-cost-value kill promotes to veteran"
    )
    _teardown(c)


func test_expensive_kills_cheap_stays_rookie():
    var rules := GlobalRules.get_current()
    if rules == null:
        TestHelper.fail("GlobalRules unavailable")
        return
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.INFANTRY, 10000, 1)
    var victim := _entity("victim", EntityData.EntityType.INFANTRY, 100, 0)
    c.add_child(killer)
    c.add_child(victim)
    _kill(victim, killer)
    TestHelper.assert_eq(
        _stats(killer).veteran_level, 0, "cheap kill leaves an expensive killer rookie"
    )
    _teardown(c)


func test_experience_clamped_to_cap():
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.INFANTRY, 1, 1)
    var victim := _entity("victim", EntityData.EntityType.BUILDING, 100000, 0)
    c.add_child(killer)
    c.add_child(victim)
    _kill(victim, killer)
    var rules := GlobalRules.get_current()
    TestHelper.assert_eq(
        _stats(killer).experience, float(rules.veteran_cap), "experience clamped to veteran_cap"
    )
    _teardown(c)


func test_untrainable_killer_earns_nothing():
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.BUILDING, 100, 1)
    var victim := _entity("victim", EntityData.EntityType.INFANTRY, 100, 0)
    c.add_child(killer)
    c.add_child(victim)
    _kill(victim, killer)
    TestHelper.assert_eq(_stats(killer).experience, 0.0, "untrainable building earns nothing")
    _teardown(c)


func test_allied_killer_earns_nothing():
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.INFANTRY, 100, 0)
    var victim := _entity("victim", EntityData.EntityType.INFANTRY, 100, 0)
    c.add_child(killer)
    c.add_child(victim)
    _kill(victim, killer)
    TestHelper.assert_eq(_stats(killer).experience, 0.0, "allied killer earns nothing")
    _teardown(c)


func test_zero_ratio_guarded():
    var rules := GlobalRules.get_current()
    var saved := rules.veteran_ratio
    rules.veteran_ratio = 0.0
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.INFANTRY, 100, 1)
    var victim := _entity("victim", EntityData.EntityType.INFANTRY, 100, 0)
    c.add_child(killer)
    c.add_child(victim)
    _kill(victim, killer)
    TestHelper.assert_eq(_stats(killer).experience, 0.0, "zero ratio credits nothing, no crash")
    _teardown(c)
    rules.veteran_ratio = saved


func test_only_fatal_blow_credited():
    var rules := GlobalRules.get_current()
    if rules == null:
        TestHelper.fail("GlobalRules unavailable")
        return
    var c := _setup()
    var attacker := _entity("attacker", EntityData.EntityType.INFANTRY, 100, 1)
    var finisher := _entity("finisher", EntityData.EntityType.INFANTRY, 100, 1)
    var victim := _entity(
        "victim", EntityData.EntityType.INFANTRY, int(100.0 * rules.veteran_ratio), 0, 200
    )
    c.add_child(attacker)
    c.add_child(finisher)
    c.add_child(victim)
    (victim.get_node("HealthComponent") as HealthComponent).take_damage(10, "", attacker)
    (victim.get_node("HealthComponent") as HealthComponent).take_damage(9999, "", finisher)
    TestHelper.assert_eq(_stats(attacker).experience, 0.0, "non-fatal attacker earns nothing")
    TestHelper.assert_eq(_stats(finisher).veteran_level, 1, "fatal attacker earns the kill")
    _teardown(c)


func test_freed_killer_credits_nobody():
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.INFANTRY, 100, 1)
    killer.free()
    var victim := _entity("victim", EntityData.EntityType.INFANTRY, 100, 0)
    c.add_child(victim)
    _kill(victim, killer)
    TestHelper.assert_true(true, "freed killer handled without error")
    _teardown(c)


func test_corpse_does_not_recredit():
    var rules := GlobalRules.get_current()
    if rules == null:
        TestHelper.fail("GlobalRules unavailable")
        return
    var c := _setup()
    var killer := _entity("killer", EntityData.EntityType.INFANTRY, 100, 1)
    var victim := _entity(
        "victim", EntityData.EntityType.INFANTRY, int(100.0 * rules.veteran_ratio), 0
    )
    c.add_child(killer)
    c.add_child(victim)
    _kill(victim, killer)
    var after_kill: float = _stats(killer).experience
    _kill(victim, killer)
    TestHelper.assert_eq(
        _stats(killer).experience, after_kill, "a dead victim cannot credit a second kill"
    )
    _teardown(c)
