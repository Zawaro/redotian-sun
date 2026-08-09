extends Node

# VisionComponent unit tests — revealer registration, deferred registration,
# cell-crossing re-stamp, permanent building registration, tree-exit unregister.

const VISION_SCRIPT: GDScript = preload("res://scripts/components/VisionComponent.gd")
const STATS_SCRIPT: GDScript = preload("res://scripts/components/StatsComponent.gd")

const GRID := Vector2i(50, 50)

var _ss: Node = null
var _ts: Node = null
var _pm: Node = null
var _container: Node3D = null
var _saved_insets := Vector4i(0, 0, 0, 0)


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _ready() -> void:
    _ss = get_node_or_null("/root/ShroudSystem")
    _ts = get_node_or_null("/root/TerrainSystem")
    _pm = get_node_or_null("/root/PlayerManager")


func _setup() -> void:
    _ts.init_grid(GRID.x, GRID.y)
    _saved_insets = Vector4i(
        BoundsSystem.left_inset,
        BoundsSystem.right_inset,
        BoundsSystem.top_inset,
        BoundsSystem.bottom_inset,
    )
    BoundsSystem.left_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.x
    BoundsSystem.right_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.y
    BoundsSystem.top_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.z
    BoundsSystem.bottom_inset = BoundsSystem.DEFAULT_VISIBLE_INSETS.w
    _pm._players.clear()
    _pm._local_player_id = 0
    _pm._init_defaults()
    _container = Node3D.new()
    _container.name = "VisionTestContainer"
    _tree().root.add_child(_container)


func _teardown() -> void:
    BoundsSystem.left_inset = _saved_insets.x
    BoundsSystem.right_inset = _saved_insets.y
    BoundsSystem.top_inset = _saved_insets.z
    BoundsSystem.bottom_inset = _saved_insets.w
    if is_instance_valid(_container):
        _tree().root.remove_child(_container)
        _container.queue_free()


func _world(cell: Vector2i) -> Vector3:
    return CellUtil.cell_to_world(cell)


func _make_entity(pos: Vector3, player_id: int, sight: int = 5) -> Node3D:
    var entity := Node3D.new()
    entity.position = pos
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    entity.add_child(stats)
    stats.player_id = player_id
    var vision := Node.new()
    vision.name = "VisionComponent"
    vision.set_script(VISION_SCRIPT)
    entity.add_child(vision)
    var data := EntityData.new()
    data.sight = sight
    data.entity_type = EntityData.EntityType.VEHICLE
    data.height = 1.0
    data.foundation = Vector2i(1, 1)
    vision.configure(data)
    _container.add_child(entity)
    return entity


func test_registers_revealer_on_spawn():
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return
    _setup()
    var cell := Vector2i(40, 40)
    var entity := _make_entity(_world(cell), 0)
    var vision := entity.get_node("VisionComponent")
    vision._physics_process(0.0)
    TestHelper.assert_true(_ss.is_visible(0, cell), "revealer registered at unit cell")
    TestHelper.assert_true(vision._registered_key >= 0, "revealer key cached")
    TestHelper.assert_eq(vision._registered_player_id, 0, "revealer registered for owner")
    _teardown()
    _finish()


func test_unregisters_on_tree_exit():
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return
    _setup()
    var cell := Vector2i(40, 40)
    var entity := _make_entity(_world(cell), 0)
    var vision := entity.get_node("VisionComponent")
    vision._physics_process(0.0)
    TestHelper.assert_true(_ss.is_visible(0, cell), "visible before removal")
    _container.remove_child(entity)
    entity.queue_free()
    TestHelper.assert_true(vision._registered_key < 0, "revealer unregistered on tree exit")
    _teardown()
    _finish()


func test_re_stamps_on_cell_crossing():
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return
    _setup()
    var cell_a := Vector2i(40, 40)
    var cell_b := Vector2i(46, 40)
    var entity := _make_entity(_world(cell_a), 0)
    var vision := entity.get_node("VisionComponent")
    vision._physics_process(0.0)
    TestHelper.assert_true(_ss.is_visible(0, cell_a), "cell A visible before move")
    entity.position = _world(cell_b)
    vision._physics_process(0.0)
    TestHelper.assert_true(not _ss.is_visible(0, cell_a), "cell A loses visibility after move")
    TestHelper.assert_true(_ss.is_visible(0, cell_b), "cell B visible after move")
    TestHelper.assert_eq(vision._registered_cell, cell_b, "registered cell updated")
    _teardown()
    _finish()


