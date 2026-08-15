extends Node

# Entity fog-ghost tests (#275): every entity type freezes to a last-known
# visual in fog, and entities destroyed in fog leave a post-destruction ghost
# released on reveal / shroud-revert / fog toggle-off.

const MODEL_PATH := "res://assets/models/nod_buggy01.glb"

const STATS_SCRIPT: GDScript = preload("res://scripts/components/StatsComponent.gd")

var _renderer: UnitMeshRenderer
var _fr: Node = null
var _ss: Node = null
var _ts: Node = null
var _pm: Node = null
var _container: Node3D
var _fog_was := false
var _shroud_was := true
var _saved_insets := Vector4i(0, 0, 0, 0)


func _tree() -> SceneTree:
    return Engine.get_main_loop() as SceneTree


func _setup() -> void:
    _resolve()
    _renderer.clear_all()
    var bounds := _tree().root.get_node_or_null("BoundsSystem")
    var rules := GlobalRules.get_current()
    _fog_was = rules.fog_of_war
    _shroud_was = rules.shroud_enabled
    rules.fog_of_war = true
    rules.shroud_enabled = true
    _ts.init_grid(50, 50)
    _saved_insets = Vector4i(
        bounds.left_inset, bounds.right_inset, bounds.top_inset, bounds.bottom_inset
    )
    bounds.left_inset = int(bounds.DEFAULT_VISIBLE_INSETS.x)
    bounds.right_inset = int(bounds.DEFAULT_VISIBLE_INSETS.y)
    bounds.top_inset = int(bounds.DEFAULT_VISIBLE_INSETS.z)
    bounds.bottom_inset = int(bounds.DEFAULT_VISIBLE_INSETS.w)
    _pm._players.clear()
    _pm._local_player_id = 0
    _pm._init_defaults()
    _container = Node3D.new()
    _container.name = "FogGhostTestContainer"
    _tree().root.add_child(_container)


func _teardown() -> void:
    _renderer.clear_all()
    var depot := GhostDepot.get_instance()
    if depot:
        depot.release_all()
        depot.assert_no_leaks()
    BoundsSystem.left_inset = _saved_insets.x
    BoundsSystem.right_inset = _saved_insets.y
    BoundsSystem.top_inset = _saved_insets.z
    BoundsSystem.bottom_inset = _saved_insets.w
    var rules := GlobalRules.get_current()
    rules.fog_of_war = _fog_was
    rules.shroud_enabled = _shroud_was
    if is_instance_valid(_container):
        _tree().root.remove_child(_container)
        _container.queue_free()


func _resolve() -> void:
    _renderer = _tree().root.get_node_or_null("UnitMeshRenderer") as UnitMeshRenderer
    _fr = _tree().root.get_node_or_null("FogRenderer")
    _ss = _tree().root.get_node_or_null("ShroudSystem")
    _ts = _tree().root.get_node_or_null("TerrainSystem")
    _pm = _tree().root.get_node_or_null("PlayerManager")


func _depot() -> GhostDepot:
    return GhostDepot.get_instance()


func _make_building(cell: Vector2i, player_id: int, with_model: bool) -> Node3D:
    var building := Node3D.new()
    building.position = CellUtil.cell_to_world(cell)
    building.add_to_group("entities")
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    building.add_child(stats)
    stats.player_id = player_id
    stats.entity_type = EntityData.EntityType.BUILDING
    if with_model:
        var art := ArtComponent.new()
        art.name = "ArtComponent"
        building.add_child(art)
        var model := Node3D.new()
        model.name = "Model"
        art.add_child(model)
        art._model_root = model
    _container.add_child(building)
    return building


func _make_tiberium(cell: Vector2i) -> Node3D:
    var tib := Node3D.new()
    tib.position = CellUtil.cell_to_world(cell)
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    tib.add_child(stats)
    stats.player_id = -1
    stats.entity_type = EntityData.EntityType.OVERLAY
    var rc := ResourceComponent.new()
    rc.name = "ResourceComponent"
    tib.add_child(rc)
    var stage := Node3D.new()
    stage.name = "Stage2"
    tib.add_child(stage)
    var cubes: Array[Node3D] = [null, null, stage]
    rc._cube_nodes = cubes
    rc._current_visual_stage = 2
    _container.add_child(tib)
    return tib


