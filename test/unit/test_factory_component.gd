extends Node

# FactoryComponent tests — produces field, is_primary toggle, is_busy state

var _test_passed := 0
var _test_failed := 0


func _make_factory(produces: Array[String] = ["infantry"], player_id: int = 0) -> FactoryComponent:
    var factory := FactoryComponent.new()
    factory.name = "FactoryComponent"
    factory.produces = produces
    factory.player_id = player_id
    return factory


# --- Basic tests ---


func test_produces_field():
    var factory := _make_factory(["vehicle"])
    if factory.produces == ["vehicle"]:
        _test_passed += 1
        print("    PASS: produces field set correctly")
    else:
        _test_failed += 1
        print("    FAIL: produces field not set")


func test_is_primary_default_false():
    var factory := _make_factory()
    if not factory.is_primary:
        _test_passed += 1
        print("    PASS: is_primary defaults to false")
    else:
        _test_failed += 1
        print("    FAIL: is_primary should default to false")


func test_set_primary_sets_is_primary():
    var factory := _make_factory()
    factory.set_primary()
    if factory.is_primary:
        _test_passed += 1
        print("    PASS: set_primary sets is_primary to true")
    else:
        _test_failed += 1
        print("    FAIL: set_primary did not set is_primary")


func test_set_primary_clears_siblings():
    var parent := Node.new()
    parent.name = "TestBuilding"
    add_child(parent)

    var factory_a := _make_factory(["infantry"], 0)
    var factory_b := _make_factory(["infantry"], 0)
    parent.add_child(factory_a)
    parent.add_child(factory_b)

    factory_a.is_primary = false
    factory_b.is_primary = false

    factory_a.set_primary()

    if factory_a.is_primary and not factory_b.is_primary:
        _test_passed += 1
        print("    PASS: set_primary clears siblings")
    else:
        _test_failed += 1
        print("    FAIL: set_primary did not clear siblings")

    parent.remove_child(factory_a)
    parent.remove_child(factory_b)
    remove_child(parent)


# --- is_busy tests ---


func test_is_busy_default_false():
    var factory := _make_factory()
    if not factory.is_busy:
        _test_passed += 1
        print("    PASS: is_busy defaults to false")
    else:
        _test_failed += 1
        print("    FAIL: is_busy should default to false")


func test_exit_completed_clears_busy():
    var factory := _make_factory()
    factory.is_busy = true
    factory._on_exit_completed()
    if not factory.is_busy:
        _test_passed += 1
        print("    PASS: _on_exit_completed clears is_busy")
    else:
        _test_failed += 1
        print("    FAIL: is_busy still true after exit_completed")


# --- Run all tests ---


func run_tests():
    print("  FactoryComponent tests:")
    test_produces_field()
    test_is_primary_default_false()
    test_set_primary_sets_is_primary()
    test_set_primary_clears_siblings()
    test_is_busy_default_false()
    test_exit_completed_clears_busy()
    print("  Results: %d passed, %d failed" % [_test_passed, _test_failed])
