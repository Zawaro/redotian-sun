extends Node

# Bridge deck land data fidelity: the synthetic `bridge` land type is retired.
# A deck lane resolves `road` (road bridges, rail outer lanes, low/high) or
# `railroad` (rail middle lane); deck passability and cost come from that
# resolved land row with the underlying ground terrain figure skipped.

const _RULES_PATH: String = "res://games/ts/global_rules.tres"
const _GROUND_LOCOMOTORS: Array[String] = ["Foot", "Wheel", "Track", "Amphibious"]
const HEIGHT_STEP: float = 0.815

## overlay name -> {kind, end, land} derived from the TS lane model: a rail
## bridge's middle lane is railroad, every road/outer lane is road.
var _overlay_expected: Dictionary = {
    "bridge": {"kind": EntityData.BridgeKind.LOW, "end": false, "land": "road"},
    "rail_bridge": {"kind": EntityData.BridgeKind.RAIL, "end": false, "land": "railroad"},
    "bridge_high": {"kind": EntityData.BridgeKind.HIGH, "end": false, "land": "road"},
    "bridge_end": {"kind": EntityData.BridgeKind.LOW, "end": true, "land": "road"},
    "rail_bridge_end": {"kind": EntityData.BridgeKind.RAIL, "end": true, "land": "railroad"},
    "bridge_high_end": {"kind": EntityData.BridgeKind.HIGH, "end": true, "land": "road"},
}

var _ts: Node = null
var _sh: Node = null
var _root: Node = null
var _spawned: Array[Node3D] = []


class StubBridge:
    extends Node3D
    var data: Dictionary = {}

    func get_bridge_cell_data() -> Dictionary:
        return data


func _ensure_root() -> void:
    if _root == null:
        _root = Engine.get_main_loop().root


## Registers a level-1 deck over `cell` whose lane resolves `land`.
func _register(cell: Vector2i, land: String, surface_height: float = 0.0) -> StubBridge:
    _ensure_root()
    var bridge := StubBridge.new()
    bridge.data = {
        "surface_height": surface_height,
        "bridge_kind": int(EntityData.BridgeKind.HIGH),
        "land": land,
        "is_end": false,
        "piece_id": "land_%s" % land,
        "level": 1,
    }
    bridge.add_to_group("bridge")
    _root.add_child(bridge)
    bridge.global_position = CellUtil.cell_to_world(cell)
    _spawned.append(bridge)
    return bridge


func _clear() -> void:
    if _root == null:
        return
    for bridge in _spawned:
        if is_instance_valid(bridge):
            _root.remove_child(bridge)
            bridge.free()
    _spawned.clear()
    if _sh:
        _sh.rebuild()


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
        TestHelper.assert_eq(
            data.bridge_land,
            String(_overlay_expected[overlay_name]["land"]),
            overlay_name + " deck land"
        )
    var blank := EntityData.new()
    TestHelper.assert_eq(blank.bridge_kind, EntityData.BridgeKind.NONE, "default kind none")
    TestHelper.assert_eq(blank.bridge_land, "road", "default deck land is road")
    TestHelper.assert_eq(blank.bridge_end, false, "default end false")
    TestHelper.assert_eq(blank.bridge_level, 0, "default bridge level is ground (inert)")
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


func test_railroad_land_type_registered_and_bridge_retired():
    var rules := load(_RULES_PATH) as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        return
    var railroad := rules.get_land_type("railroad")
    TestHelper.assert_true(railroad != null, "railroad land type registered")
    if railroad != null:
        TestHelper.assert_eq(railroad.id, "railroad", "railroad id")
        TestHelper.assert_true(railroad.display_name != "", "railroad has a display name")
        TestHelper.assert_true(railroad.group != "", "railroad has a group")
        TestHelper.assert_true(railroad.color != Color.WHITE, "railroad has a distinct color")
    TestHelper.assert_eq(
        rules.get_land_type("bridge"), null, "synthetic bridge land type is retired"
    )


func test_validate_locomotor_keys_clean():
    var rules := load(_RULES_PATH) as GlobalRules
    TestHelper.assert_true(rules != null, "global_rules.tres loads")
    if rules == null:
        return
    TestHelper.assert_true(
        rules.validate_locomotor_keys().is_empty(),
        "locomotor keys validate clean after bridge retirement / railroad addition"
    )


func test_ground_locomotors_declare_railroad_at_road_speed():
    for lm_id in _GROUND_LOCOMOTORS:
        var lm := load("res://games/ts/locomotors/%s.tres" % lm_id) as Locomotor
        TestHelper.assert_true(lm != null, "locomotor loads: " + lm_id)
        if lm == null:
            continue
        TestHelper.assert_true(lm.is_passable("railroad"), "%s passes railroad" % lm_id)
        TestHelper.assert_eq(
            lm.get_speed_multiplier("railroad"),
            lm.get_speed_multiplier("road"),
            "%s railroad speed equals road" % lm_id
        )
        TestHelper.assert_eq(
            lm.terrain_speeds.has("bridge"), false, "%s declares no retired bridge row" % lm_id
        )


func test_ship_does_not_use_railroad_deck():
    var ship := load("res://games/ts/locomotors/Ship.tres") as Locomotor
    TestHelper.assert_true(ship != null, "Ship locomotor loads")
    if ship == null:
        return
    TestHelper.assert_eq(ship.is_passable("railroad"), false, "Ship cannot use a rail deck")
    TestHelper.assert_eq(
        ship.terrain_speeds.has("railroad"), false, "Ship declares no railroad key"
    )
    TestHelper.assert_eq(ship.terrain_speeds.has("bridge"), false, "Ship declares no bridge key")