func _make_tiberium_full(cell: Vector2i) -> Node3D:
    var tib := Node3D.new()
    tib.position = CellUtil.cell_to_world(cell)
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    tib.add_child(stats)
    stats.player_id = -1
    stats.entity_type = EntityData.EntityType.OVERLAY
    var rc := ResourceComponent.new()
    rc.name = "ResourceComponent"
    tib.add_child(rc)
    var stages: Array[Node3D] = []
    for i in 3:
        var stage := Node3D.new()
        stage.name = "Stage%d" % i
        tib.add_child(stage)
        stages.append(stage)
    var hp := HealthComponent.new()
    hp.name = "HealthComponent"
    hp.max_health = 300
    hp.current_health = 300
    tib.add_child(hp)
    rc._cube_nodes = stages
    rc._current_visual_stage = 2
    for i in 3:
        stages[i].visible = (i == 2)
    _container.add_child(tib)
    return tib


## A spread-spawned crystal: ResourceComponent exists but stage containers are
## not built yet (they are created deferred in `_ready`). Mirrors the exact
## state `_sync_overlay` sees on the node_added pass for a crystal that spreads
## into a fog cell.
func _make_tiberium_unstaged(cell: Vector2i) -> Node3D:
    var tib := Node3D.new()
    tib.position = CellUtil.cell_to_world(cell)
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    tib.add_child(stats)
    stats.player_id = -1
    stats.entity_type = EntityData.EntityType.OVERLAY
    var rc := ResourceComponent.new()
    rc.name = "ResourceComponent"
    tib.add_child(rc)
    rc._cube_nodes = []
    rc._current_visual_stage = -1
    _container.add_child(tib)
    return tib


func _make_unit_with_player(pos: Vector3, player_id: int) -> Node3D:
    var entity := Node3D.new()
    entity.position = pos
    var model_root := Node3D.new()
    model_root.name = "ModelRoot"
    entity.add_child(model_root)
    _container.add_child(entity)
    var stats := Node.new()
    stats.name = "StatsComponent"
    stats.set_script(STATS_SCRIPT)
    entity.add_child(stats)
    stats.player_id = player_id
    return entity


func _register(entity: Node3D) -> bool:
    return _renderer.register(
        entity, MODEL_PATH, entity.get_node("ModelRoot") as Node3D, Transform3D.IDENTITY, false
    )


## Registers a node-tree (placeholder) unit — empty model_path, no baked slot.
func _register_placeholder(entity: Node3D) -> bool:
    return _renderer.register(
        entity, "", entity.get_node("ModelRoot") as Node3D, Transform3D.IDENTITY, false
    )


func _enter_fog(cell: Vector2i) -> void:
    ShroudSystem.explore_area(0, cell, 1)
    _ss.resolve_dirty()


func _reveal(cell: Vector2i) -> void:
    ShroudSystem.register_revealer(0, cell, 5, 0.0, true)
    _ss.resolve_dirty()


func _reveal_key(cell: Vector2i) -> int:
    var key := ShroudSystem.register_revealer(0, cell, 5, 0.0, true)
    _ss.resolve_dirty()
    return key


## Flip a cell from visible back to fog (explored, not visible): reveals, syncs,
## then drops the revealer. Explored state is sticky, so the cell lands in fog.
func _visible_then_fog(cell: Vector2i) -> void:
    var key := _reveal_key(cell)
    _fr._sync_overlays()
    ShroudSystem.unregister_revealer(0, key)
    _ss.resolve_dirty()
    _fr._sync_overlays()


func test_building_frozen_in_fog():
    _setup()
    var cell := Vector2i(40, 40)
    var building := _make_building(cell, 1, true)
    var art := building.get_node("ArtComponent") as ArtComponent
    var model: Node3D = art.get_model_root()
    _enter_fog(cell)
    _fr._sync_buildings()
    TestHelper.assert_true(_depot().has_ghost(building), "building ghosted in fog")
    TestHelper.assert_true(model.get_parent() == _depot(), "building model reparented to depot")
    _teardown()


