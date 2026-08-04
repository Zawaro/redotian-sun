extends Node

# TransportComponent tests — cargo, cursor resolution, and order generation

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")


func _make_transport(capacity: int = 28) -> TransportComponent:
    var transport := TransportComponent.new()
    transport.name = "TransportComponent"
    transport.storage = capacity
    return transport


func _make_rules() -> GlobalRules:
    var rules := GlobalRules.new()
    rules.resource_types = {}
    var tib_green := ResourceType.new()
    tib_green.id = "tiberium_green"
    tib_green.value = 25.0
    rules.resource_types["tiberium_green"] = tib_green
    var tib_blue := ResourceType.new()
    tib_blue.id = "tiberium_blue"
    tib_blue.value = 40.0
    rules.resource_types["tiberium_blue"] = tib_blue
    return rules


func test_add_cargo():
    var transport := _make_transport(28)
    var actual := transport.add_cargo("tiberium_green", 10.5)
    (
        TestHelper
        . assert_true(
            actual == 10.5 and transport.cargo.get("tiberium_green") == 10.5,
            "add_cargo adds correctly: add_cargo mismatch",
        )
    )


func test_add_cargo_respects_capacity():
    var transport := _make_transport(10)
    var actual := transport.add_cargo("tiberium_green", 15.0)
    (
        TestHelper
        . assert_true(
            actual == 10.0 and transport.get_cargo_total() == 10.0,
            "add_cargo respects capacity: add_cargo did not respect capacity",
        )
    )


func test_remove_cargo():
    var transport := _make_transport(28)
    transport.add_cargo("tiberium_green", 10.0)
    var actual := transport.remove_cargo("tiberium_green", 3.5)
    (
        TestHelper
        . assert_true(
            actual == 3.5 and transport.cargo.get("tiberium_green") == 6.5,
            "remove_cargo removes correctly: remove_cargo mismatch",
        )
    )


func test_remove_cargo_erases_at_zero():
    var transport := _make_transport(28)
    transport.add_cargo("tiberium_green", 10.0)
    transport.remove_cargo("tiberium_green", 10.0)
    (
        TestHelper
        . assert_true(
            transport.cargo.is_empty(),
            "remove_cargo erases at zero: " + "remove_cargo did not erase at zero",
        )
    )


func test_get_cargo_total():
    var transport := _make_transport(28)
    transport.add_cargo("tiberium_green", 14.5)
    transport.add_cargo("tiberium_blue", 7.5)
    (
        TestHelper
        . assert_true(
            transport.get_cargo_total() == 22.0,
            (
                "get_cargo_total sums correctly: get_cargo_total returned %f"
                % transport.get_cargo_total()
            ),
        )
    )


func test_get_cargo_value():
    var transport := _make_transport(28)
    transport.add_cargo("tiberium_green", 14.0)
    transport.add_cargo("tiberium_blue", 7.0)
    var rules := _make_rules()
    var value := transport.get_cargo_value(rules)
    TestHelper.assert_true(
        value == 630, "get_cargo_value calculates correctly: get_cargo_value returned %d" % value
    )


# --- get_cursor_for_target tests ---


func test_cursor_loadable_unit_returns_enter():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    target.add_to_group("selectable")
    var target_sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    target.add_child(target_sc)
    var target_transport := TransportComponent.new()
    target_transport.name = "TransportComponent"
    target_transport.passengers = 2
    target.add_child(target_transport)

    var cursor := transport.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.ENTER, "loadable unit -> ENTER")

    entity.queue_free()
    target.queue_free()


func test_cursor_no_passengers_returns_default():
    var transport := _make_transport(28)
    transport.passengers = 0
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    var cursor := transport.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "no passengers -> DEFAULT")

    entity.queue_free()
    target.queue_free()


func test_cursor_null_target_returns_default():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var cursor := transport.get_cursor_for_target(null, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "null target -> DEFAULT")

    entity.queue_free()


func test_cursor_enemy_returns_default():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "EnemyUnit"
    target.add_to_group("enemy")
    var target_sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    target.add_child(target_sc)

    var cursor := transport.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "enemy -> DEFAULT")

    entity.queue_free()
    target.queue_free()


func test_cursor_target_without_transport_returns_default():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    target.add_to_group("selectable")
    var target_sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    target.add_child(target_sc)

    var cursor := transport.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(
        cursor, CursorState.Type.DEFAULT, "target without TransportComponent -> DEFAULT"
    )

    entity.queue_free()
    target.queue_free()


func test_cursor_target_zero_passengers_returns_default():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    target.add_to_group("selectable")
    var target_sc := SelectComponent.new()
    target.add_child(target_sc)
    var target_transport := TransportComponent.new()
    target_transport.name = "TransportComponent"
    target_transport.passengers = 0
    target.add_child(target_transport)

    var cursor := transport.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(cursor, CursorState.Type.DEFAULT, "target with 0 passengers -> DEFAULT")

    entity.queue_free()
    target.queue_free()


func test_cursor_no_select_component_returns_default():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"

    var cursor := transport.get_cursor_for_target(target, Vector2i.ZERO)
    TestHelper.assert_eq(
        cursor, CursorState.Type.DEFAULT, "target without SelectComponent -> DEFAULT"
    )

    entity.queue_free()
    target.queue_free()


# --- get_order_for_target tests ---


func test_order_loadable_unit_returns_enter():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    target.add_to_group("selectable")
    var target_sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    target.add_child(target_sc)
    var target_transport := TransportComponent.new()
    target_transport.name = "TransportComponent"
    target_transport.passengers = 2
    target.add_child(target_transport)

    var order := transport.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order != null, "loadable unit -> order not null")
    TestHelper.assert_eq(order.cursor, CursorState.Type.ENTER, "cursor -> ENTER")
    TestHelper.assert_eq(order.priority, 10, "priority -> 10")

    entity.queue_free()
    target.queue_free()


func test_order_null_target_returns_null():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var order := transport.get_order_for_target(null, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "null target -> null order")

    entity.queue_free()


func test_order_no_passengers_returns_null():
    var transport := _make_transport(28)
    transport.passengers = 0
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    var order := transport.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "no passengers -> null order")

    entity.queue_free()
    target.queue_free()


func test_order_enemy_returns_null():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "EnemyUnit"
    target.add_to_group("enemy")
    var order := transport.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "enemy -> null order")

    entity.queue_free()
    target.queue_free()


func test_order_target_without_transport_returns_null():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    target.add_to_group("selectable")
    var target_sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    target.add_child(target_sc)

    var order := transport.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, {})
    TestHelper.assert_true(order == null, "target without TransportComponent -> null order")

    entity.queue_free()
    target.queue_free()


func test_order_queued_modifier():
    var transport := _make_transport(28)
    transport.passengers = 1
    var entity := Node3D.new()
    entity.name = "TransportEntity"
    entity.add_child(transport)

    var target := Node3D.new()
    target.name = "TargetUnit"
    target.add_to_group("selectable")
    var target_sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    target.add_child(target_sc)
    var target_transport := TransportComponent.new()
    target_transport.name = "TransportComponent"
    target_transport.passengers = 2
    target.add_child(target_transport)

    var modifiers := {OrderResult.MOD_QUEUED: true}
    var order := transport.get_order_for_target(target, Vector2i.ZERO, Vector3.ZERO, modifiers)
    TestHelper.assert_true(order != null, "queued modifier -> order not null")
    TestHelper.assert_true(order.queued, "queued modifier -> order.queued = true")

    entity.queue_free()
    target.queue_free()
