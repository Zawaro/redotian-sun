extends Node

# Bridge persistence integration — an authored bridge span round-trips through the
# real map save/load path. The span is written by EditorSaveLoad (the production
# save loop: one `entities` entry per covered cell) and read back by
# MapLoader.load_map_into. The covered cells must resolve as "bridge" again while
# the underlying painted water — not a bridge land-type override — is what the
# JSON persists.

const SAVE_LOAD_SCRIPT: GDScript = preload("res://scripts/editor/EditorSaveLoad.gd")
const SAVE_PATH: String = "user://test_bridge_persistence.json"
const SPAN_CELLS: Array[Vector2i] = [Vector2i(24, 25), Vector2i(25, 25), Vector2i(26, 25)]
const HEIGHT_STEP: float = 0.815
const END_OBJECT_ID: String = "cliff_bridge_end_n"
const STAMP_ORIGIN: Vector2i = Vector2i(25, 25)
const STACK_CELLS: Array[Vector2i] = [Vector2i(32, 32), Vector2i(33, 32)]
const SHARED_PIECE_ID: String = "span_piece_one"

var _ts: Node = null
var _sh: Node = null
var _ef: Node = null
var _parent: Node3D = null


## Minimal stand-in for the MapEditor node's save-facing surface. Only the fields
## the production save loop reads are provided; nodes are intentionally absent
## because saving never touches them (one data entry per covered cell).
class StubEditor:
    extends Node3D
    var _painted_entities: Dictionary = {}
    var _player_start_tool: Node = null


class StubStartTool:
    extends Node

    func save_data() -> Array:
        return []


func _read_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    file.close()
    if parsed is Dictionary:
        return parsed as Dictionary
    return {}


func _json_has_land_type(json: Dictionary, land_id: String) -> bool:
    var land: Dictionary = json.get("land_types", {})
    for key in land:
        if String(land[key]) == land_id:
            return true
    return false


func _cell_key(cell: Vector2i) -> String:
    return "%d,%d" % [cell.x, cell.y]


## Flattens a vertex rectangle to `grade` raw steps, bypassing the cascading
## setter (matching the other bridge fixtures).
func _flatten_rect(min_v: Vector2i, max_v: Vector2i, grade: int) -> void:
    for vx in range(min_v.x, max_v.x + 1):
        for vz in range(min_v.y, max_v.y + 1):
            _ts._set_vertex_no_cascade(vx, vz, grade)
    _ts.invalidate_height_snapshot()


## Raw corner heights [nw, ne, sw, se] of a cell (matching TerrainSystem's order).
func _cell_corners(cell: Vector2i) -> Array[int]:
    return [
        _ts.get_vertex(cell.x, cell.y),
        _ts.get_vertex(cell.x + 1, cell.y),
        _ts.get_vertex(cell.x, cell.y + 1),
        _ts.get_vertex(cell.x + 1, cell.y + 1),
    ]