func test_building_reveal_unfreezes_at_real_position():
    _setup()
    var cell := Vector2i(40, 40)
    var building := _make_building(cell, 1, true)
    var art := building.get_node("ArtComponent") as ArtComponent
    var model: Node3D = art.get_model_root()
    _enter_fog(cell)
    _fr._sync_buildings()
    TestHelper.assert_true(_depot().has_ghost(building), "frozen before reveal")
    _reveal(cell)
    _fr._sync_buildings()
    TestHelper.assert_true(not _depot().has_ghost(building), "ghost released on reveal")
    TestHelper.assert_true(model.get_parent() == art, "model restored to ArtComponent")
    TestHelper.assert_true(building.visible, "building visible when revealed")
    _teardown()


func test_building_hidden_in_shroud_and_ghost_released():
    _setup()
    var cell := Vector2i(40, 40)
    var building := _make_building(cell, 1, true)
    _enter_fog(cell)
    _fr._sync_buildings()
    TestHelper.assert_true(_depot().has_ghost(building), "frozen before cover")
    ShroudSystem.cover_shroud(0)
    _ss.resolve_dirty()
    _fr._sync_buildings()
    TestHelper.assert_true(not _depot().has_ghost(building), "ghost released on shroud revert")
    TestHelper.assert_true(not building.visible, "building hidden in shroud")
    _teardown()


func test_friendly_building_never_frozen():
    _setup()
    var cell := Vector2i(40, 40)
    var friendly := _make_building(cell, 0, true)
    _enter_fog(cell)
    _fr._sync_buildings()
    TestHelper.assert_true(not _depot().has_ghost(friendly), "friendly building never frozen")
    TestHelper.assert_true(friendly.visible, "friendly building stays visible")
    _teardown()


func test_tiberium_harvest_stage_frozen_in_fog():
    _setup()
    var cell := Vector2i(40, 40)
    var tib := _make_tiberium(cell)
    var rc := tib.get_node("ResourceComponent") as ResourceComponent
    _visible_then_fog(cell)
    var stage: Node3D = rc.get_active_stage_node()
    TestHelper.assert_true(_depot().has_ghost(tib), "tiberium ghosted in fog")
    TestHelper.assert_true(stage.get_parent() == _depot(), "harvest stage reparented to depot")
    _reveal(cell)
    _fr._sync_overlays()
    TestHelper.assert_true(not _depot().has_ghost(tib), "tiberium ghost released on reveal")
    TestHelper.assert_true(stage.get_parent() == tib, "stage restored to tiberium entity")
    _teardown()


func test_tiberium_harvest_under_fog_keeps_frozen_stage():
    _setup()
    var cell := Vector2i(40, 40)
    var tib := _make_tiberium_full(cell)
    var rc := tib.get_node("ResourceComponent") as ResourceComponent
    var stages: Array[Node3D] = rc._cube_nodes
    _visible_then_fog(cell)
    var frozen_stage: Node3D = rc.get_active_stage_node()
    TestHelper.assert_true(_depot().has_ghost(tib), "tiberium ghosted in fog")
    TestHelper.assert_true(frozen_stage == stages[2], "full stage frozen")
    TestHelper.assert_true(frozen_stage.get_parent() == _depot(), "stage reparented to depot")
    var collected := rc.collect(0.5)
    TestHelper.assert_true(collected == 0.5, "harvest under fog still collects")
    TestHelper.assert_eq(rc._current_visual_stage, 2, "stage index kept frozen in fog")
    TestHelper.assert_true(_depot().has_ghost(tib), "harvest does not release the ghost")
    TestHelper.assert_true(frozen_stage.get_parent() == _depot(), "frozen stage stays in depot")
    TestHelper.assert_true(frozen_stage.visible, "frozen stage keeps last-known visual")
    TestHelper.assert_true(not stages[1].visible, "reduced stage not shown while frozen")
    _reveal(cell)
    _fr._sync_overlays()
    TestHelper.assert_true(not _depot().has_ghost(tib), "ghost released on reveal")
    TestHelper.assert_eq(rc._current_visual_stage, 1, "stage snaps to live health on reveal")
    TestHelper.assert_true(stages[1].visible, "reduced stage shown after reveal")
    TestHelper.assert_true(not stages[2].visible, "full stage hidden after reveal")
    _teardown()


