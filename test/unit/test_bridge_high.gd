extends Node

# HIGH bridge (Phase 5). The deck sits `bridge_rise` (4 height steps = 3.26) above
# the ground on one authored flat span grade, with thickness rendered downward;
# every HIGH cell is indestructible (only LOW normal pieces are destructible).
# Bridge ends are TerrainObjects (a cliff with a 3-cell road cut at the deck
# grade) stamped onto the grid by TerrainSystem.stamp_terrain_object, which
# applies the authored per-cell land/corners and pins the cells. Pins round-trip
# through the existing cell_pins JSON and rebuild the stamp on import. Rail
# bridges exist only as HIGH variants.

const HEIGHT_STEP: float = 0.815
const HIGH_RISE: float = 4.0 * HEIGHT_STEP
const LOW_RISE: float = 0.5 * HEIGHT_STEP
const GRADE: int = 2
const WHEEL_LOCOMOTOR_PATH: String = "res://games/ts/locomotors/Wheel.tres"
const END_OBJECT_ID: String = "cliff_bridge_end_n"
const RAIL_END_OBJECT_ID: String = "cliff_rail_bridge_end_n"
## Every fixture cell sits inside the playable diamond of a 50x50 map.
const STAMP_ORIGIN: Vector2i = Vector2i(25, 25)

var _ts: Node = null
var _sh: Node = null
var _ef: Node = null
var _root: Node = null
var _spawned: Array[Node3D] = []


## Restore the shared grid after this suite so later suites relying on the 50x50
## default are not poisoned by these small fixtures.
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _clear()
        if is_instance_valid(_ts):
            _ts.init_grid(50, 50)
            _ts.clear()


func _ensure_root() -> void:
    if _root == null:
        _root = Engine.get_main_loop().root


func _spawn(entity_id: String, cell: Vector2i, override: Dictionary = {}) -> Node3D:
    _ensure_root()
    var entity: Node3D = _ef.create_entity(entity_id, override)
    if entity == null:
        return null
    _root.add_child(entity)
    entity.global_position = CellUtil.cell_to_world(cell)
    _spawned.append(entity)
    return entity


func _clear() -> void:
    for entity in _spawned:
        if is_instance_valid(entity):
            if entity.get_parent():
                entity.get_parent().remove_child(entity)
            entity.free()
    _spawned.clear()
    if _sh:
        _sh.rebuild()


## Flattens a vertex rectangle to `grade` raw steps, bypassing the cascading setter.
func _flatten_rect(min_v: Vector2i, max_v: Vector2i, grade: int) -> void:
    for vx in range(min_v.x, max_v.x + 1):
        for vz in range(min_v.y, max_v.y + 1):
            _ts._set_vertex_no_cascade(vx, vz, grade)
    _ts.invalidate_height_snapshot()


## TerrainSystem vertex order [nw, ne, sw, se] for a cell (raw height steps).
func _cell_corners(cell: Vector2i) -> Array[int]:
    return [
        _ts.get_vertex(cell.x, cell.y),
        _ts.get_vertex(cell.x + 1, cell.y),
        _ts.get_vertex(cell.x, cell.y + 1),
        _ts.get_vertex(cell.x + 1, cell.y + 1),
    ]


func _overlay(id: String) -> EntityData:
    return load("res://games/ts/entities/overlay/%s.tres" % id) as EntityData


func _catalog_object(id: String) -> TerrainObject:
    return load("res://games/ts/terrain_objects/%s.tres" % id) as TerrainObject


func test_high_overlay_data_is_four_step_rise() -> void:
    TestHelper.assert_true(
        is_equal_approx(HIGH_RISE, 3.26), "4 height steps is exactly 3.26 world units"
    )
    var expected := {
        "bridge_high": [EntityData.BridgeKind.HIGH, false],
        "bridge_high_end": [EntityData.BridgeKind.HIGH, true],
        "rail_bridge": [EntityData.BridgeKind.RAIL, false],
        "rail_bridge_end": [EntityData.BridgeKind.RAIL, true],
    }
    for id in expected:
        var data := _overlay(id)
        TestHelper.assert_true(data != null, "overlay loads: " + id)
        if data == null:
            continue
        var entry: Array = expected[id]
        TestHelper.assert_eq(data.bridge_kind, entry[0], id + " deck kind")
        TestHelper.assert_eq(data.bridge_level, 1, id + " deck level is 1")
        TestHelper.assert_true(
            is_equal_approx(data.bridge_rise, HIGH_RISE), id + " deck rise is 4 height steps"
        )
        TestHelper.assert_eq(data.bridge_end, bool(entry[1]), id + " end flag")
    # Rail is high only: both rail resources carry the RAIL kind, never LOW.
    TestHelper.assert_true(
        (
            _overlay("rail_bridge").bridge_kind == EntityData.BridgeKind.RAIL
            and _overlay("rail_bridge_end").bridge_kind == EntityData.BridgeKind.RAIL
        ),
        "rail bridges are authored as RAIL, a HIGH-only variant"
    )


