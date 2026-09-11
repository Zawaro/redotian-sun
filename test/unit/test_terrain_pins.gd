extends Node

# TerrainSystem cell pins: stamp/lock/delete semantics — pin API, height-edit
# locks (cell and shared-vertex granularity), cascade cooperation, JSON
# round-trip, and TerrainCatalog pin-priority resolution.
#
# Fixture cells are playable-diamond members; the diamond excludes grid corners,
# so corner-ish cells would test the guard instead of the lock.

const PIN_ID := "cliff01_n"

var _ts: Node = null


## Restore the shared TerrainSystem grid after this suite so later suites that
## rely on the 50x50 default are not poisoned by these small fixtures.
func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE and is_instance_valid(_ts):
        _ts.init_grid(50, 50)


func _cell_corners(cell: Vector2i) -> Array:
    return [
        _ts.get_vertex(cell.x, cell.y),
        _ts.get_vertex(cell.x + 1, cell.y),
        _ts.get_vertex(cell.x, cell.y + 1),
        _ts.get_vertex(cell.x + 1, cell.y + 1),
    ]


func test_pin_round_trip():
    _ts.init_grid(6, 6)
    var cell := Vector2i(3, 3)
    TestHelper.assert_true(_ts.pin_cell(cell, PIN_ID), "in-diamond pin succeeds")
    TestHelper.assert_eq(_ts.get_pin(cell), PIN_ID, "pin readable")
    TestHelper.assert_true(_ts.is_cell_pinned(cell), "cell reports pinned")
    TestHelper.assert_true(_ts.unpin_cell(cell), "unpin succeeds when pinned")
    TestHelper.assert_eq(_ts.get_pin(cell), "", "pin cleared")
    TestHelper.assert_true(not _ts.is_cell_pinned(cell), "cell reports unpinned")
    TestHelper.assert_true(not _ts.unpin_cell(cell), "unpin without pin fails")
    TestHelper.assert_true(not _ts.pin_cell(Vector2i(0, 0), PIN_ID), "out-of-diamond pin rejected")


func test_pin_round_trip_through_json():
    _ts.init_grid(6, 6)
    _ts.set_vertex(2, 3, 4)
    TestHelper.assert_true(_ts.pin_cell(Vector2i(2, 3), PIN_ID), "pin a")
    TestHelper.assert_true(_ts.pin_cell(Vector2i(3, 3), "ramp01_n"), "pin b")
    var path := "user://test_pins_roundtrip.json"
    _ts.export_to_json(path)
    _ts.clear()
    _ts.import_from_json(path)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    TestHelper.assert_eq(_ts.get_pin(Vector2i(2, 3)), PIN_ID, "pin a survives round-trip")
    TestHelper.assert_eq(_ts.get_pin(Vector2i(3, 3)), "ramp01_n", "pin b survives round-trip")
    TestHelper.assert_eq(_ts.get_vertex(2, 3), 4, "vertices survive round-trip")


func test_map_without_pins_loads_clean():
    _ts.init_grid(6, 6)
    var path := "user://test_pins_absent.json"
    _ts.export_to_json(path)
    _ts.pin_cell(Vector2i(3, 3), PIN_ID)
    _ts.import_from_json(path)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    TestHelper.assert_eq(_ts.get_pin(Vector2i(3, 3)), "", "no cell_pins key -> no pins")


func test_raise_and_lower_skip_pinned_cell():
    _ts.init_grid(6, 6)
    var cell := Vector2i(3, 3)
    for vx in [3, 4]:
        for vz in [3, 4]:
            _ts.set_vertex(vx, vz, 4)
    _ts.pin_cell(cell, PIN_ID)
    var before := _cell_corners(cell)
    for i in 3:
        _ts.raise_cell(cell)
        _ts.lower_cell(cell)
    TestHelper.assert_eq(
        _cell_corners(cell), before, "pinned cell corners unchanged by raise/lower"
    )


func test_raise_near_pin_skips_shared_vertices():
    _ts.init_grid(6, 6)
    var pinned := Vector2i(3, 3)
    for i in 4:
        _ts.raise_cell(pinned)
    _ts.pin_cell(pinned, PIN_ID)
    var before := _cell_corners(Vector2i(2, 3))
    _ts.raise_cell(Vector2i(2, 3))
    var after := _cell_corners(Vector2i(2, 3))
    TestHelper.assert_eq(after[1], before[1], "shared pinned corner untouched")
    TestHelper.assert_eq(after[3], before[3], "second shared pinned corner untouched")
    TestHelper.assert_eq(after[0], before[0] + 1, "free corner raised by one step")
    TestHelper.assert_eq(after[2], before[2] + 1, "other free corner raised by one step")


