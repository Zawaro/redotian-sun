extends Node

# Perf guards for the entity-scalability change (#218) — deterministic counters,
# not wall-clock. Each guard asserts the per-frame code path never reintroduces
# the O(n) group scans it replaced.

const SELECT_COMPONENT_SCENE: PackedScene = preload("res://scenes/components/SelectComponent.tscn")

var _sh: Node = null
var _sm: Node = null


func _overlay() -> Node:
    var tree: SceneTree = Engine.get_main_loop() as SceneTree
    return tree.root.get_node_or_null("SelectionOverlay") if tree else null


func _make_grid_entity(entity_name: String) -> Node3D:
    var entity := Node3D.new()
    entity.name = entity_name
    entity.add_to_group("entities")
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.entity_type = EntityData.EntityType.VEHICLE
    stats.player_id = 0
    entity.add_child(stats)
    var mc := MovementController.new()
    mc.name = "MovementController"
    entity.add_child(mc)
    return entity


func _make_selectable_entity(entity_name: String) -> Node3D:
    var entity := Node3D.new()
    entity.name = entity_name
    entity.position = Vector3(0, 0, -5)
    var sc := SELECT_COMPONENT_SCENE.instantiate() as SelectComponent
    sc.name = "SelectComponent"
    entity.add_child(sc)
    _sm.add_child(entity)
    return entity


func _ensure_camera() -> Camera3D:
    var cam := Camera3D.new()
    cam.current = true
    _sm.get_tree().root.add_child(cam)
    return cam


## 9.1 — the per-frame SpatialHash `_reconcile()` must never scan the
## entities/ice groups, even after entities drift across cells.
func test_spatial_reconcile_performs_no_group_scans():
    if _sh == null:
        TestHelper.fail("SpatialHash not injected")
        return
    _sh.set_process(false)
    _sh.set_physics_process(false)
    _sh._shared_cell_counts.clear()
    _sh._blocked_cells.clear()
    var entities: Array[Node3D] = []
    for i in 20:
        var e := _make_grid_entity("PerfSpatial%d" % i)
        e.position = Vector3(float(i), 0.0, float(i))
        _sh.add_child(e)
        entities.append(e)
    _sh.rebuild()
    TestHelper.assert_true(
        _sh.perf_group_scans > 0, "rebuild scans the entities/ice groups (counter sanity)"
    )
    _sh.perf_group_scans = 0
    _sh._reconcile()
    TestHelper.assert_eq(_sh.perf_group_scans, 0, "idle reconcile performs no group scans")
    for i in entities.size():
        var e: Node3D = entities[i]
        e.position = Vector3(float(i) + 5.0, 0.0, float(i) + 5.0)
    _sh._reconcile()
    TestHelper.assert_eq(
        _sh.perf_group_scans, 0, "reconcile after cell drift performs no group scans"
    )
    for e in entities:
        _sh.remove_child(e)
        e.free()
    _sh.rebuild()


## 9.2 — SelectionManager's per-frame `_process` must only scan the
## "selectable" group every 6th frame (the throttled sync safety net).
func test_selection_sync_scans_group_only_every_sixth_frame():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    _sm._selection_sync_counter = 0
    _sm.perf_group_scans = 0
    for i in 5:
        _sm._process(0.0)
    TestHelper.assert_eq(
        _sm.perf_group_scans, 0, "five consecutive _process ticks perform no group scan"
    )
    _sm._process(0.0)
    TestHelper.assert_eq(
        _sm.perf_group_scans, 1, "sixth _process tick runs the throttled sync exactly once"
    )


## 9.2 — SelectionOverlay's per-frame `_collect_entities()` must render the
## tracked selection without scanning the "selectable" group.
func test_overlay_collect_performs_no_group_scans():
    if _sm == null:
        TestHelper.fail("SelectionManager not injected")
        return
    var overlay := _overlay()
    if overlay == null:
        TestHelper.fail("SelectionOverlay autoload not present")
        return
    _sm.deselect_all()
    var entity := _make_selectable_entity("PerfOverlay")
    var sc := entity.get_node("SelectComponent") as SelectComponent
    var cam := _ensure_camera()
    _sm.add_entity(sc)
    overlay.perf_group_scans = 0
    overlay._collect_entities()
    TestHelper.assert_eq(
        overlay.perf_group_scans, 0, "collect_entities performs no selectable-group scan"
    )
    TestHelper.assert_eq(
        overlay._entities.size(), 1, "tracked entity still collected without a group scan"
    )
    _sm.deselect_all()
    _sm.remove_child(entity)
    entity.free()
    cam.free()