func test_tiberium_growth_under_fog_keeps_frozen_stage():
    _setup()
    var cell := Vector2i(40, 40)
    var tib := _make_tiberium_full(cell)
    var rc := tib.get_node("ResourceComponent") as ResourceComponent
    var hp := tib.get_node("HealthComponent") as HealthComponent
    hp.current_health = 90
    rc._update_visual()
    TestHelper.assert_eq(rc._current_visual_stage, 0, "staged at reduced health before fog")
    _visible_then_fog(cell)
    var frozen_stage: Node3D = rc.get_active_stage_node()
    TestHelper.assert_true(_depot().has_ghost(tib), "tiberium ghosted in fog")
    TestHelper.assert_true(frozen_stage == rc._cube_nodes[0], "stage 0 frozen")
    hp.heal(300)
    rc._update_visual()
    TestHelper.assert_eq(rc._current_visual_stage, 0, "growth does not advance frozen stage")
    TestHelper.assert_true(_depot().has_ghost(tib), "growth does not release the ghost")
    TestHelper.assert_true(frozen_stage.get_parent() == _depot(), "frozen stage stays in depot")
    TestHelper.assert_true(frozen_stage.visible, "frozen stage keeps last-known visual")
    TestHelper.assert_true(
        not (rc._cube_nodes[2] as Node3D).visible, "grown stage not shown under fog"
    )
    _reveal(cell)
    _fr._sync_overlays()
    TestHelper.assert_true(not _depot().has_ghost(tib), "ghost released on reveal")
    TestHelper.assert_eq(rc._current_visual_stage, 2, "stage snaps to grown health on reveal")
    TestHelper.assert_true((rc._cube_nodes[2] as Node3D).visible, "grown stage shown after reveal")
    TestHelper.assert_true(not frozen_stage.visible, "old reduced stage hidden after reveal")
    _teardown()


func test_tiberium_spawn_in_fog_stays_hidden_until_revealed():
    _setup()
    var cell := Vector2i(40, 40)
    var tib := _make_tiberium_unstaged(cell)
    var rc := tib.get_node("ResourceComponent") as ResourceComponent
    _enter_fog(cell)
    _fr._sync_overlays()
    TestHelper.assert_true(not _depot().has_ghost(tib), "spawn-in-fog crystal not frozen")
    TestHelper.assert_true(not tib.visible, "spawn-in-fog crystal hidden")
    var stages: Array[Node3D] = []
    for i in 3:
        var stage := Node3D.new()
        stage.name = "Stage%d" % i
        tib.add_child(stage)
        stages.append(stage)
    rc._cube_nodes = stages
    rc._current_visual_stage = 2
    for i in 3:
        stages[i].visible = (i == 2)
    _fr._sync_overlays()
    TestHelper.assert_true(
        not _depot().has_ghost(tib), "stage build does not freeze a never-seen crystal"
    )
    TestHelper.assert_true(not tib.visible, "never-seen crystal stays hidden once staged")
    _reveal(cell)
    _fr._sync_overlays()
    TestHelper.assert_true(tib.visible, "crystal visible once revealed")
    TestHelper.assert_true(not _depot().has_ghost(tib), "revealed crystal not frozen")
    _teardown()


func test_tiberium_spawn_in_fog_stays_hidden_through_shroud_change():
    _setup()
    var cell := Vector2i(40, 40)
    var other := Vector2i(44, 40)
    var tib := _make_tiberium(cell)
    _enter_fog(cell)
    _fr._sync_overlays()
    TestHelper.assert_true(not _depot().has_ghost(tib), "spawn-in-fog crystal not frozen")
    TestHelper.assert_true(not tib.visible, "spawn-in-fog crystal hidden")
    _enter_fog(other)
    TestHelper.assert_true(
        not _depot().has_ghost(tib), "unrelated shroud change does not freeze it"
    )
    TestHelper.assert_true(not tib.visible, "stays hidden through unrelated shroud change")
    _teardown()


func test_never_seen_crystal_destroyed_in_fog_leaves_no_ghost():
    _setup()
    var cell := Vector2i(40, 40)
    var tib := _make_tiberium(cell)
    _enter_fog(cell)
    _fr._sync_overlays()
    GhostDepot.capture_entity(tib)
    TestHelper.assert_true(not _depot().has_ghost(tib), "never-seen crystal leaves no death ghost")
    _teardown()