func test_lower_near_pin_skips_shared_vertices():
    _ts.init_grid(6, 6)
    var pinned := Vector2i(3, 3)
    for i in 4:
        _ts.raise_cell(pinned)
    _ts.pin_cell(pinned, PIN_ID)
    var before := _cell_corners(Vector2i(2, 3))
    _ts.lower_cell(Vector2i(2, 3))
    var after := _cell_corners(Vector2i(2, 3))
    TestHelper.assert_eq(after[1], before[1], "shared pinned corner untouched by lower")
    TestHelper.assert_eq(after[3], before[3], "second shared pinned corner untouched")
    TestHelper.assert_eq(after[0], before[0] - 1, "free corner lowered by one step")
    TestHelper.assert_eq(after[2], before[2] - 1, "other free corner lowered by one step")


func test_flatten_skips_pinned_vertices_and_levels_editable():
    _ts.init_grid(8, 8)
    # Raise one editable corner, pin cell (4,4), then flatten the region
    # covering vertices 4..6 (centered offset for 8x8 is 4).
    _ts.set_vertex(6, 6, 2)
    var pinned := Vector2i(4, 4)
    _ts.pin_cell(pinned, PIN_ID)
    var before := _cell_corners(pinned)
    _ts.flatten_footprint(Vector2i(0, 0), Vector2i(2, 2))
    TestHelper.assert_eq(_cell_corners(pinned), before, "pinned cell corners unchanged by flatten")
    var target: int = _ts.get_vertex(6, 6)
    TestHelper.assert_eq(target, 2, "max editable height is the flatten target")
    for v in [Vector2i(6, 4), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 5)]:
        TestHelper.assert_eq(_ts.get_vertex(v.x, v.y), target, "editable vertex leveled to target")


func test_flatten_footprint_levels_when_no_pins():
    # BuildingManager relies on flatten_footprint to level a foundation; with no
    # pins the whole footprint region must reach a single height.
    _ts.init_grid(8, 8)
    _ts.set_vertex(6, 6, 3)
    _ts.flatten_footprint(Vector2i(0, 0), Vector2i(2, 2))
    var target: int = _ts.get_vertex(6, 6)
    TestHelper.assert_eq(target, 3, "unpinned region keeps its max as target")
    for vx in range(4, 7):
        for vz in range(4, 7):
            TestHelper.assert_eq(_ts.get_vertex(vx, vz), target, "region vertex leveled")


func test_set_vertex_guarded_near_pins():
    _ts.init_grid(6, 6)
    for vx in [3, 4]:
        for vz in [3, 4]:
            _ts.set_vertex(vx, vz, 4)
    _ts.pin_cell(Vector2i(3, 3), PIN_ID)
    _ts.set_vertex(3, 3, 0)
    TestHelper.assert_eq(_ts.get_vertex(3, 3), 4, "set_vertex rejected on pinned-shared vertex")
    _ts.set_vertex(2, 3, 2)
    TestHelper.assert_eq(_ts.get_vertex(2, 3), 2, "set_vertex works on free vertex")


func test_raise_plateau_next_to_pin_keeps_cliff_constant():
    # Property check on an odd-width grid: repeated raises beside a pinned
    # cliff must never deform the pinned geometry.
    _ts.init_grid(7, 7)
    var pinned := Vector2i(3, 3)
    for vx in [3, 4]:
        for vz in [3, 4]:
            _ts.set_vertex(vx, vz, 6)
    _ts.pin_cell(pinned, PIN_ID)
    var before := _cell_corners(pinned)
    for i in 5:
        _ts.raise_cell(Vector2i(2, 3))
        _ts.raise_cell(Vector2i(3, 2))
        _ts.raise_cell(Vector2i(2, 4))
    TestHelper.assert_eq(_cell_corners(pinned), before, "cliff corners constant across raises")


func test_cascade_steps_stay_legal_around_pin():
    _ts.init_grid(7, 7)
    var pinned := Vector2i(3, 3)
    for vx in [3, 4]:
        for vz in [3, 4]:
            _ts.set_vertex(vx, vz, 6)
    _ts.pin_cell(pinned, PIN_ID)
    for i in 3:
        _ts.raise_cell(Vector2i(2, 3))
    TestHelper.assert_eq(_ts.get_vertex(3, 3), 6, "locked corner keeps cliff height")
    TestHelper.assert_true(_ts.get_vertex(2, 3) <= 6, "neighbor stays at or below cliff top")
