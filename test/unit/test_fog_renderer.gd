extends Node

# FogRenderer unit tests — fog plane texture rebuild driven by ShroudSystem
# state changes (allied-only noise filtered), plane geometry covering the grid,
# and inert behavior when fog_of_war is false.

const STATS_SCRIPT: GDScript = preload("res://scripts/components/StatsComponent.gd")

var _fr: Node = null
var _ss: Node = null
var _ts: Node = null
var _pm: Node = null
var _saved_insets := Vector4i(0, 0, 0, 0)
var _fog_was := false
var _shroud_was := true


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _ready() -> void:
    pass


func _resolve_autoloads() -> void:
    var root := (Engine.get_main_loop() as SceneTree).root
    _fr = root.get_node_or_null("FogRenderer")
    _ss = root.get_node_or_null("ShroudSystem")
    _ts = root.get_node_or_null("TerrainSystem")
    _pm = root.get_node_or_null("PlayerManager")
    if _fr == null:
        print("DBG _fr null; root children: ", root.get_children())


func _setup() -> void:
    _resolve_autoloads()
    var bounds: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("BoundsSystem")
    var rules := GlobalRules.get_current()
    _fog_was = rules.fog_of_war
    _shroud_was = rules.shroud_enabled
    rules.fog_of_war = true
    _ts.init_grid(50, 50)
    _saved_insets = Vector4i(
        bounds.left_inset,
        bounds.right_inset,
        bounds.top_inset,
        bounds.bottom_inset,
    )
    bounds.left_inset = int(bounds.DEFAULT_VISIBLE_INSETS.x)
    bounds.right_inset = int(bounds.DEFAULT_VISIBLE_INSETS.y)
    bounds.top_inset = int(bounds.DEFAULT_VISIBLE_INSETS.z)
    bounds.bottom_inset = int(bounds.DEFAULT_VISIBLE_INSETS.w)
    _pm._players.clear()
    _pm._local_player_id = 0
    _pm._init_defaults()


func _teardown() -> void:
    BoundsSystem.left_inset = _saved_insets.x
    BoundsSystem.right_inset = _saved_insets.y
    BoundsSystem.top_inset = _saved_insets.z
    BoundsSystem.bottom_inset = _saved_insets.w
    var rules := GlobalRules.get_current()
    rules.fog_of_war = _fog_was
    rules.shroud_enabled = _shroud_was


func _plane() -> MeshInstance3D:
    return _fr.get_node_or_null("FogOfWarPlane") as MeshInstance3D


func test_plane_geometry_covers_grid():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var mesh := _plane().mesh as ArrayMesh
    TestHelper.assert_true(mesh != null, "fog plane uses a draped grid mesh")
    var aabb: AABB = mesh.get_aabb()
    var expected := _rim_world_aabb()
    var covers_map_and_rim: bool = (
        is_equal_approx(aabb.position.x, expected.position.x)
        and is_equal_approx(aabb.position.z, expected.position.z)
        and is_equal_approx(aabb.size.x, expected.size.x)
        and is_equal_approx(aabb.size.z, expected.size.z)
    )
    TestHelper.assert_true(covers_map_and_rim, "plane AABB spans map square plus rim")
    # Read the lift consts off the script so this test doesn't drift when the
    # knob changes (`_fr` is Node-typed, so direct const access isn't available).
    var consts: Dictionary = _fr.get_script().get_script_constant_map()
    var lift := Vector3(consts["SHROUD_LIFT_XZ"], consts["SHROUD_LIFT_Y"], consts["SHROUD_LIFT_XZ"])
    TestHelper.assert_true(_plane().position == lift, "fog plane sits lifted above entity height")
    var opaque := _fr.get_node_or_null("FogShroudPlane") as MeshInstance3D
    TestHelper.assert_true(
        opaque != null and opaque.position == lift, "shroud plane lifted by the same offset"
    )
    TestHelper.assert_eq(
        _fr._material.render_priority, 127, "fog overlay sorts above other transparents"
    )
    var plane_basis_y: Vector3 = _plane().global_transform.basis.y
    TestHelper.assert_true(plane_basis_y.is_equal_approx(Vector3.UP), "plane stays horizontal")
    _teardown()


## Local AABB of the draped mesh: cells from -RIM_MARGIN to extent+RIM_MARGIN
## (half-open raster), so it spans ±(extent/2 + RIM_MARGIN) × CELL_SIZE.
func _rim_world_aabb() -> AABB:
    var extent := CellUtil.get_diamond_extent(TerrainSystem.grid_cells)
    var center: float = float(TerrainSystem.grid_cells.x + TerrainSystem.grid_cells.y) * 0.5
    var cs := CellUtil.CELL_SIZE
    var min_v: float = (float(-_fr.RIM_MARGIN) - center) * cs
    var max_v: float = (float(extent.x + _fr.RIM_MARGIN) - center) * cs
    return AABB(Vector3(min_v, 0.0, min_v), Vector3(max_v - min_v, 0.0, max_v - min_v))