func test_deck_land_resolution_and_ground_beneath():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var road_cell := Vector2i(30, 30)
    var rail_cell := Vector2i(31, 30)
    TestHelper.assert_true(
        (
            CellUtil.is_in_diamond(road_cell, Vector2i(50, 50))
            and CellUtil.is_in_diamond(rail_cell, Vector2i(50, 50))
        ),
        "fixture cells are inside the map"
    )
    _ts.set_land_type(road_cell, "water")
    _ts.set_land_type(rail_cell, "water")
    _register(road_cell, "road")
    _register(rail_cell, "railroad")
    _sh.rebuild()
    TestHelper.assert_eq(_ts.get_land_type(road_cell, 1), "road", "road deck lane resolves road")
    TestHelper.assert_eq(
        _ts.get_land_type(rail_cell, 1), "railroad", "rail deck lane resolves railroad"
    )
    TestHelper.assert_eq(
        _ts.get_land_type(road_cell, 0), "water", "level 0 under a road deck stays water"
    )
    TestHelper.assert_eq(
        _ts.get_land_type(rail_cell, 0), "water", "level 0 under a rail deck stays water"
    )
    TestHelper.assert_eq(_ts.get_land_type(road_cell, 2), "", "no deck at level 2 -> no surface")
    _ts.set_land_type(road_cell, "clear")
    _ts.set_land_type(rail_cell, "clear")
    _clear()


func test_deck_land_defaults_to_road_when_publisher_omits_it():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var cell := Vector2i(32, 30)
    _ensure_root()
    var bridge := StubBridge.new()
    # No "land" key: SpatialHash must default the registry entry to "road".
    bridge.data = {
        "surface_height": 0.0,
        "is_end": false,
        "piece_id": "legacy",
        "level": 1,
    }
    bridge.add_to_group("bridge")
    _root.add_child(bridge)
    bridge.global_position = CellUtil.cell_to_world(cell)
    _spawned.append(bridge)
    _sh.rebuild()
    var stored: Dictionary = _sh.get_bridge_cell(cell, 1)
    TestHelper.assert_true(not stored.is_empty(), "legacy deck registered")
    if not stored.is_empty():
        TestHelper.assert_eq(String(stored.get("land", "")), "road", "missing land defaults road")
    TestHelper.assert_eq(_ts.get_land_type(cell, 1), "road", "level 1 resolves the road default")
    _clear()


func test_deck_cost_uses_resolved_land_row():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var base := Vector2i(34, 30)
    var road_cell := Vector2i(34, 31)
    var rail_cell := Vector2i(34, 32)
    for cell: Vector2i in [base, road_cell, rail_cell]:
        for vx in [cell.x, cell.x + 1]:
            for vz in [cell.y, cell.y + 1]:
                _ts._vertex_grid[vx][vz] = 0
    _ts.invalidate_height_snapshot()
    # Distinguish the two rows: road -> cost 0.5, railroad -> cost 0.25.
    var wheel := Locomotor.new()
    wheel.terrain_speeds = {"clear": 1.0, "road": 2.0, "railroad": 4.0}
    wheel.climb_tolerance = 1
    _register(road_cell, "road")
    _register(rail_cell, "railroad")
    _sh.rebuild()
    var climb: float = wheel.climb_tolerance * HEIGHT_STEP
    var road_trans: Dictionary = Pathfinder._evaluate_transition(
        _ts, wheel, 0.0, base, 0, road_cell, 1, climb, false, null
    )
    var rail_trans: Dictionary = Pathfinder._evaluate_transition(
        _ts, wheel, 0.0, base, 0, rail_cell, 1, climb, false, null
    )
    TestHelper.assert_true(road_trans.get("allowed", false), "road deck step allowed")
    TestHelper.assert_true(rail_trans.get("allowed", false), "rail deck step allowed")
    if road_trans.get("allowed", false):
        TestHelper.assert_true(
            is_equal_approx(float(road_trans["cost_multiplier"]), 0.5),
            "road deck cost is the inverse Road multiplier (2.0 -> 0.5), not the ground figure"
        )
    if rail_trans.get("allowed", false):
        TestHelper.assert_true(
            is_equal_approx(float(rail_trans["cost_multiplier"]), 0.25),
            "rail deck cost is the inverse Railroad multiplier (4.0 -> 0.25)"
        )
    _clear()


func test_deck_falls_back_to_road_row_when_locomotor_lacks_deck_row():
    if _ts == null or _sh == null:
        TestHelper.fail("TerrainSystem/SpatialHash not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    var base := Vector2i(36, 30)
    var rail_cell := Vector2i(36, 31)
    for cell: Vector2i in [base, rail_cell]:
        for vx in [cell.x, cell.x + 1]:
            for vz in [cell.y, cell.y + 1]:
                _ts._vertex_grid[vx][vz] = 0
    _ts.invalidate_height_snapshot()
    var road_only := Locomotor.new()
    road_only.terrain_speeds = {"clear": 1.0, "road": 1.25}
    road_only.climb_tolerance = 1
    _register(rail_cell, "railroad")
    _sh.rebuild()
    var trans: Dictionary = Pathfinder._evaluate_transition(
        _ts,
        road_only,
        0.0,
        base,
        0,
        rail_cell,
        1,
        road_only.climb_tolerance * HEIGHT_STEP,
        false,
        null
    )
    TestHelper.assert_true(
        trans.get("allowed", false), "a road-only locomotor may still use a rail deck"
    )
    if trans.get("allowed", false):
        TestHelper.assert_true(
            is_equal_approx(float(trans["cost_multiplier"]), 1.0 / 1.25),
            "rail deck falls back to the Road row when the locomotor lacks Railroad"
        )
    _clear()