func test_catalog_end_objects_are_cliffs_with_a_three_cell_road_cut() -> void:
    for base in ["cliff_bridge_end", "cliff_rail_bridge_end"]:
        for direction in ["n", "e", "s", "w"]:
            var obj := _catalog_object("%s_%s" % [base, direction])
            TestHelper.assert_true(
                obj != null, "catalog end variant loads: %s_%s" % [base, direction]
            )
            if obj == null:
                continue
            TestHelper.assert_eq(obj.cell_type, "cliff", "end object is a cliff: " + obj.id)
            # Real TS footprint: 5 wide (bank + three lanes + bank) x 2 deep
            # (grade-4 cut row over a grade-0 base row).
            TestHelper.assert_eq(obj.cells.size(), 10, "end object footprint is 5x2: " + obj.id)
            var road_cells := 0
            var rail_cells := 0
            for key in obj.cells:
                var land := obj.land_type_at(String(key))
                if land == "road":
                    road_cells += 1
                elif land == "railroad":
                    rail_cells += 1
                TestHelper.assert_true(
                    TerrainCatalog.resolve_art(obj.id, "temperate").valid,
                    "end object art resolves: " + obj.id
                )
            TestHelper.assert_eq(
                road_cells + rail_cells, 3, "end object cuts exactly 3 lane cells: " + obj.id
            )
            if base == "cliff_rail_bridge_end":
                TestHelper.assert_eq(
                    rail_cells, 1, "rail end has one railroad middle lane: " + obj.id
                )
            else:
                TestHelper.assert_eq(rail_cells, 0, "road end has no rail lane: " + obj.id)


func test_high_and_low_decks_coexist_over_flat_grade() -> void:
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_rect(Vector2i(24, 22), Vector2i(30, 28), GRADE)
    var high_cell := Vector2i(27, 24)
    var low_cell := Vector2i(27, 26)
    var high := _spawn("BRIDGE_HIGH", high_cell)
    var low := _spawn("BRIDGE", low_cell)
    _sh.rebuild()
    TestHelper.assert_true(high != null and low != null, "HIGH and LOW decks spawned")
    var base: float = float(GRADE) * HEIGHT_STEP

    var high_data: Dictionary = _sh.get_bridge_cell(high_cell, 1)
    TestHelper.assert_true(not high_data.is_empty(), "HIGH deck registered")
    if not high_data.is_empty():
        TestHelper.assert_true(
            is_equal_approx(float(high_data["surface_height"]), base + HIGH_RISE),
            "HIGH deck sits 4 height steps above the ground"
        )
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(high_cell, 1), base + HIGH_RISE),
            "surface query reads the HIGH deck"
        )
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(high_cell, 0), base),
            "ground under the HIGH deck keeps its own height"
        )
    var low_data: Dictionary = _sh.get_bridge_cell(low_cell, 1)
    TestHelper.assert_true(not low_data.is_empty(), "LOW deck registered alongside the HIGH one")
    if not low_data.is_empty():
        TestHelper.assert_true(
            is_equal_approx(float(low_data["surface_height"]), base + LOW_RISE),
            "LOW deck still sits half a step above the same grade"
        )
    # The HIGH deck is authored on one flat span grade: a second HIGH cell over
    # the same flat terrain resolves to the same elevation.
    var high_b := _spawn("BRIDGE_HIGH", Vector2i(28, 24))
    _sh.rebuild()
    if high_b != null:
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(Vector2i(28, 24), 1), base + HIGH_RISE),
            "every HIGH span cell shares the one flat grade"
        )
    _clear()