func test_plane_covers_map_and_rim():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var mesh := _plane().mesh as ArrayMesh
    TestHelper.assert_true(mesh != null, "draped mesh present")
    var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    # The four map-square corners are now meshed so shroud covers the void
    # beyond the map diamond; the diamond's north tip stays present.
    var map_corners := [
        Vector2(-100.0, -100.0),
        Vector2(100.0, -100.0),
        Vector2(-100.0, 100.0),
        Vector2(100.0, 100.0),
    ]
    for c in map_corners:
        TestHelper.assert_true(_has_vertex_at(verts, c), "shroud corner present at %s" % c)
    TestHelper.assert_true(
        _has_vertex_at(verts, Vector2(0.0, -100.0)), "diamond north tip vertex present"
    )
    var aabb: AABB = mesh.get_aabb()
    var expected := _rim_world_aabb()
    TestHelper.assert_true(
        is_equal_approx(aabb.position.x, expected.position.x), "mesh reaches the -x rim"
    )
    TestHelper.assert_true(
        is_equal_approx(aabb.position.z, expected.position.z), "mesh reaches the -z rim"
    )
    TestHelper.assert_true(
        is_equal_approx(aabb.size.x, expected.size.x), "mesh spans the rim width"
    )
    TestHelper.assert_true(
        is_equal_approx(aabb.size.z, expected.size.z), "mesh spans the rim depth"
    )
    _teardown()


func _has_vertex_at(verts: PackedVector3Array, pos: Vector2) -> bool:
    for v in verts:
        if Vector2(v.x, v.z).distance_to(pos) < 0.01:
            return true
    return false


func test_plane_drapes_terrain():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    # Raise a known corner so the terrain is not flat.
    TerrainSystem.set_vertex(45, 45, 4)
    TerrainSystem.set_vertex(46, 46, 3)
    _fr._on_grid_initialized()
    var mesh := _plane().mesh as ArrayMesh
    TestHelper.assert_true(mesh != null, "draped mesh built after terrain change")
    var arrays := mesh.surface_get_arrays(0)
    var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    TestHelper.assert_true(not verts.is_empty(), "mesh has vertices")
    var center: float = float(TerrainSystem.grid_cells.x + TerrainSystem.grid_cells.y) * 0.5
    var cs := CellUtil.CELL_SIZE
    # Mirrors FogRenderer.PLANE_EPSILON (not reachable through the Node-typed _fr).
    var plane_eps: float = 0.02
    for corner in [Vector2i(45, 45), Vector2i(46, 46)]:
        var wp := Vector2((float(corner.x) - center) * cs, (float(corner.y) - center) * cs)
        var expected_h: float = (
            float(TerrainSystem.get_vertex(corner.x, corner.y)) * TerrainSystem.HEIGHT_STEP
            + plane_eps
        )
        var found := false
        for v in verts:
            if Vector2(v.x, v.z).distance_to(wp) < 0.01:
                found = true
                TestHelper.assert_true(
                    absf(v.y - expected_h) < 0.01, "fog vertex follows terrain height"
                )
                break
        TestHelper.assert_true(found, "vertex exists at cell corner %s" % corner)
    _teardown()


func test_texture_rebuilds_only_on_change():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var cell := Vector2i(40, 40)
    var tex_initial: ImageTexture = _fr._material.get_shader_parameter("fog_grid")
    TestHelper.assert_true(tex_initial != null, "texture built from initial grid state")
    ShroudSystem.register_revealer(0, cell, 1, 0.0, true)
    _ss.resolve_dirty()
    var tex_after: ImageTexture = _fr._material.get_shader_parameter("fog_grid")
    TestHelper.assert_true(tex_after != null, "texture present after state change")
    TestHelper.assert_true(tex_initial != tex_after, "texture rebuilt when state changed")
    var tex_same: ImageTexture = _fr._material.get_shader_parameter("fog_grid")
    TestHelper.assert_true(tex_after == tex_same, "no rebuild when effective state unchanged")
    _teardown()


func test_allied_only_noise_does_not_rebuild():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var cell := Vector2i(40, 40)
    ShroudSystem.register_revealer(0, cell, 1, 0.0, true)
    _ss.resolve_dirty()
    var tex_first: ImageTexture = _fr._material.get_shader_parameter("fog_grid")
    TestHelper.assert_true(tex_first != null, "texture built for local reveal")
    # Player 1 is an enemy (different team); its reveal must not alter the local
    # player's effective state, so no rebuild.
    _set_team(1, 2)
    ShroudSystem.register_revealer(1, Vector2i(40, 45), 1, 0.0, true)
    _ss.resolve_dirty()
    var tex_second: ImageTexture = _fr._material.get_shader_parameter("fog_grid")
    TestHelper.assert_true(
        tex_first == tex_second, "enemy-only resolve does not rebuild local texture"
    )
    _teardown()