func test_overlay_resync_is_linear_and_gives_up_after_cap():
    _setup()
    var tibs: Array[Node3D] = [
        _make_tiberium_unstaged(Vector2i(40, 40)),
        _make_tiberium_unstaged(Vector2i(41, 40)),
        _make_tiberium_unstaged(Vector2i(40, 41)),
    ]
    var key := _reveal_key(Vector2i(40, 40))
    _fr._sync_overlays()
    ShroudSystem.unregister_revealer(0, key)
    _ss.resolve_dirty()
    _fr._sync_overlays()
    TestHelper.assert_true(
        _fr._overlay_resync_pending, "seen unstaged crystals share one pending flag"
    )
    TestHelper.assert_eq(_fr._overlay_resync_ticks, 1, "one resync tick per sweep, not per crystal")
    for i in _fr.MAX_OVERLAY_RESYNC_TICKS:
        _fr._sync_overlays()
    TestHelper.assert_true(
        not _fr._overlay_resync_pending, "resync sweep stops re-queueing after the cap"
    )
    _teardown()


func test_fallback_unit_frozen_in_fog():
    _setup()
    var cell := Vector2i(40, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell), 1)
    TestHelper.assert_true(_register(unit), "unit registered")
    var model := unit.get_node("ModelRoot") as Node3D
    _renderer._registry[unit]["slot"] = -1
    _enter_fog(cell)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(_depot().has_ghost(unit), "fallback unit ghosted in fog")
    TestHelper.assert_true(model.get_parent() == _depot(), "fallback model reparented")
    _reveal(cell)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(not _depot().has_ghost(unit), "fallback ghost released on reveal")
    TestHelper.assert_true(model.get_parent() == unit, "fallback model restored to entity")
    _teardown()


func test_fallback_unit_hidden_in_shroud():
    _setup()
    var cell := Vector2i(40, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell), 1)
    TestHelper.assert_true(_register(unit), "unit registered")
    _renderer._registry[unit]["slot"] = -1
    _renderer._physics_process(0.0)
    var model := unit.get_node("ModelRoot") as Node3D
    TestHelper.assert_true(not model.visible, "fallback unit model hidden in shroud")
    _teardown()


func test_post_destruction_building_ghost_released_on_reveal():
    _setup()
    var cell := Vector2i(40, 40)
    var building := _make_building(cell, 1, true)
    _enter_fog(cell)
    _fr._sync_buildings()
    GhostDepot.capture_entity(building)
    TestHelper.assert_true(_depot().has_ghost(building), "death keeps the frozen ghost")
    _reveal(cell)
    _fr._sync_buildings()
    TestHelper.assert_true(not _depot().has_ghost(building), "death ghost released on reveal")
    _teardown()


func test_post_destruction_tiberium_ghost():
    _setup()
    var cell := Vector2i(40, 40)
    var tib := _make_tiberium(cell)
    _visible_then_fog(cell)
    GhostDepot.capture_entity(tib)
    TestHelper.assert_true(_depot().has_ghost(tib), "killed tiberium keeps a ghost in fog")
    _reveal(cell)
    _fr._sync_overlays()
    TestHelper.assert_true(not _depot().has_ghost(tib), "tiberium ghost released on reveal")
    _teardown()


func test_unit_tombstone_survives_destruction_in_fog():
    _setup()
    var cell := Vector2i(40, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell), 1)
    TestHelper.assert_true(_register(unit), "unit registered")
    _enter_fog(cell)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(_renderer._registry[unit]["fogged"], "unit frozen before death")
    var key := unit.get_instance_id()
    _renderer.unregister(unit)
    TestHelper.assert_true(_renderer._tombstones.has(key), "destroyed frozen unit leaves tombstone")
    TestHelper.assert_eq(_renderer._active_count, 1, "tombstone slot retained")
    _reveal(cell)
    _renderer._reconcile(PackedInt32Array())
    TestHelper.assert_true(not _renderer._tombstones.has(key), "tombstone released on reveal")
    TestHelper.assert_eq(_renderer._active_count, 0, "slot freed after release")
    _teardown()


func test_unit_tombstone_released_on_shroud_revert():
    _setup()
    var cell := Vector2i(40, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell), 1)
    TestHelper.assert_true(_register(unit), "unit registered")
    _enter_fog(cell)
    _renderer._physics_process(0.0)
    var key := unit.get_instance_id()
    _renderer.unregister(unit)
    TestHelper.assert_true(_renderer._tombstones.has(key), "tombstone created")
    ShroudSystem.cover_shroud(0)
    _ss.resolve_dirty()
    _renderer._reconcile(PackedInt32Array())
    TestHelper.assert_true(
        not _renderer._tombstones.has(key), "tombstone released on shroud revert"
    )
    _teardown()