func test_bridge_span_round_trips_through_map_entities() -> void:
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    for cell in SPAN_CELLS:
        _ts.set_land_type(cell, "water")

    # Author the span through the production save path.
    var editor := StubEditor.new()
    editor.name = "BridgePersistenceStubEditor"
    editor._player_start_tool = StubStartTool.new()
    Engine.get_main_loop().root.add_child(editor)
    for cell in SPAN_CELLS:
        editor._painted_entities[_cell_key(cell)] = {
            "data": {"id": "BRIDGE", "bridge_piece_id": SHARED_PIECE_ID}
        }
    var saver: Node = SAVE_LOAD_SCRIPT.new()
    saver.editor = editor
    saver._on_save_file_selected(SAVE_PATH)

    var json := _read_json(SAVE_PATH)
    var entities: Array = json.get("entities", [])
    TestHelper.assert_eq(
        entities.size(), SPAN_CELLS.size(), "save writes one entity entry per covered cell"
    )
    var seen_cells: Dictionary = {}
    for entry in entities:
        var entry_dict := entry as Dictionary
        seen_cells[String(entry_dict.get("cell", ""))] = true
        (
            TestHelper
            . assert_eq(
                String(entry_dict.get("bridge_piece_id", "")),
                SHARED_PIECE_ID,
                "entity entry persists the shared bridge_piece_id",
            )
        )
    for cell in SPAN_CELLS:
        TestHelper.assert_true(
            seen_cells.has(_cell_key(cell)), "entity entry carries the covered cell %s" % cell
        )
        (
            TestHelper
            . assert_eq(
                String((json.get("land_types", {}) as Dictionary).get(_cell_key(cell), "")),
                "water",
                "bridge cell persists its underlying water, not a bridge override",
            )
        )
    TestHelper.assert_true(
        not _json_has_land_type(json, "bridge"), "no bridge land-type override is written"
    )

    # Load the authored map back through the real loader.
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    _parent = Node3D.new()
    _parent.name = "BridgePersistenceParent"
    # Skip gameplay camera framing; this is not an editor host.
    _parent.set_meta("is_map_editor", true)
    tree.root.add_child(_parent)
    var loaded := MapLoader.load_map_into(SAVE_PATH, _parent)
    _sh.rebuild()
    TestHelper.assert_eq(
        loaded.size(), SPAN_CELLS.size(), "loader re-instantiates every bridge cell"
    )
    for item in loaded:
        var node := item.get("node") as Node3D
        var comp: Node = node.get_node_or_null("BridgeComponent") if node else null
        TestHelper.assert_true(comp != null, "loaded bridge cell has a BridgeComponent")
        if comp != null:
            (
                TestHelper
                . assert_eq(
                    String(comp.get("piece_id")),
                    SHARED_PIECE_ID,
                    "reloaded cell keeps the shared bridge_piece_id",
                )
            )
    for cell in SPAN_CELLS:
        TestHelper.assert_eq(
            _ts.get_land_type(cell, 1), "bridge", "loaded covered cell resolves as a level-1 deck"
        )
        TestHelper.assert_eq(
            _ts.get_land_type(cell), "water", "level 0 under the span stays the painted water"
        )
    for cell in SPAN_CELLS:
        TestHelper.assert_eq(
            _ts.get_painted_land_type(cell), "water", "painted water under the span is untouched"
        )

    # Remove the span: the overlay-derived bridge surface must revert to the water.
    for entry in loaded:
        var node: Node3D = entry.get("node") as Node3D
        if is_instance_valid(node):
            node.get_parent().remove_child(node)
            node.free()
    _sh.rebuild()
    for cell in SPAN_CELLS:
        TestHelper.assert_eq(
            _ts.get_land_type(cell, 1), "", "removed bridge leaves no level-1 deck"
        )
        TestHelper.assert_eq(
            _ts.get_land_type(cell), "water", "removed bridge reverts the cell to water"
        )

    _teardown(editor, saver)


