extends Node

# Generated bridge-end TerrainObject behavior: the real TS footprint (a
# three-wide road/rail cut at deck grade 4, grade-4 rock banks, grade-0 rock
# base) plus the placeholder-art aliases. Behaviour, not the generator formula:
# the counts and grades are read back from the shipped .tres resources.

const ROAD_BASE: String = "cliff_bridge_end"
const ROAD_WATER_BASE: String = "cliff_bridge_end_water"
const RAIL_BASE: String = "cliff_rail_bridge_end"
const DIRECTIONS: Array[String] = ["n", "e", "s", "w"]
const DECK_GRADE: int = 4
const BASE_GRADE: int = 0

var _gc: Node = null


func _object(object_id: String) -> TerrainObject:
    return load("res://games/ts/terrain_objects/%s.tres" % object_id) as TerrainObject


func _cell(obj: TerrainObject, key: String) -> Dictionary:
    var entry: Variant = obj.cells.get(key, {})
    return entry if entry is Dictionary else {}


func _corners(obj: TerrainObject, key: String) -> Array:
    return _cell(obj, key).get("corners", []) as Array


func _registered_land_ids() -> Array:
    if _gc == null or _gc.rules == null:
        return []
    var ids: Array = _gc.rules.land_types.keys()
    return ids


func _cut_cells(obj: TerrainObject, land_ids: Array) -> Array:
    """Cells at deck grade whose land is one of the cut lane types."""
    var out: Array = []
    for key in obj.cells:
        var entry := _cell(obj, String(key))
        var corners: Array = entry.get("corners", [])
        if corners.size() == 4 and int(corners[0]) == DECK_GRADE:
            if land_ids.has(String(entry.get("land", ""))):
                out.append(String(key))
    return out


## Integral, flat cells: every corner equals `grade`.
func _flat_at(obj: TerrainObject, key: String, grade: int) -> bool:
    var corners: Array = _corners(obj, key)
    if corners.size() != 4:
        return false
    for c in corners:
        if int(c) != grade:
            return false
    return true


func test_end_objects_satisfy_catalog_integrity() -> void:
    if _gc == null:
        TestHelper.fail("GameContext not injected")
        return
    var lands := _registered_land_ids()
    TestHelper.assert_true(lands.has("road"), "road land registered")
    TestHelper.assert_true(lands.has("railroad"), "railroad land registered")
    TestHelper.assert_true(lands.has("cliff"), "cliff land registered")
    for base in [ROAD_BASE, ROAD_WATER_BASE, RAIL_BASE]:
        for direction in DIRECTIONS:
            var obj := _object("%s_%s" % [base, direction])
            TestHelper.assert_true(obj != null, "end object loads: %s_%s" % [base, direction])
            if obj == null:
                continue
            TestHelper.assert_eq(obj.cell_type, "cliff", "end is a cliff: " + obj.id)
            TestHelper.assert_true(not obj.cells.is_empty(), "end has cells: " + obj.id)
            var res := TerrainCatalog.resolve_art(obj.id, "temperate")
            TestHelper.assert_true(res.valid, "end art resolves: " + obj.id)
            for key in obj.cells:
                var entry := _cell(obj, String(key))
                TestHelper.assert_eq(
                    (entry.get("corners", []) as Array).size(),
                    4,
                    "4 corners: %s @%s" % [obj.id, key]
                )
                TestHelper.assert_true(
                    ["flat", "x", "y"].has(String(entry.get("crease", ""))),
                    "valid crease: %s @%s" % [obj.id, key]
                )
                TestHelper.assert_true(
                    lands.has(String(entry.get("land", ""))),
                    "registered land '%s': %s @%s" % [entry.get("land", ""), obj.id, key]
                )


