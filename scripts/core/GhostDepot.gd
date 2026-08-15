class_name GhostDepot extends Node3D

## Holds frozen "last-known" visuals for entities in fog. A ghost is the
## entity's own visual node (reparented in on fog entry) or a MultiMesh
## tombstone tracked by UnitMeshRenderer. Ghost existence is derived from the
## fog grid: a ghost is valid only while its anchor cell is fog (explored but
## not visible). Release on reveal, shroud-revert, fog toggle-off, grid reinit,
## and teardown is driven by the reconcile sweep and release_all().

var _entries: Dictionary = {}


static func get_instance() -> GhostDepot:
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        return null
    var umr := tree.root.get_node_or_null("UnitMeshRenderer")
    if umr == null:
        return null
    return umr.get_node_or_null("GhostDepot") as GhostDepot


## Freezes a living entity's visual into the depot (fog entry / async model
## load). `dead` marks a post-destruction ghost that must be freed, never
## reparented back, on release.
func reparent_in(
    source: Node3D,
    visual: Node3D,
    original_parent: Node,
    cell: Vector2i,
    dead: bool = false,
) -> void:
    if not is_instance_valid(source) or not is_instance_valid(visual):
        return
    var key := source.get_instance_id()
    var entry: Dictionary = _entries.get(key, {})
    if not entry.is_empty():
        entry["dead"] = entry["dead"] or dead
        entry["cell"] = cell
        return
    var original_local := visual.transform
    visual.reparent(self, true)
    _entries[key] = {
        "source": source,
        "visual": visual,
        "original_parent": original_parent,
        "cell": cell,
        "dead": dead,
        "local_transform": original_local,
    }


func mark_dead(source: Node3D) -> void:
    if not is_instance_valid(source):
        return
    var entry: Dictionary = _entries.get(source.get_instance_id(), {})
    if not entry.is_empty():
        entry["dead"] = true


func has_ghost(source: Node3D) -> bool:
    if not is_instance_valid(source):
        return false
    return _entries.has(source.get_instance_id())


func release_entry(source: Node3D) -> void:
    if is_instance_valid(source):
        _release_key(source.get_instance_id())


## Releases every ghost whose anchor cell is no longer fog (became visible or
## reverted to shroud). The reconcile sweep runs this on state_changed.
func release_unfogged() -> void:
    var local := PlayerManager.get_local_player_id()
    for key in _entries.keys():
        var cell: Vector2i = _entries[key]["cell"]
        if (
            not ShroudSystem.is_cell_visible_to_local(cell)
            and ShroudSystem.is_explored(local, cell)
        ):
            continue
        _release_key(key)


func release_all() -> void:
    for key in _entries.keys():
        _release_key(key)


func assert_no_leaks() -> void:
    for key in _entries.keys():
        var entry: Dictionary = _entries[key]
        if not entry["dead"] and not is_instance_valid(entry["source"]):
            push_error("GhostDepot: live ghost lost its source")
        var cell: Vector2i = entry["cell"]
        if ShroudSystem.is_cell_visible_to_local(cell):
            push_error("GhostDepot: ghost in visible cell")


func _release_key(key: int) -> void:
    var entry: Dictionary = _entries.get(key, {})
    if entry.is_empty():
        return
    _entries.erase(key)
    var visual: Node3D = entry["visual"]
    if entry["dead"] or not is_instance_valid(entry["original_parent"]):
        if is_instance_valid(visual):
            visual.queue_free()
        return
    if is_instance_valid(visual):
        # Snap back to the original local pose (keep_global_transform=false so
        # the visual lands on the entity's CURRENT transform, not the stale
        # ghost pose — a preserve-global release would leave a huge local offset
        # that drifts/slides as the entity keeps moving).
        visual.reparent(entry["original_parent"], false)
        visual.transform = entry["local_transform"]
    # A released tiberium ghost hands the harvest-stage container back; re-apply
    # the live stage (health may have changed while the visual was frozen).
    var source: Node3D = entry["source"]
    if is_instance_valid(source):
        var rc := source.get_node_or_null("ResourceComponent") as ResourceComponent
        if rc:
            rc.refresh_visual()


## Shared death capture: an entity removed while its cell is fog keeps its
## frozen ghost as a post-destruction tombstone. An entity that was never
## frozen (e.g. tiberium that spawned into fog, never revealed) has no
## last-known visual and leaves nothing. Units are excluded (they use MultiMesh
## tombstones via UnitMeshRenderer).
static func capture_entity(entity: Node3D) -> void:
    if not is_instance_valid(entity):
        return
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    if stats == null:
        return
    var etype := stats.entity_type
    if etype == EntityData.EntityType.INFANTRY:
        return
    if etype == EntityData.EntityType.VEHICLE:
        return
    if etype == EntityData.EntityType.AIRCRAFT:
        return
    if not _in_fog(entity):
        return
    var depot := get_instance()
    if depot == null:
        return
    if depot.has_ghost(entity):
        depot.mark_dead(entity)


## True when the local player considers `entity` fogged (enemy or player-less,
## explored cell, not visible) and the fog layer is active.
static func is_frozen_candidate(entity: Node3D) -> bool:
    if not is_instance_valid(entity):
        return false
    if not ShroudSystem.is_fog_enabled():
        return false
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    if stats == null:
        return false
    var player_id: int = stats.player_id
    if player_id >= 0:
        if not PlayerManager.is_enemy(PlayerManager.get_local_player_id(), player_id):
            return false
    return _in_fog(entity)


static func _in_fog(entity: Node3D) -> bool:
    return ShroudSystem.cell_state_to_local(_cell_of(entity)) == ShroudSystem.STATE_FOG


static func _cell_of(entity: Node3D) -> Vector2i:
    return CellUtil.world_to_cell(entity.global_position)
