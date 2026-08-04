extends Node

# FactoryComponent tests — produces field, is_primary toggle, is_busy state


func _make_factory(produces: Array[String] = ["infantry"], player_id: int = 0) -> FactoryComponent:
    var factory := FactoryComponent.new()
    factory.name = "FactoryComponent"
    factory.produces = produces
    factory.player_id = player_id
    return factory


# --- Basic tests ---


func test_produces_field():
    var factory := _make_factory(["vehicle"])
    TestHelper.assert_true(
        factory.produces == ["vehicle"], "produces field set correctly: produces field not set"
    )


func test_is_primary_default_false():
    var factory := _make_factory()
    TestHelper.assert_true(
        not factory.is_primary, "is_primary defaults to false: is_primary should default to false"
    )


func test_set_primary_sets_is_primary():
    var factory := _make_factory()
    factory.set_primary()
    (
        TestHelper
        . assert_true(
            factory.is_primary,
            "set_primary sets is_primary to true: set_primary did not set is_primary",
        )
    )


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

    (
        TestHelper
        . assert_true(
            factory_a.is_primary and not factory_b.is_primary,
            "set_primary clears siblings: set_primary did not clear siblings",
        )
    )

    parent.remove_child(factory_a)
    parent.remove_child(factory_b)
    remove_child(parent)


# --- is_busy tests ---


func test_is_busy_default_false():
    var factory := _make_factory()
    TestHelper.assert_true(
        not factory.is_busy, "is_busy defaults to false: is_busy should default to false"
    )


func test_exit_completed_clears_busy():
    var factory := _make_factory()
    factory.is_busy = true
    factory._on_exit_completed()
    (
        TestHelper
        . assert_true(
            not factory.is_busy,
            "_on_exit_completed clears is_busy: is_busy still true after exit_completed",
        )
    )