func test_road_end_cut_is_three_road_cells_at_deck_grade() -> void:
    for direction in DIRECTIONS:
        var obj := _object("%s_%s" % [ROAD_BASE, direction])
        if obj == null:
            TestHelper.fail("road end missing: " + direction)
            continue
        var cut := _cut_cells(obj, ["road"])
        TestHelper.assert_eq(cut.size(), 3, "road cut is exactly three cells: %s" % direction)
        for key in cut:
            TestHelper.assert_true(
                _flat_at(obj, String(key), DECK_GRADE),
                "road cut cell at grade 4: %s @%s" % [direction, key]
            )
        for key in obj.cells:
            if String(_cell(obj, String(key)).get("land", "")) == "road":
                TestHelper.assert_true(
                    cut.has(String(key)), "no extra road cell: %s @%s" % [direction, key]
                )


func test_rail_end_middle_cut_is_railroad() -> void:
    for direction in DIRECTIONS:
        var obj := _object("%s_%s" % [RAIL_BASE, direction])
        if obj == null:
            TestHelper.fail("rail end missing: " + direction)
            continue
        var cut := _cut_cells(obj, ["road", "railroad"])
        TestHelper.assert_eq(cut.size(), 3, "rail cut is exactly three cells: %s" % direction)
        var rail_cells: Array = []
        var road_cells: Array = []
        for key in cut:
            var land := String(_cell(obj, String(key)).get("land", ""))
            if land == "railroad":
                rail_cells.append(key)
            elif land == "road":
                road_cells.append(key)
        TestHelper.assert_eq(rail_cells.size(), 1, "one railroad middle lane: " + direction)
        TestHelper.assert_eq(road_cells.size(), 2, "two road outer lanes: " + direction)
        for key in cut:
            TestHelper.assert_true(
                _flat_at(obj, String(key), DECK_GRADE),
                "rail cut at grade 4: %s @%s" % [direction, key]
            )


func test_end_banks_and_base_grades() -> void:
    # The cut row/column is flanked by grade-4 rock, and the base course sits at
    # grade 0 — both real TS heights, not a uniform plateau.
    for base in [ROAD_BASE, RAIL_BASE]:
        for direction in DIRECTIONS:
            var obj := _object("%s_%s" % [base, direction])
            if obj == null:
                TestHelper.fail("end missing: %s_%s" % [base, direction])
                continue
            var banks := 0
            var base_cells := 0
            for key in obj.cells:
                var entry := _cell(obj, String(key))
                if String(entry.get("land", "")) != "cliff":
                    continue
                if _flat_at(obj, String(key), DECK_GRADE):
                    banks += 1
                elif _flat_at(obj, String(key), BASE_GRADE):
                    base_cells += 1
            TestHelper.assert_eq(banks, 2, "two grade-4 rock banks: %s_%s" % [base, direction])
            TestHelper.assert_true(base_cells > 0, "grade-0 base cells: %s_%s" % [base, direction])


func test_water_road_end_aliases_the_water_placeholder() -> void:
    var clear := TerrainCatalog.resolve_art("%s_n" % ROAD_BASE, "temperate")
    var water := TerrainCatalog.resolve_art("%s_n" % ROAD_WATER_BASE, "temperate")
    var rail := TerrainCatalog.resolve_art("%s_n" % RAIL_BASE, "temperate")
    TestHelper.assert_true(clear.valid, "clear road end art resolves")
    TestHelper.assert_true(water.valid, "water road end art resolves")
    TestHelper.assert_true(rail.valid, "rail end art resolves")
    if clear.valid:
        TestHelper.assert_eq(clear.submesh_id, "ovrps01", "clear end uses ovrps01")
    if water.valid:
        TestHelper.assert_eq(water.submesh_id, "ovrps02", "water end uses ovrps02")
    if rail.valid:
        TestHelper.assert_eq(rail.submesh_id, "ovrps01", "rail end uses the bridge placeholder")
    # The water variant shares the road footprint's real geometry, only the art differs.
    var road_n := _object("%s_n" % ROAD_BASE)
    var water_n := _object("%s_n" % ROAD_WATER_BASE)
    TestHelper.assert_true(road_n != null and water_n != null, "road + water n ends load")
    if road_n != null and water_n != null:
        TestHelper.assert_eq(water_n.cells.size(), road_n.cells.size(), "water end same footprint")
        TestHelper.assert_eq(
            _cut_cells(water_n, ["road"]).size(), 3, "water end keeps the three-cell road cut"
        )
