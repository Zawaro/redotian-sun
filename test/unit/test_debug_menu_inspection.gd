extends Node

# DebugMenu inspection tests — live health updates on damage/heal (#182)

const DEBUG_MENU_SCENE: PackedScene = preload("res://scenes/ui/DebugMenu.tscn")


func _make_menu() -> DebugMenu:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    var menu := DEBUG_MENU_SCENE.instantiate() as DebugMenu
    tree.root.add_child(menu)
    return menu


func _make_entity(current_hp: int, max_hp: int) -> Node3D:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    var entity := Node3D.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    health.max_health = max_hp
    health.current_health = current_hp
    entity.add_child(health)
    tree.root.add_child(entity)
    return entity


func _health_of(entity: Node3D) -> HealthComponent:
    return entity.get_node("HealthComponent") as HealthComponent


func _teardown(menu: DebugMenu, entities: Array[Node3D] = []) -> void:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    menu.clear_inspection()
    menu.free()
    for entity in entities:
        entity.free()


func test_inspection_shows_entity_health() -> void:
    var menu := _make_menu()
    var entity := _make_entity(100, 100)

    menu._show_inspection(entity)

    TestHelper.assert_true(menu.inspect_content.visible, "inspection panel becomes visible")
    TestHelper.assert_true(
        menu.inspect_label.text.contains("[b]Health[/b] 100 / 100"),
        "panel shows the entity's health at inspection time"
    )

    _teardown(menu, [entity] as Array[Node3D])


func test_inspection_updates_on_damage() -> void:
    var menu := _make_menu()
    var entity := _make_entity(100, 100)
    menu._show_inspection(entity)

    _health_of(entity).take_damage(30)

    TestHelper.assert_true(
        menu.inspect_label.text.contains("[b]Health[/b] 70 / 100"),
        "panel shows 70 / 100 immediately after 30 damage"
    )

    _teardown(menu, [entity] as Array[Node3D])


func test_inspection_updates_on_heal() -> void:
    var menu := _make_menu()
    var entity := _make_entity(70, 100)
    menu._show_inspection(entity)

    _health_of(entity).heal(20)

    TestHelper.assert_true(
        menu.inspect_label.text.contains("[b]Health[/b] 90 / 100"),
        "panel shows 90 / 100 immediately after healing 20"
    )

    _teardown(menu, [entity] as Array[Node3D])


func test_inspection_health_clamps_at_bounds() -> void:
    var menu := _make_menu()
    var entity := _make_entity(100, 100)
    menu._show_inspection(entity)

    _health_of(entity).take_damage(500)
    TestHelper.assert_true(
        menu.inspect_label.text.contains("[b]Health[/b] 0 / 100"),
        "panel clamps at 0 / 100 on lethal damage"
    )

    _health_of(entity).heal(999)
    TestHelper.assert_true(
        menu.inspect_label.text.contains("[b]Health[/b] 100 / 100"),
        "panel clamps at 100 / 100 on over-heal"
    )

    _teardown(menu, [entity] as Array[Node3D])


func test_clear_inspection_stops_live_updates() -> void:
    var menu := _make_menu()
    var entity := _make_entity(100, 100)
    menu._show_inspection(entity)

    menu.clear_inspection()
    _health_of(entity).take_damage(30)

    TestHelper.assert_eq(menu.inspect_label.text, "", "cleared panel stays empty after damage")
    TestHelper.assert_true(not menu.inspect_content.visible, "cleared panel stays hidden")

    _teardown(menu, [entity] as Array[Node3D])


func test_reinspect_moves_live_updates_to_new_entity() -> void:
    var menu := _make_menu()
    var first := _make_entity(100, 100)
    var second := _make_entity(50, 50)
    menu._show_inspection(first)
    menu._show_inspection(second)

    _health_of(first).take_damage(10)
    TestHelper.assert_true(
        menu.inspect_label.text.contains("[b]Health[/b] 50 / 50"),
        "damage to the first entity does not leak into the second entity's panel"
    )

    _health_of(second).take_damage(10)
    TestHelper.assert_true(
        menu.inspect_label.text.contains("[b]Health[/b] 40 / 50"),
        "panel follows the re-inspected entity"
    )

    _teardown(menu, [first, second] as Array[Node3D])


func test_healthless_inspection_drops_previous_live_updates() -> void:
    var menu := _make_menu()
    var healthy := _make_entity(100, 100)
    var healthless := Node3D.new()
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    tree.root.add_child(healthless)
    menu._show_inspection(healthy)
    menu._show_inspection(healthless)

    TestHelper.assert_eq(
        menu.inspect_label.text, "No components found", "healthless entity inspects without error"
    )

    # Hide the panel after inspection: a leaked connection to the healthy entity
    # would re-run _show_inspection and make the panel visible again.
    menu.inspect_content.visible = false
    _health_of(healthy).take_damage(30)

    TestHelper.assert_true(
        not menu.inspect_content.visible,
        "damage to the previously inspected entity does not resurrect the panel"
    )

    _teardown(menu, [healthy, healthless] as Array[Node3D])


func test_health_change_handler_safe_without_inspection() -> void:
    var menu := _make_menu()
    var text_before: String = menu.inspect_label.text

    menu._on_inspected_health_changed(5, 10)

    TestHelper.assert_eq(
        menu.inspect_label.text, text_before, "health change without an inspected entity is a no-op"
    )

    _teardown(menu)