func test_high_cells_indestructible_low_normal_still_destructible() -> void:
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_rect(Vector2i(24, 24), Vector2i(30, 26), 0)
    var high_cell := Vector2i(26, 25)
    var high_end_cell := Vector2i(27, 25)
    var low_cell := Vector2i(28, 25)
    var high := _spawn("BRIDGE_HIGH", high_cell)
    var high_end := _spawn("BRIDGE_HIGH_END", high_end_cell)
    var low := _spawn("BRIDGE", low_cell)
    _sh.rebuild()
    if high == null or high_end == null or low == null:
        _clear()
        return
    var high_comp := high.get_node_or_null("BridgeComponent")
    var high_end_comp := high_end.get_node_or_null("BridgeComponent")
    var low_comp := low.get_node_or_null("BridgeComponent")
    var high_health := high.get_node_or_null("HealthComponent") as HealthComponent
    var high_end_health := high_end.get_node_or_null("HealthComponent") as HealthComponent
    var low_health := low.get_node_or_null("HealthComponent") as HealthComponent
    TestHelper.assert_true(
        high_comp != null and high_end_comp != null and low_comp != null,
        "all bridge pieces have a BridgeComponent"
    )
    TestHelper.assert_true(
        high_health != null and high_end_health != null and low_health != null,
        "all bridge pieces have health"
    )
    if high_health == null or high_end_health == null or low_health == null:
        _clear()
        return

    # HIGH is a destructibility gate of LOW-only: neither HIGH piece hooks the revert.
    TestHelper.assert_eq(
        high_health.health_zero.is_connected(high_comp._on_destroyed),
        false,
        "HIGH normal cell does not hook health_zero"
    )
    TestHelper.assert_eq(
        high_end_health.health_zero.is_connected(high_end_comp._on_destroyed),
        false,
        "HIGH end cell does not hook health_zero"
    )
    high_health.kill()
    high_end_health.kill()
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(high_cell, 1), "killed HIGH cell keeps its deck")
    TestHelper.assert_true(
        _sh.has_bridge_on_cell(high_end_cell, 1), "killed HIGH end keeps its deck"
    )
    TestHelper.assert_eq(high_comp._destroyed, false, "HIGH normal never reverts")
    TestHelper.assert_eq(high_end_comp._destroyed, false, "HIGH end never reverts")

    # Regression: a LOW normal span piece is still destructible and reverts.
    TestHelper.assert_eq(
        low_health.health_zero.is_connected(low_comp._on_destroyed),
        true,
        "LOW normal cell hooks health_zero"
    )
    low_health.kill()
    _sh.rebuild()
    TestHelper.assert_true(low_comp._destroyed, "LOW normal piece reverts on destruction")
    TestHelper.assert_eq(
        _sh.has_bridge_on_cell(low_cell, 1), false, "destroyed LOW piece leaves the registry"
    )
    TestHelper.assert_eq(_ts.get_land_type(low_cell, 1), "", "destroyed LOW cell loses its deck")
    _clear()


func test_rail_bridge_is_high_indestructible() -> void:
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _clear()
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_rect(Vector2i(24, 24), Vector2i(30, 26), 0)
    var cell := Vector2i(27, 25)
    var rail := _spawn("RAIL_BRIDGE", cell)
    _sh.rebuild()
    TestHelper.assert_true(rail != null, "rail bridge entity created")
    if rail == null:
        _clear()
        return
    var comp: Node = rail.get_node_or_null("BridgeComponent")
    var health := rail.get_node_or_null("HealthComponent") as HealthComponent
    TestHelper.assert_true(comp != null and health != null, "rail has bridge + health")
    if comp == null or health == null:
        _clear()
        return
    TestHelper.assert_eq(comp._bridge_kind, EntityData.BridgeKind.RAIL, "rail kind is RAIL")
    # RAIL is a HIGH variant: never a destruction target.
    (
        TestHelper
        . assert_eq(
            health.health_zero.is_connected(comp._on_destroyed),
            false,
            "rail cell does not hook health_zero (indestructible)",
        )
    )
    health.kill()
    _sh.rebuild()
    TestHelper.assert_true(_sh.has_bridge_on_cell(cell, 1), "killed rail cell keeps its deck")
    TestHelper.assert_eq(comp._destroyed, false, "rail never reverts")
    # It resolves at the high rise — four height steps above the ground.
    (
        TestHelper
        . assert_true(
            is_equal_approx(_ts.get_cell_surface_height(cell, 1), HIGH_RISE),
            "rail deck resolves at the high rise",
        )
    )
    _clear()


