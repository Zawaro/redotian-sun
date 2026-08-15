extends Node

# SelectComponent unit tests — refinery storage bar (3D mesh path)

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")


func _make_refinery_entity(player_id: int) -> Node3D:
    var entity := Node3D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.id = "GDI_REFINERY"
    stats.player_id = player_id
    entity.add_child(stats)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    sc.select_box_type = SelectComponent.SelectBoxType.Structure
    entity.add_child(sc)
    return entity


func _make_non_refinery_entity() -> Node3D:
    var entity := Node3D.new()
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    sc.select_box_type = SelectComponent.SelectBoxType.Structure
    entity.add_child(sc)
    return entity


func test_refinery_builds_storage_bar():
    var pid := 1300
    EconomyManager.add(pid, 500, "test")
    var entity := _make_refinery_entity(pid)
    (Engine.get_main_loop() as SceneTree).root.add_child(entity)
    var sc := entity.get_node("SelectComponent") as SelectComponent
    (
        TestHelper
        . assert_true(
            is_instance_valid(sc._storage_bar),
            "refinery SelectComponent builds a storage bar",
        )
    )
    (
        TestHelper
        . assert_true(
            sc._storage_bar.name == "StorageBar",
            "storage bar node is named StorageBar",
        )
    )
    (
        TestHelper
        . assert_true(
            absf(sc._storage_bar.scale.x - 0.5) < 0.001,
            "storage bar fill is balance/capacity: expected 0.5, got %f" % sc._storage_bar.scale.x,
        )
    )
    var expected_z: float = 1.0 - SelectComponent.HEALTH_BAR_CUBE_SIZE / 2.0
    (
        TestHelper
        . assert_true(
            absf(sc._storage_bar.position.z - expected_z) < 0.001,
            (
                "storage bar sits on the south z edge: expected z %f, got %f"
                % [expected_z, sc._storage_bar.position.z]
            ),
        )
    )
    (
        TestHelper
        . assert_true(
            not sc._storage_bar.visible,
            "storage bar hidden until selected",
        )
    )
    entity.free()


func test_storage_bar_updates_on_credits_changed():
    var pid := 1301
    EconomyManager.add(pid, 500, "test")
    var entity := _make_refinery_entity(pid)
    (Engine.get_main_loop() as SceneTree).root.add_child(entity)
    var sc := entity.get_node("SelectComponent") as SelectComponent
    EconomyManager.add(pid, 500, "harvest")
    (
        TestHelper
        . assert_true(
            absf(sc._storage_bar.scale.x - 1.0) < 0.001,
            (
                "storage bar fill updates after harvest: expected 1.0, got %f"
                % sc._storage_bar.scale.x
            ),
        )
    )
    entity.free()


func test_free_credits_do_not_fill_storage_bar():
    var pid := 1303
    EconomyManager.add(pid, 1000, "crate", "tiberium", true)
    var entity := _make_refinery_entity(pid)
    (Engine.get_main_loop() as SceneTree).root.add_child(entity)
    var sc := entity.get_node("SelectComponent") as SelectComponent
    (
        TestHelper
        . assert_true(
            sc._storage_bar.scale.x < 0.01,
            (
                "free credits do not fill the storage bar: expected near 0, got %f"
                % sc._storage_bar.scale.x
            ),
        )
    )
    EconomyManager.add(pid, 500, "harvest")
    (
        TestHelper
        . assert_true(
            absf(sc._storage_bar.scale.x - 0.5) < 0.001,
            (
                "harvest income fills the bar alongside free credits: expected 0.5, got %f"
                % sc._storage_bar.scale.x
            ),
        )
    )
    entity.free()


func test_storage_bar_visible_on_select_and_hover():
    var pid := 1302
    EconomyManager.add(pid, 500, "test")
    var entity := _make_refinery_entity(pid)
    (Engine.get_main_loop() as SceneTree).root.add_child(entity)
    var sc := entity.get_node("SelectComponent") as SelectComponent
    sc.set_is_selected(true)
    (
        TestHelper
        . assert_true(
            sc._storage_bar.visible,
            "storage bar visible when selected",
        )
    )
    sc.set_is_selected(false)
    sc.set_is_hovering(true)
    (
        TestHelper
        . assert_true(
            sc._storage_bar.visible,
            "storage bar visible when hovered",
        )
    )
    sc.set_is_hovering(false)
    (
        TestHelper
        . assert_true(
            not sc._storage_bar.visible,
            "storage bar hidden when neither selected nor hovered",
        )
    )
    entity.free()


func test_non_refinery_builds_no_storage_bar():
    var entity := _make_non_refinery_entity()
    (Engine.get_main_loop() as SceneTree).root.add_child(entity)
    var sc := entity.get_node("SelectComponent") as SelectComponent
    (
        TestHelper
        . assert_true(
            not is_instance_valid(sc._storage_bar),
            "non-refinery structure builds no storage bar",
        )
    )
    entity.free()