func test_map_without_bridges_loads_no_bridge_cells() -> void:
    if _ts == null or _sh == null:
        TestHelper.fail("autoloads not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var cell := Vector2i(30, 30)
    _ts.set_land_type(cell, "water")
    var editor := StubEditor.new()
    editor.name = "BridgePersistenceEmptyStubEditor"
    editor._player_start_tool = StubStartTool.new()
    Engine.get_main_loop().root.add_child(editor)
    # A plain terrain export (no bridge entity entries).
    _ts.export_to_json(SAVE_PATH, {"entities": [], "start_locations": []})

    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    _parent = Node3D.new()
    _parent.name = "BridgePersistenceEmptyParent"
    _parent.set_meta("is_map_editor", true)
    tree.root.add_child(_parent)
    MapLoader.load_map_into(SAVE_PATH, _parent)
    _sh.rebuild()
    TestHelper.assert_eq(_sh.has_bridge_on_cell(cell), false, "no bridge entity -> no bridge cell")
    TestHelper.assert_eq(
        _ts.get_land_type(cell), "water", "bridge-free map keeps its painted water"
    )
    _teardown(editor, null)


## MapLoader mesh Y: a loaded bridge overlay is placed at its walkable deck height
## — the cell's lowest terrain corner plus the authored rise, matching
## BridgeComponent.get_surface_height — not the ground max_height and not the
## smooth cell-centre sample. A stacked level-2 deck loads at its own higher Y.
## Registry-free by design (deck surfaces are not rebuilt at load time).
func test_loaded_bridge_overlay_y_is_deck_height() -> void:
    if _ts == null:
        TestHelper.fail("TerrainSystem not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    var cell := Vector2i(36, 36)
    var base_grade := 0
    var neighbour_grade := 4
    _flatten_rect(Vector2i(34, 34), Vector2i(38, 38), base_grade)
    # The deck cell shares its west corners with a raised neighbour (an abutting
    # bridge end/cliff). The min-corner base must stay at the flat span grade
    # while the smooth cell-centre sample reads raised.
    _ts._set_vertex_no_cascade(cell.x, cell.y, neighbour_grade)
    _ts._set_vertex_no_cascade(cell.x, cell.y + 1, neighbour_grade)
    _ts.invalidate_height_snapshot()
    var base: float = float(base_grade) * HEIGHT_STEP
    TestHelper.assert_true(
        is_equal_approx(_ts.get_cell_min_height(cell), base),
        "deck cell min corner is the flat grade"
    )
    var smooth_base: float = _ts.get_height_at_world_smooth(CellUtil.cell_to_world(cell))
    (
        TestHelper
        . assert_true(
            smooth_base > base + 0.01,
            (
                "control: the smooth sample is raised by the neighbour's corners (got %.4f)"
                % smooth_base
            ),
        )
    )
    var level1_rise := 4.0 * HEIGHT_STEP
    var level2_rise := 8.0 * HEIGHT_STEP
    var entries: Array[Dictionary] = [
        {
            "id": "BRIDGE_HIGH",
            "cell": _cell_key(cell),
            "bridge_kind": int(EntityData.BridgeKind.HIGH),
            "bridge_level": 1,
            "bridge_end": false,
            "bridge_rise": level1_rise,
        },
        {
            "id": "BRIDGE_HIGH",
            "cell": _cell_key(cell),
            "bridge_kind": int(EntityData.BridgeKind.HIGH),
            "bridge_level": 2,
            "bridge_end": false,
            "bridge_rise": level2_rise,
        },
    ]
    _ts.export_to_json(SAVE_PATH, {"entities": entries, "start_locations": []})

    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    _parent = Node3D.new()
    _parent.name = "BridgeMeshYParent"
    _parent.set_meta("is_map_editor", true)
    tree.root.add_child(_parent)
    var loaded := MapLoader.load_map_into(SAVE_PATH, _parent)
    TestHelper.assert_eq(loaded.size(), 2, "both stacked deck entries load")

    var expected_y: Array[float] = [base + level1_rise, base + level2_rise]
    for i in loaded.size():
        var node: Node3D = loaded[i].get("node") as Node3D
        TestHelper.assert_true(node != null, "loaded deck node %d exists" % i)
        if node == null:
            continue
        (
            TestHelper
            . assert_true(
                is_equal_approx(node.position.y, expected_y[i]),
                (
                    "loaded deck %d sits at min-corner + rise (%.4f), not the raised smooth sample"
                    % [i + 1, expected_y[i]]
                ),
            )
        )
        var comp: Node = node.get_node_or_null("BridgeComponent")
        TestHelper.assert_true(comp != null, "loaded deck %d has a BridgeComponent" % (i + 1))
        if comp != null:
            TestHelper.assert_eq(
                int(comp.get("_bridge_level")), i + 1, "loaded deck %d restores its level" % (i + 1)
            )
    (
        TestHelper
        . assert_true(
            expected_y[1] > expected_y[0] and expected_y[1] > base,
            "level-2 deck loads above the level-1 deck and the flat span grade",
        )
    )
    _teardown(null, null)


## Stacked extra-high decks plus a stamped high-bridge end round-trip through
## the real map path: `TerrainSystem.export_to_json` writes the deck entity
## entries and the end's `cell_pins`, and `MapLoader.load_map_into` (which calls
## `import_from_json`) restores each deck at its own level and rebuilds the end's
## land/corners from the pins — with no JSON section beyond `cell_pins`.
func test_stacked_decks_and_stamped_end_round_trip() -> void:
    if _ts == null or _sh == null or _ef == null:
        TestHelper.fail("autoloads not injected")
        return
    _ts.init_grid(50, 50)
    _ts.clear()
    _sh._bridge_cells.clear()
    _sh.clear_reservations()
    _flatten_rect(Vector2i(24, 24), Vector2i(34, 34), 0)
    # Water under the deck cells, so only the deck surface can carry traffic there.
    for cell in STACK_CELLS:
        _ts.set_land_type(cell, "water")
    TestHelper.assert_true(
        _ts.stamp_terrain_object_by_id(END_OBJECT_ID, STAMP_ORIGIN), "high-bridge end stamps"
    )

    # Author two real deck overlays over the same corridor at levels 1 and 2, and
    # derive their map entries from the live components (not hardcoded values).
    var authored: Array[Node3D] = []
    var entries: Array[Dictionary] = []
    for cell in STACK_CELLS:
        for level in [1, 2]:
            var rise := (4.0 if level == 1 else 8.0) * HEIGHT_STEP
            var node: Node3D = _ef.create_entity(
                "BRIDGE_HIGH", {"bridge_level": level, "bridge_rise": rise}
            )
            TestHelper.assert_true(node != null, "authored BRIDGE_HIGH at level %d" % level)
            if node == null:
                continue
            Engine.get_main_loop().root.add_child(node)
            node.global_position = CellUtil.cell_to_world(cell)
            authored.append(node)
            var comp: Node = node.get_node_or_null("BridgeComponent")
            TestHelper.assert_true(comp != null, "authored deck has a BridgeComponent")
            if comp == null:
                continue
            (
                entries
                . append(
                    {
                        "id": "BRIDGE_HIGH",
                        "cell": _cell_key(cell),
                        "bridge_kind": int(comp.get("_bridge_kind")),
                        "bridge_level": int(comp.get("_bridge_level")),
                        "bridge_end": bool(comp.get("_is_end")),
                        "bridge_rise": float(comp.get("_bridge_rise")),
                    }
                )
            )
    TestHelper.assert_eq(entries.size(), STACK_CELLS.size() * 2, "both decks authored per cell")
    TestHelper.assert_eq(
        _sh.get_bridge_levels(STACK_CELLS[0]).size(), 0, "authored decks are not yet registered"
    )

    _ts.export_to_json(SAVE_PATH, {"entities": entries, "start_locations": []})
    var json := _read_json(SAVE_PATH)
    TestHelper.assert_true(json.has("cell_pins"), "stamped end persists under cell_pins")
    TestHelper.assert_eq(json.has("bridge_ends"), false, "no bridge-ends JSON section")
    TestHelper.assert_eq(
        (json.get("entities", []) as Array).size(), entries.size(), "entries saved"
    )

    for node in authored:
        if is_instance_valid(node):
            node.get_parent().remove_child(node)
            node.free()
    _ts.init_grid(50, 50)
    _ts.clear()

    # Load back through the real map path: import_from_json restores pins/land,
    # then MapLoader re-creates the bridge entities with their deck fields.
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    _parent = Node3D.new()
    _parent.name = "BridgeStackedPersistenceParent"
    _parent.set_meta("is_map_editor", true)
    tree.root.add_child(_parent)
    var loaded := MapLoader.load_map_into(SAVE_PATH, _parent)
    _sh.rebuild()
    TestHelper.assert_eq(
        loaded.size(), STACK_CELLS.size() * 2, "loader re-instantiates every deck cell"
    )

    for cell in STACK_CELLS:
        var levels: Array[int] = _sh.get_bridge_levels(cell)
        TestHelper.assert_eq(levels.size(), 2, "both decks restored at %s" % cell)
        if levels.size() == 2:
            TestHelper.assert_eq(levels[0], 1, "lower deck restored at level 1")
            TestHelper.assert_eq(levels[1], 2, "upper deck restored at level 2")
        TestHelper.assert_eq(_ts.get_cell_surface_levels(cell), [0, 1, 2], "ground + both decks")
        (
            TestHelper
            . assert_true(
                is_equal_approx(_ts.get_cell_surface_height(cell, 1), 4.0 * HEIGHT_STEP),
                "level 1 restored at its authored height",
            )
        )
        (
            TestHelper
            . assert_true(
                is_equal_approx(_ts.get_cell_surface_height(cell, 2), 8.0 * HEIGHT_STEP),
                "level 2 restored at its authored height",
            )
        )
        (
            TestHelper
            . assert_true(
                _ts.get_cell_surface_height(cell, 2) > _ts.get_cell_surface_height(cell, 1),
                "the upper deck sits above the lower one",
            )
        )
        TestHelper.assert_eq(_ts.get_land_type(cell, 2), "bridge", "level 2 resolves a deck")
        TestHelper.assert_eq(_ts.get_land_type(cell), "water", "level 0 keeps the water beneath")

    # Stamped end: land + corners + pin restored from cell_pins alone.
    var road_cells: Array[Vector2i] = [Vector2i(25, 26), Vector2i(26, 26), Vector2i(27, 26)]
    for cell in road_cells:
        TestHelper.assert_eq(_ts.get_land_type(cell), "road", "road-cut land restored at %s" % cell)
        TestHelper.assert_eq(_cell_corners(cell), [4, 4, 4, 4], "road-cut corners restored")
        TestHelper.assert_true(_ts.is_cell_pinned(cell), "road-cut cell pinned at %s" % cell)
        TestHelper.assert_eq(_ts.get_pin(cell), END_OBJECT_ID, "pin id restored at %s" % cell)
    TestHelper.assert_eq(_ts.get_land_type(STAMP_ORIGIN), "cliff", "flanking cliff land restored")

    _teardown(null, null)


func _teardown(editor: Node, saver: Node) -> void:
    if _parent != null and is_instance_valid(_parent):
        for child in _parent.get_children():
            child.free()
        _parent.get_parent().remove_child(_parent)
        _parent.free()
    _parent = null
    if is_instance_valid(editor):
        editor.free()
    if saver != null and is_instance_valid(saver):
        saver.free()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
    if _sh != null:
        _sh.rebuild()
    if _ts != null:
        _ts.init_grid(50, 50)
        _ts.clear()