func test_stamp_applies_authored_land_and_corners_and_pins() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_rect(Vector2i(23, 23), Vector2i(27, 27), 0)
    # Synthetic single-cell probe pins the exact [nw, ne, se, sw] -> vertex mapping.
    var probe := TerrainObject.new()
    probe.id = "stamp_probe"
    probe.cell_type = "clear"
    probe.cells = {"0,0": {"corners": [1, 2, 3, 4], "crease": "flat", "land": "road"}}
    var probe_cell := Vector2i(25, 25)
    _ts.stamp_terrain_object(probe, probe_cell)
    TestHelper.assert_eq(_ts.get_vertex(probe_cell.x, probe_cell.y), 1, "NW corner -> (x, z)")
    TestHelper.assert_eq(_ts.get_vertex(probe_cell.x + 1, probe_cell.y), 2, "NE corner -> (x+1, z)")
    TestHelper.assert_eq(
        _ts.get_vertex(probe_cell.x + 1, probe_cell.y + 1), 3, "SE corner -> (x+1, z+1)"
    )
    TestHelper.assert_eq(_ts.get_vertex(probe_cell.x, probe_cell.y + 1), 4, "SW corner -> (x, z+1)")
    TestHelper.assert_eq(_ts.get_land_type(probe_cell), "road", "stamped land is applied")
    TestHelper.assert_true(_ts.is_cell_pinned(probe_cell), "stamped cell is pinned")
    TestHelper.assert_eq(_ts.get_pin(probe_cell), "stamp_probe", "pin records the object id")
    var before := _cell_corners(probe_cell)
    _ts.raise_cell(probe_cell)
    _ts.lower_cell(probe_cell)
    _ts.set_vertex(probe_cell.x, probe_cell.y, 0)
    TestHelper.assert_eq(_cell_corners(probe_cell), before, "pinned stamp rejects height edits")

    # Real catalog end at STAMP_ORIGIN: the cut row is local z=0, so the three
    # road lanes sit at (origin.x+1..3, origin.y); origin itself is the left
    # grade-4 rock bank.
    _ts.clear()
    _flatten_rect(Vector2i(23, 23), Vector2i(29, 29), 0)
    TestHelper.assert_true(
        _ts.stamp_terrain_object_by_id(END_OBJECT_ID, STAMP_ORIGIN), "catalog end stamps by id"
    )
    var road_cells: Array[Vector2i] = [Vector2i(26, 25), Vector2i(27, 25), Vector2i(28, 25)]
    for cell in road_cells:
        TestHelper.assert_eq(_ts.get_land_type(cell), "road", "road-cut cell is road at %s" % cell)
        TestHelper.assert_eq(_cell_corners(cell), [4, 4, 4, 4], "road-cut cell at deck grade")
        TestHelper.assert_true(_ts.is_cell_pinned(cell), "road-cut cell pinned")
        TestHelper.assert_eq(_ts.get_pin(cell), END_OBJECT_ID, "road-cut pin id")
        TestHelper.assert_true(
            is_equal_approx(_ts.get_cell_surface_height(cell), HIGH_RISE),
            "road-cut surface equals the deck grade"
        )
    TestHelper.assert_eq(_ts.get_land_type(STAMP_ORIGIN), "cliff", "flanking bank is cliff")
    TestHelper.assert_eq(
        _cell_corners(STAMP_ORIGIN), [4, 4, 4, 4], "flanking bank is at the deck grade too"
    )
    var wheel := load(WHEEL_LOCOMOTOR_PATH) as Locomotor
    TestHelper.assert_true(wheel != null, "Wheel locomotor loads")
    if wheel != null:
        TestHelper.assert_true(wheel.is_passable("road"), "the road cut is passable to wheels")
        TestHelper.assert_eq(wheel.is_passable("cliff"), false, "the flanking cliff blocks wheels")
    TestHelper.assert_eq(
        _ts.stamp_terrain_object_by_id("not_a_tile", STAMP_ORIGIN),
        false,
        "stamping an unknown id fails"
    )


func test_stamp_is_idempotent_and_does_not_cascade() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_rect(Vector2i(23, 23), Vector2i(31, 31), 0)
    _ts.stamp_terrain_object_by_id(END_OBJECT_ID, STAMP_ORIGIN)
    var first: Dictionary = {}
    for vx in range(23, 32):
        for vz in range(23, 32):
            first[CellUtil.cell_key_str(Vector2i(vx, vz))] = _ts.get_vertex(vx, vz)
    _ts.stamp_terrain_object_by_id(END_OBJECT_ID, STAMP_ORIGIN)
    var same := true
    for key in first:
        var parts: PackedStringArray = String(key).split(",")
        if _ts.get_vertex(int(parts[0]), int(parts[1])) != int(first[key]):
            same = false
    TestHelper.assert_true(same, "re-stamping writes identical absolute heights (idempotent)")
    TestHelper.assert_eq(
        _ts.get_vertex(STAMP_ORIGIN.x + 4, STAMP_ORIGIN.y + 4),
        0,
        "cells not sharing a stamped vertex are untouched (no cascade leak)"
    )


