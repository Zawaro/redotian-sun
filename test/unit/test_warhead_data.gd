extends Node

# WarheadData keyed-multiplier tests — armor_damage_multipliers dictionary

var _test_passed := 0
var _test_failed := 0


func _make_warhead(multipliers: Dictionary) -> WarheadData:
    var wh := WarheadData.new()
    wh.id = "TEST_WH"
    wh.armor_damage_multipliers = multipliers
    return wh


func test_get_armor_multiplier_known():
    var wh := _make_warhead({"none": 1.0, "heavy": 0.25})
    TestHelper.assert_eq(
        wh.get_armor_multiplier("heavy"), 0.25, "returns multiplier for known armor"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_armor_multiplier_unknown_defaults_full():
    var wh := _make_warhead({"none": 1.0})
    TestHelper.assert_eq(
        wh.get_armor_multiplier("unknown_armor"), 1.0, "unknown armor defaults to full damage"
    )
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_armor_multiplier_overkill():
    var wh := _make_warhead({"none": 6.0, "wood": 1.48})
    TestHelper.assert_eq(
        wh.get_armor_multiplier("none"), 6.0, "overkill multiplier above 1.0 allowed"
    )
    TestHelper.assert_eq(wh.get_armor_multiplier("wood"), 1.48, "partial overkill multiplier")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_get_armor_multiplier_zero():
    var wh := _make_warhead({"none": 0.0, "wood": 1.0})
    TestHelper.assert_eq(wh.get_armor_multiplier("none"), 0.0, "zero multiplier allowed")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_validate_empty_multipliers():
    var wh := WarheadData.new()
    wh.id = "EMPTY"
    wh.armor_damage_multipliers = {}
    var errors := wh.validate()
    TestHelper.assert_true(errors.size() > 0, "validate reports error for empty multipliers")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_validate_empty_id():
    var wh := WarheadData.new()
    wh.armor_damage_multipliers = {"none": 1.0}
    var errors := wh.validate()
    TestHelper.assert_true(errors.size() > 0, "validate reports error for empty id")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_validate_keyed_multipliers_clean():
    var wh := _make_warhead({"none": 1.0, "heavy": 0.25})
    var errors := wh.validate_against_armor(["none", "heavy"])
    TestHelper.assert_eq(errors.size(), 0, "all keys present -> no errors")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_validate_against_armor_missing_entry():
    var wh := _make_warhead({"none": 1.0, "heavy": 0.25})
    var errors := wh.validate_against_armor(["none", "heavy", "concrete"])
    TestHelper.assert_true(errors.size() > 0, "missing armor entry reported")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()


func test_validate_against_armor_unknown_key():
    var wh := _make_warhead({"none": 1.0, "bogus": 0.5})
    var errors := wh.validate_against_armor(["none"])
    TestHelper.assert_true(errors.size() > 0, "unknown armor key reported")
    _test_passed += TestHelper._passed
    _test_failed += TestHelper._failed
    TestHelper.reset()
