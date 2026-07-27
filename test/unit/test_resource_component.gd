extends Node

# ResourceComponent tests — collect, visual stages, spread_count
# Uses HealthComponent as the source of truth for resource amount.
# Bales are fractional: 1.0 = full cell, 0.5 = half cell, etc.

var _test_passed := 0
var _test_failed := 0


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
    if collected == 0.5 and tib.get_amount() == 0.5:
        _test_passed += 1
        print("    PASS: collect reduces health and returns bales")
    else:
        _test_failed += 1
        print(
            "    FAIL: expected collected=0.5 amount=0.5, got %f %f" % [collected, tib.get_amount()]
        )
    entity.free()


func test_collect_clamps_to_available():
    var entity := _make_entity(150, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var collected := tib.collect(1.0)
    if collected == 0.5 and tib.get_amount() == 0.0:
        _test_passed += 1
        print("    PASS: collect clamps to available bales")
    else:
        _test_failed += 1
        print(
            "    FAIL: expected collected=0.5 amount=0.0, got %f %f" % [collected, tib.get_amount()]
        )
    entity.free()


func test_collect_returns_zero_when_depleted():
    var entity := _make_entity(0, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var collected := tib.collect(0.5)
    if collected == 0.0:
        _test_passed += 1
        print("    PASS: collect returns 0 when depleted")
    else:
        _test_failed += 1
        print("    FAIL: expected 0.0, got %f" % collected)
    entity.free()


func test_is_depleted():
    var entity := _make_entity(0, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    if tib.is_depleted() == true:
        _test_passed += 1
        print("    PASS: is_depleted returns true at 0")
    else:
        _test_failed += 1
        print("    FAIL: expected true at 0")

    var hp := entity.get_node("HealthComponent") as HealthComponent
    hp.current_health = 1
    if tib.is_depleted() == false:
        _test_passed += 1
        print("    PASS: is_depleted returns false at 1")
    else:
        _test_failed += 1
        print("    FAIL: expected false at 1")
    entity.free()


func test_get_visual_stage():
    var entity := _make_entity(100, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var hp := entity.get_node("HealthComponent") as HealthComponent

    hp.current_health = 50
    if tib.get_visual_stage() == 0:
        _test_passed += 1
        print("    PASS: visual stage 0 at <=33%%")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 0 at 50/300, got %d" % tib.get_visual_stage())

    hp.current_health = 150
    if tib.get_visual_stage() == 1:
        _test_passed += 1
        print("    PASS: visual stage 1 at 34-66%%")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 1 at 150/300, got %d" % tib.get_visual_stage())

    hp.current_health = 250
    if tib.get_visual_stage() == 2:
        _test_passed += 1
        print("    PASS: visual stage 2 at >66%%")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 2 at 250/300, got %d" % tib.get_visual_stage())
    entity.free()


func test_get_visual_stage_zero_max():
    var entity := _make_entity(0, 0)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    if tib.get_visual_stage() == 0:
        _test_passed += 1
        print("    PASS: visual stage 0 when max_health is 0")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 0, got %d" % tib.get_visual_stage())
    entity.free()


func test_spread_count_starts_at_zero():
    var tib := ResourceComponent.new()
    if tib.spread_count == 0:
        _test_passed += 1
        print("    PASS: spread_count starts at 0")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % tib.spread_count)


func test_spread_count_increments():
    var tib := ResourceComponent.new()
    tib.spread_count += 1
    tib.spread_count += 1
    if tib.spread_count == 2:
        _test_passed += 1
        print("    PASS: spread_count increments")
    else:
        _test_failed += 1
        print("    FAIL: expected 2, got %d" % tib.spread_count)


func test_get_amount_returns_bale_fraction():
    var entity := _make_entity(150, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    if tib.get_amount() == 0.5:
        _test_passed += 1
        print("    PASS: get_amount returns 0.5 bales (150/300)")
    else:
        _test_failed += 1
        print("    FAIL: expected 0.5, got %f" % tib.get_amount())
    entity.free()


func test_get_max_amount_is_always_one():
    var entity := _make_entity(150, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    if tib.get_max_amount() == 1.0:
        _test_passed += 1
        print("    PASS: get_max_amount returns 1.0")
    else:
        _test_failed += 1
        print("    FAIL: expected 1.0, got %f" % tib.get_max_amount())
    entity.free()


func test_full_health_is_one_bale():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    if tib.get_amount() == 1.0:
        _test_passed += 1
        print("    PASS: full health = 1.0 bale")
    else:
        _test_failed += 1
        print("    FAIL: expected 1.0, got %f" % tib.get_amount())
    entity.free()


func test_build_material_is_emissive():
    var green := Color(0.2, 0.8, 0.2, 1)
    var mat := ResourceComponent._build_material(green)
    var ok := (
        mat.emission_enabled
        and mat.emission == green
        and mat.albedo_color == green
        and mat.emission_energy_multiplier >= 3.0
    )
    if ok:
        _test_passed += 1
        print("    PASS: _build_material emits resource color with bloom energy")
    else:
        _test_failed += 1
        print(
            (
                "    FAIL: expected emissive green mat, got enabled=%s emission=%s energy=%f"
                % [mat.emission_enabled, mat.emission, mat.emission_energy_multiplier]
            )
        )


func test_build_material_matches_type_color():
    var red := Color(1.0, 0.2, 0.2, 1)
    var mat := ResourceComponent._build_material(red)
    if mat.emission == red and mat.albedo_color == red:
        _test_passed += 1
        print("    PASS: _build_material tints emission per resource color")
    else:
        _test_failed += 1
        print(
            "    FAIL: expected emission=albedo=red, got %s / %s" % [mat.emission, mat.albedo_color]
        )


func test_collect_partial_bale():
    var entity := _make_entity(300, 300)
    var tib := entity.get_node("ResourceComponent") as ResourceComponent
    var collected := tib.collect(0.3)
    if absf(collected - 0.3) < 0.001 and absf(tib.get_amount() - 0.7) < 0.001:
        _test_passed += 1
        print("    PASS: collect 0.3 bales leaves 0.7")
    else:
        _test_failed += 1
        print(
            "    FAIL: expected collected=0.3 amount=0.7, got %f %f" % [collected, tib.get_amount()]
        )
    entity.free()