func test_fog_toggle_off_releases_all_ghosts():
    _setup()
    var cell := Vector2i(40, 40)
    var building := _make_building(cell, 1, true)
    _enter_fog(cell)
    _fr._sync_buildings()
    TestHelper.assert_true(_depot().has_ghost(building), "frozen before toggle")
    var rules := GlobalRules.get_current()
    rules.fog_of_war = false
    _renderer.sweep_ghosts()
    TestHelper.assert_true(not _depot().has_ghost(building), "all ghosts released on toggle-off")
    _teardown()


func test_assert_no_leaks_clean_after_reveal():
    _setup()
    var cell := Vector2i(40, 40)
    var building := _make_building(cell, 1, true)
    _enter_fog(cell)
    _fr._sync_buildings()
    _reveal(cell)
    _fr._sync_buildings()
    _renderer._reconcile(PackedInt32Array())
    TestHelper.assert_eq(_depot()._entries.size(), 0, "no ghost survives a clean reveal")
    _teardown()


func test_placeholder_unit_registers_slot_minus_one():
    _setup()
    var unit := _make_unit_with_player(CellUtil.cell_to_world(Vector2i(40, 40)), 1)
    TestHelper.assert_true(_register_placeholder(unit), "placeholder unit registers")
    var entry: Dictionary = _renderer._registry[unit]
    TestHelper.assert_eq(entry["slot"], -1, "placeholder gets no baked slot")
    _teardown()


func test_placeholder_unit_frozen_in_fog():
    _setup()
    var cell := Vector2i(40, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell), 1)
    TestHelper.assert_true(_register_placeholder(unit), "placeholder unit registers")
    var model := unit.get_node("ModelRoot") as Node3D
    TestHelper.assert_true(model.visible, "placeholder tree visible when registered")
    _enter_fog(cell)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(_renderer._registry[unit]["fogged"], "placeholder frozen in fog")
    TestHelper.assert_true(_depot().has_ghost(unit), "placeholder model reparented to depot")
    TestHelper.assert_true(model.get_parent() == _depot(), "placeholder model under depot")
    _reveal(cell)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(not _depot().has_ghost(unit), "placeholder released on reveal")
    TestHelper.assert_true(model.get_parent() == unit, "placeholder restored to entity")
    TestHelper.assert_true(model.visible, "placeholder visible again on reveal")
    _teardown()


func test_placeholder_unit_hidden_in_shroud():
    _setup()
    var unit := _make_unit_with_player(CellUtil.cell_to_world(Vector2i(40, 40)), 1)
    TestHelper.assert_true(_register_placeholder(unit), "placeholder unit registers")
    _renderer._physics_process(0.0)
    var model := unit.get_node("ModelRoot") as Node3D
    TestHelper.assert_true(not model.visible, "placeholder model hidden in unexplored shroud")
    _teardown()


func test_placeholder_unit_tombstone_survives_destruction_in_fog():
    _setup()
    var cell := Vector2i(40, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell), 1)
    TestHelper.assert_true(_register_placeholder(unit), "placeholder unit registers")
    _enter_fog(cell)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(_renderer._registry[unit]["fogged"], "frozen before death")
    var key := unit.get_instance_id()
    _renderer.unregister(unit)
    TestHelper.assert_true(_depot().has_ghost(unit), "destroyed frozen placeholder keeps a ghost")
    _reveal(cell)
    _renderer._reconcile(PackedInt32Array())
    TestHelper.assert_true(not _depot().has_ghost(unit), "placeholder death ghost released")
    _teardown()


func test_reveal_moved_entity_snaps_to_current_pose():
    _setup()
    var cell_a := Vector2i(40, 40)
    var cell_b := Vector2i(42, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell_a), 1)
    TestHelper.assert_true(_register_placeholder(unit), "placeholder unit registers")
    var model := unit.get_node("ModelRoot") as Node3D
    var original_local := model.transform
    _enter_fog(cell_a)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(_depot().has_ghost(unit), "unit frozen in fog")
    unit.global_position = CellUtil.cell_to_world(cell_b)
    _reveal(cell_a)
    _reveal(cell_b)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(not _depot().has_ghost(unit), "ghost released on reveal")
    TestHelper.assert_true(model.get_parent() == unit, "model restored to entity")
    TestHelper.assert_true(
        model.transform == original_local, "model local pose restored (no offset)"
    )
    (
        TestHelper
        . assert_true(
            model.global_position.distance_to(unit.global_position) < 0.01,
            "model sits on entity's current position, not the stale ghost pose",
        )
    )
    _teardown()