func test_inert_when_fog_disabled():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var rules := GlobalRules.get_current()
    rules.shroud_enabled = false
    rules.fog_of_war = false
    # Re-init the grid with fog already off so no texture is ever built.
    _ts.init_grid(50, 50)
    ShroudSystem.register_revealer(0, Vector2i(40, 40), 1, 0.0, true)
    _ss.resolve_dirty()
    TestHelper.assert_true(not _plane().visible, "fog plane hidden when fog disabled")
    var tex: ImageTexture = _fr._material.get_shader_parameter("fog_grid")
    TestHelper.assert_true(tex == null, "no texture built when fog disabled")
    _teardown()


func test_runtime_toggle_syncs_fog_uniform():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var rules := GlobalRules.get_current()
    rules.fog_of_war = false
    _ts.init_grid(50, 50)
    var mat: ShaderMaterial = _fr._material
    TestHelper.assert_eq(
        mat.get_shader_parameter("fog_enabled"), false, "fog uniform off at grid init"
    )
    rules.fog_of_war = true
    _fr.refresh()
    TestHelper.assert_eq(
        mat.get_shader_parameter("fog_enabled"), true, "runtime toggle syncs the fog uniform"
    )
    rules.fog_of_war = false
    _fr.refresh()
    TestHelper.assert_eq(
        mat.get_shader_parameter("fog_enabled"), false, "toggle back off syncs again"
    )
    _teardown()


func _set_team(player_id: int, team_id: int) -> void:
    _pm.get_player_data(player_id).team_id = team_id


func _make_building(cell: Vector2i, player_id: int) -> Node3D:
    var entity := Node3D.new()
    entity.position = CellUtil.cell_to_world(cell)
    entity.add_to_group("entities")
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    entity.add_child(stats)
    stats.player_id = player_id
    stats.entity_type = EntityData.EntityType.BUILDING
    (Engine.get_main_loop() as SceneTree).root.add_child(entity)
    return entity


## Multi-cell enemy building: 2x2 footprint at `origin`, global_position chosen
## so `world_to_cell_origin` round-trips to `origin`.
func _make_building_foundation(origin: Vector2i, player_id: int, foundation: Vector2i) -> Node3D:
    var entity := Node3D.new()
    entity.add_to_group("entities")
    var center: float = float(TerrainSystem.grid_cells.x + TerrainSystem.grid_cells.y) * 0.5
    entity.position = Vector3(
        (float(origin.x) - center + float(foundation.x) * 0.5) * CellUtil.CELL_SIZE,
        0.0,
        (float(origin.y) - center + float(foundation.y) * 0.5) * CellUtil.CELL_SIZE,
    )
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    entity.add_child(stats)
    stats.player_id = player_id
    stats.entity_type = EntityData.EntityType.BUILDING
    var fc := FoundationComponent.new()
    fc.name = "FoundationComponent"
    fc.foundation = foundation
    entity.add_child(fc)
    (Engine.get_main_loop() as SceneTree).root.add_child(entity)
    return entity


func test_building_hidden_before_explored():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var cell := Vector2i(40, 40)
    var enemy := _make_building(cell, 1)
    _fr._physics_process(0.0)
    TestHelper.assert_true(not enemy.visible, "enemy building hidden in shroud")
    _fr._buildings.erase(enemy)
    enemy.queue_free()
    _teardown()


func test_building_persists_in_explored_fog():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var cell := Vector2i(40, 40)
    var enemy := _make_building(cell, 1)
    ShroudSystem.explore_area(0, cell, 1)
    _ss.resolve_dirty()
    _fr._physics_process(0.0)
    TestHelper.assert_true(enemy.visible, "building visible in explored fog")
    _fr._buildings.erase(enemy)
    enemy.queue_free()
    _teardown()


func test_building_hidden_until_any_foundation_cell_explored():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    # 2x2 footprint at origin (39,39): cells (39,39)..(40,40).
    var enemy := _make_building_foundation(Vector2i(39, 39), 1, Vector2i(2, 2))
    _fr._physics_process(0.0)
    TestHelper.assert_true(not enemy.visible, "building hidden with no foundation cell explored")
    ShroudSystem.explore_area(0, Vector2i(40, 40), 0)
    _ss.resolve_dirty()
    _fr._physics_process(0.0)
    TestHelper.assert_true(enemy.visible, "building shown when one foundation corner is explored")
    _fr._buildings.erase(enemy)
    enemy.free()
    _teardown()


func test_friendly_building_always_visible():
    _setup()
    if _fr == null:
        TestHelper.fail("FogRenderer not injected")
        return
    var cell := Vector2i(40, 40)
    var friendly := _make_building(cell, 0)
    _fr._physics_process(0.0)
    TestHelper.assert_true(friendly.visible, "friendly building never hidden")
    _fr._buildings.erase(friendly)
    friendly.queue_free()
    _teardown()
