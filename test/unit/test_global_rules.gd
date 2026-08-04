extends Node

# GlobalRules registry tests — armor types, warheads, clamps, multiplier lookup


func _make_rules() -> GlobalRules:
    var rules := GlobalRules.new()
    for aid in ["none", "wood", "light", "heavy", "concrete"]:
        var at := ArmorType.new()
        at.id = aid
        rules.armor_types[aid] = at
    for wid in ["SA", "AP", "Fire"]:
        var wh := WarheadData.new()
        wh.id = wid
        rules.warheads[wid] = wh
    return rules


func test_get_armor_type_known():
    var rules := _make_rules()
    var at := rules.get_armor_type("heavy")
    TestHelper.assert_true(at != null, "known armor type found")
    TestHelper.assert_eq(at.id, "heavy", "returns correct armor type")


func test_get_armor_type_unknown():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.get_armor_type("flak"), null, "unknown armor type returns null")


func test_get_armor_ids():
    var rules := _make_rules()
    var ids := rules.get_armor_ids()
    TestHelper.assert_eq(ids.size(), 5, "all five armor types enumerated")
    TestHelper.assert_true(ids.has("concrete"), "concrete in armor ids")


func test_get_warhead_known():
    var rules := _make_rules()
    var wh := rules.get_warhead("SA")
    TestHelper.assert_true(wh != null, "known warhead found")
    TestHelper.assert_eq(wh.id, "SA", "returns correct warhead")


func test_get_warhead_unknown():
    var rules := _make_rules()
    TestHelper.assert_eq(rules.get_warhead("NOPE"), null, "unknown warhead returns null")


func test_warhead_armor_multiplier_known():
    var rules := _make_rules()
    var sa := rules.get_warhead("SA")
    sa.armor_damage_multipliers = {
        "none": 1.0, "wood": 0.6, "light": 0.4, "heavy": 0.25, "concrete": 0.1
    }
    TestHelper.assert_eq(rules.get_warhead_armor_multiplier("SA", "heavy"), 0.25, "known pair")


func test_warhead_armor_multiplier_overkill():
    var rules := _make_rules()
    var fire := rules.get_warhead("Fire")
    fire.armor_damage_multipliers = {
        "none": 6.0, "wood": 1.48, "light": 0.59, "heavy": 0.06, "concrete": 0.02
    }
    TestHelper.assert_eq(rules.get_warhead_armor_multiplier("Fire", "none"), 6.0, "overkill > 1.0")


func test_warhead_armor_multiplier_zero():
    var rules := _make_rules()
    var ap := rules.get_warhead("AP")
    ap.armor_damage_multipliers = {
        "none": 0.0, "wood": 1.0, "light": 1.0, "heavy": 1.0, "concrete": 1.0
    }
    TestHelper.assert_eq(rules.get_warhead_armor_multiplier("AP", "none"), 0.0, "zero-damage pair")


func test_warhead_armor_multiplier_unknown_warhead():
    var rules := _make_rules()
    TestHelper.assert_eq(
        rules.get_warhead_armor_multiplier("NOPE", "none"), 1.0, "unknown warhead -> 1.0"
    )


func test_warhead_armor_multiplier_unknown_armor():
    var rules := _make_rules()
    var sa := rules.get_warhead("SA")
    sa.armor_damage_multipliers = {"none": 1.0, "heavy": 0.25}
    TestHelper.assert_eq(
        rules.get_warhead_armor_multiplier("SA", "flak"), 1.0, "unknown armor -> 1.0"
    )


func test_damage_clamp_defaults():
    var rules := GlobalRules.new()
    TestHelper.assert_eq(rules.min_damage, 1, "default min_damage = 1")
    TestHelper.assert_eq(rules.max_damage, 1000, "default max_damage = 1000")


func test_bib_cost_penalty_default():
    var rules := GlobalRules.new()
    (
        TestHelper
        . assert_eq(
            rules.bib_cost_penalty,
            6.0,
            "default bib_cost_penalty == 6.0 (got %f)" % rules.bib_cost_penalty,
        )
    )


func test_bib_cost_penalty_loaded_from_tres():
    if not ResourceLoader.exists("res://resources/global_rules.tres"):
        TestHelper.fail("global_rules.tres missing")
        return
    var rules := load("res://resources/global_rules.tres") as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads as GlobalRules")
    if rules:
        (
            TestHelper
            . assert_eq(
                rules.bib_cost_penalty,
                6.0,
                "tres bib_cost_penalty == 6.0 (got %f)" % rules.bib_cost_penalty,
            )
        )