func test_no_re_stamp_while_stationary():
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return
    _setup()
    var entity := _make_entity(_world(Vector2i(40, 40)), 0)
    var vision := entity.get_node("VisionComponent")
    vision._physics_process(0.0)
    var key_before: int = vision._registered_key
    vision._physics_process(0.0)
    TestHelper.assert_eq(vision._registered_key, key_before, "no re-registration while stationary")
    _teardown()
    _finish()


func test_deferred_until_player_assigned():
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return
    _setup()
    var entity := Node3D.new()
    entity.position = _world(Vector2i(40, 40))
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    entity.add_child(stats)
    var vision := Node.new()
    vision.name = "VisionComponent"
    vision.set_script(VISION_SCRIPT)
    entity.add_child(vision)
    var data := EntityData.new()
    data.sight = 5
    data.entity_type = EntityData.EntityType.VEHICLE
    vision.configure(data)
    _container.add_child(entity)
    vision._physics_process(0.0)
    TestHelper.assert_eq(vision._registered_key, -1, "no register with unassigned player")
    stats.player_id = 1
    vision._physics_process(0.0)
    TestHelper.assert_true(vision._registered_key >= 0, "registers once player assigned")
    TestHelper.assert_eq(vision._registered_player_id, 1, "registered for assigned player")
    _teardown()
    _finish()


func test_building_registers_once_permanent():
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return
    _setup()
    var cell := Vector2i(40, 40)
    var entity := Node3D.new()
    entity.position = _world(cell)
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    entity.add_child(stats)
    stats.player_id = 0
    var vision := Node.new()
    vision.name = "VisionComponent"
    vision.set_script(VISION_SCRIPT)
    entity.add_child(vision)
    var data := EntityData.new()
    data.sight = 6
    data.entity_type = EntityData.EntityType.BUILDING
    data.height = 2.0
    data.foundation = Vector2i(3, 3)
    vision.configure(data)
    _container.add_child(entity)
    vision._physics_process(0.0)
    TestHelper.assert_true(vision._registered_key >= 0, "building registered")
    TestHelper.assert_true(_ss.is_visible(0, cell), "building reveals its cell")
    TestHelper.assert_true(not vision.is_physics_processing(), "building stops physics polling")
    var key_before: int = vision._registered_key
    vision._physics_process(0.0)
    TestHelper.assert_eq(vision._registered_key, key_before, "building never re-stamps")
    _teardown()
    _finish()


func test_building_revealer_ignores_terrain():
    if _ss == null:
        TestHelper.fail("ShroudSystem not injected")
        return
    _setup()
    _stamp_ridge_height(Vector2i(43, 40), 5)
    var cell := Vector2i(40, 40)
    var entity := Node3D.new()
    entity.position = _world(cell)
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    entity.add_child(stats)
    stats.player_id = 0
    var vision := Node.new()
    vision.name = "VisionComponent"
    vision.set_script(VISION_SCRIPT)
    entity.add_child(vision)
    var data := EntityData.new()
    data.sight = 8
    data.entity_type = EntityData.EntityType.BUILDING
    data.height = 2.0
    data.foundation = Vector2i(1, 1)
    vision.configure(data)
    _container.add_child(entity)
    vision._physics_process(0.0)
    (
        TestHelper
        . assert_true(
            _ss.is_visible(0, Vector2i(46, 40)),
            "building revealer sees over a ridge (blocks_terrain false)",
        )
    )
    _teardown()
    _finish()


func _stamp_ridge_height(cell: Vector2i, height: int) -> void:
    for corner in [
        Vector2i(cell.x, cell.y),
        Vector2i(cell.x + 1, cell.y),
        Vector2i(cell.x, cell.y + 1),
        Vector2i(cell.x + 1, cell.y + 1),
    ]:
        _ts._set_vertex_no_cascade(corner.x, corner.y, height)


func test_terrain_entity_gets_no_vision_component():
    var entity := EntityFactory.create_entity("TREE_01")
    if entity == null:
        TestHelper.fail("terrain entity fixture missing")
        return
    (
        TestHelper
        . assert_true(
            entity.get_node_or_null("VisionComponent") == null,
            "terrain entity (default sight 1) gets no VisionComponent",
        )
    )
    entity.queue_free()


func _finish() -> void:
    pass