func test_reveal_moved_entity_keeps_hidden_in_shroud():
    _setup()
    var cell_a := Vector2i(40, 40)
    var cell_b := Vector2i(47, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell_a), 1)
    TestHelper.assert_true(_register_placeholder(unit), "placeholder unit registers")
    var model := unit.get_node("ModelRoot") as Node3D
    var original_local := model.transform
    _enter_fog(cell_a)
    _renderer._physics_process(0.0)
    unit.global_position = CellUtil.cell_to_world(cell_b)
    _reveal(cell_a)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(not _depot().has_ghost(unit), "ghost released when its cell is revealed")
    TestHelper.assert_true(model.get_parent() == unit, "model restored to entity")
    TestHelper.assert_true(
        model.transform == original_local, "model local pose restored (no offset)"
    )
    (
        TestHelper
        . assert_true(
            model.global_position.distance_to(unit.global_position) < 0.01,
            "model snapped to entity position (cell_b is unexplored shroud)",
        )
    )
    TestHelper.assert_true(not model.visible, "model hidden while entity is in unexplored shroud")
    _teardown()


func test_revealed_ghost_vanish_until_visible_node_tree():
    _setup()
    var cell_a := Vector2i(40, 40)
    var cell_b := Vector2i(47, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell_a), 1)
    TestHelper.assert_true(_register_placeholder(unit), "placeholder unit registers")
    var model := unit.get_node("ModelRoot") as Node3D
    _enter_fog(cell_a)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(_depot().has_ghost(unit), "unit frozen in fog")
    unit.global_position = CellUtil.cell_to_world(cell_b)
    _enter_fog(cell_b)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(_depot().has_ghost(unit), "ghost still frozen while entity in fog")
    _reveal(cell_a)
    _renderer._physics_process(0.0)
    var entry: Dictionary = _renderer._registry[unit]
    TestHelper.assert_true(entry["ghost_invalid"], "revealed ghost marked invalid")
    TestHelper.assert_true(not entry["fogged"], "revealed ghost no longer fogged")
    TestHelper.assert_true(not _depot().has_ghost(unit), "ghost fully released")
    TestHelper.assert_true(not model.visible, "model hidden after ghost reveal, no snap to entity")
    _reveal(cell_b)
    _renderer._physics_process(0.0)
    entry = _renderer._registry[unit]
    TestHelper.assert_true(not entry["ghost_invalid"], "flag cleared once entity visible")
    TestHelper.assert_true(not entry["fogged"], "entity not fogged while visible")
    TestHelper.assert_true(model.visible, "model visible again at entity's real position")
    _teardown()


func test_revealed_ghost_vanish_until_visible_multimesh():
    _setup()
    var cell_a := Vector2i(40, 40)
    var cell_b := Vector2i(47, 40)
    var unit := _make_unit_with_player(CellUtil.cell_to_world(cell_a), 1)
    TestHelper.assert_true(_register(unit), "unit registered with baked slot")
    var entry: Dictionary = _renderer._registry[unit]
    TestHelper.assert_true(entry["slot"] >= 0, "unit has a MultiMesh slot")
    _enter_fog(cell_a)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(entry["fogged"], "unit frozen in fog")
    unit.global_position = CellUtil.cell_to_world(cell_b)
    _enter_fog(cell_b)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(entry["fogged"], "still frozen while entity in fog")
    _reveal(cell_a)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(entry["ghost_invalid"], "revealed mesh ghost marked invalid")
    TestHelper.assert_true(not entry["fogged"], "revealed mesh ghost no longer fogged")
    _reveal(cell_b)
    _renderer._physics_process(0.0)
    TestHelper.assert_true(not entry["ghost_invalid"], "mesh flag cleared once entity visible")
    TestHelper.assert_true(not entry["fogged"], "mesh entity not fogged while visible")
    _teardown()
