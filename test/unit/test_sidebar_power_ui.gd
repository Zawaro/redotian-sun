extends Node

# Sidebar power UI — PowerBar meter math and easing, scene wiring, and cameo
# tooltip power readouts.
#
# Requirement (power meter): a black column backs a green fill scaled to the
# player's power output and a red fill scaled to drain, both through a
# (value/2000)^0.4 curve, drawn in front — on deficit the red height exceeds
# the green height, and fills ease toward their targets on grid changes.
# Requirement (cameo tooltip): build menu items whose data carries a nonzero
# power value show it signed ("Power: +100" / "Power: -50"); power = 0 items
# show no power line.

const SIDEBAR_SCENE := preload("res://scenes/ui/Sidebar.tscn")

var _sidebar: Control = null


func _sidebar_instance() -> Control:
    if _sidebar == null:
        _sidebar = SIDEBAR_SCENE.instantiate() as Control
        add_child(_sidebar)
    return _sidebar


func _free_sidebar() -> void:
    if is_instance_valid(_sidebar):
        _sidebar.free()
    _sidebar = null


func _make_data(power: int) -> EntityData:
    var data := EntityData.new()
    data.id = "TEST_POWER_CAMEO_%d" % power
    data.display_name = "Power Cameo %d" % power
    data.entity_type = EntityData.EntityType.BUILDING
    data.cost = 300
    data.power = power
    return data


# --- PowerBar ratio math (pure) ---
#
# Requirement: fills map through (value / 2000)^0.4 — a milder-than-linear
# curve that keeps small bases visible (100 output ≈ 30% of the bar instead
# of 5% linear). Expected values computed independently from that formula.


func test_ratio_known_values():
    TestHelper.assert_eq(PowerBar._ratios(0, 0), Vector2.ZERO, "empty grid fills nothing")
    TestHelper.assert_eq(PowerBar._ratios(2000, 0).x, 1.0, "2000 output fills the bar")
    TestHelper.assert_eq(
        PowerBar._ratios(3000, 2500), Vector2(1.0, 1.0), "values above the scale clamp"
    )
    TestHelper.assert_eq(PowerBar._ratios(-5, 0), Vector2.ZERO, "negative output clamps to 0")
    var at_100 := PowerBar._ratios(100, 500)
    TestHelper.assert_true(
        absf(at_100.x - 0.3017) < 0.001, "100 output ≈ 0.05^0.4 ≈ 0.3017 of the bar"
    )
    TestHelper.assert_true(
        absf(at_100.y - 0.5743) < 0.001, "500 drain ≈ 0.25^0.4 ≈ 0.5743 of the bar"
    )
    var at_mid := PowerBar._ratios(500, 250)
    TestHelper.assert_true(
        absf(at_mid.x - 0.5743) < 0.001, "500 output ≈ 0.25^0.4 ≈ 0.5743 of the bar"
    )
    TestHelper.assert_true(
        absf(at_mid.y - 0.4353) < 0.001, "250 drain ≈ 0.125^0.4 ≈ 0.4353 of the bar"
    )


func test_drain_ratio_rises_above_output_ratio_on_deficit():
    TestHelper.assert_true(
        PowerBar._ratios(100, 500).y > PowerBar._ratios(100, 500).x,
        "red (drain) exceeds green (output) on deficit"
    )
    for output in [0, 100, 1000, 2000, 3000]:
        for drain in [0, 100, 1000, 2000, 3000]:
            if drain < output:
                continue
            var ratios := PowerBar._ratios(output, drain)
            TestHelper.assert_true(
                ratios.y >= ratios.x,
                "drain %d vs output %d: red never below green" % [drain, output]
            )


# --- Fill animation (pure) ---


func test_advance_eases_toward_target_without_jumping():
    var step := PowerBar._advance(Vector2.ZERO, Vector2.ONE, 0.1)
    TestHelper.assert_true(
        step.x > 0.0 and step.x < 1.0, "one eased step moves partway, not the whole way"
    )


func test_advance_converges_exactly_and_stays_settled():
    var current := Vector2.ZERO
    for i in 240:
        current = PowerBar._advance(current, Vector2.ONE, 1.0 / 60.0)
    TestHelper.assert_eq(current, Vector2.ONE, "ease converges exactly to the target")
    TestHelper.assert_eq(
        PowerBar._advance(Vector2.ONE, Vector2.ONE, 0.1), Vector2.ONE, "settled fill stays put"
    )


# --- Sidebar scene wiring ---


func test_sidebar_scene_hosts_power_bar():
    var sidebar := _sidebar_instance()
    var bar := sidebar.get_node_or_null("%PowerBar") as PowerBar
    if bar == null:
        TestHelper.fail("Sidebar.tscn must host a %%PowerBar with the PowerBar script")
        return
    var panel := sidebar.get_node_or_null("PanelContainer") as Control
    TestHelper.assert_true(panel != null, "sidebar keeps its cameo panel")
    TestHelper.assert_true(
        bar.get_index() > panel.get_index(), "power bar draws after the panel (in front)"
    )
    _free_sidebar()


# --- Cameo tooltip power readouts ---


func test_cameo_tooltip_shows_power_output():
    var sidebar := _sidebar_instance()
    var btn: Button = sidebar._create_cameo(_make_data(100))
    TestHelper.assert_true(
        btn.tooltip_text.contains("Power: +100"), "producer tooltip shows Power: +100"
    )
    btn.free()
    _free_sidebar()


func test_cameo_tooltip_shows_power_draw():
    var sidebar := _sidebar_instance()
    var btn: Button = sidebar._create_cameo(_make_data(-50))
    TestHelper.assert_true(
        btn.tooltip_text.contains("Power: -50"), "consumer tooltip shows Power: -50"
    )
    btn.free()
    _free_sidebar()


func test_cameo_tooltip_omits_power_when_zero():
    var sidebar := _sidebar_instance()
    var btn: Button = sidebar._create_cameo(_make_data(0))
    TestHelper.assert_true(
        not btn.tooltip_text.contains("Power:"), "power = 0 cameo shows no power line"
    )
    btn.free()
    _free_sidebar()
