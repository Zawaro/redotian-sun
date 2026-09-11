extends Node

# ResourceComponent tests — collect, bale yield, visual stages, spread_count
# A ripe tiberium cell (bales_per_cell = 11) holds 11 collectable bales.
# Bales are fractional during harvest; 11.0 = full tiberium cell.


func _make_entity(health: int = 300, max_health: int = 300) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestTiberium"
    var tib := ResourceComponent.new()
    tib.name = "ResourceComponent"
    entity.add_child(tib)
    var hp := HealthComponent.new()
    hp.name = "HealthComponent"
    hp.max_health = max_health
    hp.current_health = health
    entity.add_child(hp)
    return entity


func test_collect_reduces_health():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var collected := tib.collect(0.5)
    (
        TestHelper
        . assert_true(
            collected == 0.5 and tib.get_amount() == 10.5,
            (
                "collect reduces bales: expected collected=0.5 amount=10.5, got %f %f"
                % [collected, tib.get_amount()]
            ),
        )
    )
    entity.free()


func test_collect_clamps_to_available():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    tib.collect(6.0)
    var collected := tib.collect(20.0)
    (
        TestHelper
        . assert_true(
            collected == 5.0 and tib.get_amount() == 0.0,
            (
                "collect clamps to available bales: expected collected=5.0 amount=0.0, got %f %f"
                % [collected, tib.get_amount()]
            ),
        )
    )
    entity.free()


func test_collect_returns_zero_when_depleted():
    var entity := _make_entity(0, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var collected := tib.collect(0.5)
    TestHelper.assert_true(
        collected == 0.0, "collect returns 0 when depleted: expected 0.0, got %f" % collected
    )
    entity.free()


func test_is_depleted():
    var entity := _make_entity(0, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    TestHelper.assert_true(
        tib.is_depleted() == true, "is_depleted returns true at 0: expected true at 0"
    )

    var hp := entity.get_node("HealthComponent") as HealthComponent
    hp.current_health = 1
    TestHelper.assert_true(
        tib.is_depleted() == false, "is_depleted returns false at 1: expected false at 1"
    )
    entity.free()


func test_get_visual_stage():
    var entity := _make_entity(100, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var hp := entity.get_node("HealthComponent") as HealthComponent

    hp.current_health = 50
    (
        TestHelper
        . assert_true(
            tib.get_visual_stage() == 0,
            "visual stage 0 at <=33%: expected stage 0 at 50/300, got %d" % tib.get_visual_stage(),
        )
    )

    hp.current_health = 150
    (
        TestHelper
        . assert_true(
            tib.get_visual_stage() == 1,
            (
                "visual stage 1 at 34-66%: expected stage 1 at 150/300, got %d"
                % tib.get_visual_stage()
            ),
        )
    )

    hp.current_health = 250
    (
        TestHelper
        . assert_true(
            tib.get_visual_stage() == 2,
            "visual stage 2 at >66%: expected stage 2 at 250/300, got %d" % tib.get_visual_stage(),
        )
    )
    entity.free()


func test_get_visual_stage_zero_max():
    var entity := _make_entity(0, 0)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    (
        TestHelper
        . assert_true(
            tib.get_visual_stage() == 0,
            (
                "visual stage 0 when max_health is 0: expected stage 0, got %d"
                % tib.get_visual_stage()
            ),
        )
    )
    entity.free()


func test_spread_count_starts_at_zero():
    var tib := ResourceComponent.new()
    TestHelper.assert_true(
        tib.spread_count == 0, "spread_count starts at 0: expected 0, got %d" % tib.spread_count
    )


func test_spread_count_increments():
    var tib := ResourceComponent.new()
    tib.spread_count += 1
    tib.spread_count += 1
    TestHelper.assert_true(
        tib.spread_count == 2, "spread_count increments: expected 2, got %d" % tib.spread_count
    )


func test_get_amount_returns_bale_fraction():
    var entity := _make_entity(150, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    (
        TestHelper
        . assert_true(
            tib.get_amount() == 5.5,
            "get_amount returns 5.5 bales (150/300 x 11): expected 5.5, got %f" % tib.get_amount(),
        )
    )
    entity.free()


func test_get_max_amount_returns_bale_capacity():
    var entity := _make_entity(150, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    (
        TestHelper
        . assert_true(
            tib.get_max_amount() == 11.0,
            "get_max_amount returns 11.0 bales: expected 11.0, got %f" % tib.get_max_amount(),
        )
    )
    entity.free()


func test_full_health_is_bale_capacity():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    TestHelper.assert_true(
        tib.get_amount() == 11.0,
        "full health = 11.0 bales: expected 11.0, got %f" % tib.get_amount()
    )
    entity.free()


func test_collect_partial_bale():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var collected := tib.collect(0.3)
    (
        TestHelper
        . assert_true(
            absf(collected - 0.3) < 0.001 and absf(tib.get_amount() - 10.7) < 0.001,
            (
                "collect 0.3 bales leaves 10.7: expected collected=0.3 amount=10.7, got %f %f"
                % [collected, tib.get_amount()]
            ),
        )
    )
    entity.free()


func test_ripe_cell_yields_exactly_eleven_bales():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var total := 0.0
    for _i in 11:
        total += tib.collect(1.0)
    TestHelper.assert_true(
        absf(total - 11.0) < 0.001 and tib.is_depleted(),
        (
            "one-bail harvests sum to 11 and deplete: expected 11.0/true, got %f/%s"
            % [total, tib.is_depleted()]
        )
    )
    entity.free()


func test_unknown_resource_type_uses_default_capacity():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    tib.resource_type_id = "_no_such_resource_"
    TestHelper.assert_true(
        tib.get_max_amount() == 1.0 and tib.get_amount() == 1.0,
        (
            "unknown resource falls back to 1 bale capacity: expected max/amount 1.0/1.0, got %f/%f"
            % [tib.get_max_amount(), tib.get_amount()]
        )
    )
    var collected := tib.collect(0.3)
    TestHelper.assert_true(
        absf(collected - 0.3) < 0.001 and absf(tib.get_amount() - 0.7) < 0.001,
        "default-capacity collect 0.3 leaves 0.7: got %f/%f" % [collected, tib.get_amount()]
    )
    entity.free()


func test_harvester_capacity_spans_two_and_a_half_cells():
    var cells: Array[Node3D] = []
    for _i in 3:
        cells.append(_make_entity(300, 300))
    var cargo := 0.0
    for cell in cells:
        if cargo >= 28.0:
            break
        var tib := cell.get_node("ResourceComponent") as ResourceComponent
        cargo += tib.collect(28.0 - cargo)
    var third := cells[2].get_node("ResourceComponent") as ResourceComponent
    TestHelper.assert_true(
        absf(cargo - 28.0) < 0.001 and absf(third.get_amount() - 5.0) < 0.001,
        (
            "28 bales span two full cells + 6 of a third: expected cargo 28/third 5, got %f/%f"
            % [cargo, third.get_amount()]
        )
    )
    for cell in cells:
        cell.free()
