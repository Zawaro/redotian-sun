extends Node

# Bridge land type registration and ground-locomotor bridge speeds.

const _RULES_PATH: String = "res://games/ts/global_rules.tres"
const _GROUND_LOCOMOTORS: Array[String] = ["Foot", "Wheel", "Track", "Amphibious"]
var _overlay_expected: Dictionary = {
    "bridge": {"kind": EntityData.BridgeKind.LOW, "end": false},
    "rail_bridge": {"kind": EntityData.BridgeKind.RAIL, "end": false},
    "bridge_high": {"kind": EntityData.BridgeKind.HIGH, "end": false},
    "bridge_end": {"kind": EntityData.BridgeKind.LOW, "end": true},
    "rail_bridge_end": {"kind": EntityData.BridgeKind.RAIL, "end": true},
    "bridge_high_end": {"kind": EntityData.BridgeKind.HIGH, "end": true},
}


func test_bridge_overlay_entity_data():
    for overlay_name in _overlay_expected:
        var data := load("res://games/ts/entities/overlay/%s.tres" % overlay_name) as EntityData
        TestHelper.assert_true(data != null, "overlay loads: " + overlay_name)
        if data == null:
            continue
        TestHelper.assert_eq(
            data.entity_type, EntityData.EntityType.OVERLAY, overlay_name + " is OVERLAY"
        )
        TestHelper.assert_eq(data.foundation, Vector2i(1, 1), overlay_name + " is 1x1")
        TestHelper.assert_eq(
            data.bridge_kind, int(_overlay_expected[overlay_name]["kind"]), overlay_name + " kind"
        )
        TestHelper.assert_eq(
            data.bridge_end, bool(_overlay_expected[overlay_name]["end"]), overlay_name + " end"
        )
    var blank := EntityData.new()
    TestHelper.assert_eq(blank.bridge_kind, EntityData.BridgeKind.NONE, "default kind none")
    TestHelper.assert_eq(blank.bridge_end, false, "default end false")
    TestHelper.assert_true(
        is_equal_approx(blank.bridge_rise, 4.0 * 0.815), "default rise is 4 steps"
    )


func test_bridge_overlays_reference_placeholder_art():
    for overlay_name in _overlay_expected:
        var data := load("res://games/ts/entities/overlay/%s.tres" % overlay_name) as EntityData
        TestHelper.assert_true(data != null, "overlay loads: " + overlay_name)
        if data == null or data.art_data == null:
            TestHelper.fail("overlay has placeholder art_data: " + overlay_name)
            continue
        (
            TestHelper
            . assert_true(
                data.art_data.texture_path.ends_with("placeholder_terrain01_Bridge_1m_x_1m.png"),
                overlay_name + " maps the bridge placeholder texture",
            )
        )
        (
            TestHelper
            . assert_true(
                data.art_data.placeholder_size != Vector3.ZERO,
                overlay_name + " has a placeholder deck size",
            )
        )


func test_bridge_land_type_registered():
    var rules := load(_RULES_PATH) as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        return
    var bridge := rules.get_land_type("bridge")
    TestHelper.assert_true(bridge != null, "bridge land type registered")
    if bridge == null:
        return
    TestHelper.assert_eq(bridge.id, "bridge", "bridge id")
    TestHelper.assert_eq(bridge.display_name, "Bridge", "bridge display name")
    TestHelper.assert_eq(bridge.group, "Bridge", "bridge group")
    TestHelper.assert_true(bridge.color != Color.WHITE, "bridge has a distinct color")


func test_validate_locomotor_keys_clean():
    var rules := load(_RULES_PATH) as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        return
    TestHelper.assert_true(
        rules.validate_locomotor_keys().is_empty(), "locomotor keys validate clean with bridge"
    )


func test_ground_locomotors_declare_bridge_at_road_speed():
    for lm_id in _GROUND_LOCOMOTORS:
        var lm := load("res://games/ts/locomotors/%s.tres" % lm_id) as Locomotor
        TestHelper.assert_true(lm != null, "locomotor loads: " + lm_id)
        if lm == null:
            continue
        TestHelper.assert_true(lm.is_passable("bridge"), "%s passes bridge" % lm_id)
        TestHelper.assert_eq(
            lm.get_speed_multiplier("bridge"),
            lm.get_speed_multiplier("road"),
            "%s bridge speed equals road" % lm_id
        )


func test_ship_does_not_use_bridge():
    var ship := load("res://games/ts/locomotors/Ship.tres") as Locomotor
    TestHelper.assert_true(ship != null, "Ship locomotor loads")
    if ship == null:
        return
    TestHelper.assert_eq(ship.is_passable("bridge"), false, "Ship cannot use bridge")
    TestHelper.assert_eq(ship.terrain_speeds.has("bridge"), false, "Ship declares no bridge key")