func test_stamp_round_trips_through_cell_pins() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_rect(Vector2i(23, 23), Vector2i(31, 31), 0)
    _ts.stamp_terrain_object_by_id(END_OBJECT_ID, STAMP_ORIGIN)
    var path := "user://test_bridge_high_roundtrip.json"
    _ts.export_to_json(path)
    var file := FileAccess.open(path, FileAccess.READ)
    var json: Dictionary = {}
    if file:
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        file.close()
        if parsed is Dictionary:
            json = parsed as Dictionary
    TestHelper.assert_true(json.has("cell_pins"), "stamped ends persist under cell_pins")
    TestHelper.assert_eq(json.has("bridge_ends"), false, "no new bridge-ends JSON section")

    _ts.clear()
    _ts.import_from_json(path)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    for local_key in ["0,0", "1,0", "2,0"]:
        var parts: PackedStringArray = String(local_key).split(",")
        var cell := STAMP_ORIGIN + Vector2i(int(parts[0]), int(parts[1]))
        TestHelper.assert_true(_ts.is_cell_pinned(cell), "pin restored at %s" % cell)
        TestHelper.assert_eq(_ts.get_pin(cell), END_OBJECT_ID, "pin id restored at %s" % cell)
        TestHelper.assert_eq(_cell_corners(cell), [4, 4, 4, 4], "corners restored at %s" % cell)
        TestHelper.assert_true(not _ts.get_land_type(cell).is_empty(), "land restored at %s" % cell)
    _ts.clear()
    _ts.init_grid(50, 50)


func test_pins_only_json_rebuilds_stamp_geometry() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    # A pins-only map (no vertices, no land_types) must still rebuild the stamp,
    # proving the consumer re-applies land/corners from the pinned object id.
    var pins: Dictionary = {}
    for local_key in ["0,0", "1,0", "2,0", "3,0", "4,0", "0,1", "1,1", "2,1", "3,1", "4,1"]:
        var parts: PackedStringArray = String(local_key).split(",")
        var cell := STAMP_ORIGIN + Vector2i(int(parts[0]), int(parts[1]))
        pins["%d,%d" % [cell.x, cell.y]] = END_OBJECT_ID
    var payload := {"version": 4, "grid_cells": [50, 50], "cell_pins": pins}
    var path := "user://test_bridge_high_pins_only.json"
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(payload))
    file.close()
    _ts.init_grid(50, 50)
    _ts.clear()
    _ts.import_from_json(path)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var road_cell := Vector2i(26, 25)
    TestHelper.assert_eq(
        _ts.get_land_type(road_cell), "road", "pins-only import re-applies the road-cut land"
    )
    TestHelper.assert_eq(
        _cell_corners(road_cell), [4, 4, 4, 4], "pins-only import re-applies the cut corners"
    )
    TestHelper.assert_eq(
        _ts.get_land_type(STAMP_ORIGIN),
        "cliff",
        "pins-only import re-applies the flanking bank land"
    )
    _ts.clear()
    _ts.init_grid(50, 50)


func test_stamp_control_unpinned_cell_allows_the_edit() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    _flatten_rect(Vector2i(24, 24), Vector2i(26, 26), 0)
    var cell := Vector2i(25, 25)
    # Control: unpinned ground accepts a height edit.
    _ts.raise_cell(cell)
    TestHelper.assert_eq(_ts.get_vertex(cell.x, cell.y), 1, "unpinned cell accepts a raise")
    # Now stamp a single-cell object on the same cell; the pin rejects the edit.
    var probe := TerrainObject.new()
    probe.id = "stamp_probe"
    probe.cell_type = "clear"
    probe.cells = {"0,0": {"corners": [4, 4, 4, 4], "crease": "flat", "land": "road"}}
    _ts.stamp_terrain_object(probe, cell)
    var before := _cell_corners(cell)
    _ts.raise_cell(cell)
    TestHelper.assert_eq(_cell_corners(cell), before, "stamped cell rejects the same edit")
    TestHelper.assert_true(_ts.is_cell_pinned(cell), "difference is the pin, not the height")
    _ts.clear()
    _ts.init_grid(50, 50)
