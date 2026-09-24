extends Node

# CombatComponent veteran ROF — the reload cooldown shortens with rank.


func _make() -> Array:
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.cost = 100
    entity.add_child(stats)
    var combat := CombatComponent.new()
    combat.name = "CombatComponent"
    entity.add_child(combat)
    var weapon := WeaponData.new()
    weapon.rate_of_fire = 30.0
    return [entity, stats, combat, weapon]


func test_rookie_uses_base_cooldown():
    var t := _make()
    var combat: CombatComponent = t[2]
    var weapon: WeaponData = t[3]
    var rules := GlobalRules.get_current()
    var base: float = 30.0 / rules.logic_fps
    TestHelper.assert_true(
        absf(combat._rof_seconds(weapon) - base) < 0.0001, "rookie uses the base cooldown"
    )
    t[0].free()


func test_veteran_shortens_cooldown():
    var t := _make()
    var stats: StatsComponent = t[1]
    var combat: CombatComponent = t[2]
    var weapon: WeaponData = t[3]
    stats.veteran_level = 1
    var rules := GlobalRules.get_current()
    var expected: float = (30.0 / rules.logic_fps) / rules.get_veteran_rof_multiplier(1)
    TestHelper.assert_true(
        absf(combat._rof_seconds(weapon) - expected) < 0.0001,
        "veteran cooldown is divided by the ROF bonus"
    )
    t[0].free()


func test_bonus_applies_after_promotion():
    var t := _make()
    var stats: StatsComponent = t[1]
    var combat: CombatComponent = t[2]
    var weapon: WeaponData = t[3]
    var rookie: float = combat._rof_seconds(weapon)
    stats.veteran_level = 2
    var elite: float = combat._rof_seconds(weapon)
    TestHelper.assert_true(elite < rookie, "cooldown shortens after promotion")
    t[0].free()
