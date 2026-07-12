extends Node

# TiberiumComponent tests — configure, collect, visual stages, spread_count

var _test_passed := 0
var _test_failed := 0


func _make_tib_comp(amount: int = 300, max_amount: int = 300) -> TiberiumComponent:
    var tib := TiberiumComponent.new()
    tib.amount = amount
    tib.max_amount = max_amount
    return tib


func _make_entity_with_tib(amount: int = 300, max_amount: int = 300) -> Node3D:
    var entity := Node3D.new()
    entity.name = "TestTiberium"
    var tib := _make_tib_comp(amount, max_amount)
    tib.name = "TiberiumComponent"
    entity.add_child(tib)
    return entity


func test_configure_sets_fields():
    var tib := _make_tib_comp()
    var data := EntityData.new()
    data.tiberium_amount = 150
    data.tiberium_max_amount = 500
    data.tiberium_type = 1
    data.tiberium_regrowth_rate = 2.5
    tib.configure(data)
    if tib.amount == 150 and tib.max_amount == 500 \
        and tib.tiberium_type == 1 and tib.regrowth_rate == 2.5:
        _test_passed += 1
        print("    PASS: configure sets all fields")
    else:
        _test_failed += 1
        print("    FAIL: configure fields mismatch")


func test_collect_reduces_amount():
    var entity := _make_entity_with_tib(300, 300)
    var tib := entity.get_node("TiberiumComponent") as TiberiumComponent
    var collected := tib.collect(50)
    if collected == 50 and tib.amount == 250:
        _test_passed += 1
        print("    PASS: collect reduces amount and returns collected")
    else:
        _test_failed += 1
        print("    FAIL: expected collected=50 amount=250, got %d %d" % [collected, tib.amount])
    entity.free()


func test_collect_clamps_to_available():
    var entity := _make_entity_with_tib(30, 300)
    var tib := entity.get_node("TiberiumComponent") as TiberiumComponent
    var collected := tib.collect(100)
    if collected == 30 and tib.amount == 0:
        _test_passed += 1
        print("    PASS: collect clamps to available amount")
    else:
        _test_failed += 1
        print("    FAIL: expected collected=30 amount=0, got %d %d" % [collected, tib.amount])
    entity.free()


func test_collect_returns_zero_when_depleted():
    var entity := _make_entity_with_tib(0, 300)
    var tib := entity.get_node("TiberiumComponent") as TiberiumComponent
    var collected := tib.collect(50)
    if collected == 0:
        _test_passed += 1
        print("    PASS: collect returns 0 when depleted")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % collected)
    entity.free()


func test_is_depleted():
    var tib := _make_tib_comp(0, 300)
    if tib.is_depleted() == true:
        _test_passed += 1
        print("    PASS: is_depleted returns true at 0")
    else:
        _test_failed += 1
        print("    FAIL: expected true at 0")

    tib.amount = 1
    if tib.is_depleted() == false:
        _test_passed += 1
        print("    PASS: is_depleted returns false at 1")
    else:
        _test_failed += 1
        print("    FAIL: expected false at 1")


func test_get_visual_stage():
    var tib := _make_tib_comp(100, 300)

    tib.amount = 50
    if tib.get_visual_stage() == 0:
        _test_passed += 1
        print("    PASS: visual stage 0 at <=33%")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 0 at 50/300, got %d" % tib.get_visual_stage())

    tib.amount = 150
    if tib.get_visual_stage() == 1:
        _test_passed += 1
        print("    PASS: visual stage 1 at 34-66%")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 1 at 150/300, got %d" % tib.get_visual_stage())

    tib.amount = 250
    if tib.get_visual_stage() == 2:
        _test_passed += 1
        print("    PASS: visual stage 2 at >66%")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 2 at 250/300, got %d" % tib.get_visual_stage())


func test_get_visual_stage_zero_max():
    var tib := _make_tib_comp(0, 0)
    if tib.get_visual_stage() == 0:
        _test_passed += 1
        print("    PASS: visual stage 0 when max_amount is 0")
    else:
        _test_failed += 1
        print("    FAIL: expected stage 0, got %d" % tib.get_visual_stage())


func test_spread_count_starts_at_zero():
    var tib := _make_tib_comp()
    if tib.spread_count == 0:
        _test_passed += 1
        print("    PASS: spread_count starts at 0")
    else:
        _test_failed += 1
        print("    FAIL: expected 0, got %d" % tib.spread_count)


func test_spread_count_increments():
    var tib := _make_tib_comp()
    tib.spread_count += 1
    tib.spread_count += 1
    if tib.spread_count == 2:
        _test_passed += 1
        print("    PASS: spread_count increments")
    else:
        _test_failed += 1
        print("    FAIL: expected 2, got %d" % tib.spread_count)
