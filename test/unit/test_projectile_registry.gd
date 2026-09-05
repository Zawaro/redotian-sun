extends Node

# Projectile registry + speed precedence tests

const WEAPONS_DIR := "res://games/ts/weapons/"


func _make_rules() -> GlobalRules:
    var rules := GlobalRules.new()
    var inv := ProjectileData.new()
    inv.id = "Invisible"
    rules.projectiles["Invisible"] = inv
    var rocket := ProjectileData.new()
    rocket.id = "HeatSeeker"
    rules.projectiles["HeatSeeker"] = rocket
    return rules


func test_get_projectile_known():
    var rules := _make_rules()
    var proj: ProjectileData = rules.get_projectile("Invisible")
    TestHelper.assert_true(proj != null, "known projectile found")
    TestHelper.assert_eq(proj.id, "Invisible", "returns correct projectile")


func test_get_projectile_unknown():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.get_projectile("NOPE"), null, "unknown projectile returns null")


func test_get_projectile_wrong_type_returns_null():
    var rules := _make_rules()
    rules.projectiles["Bad"] = WeaponData.new()
    TestHelper.assert_eq(rules.get_projectile("Bad"), null, "non-ProjectileData entry returns null")


func test_default_projectile_speed_positive():
    var rules := GlobalRules.new()
    TestHelper.assert_true(rules.default_projectile_speed > 0.0, "default speed is positive")


func test_every_weapon_projectile_id_resolves():
    var rules := load("res://games/ts/global_rules.tres") as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if not rules:
        return
    var checked := 0
    var dir := DirAccess.open(WEAPONS_DIR)
    TestHelper.assert_true(dir != null, "weapons directory opens")
    if not dir:
        return
    dir.list_dir_begin()
    var fname := dir.get_next()
    while fname != "":
        if fname.ends_with(".tres"):
            var weapon := load(WEAPONS_DIR + fname) as WeaponData
            if weapon and not weapon.projectile.is_empty():
                checked += 1
                var proj: ProjectileData = rules.get_projectile(weapon.projectile)
                TestHelper.assert_true(
                    proj != null, "%s -> projectile '%s' resolves" % [weapon.id, weapon.projectile]
                )
        fname = dir.get_next()
    TestHelper.assert_true(checked > 0, "at least one weapon projectile reference checked")
