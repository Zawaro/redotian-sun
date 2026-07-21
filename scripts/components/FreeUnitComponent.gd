class_name FreeUnitComponent extends Node

@export var free_unit_id: String = ""

const RETRY_INTERVAL: float = 2.0
var _retry_timer: float = 0.0
var _retrying: bool = false


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    if get_parent().get_meta("_preview", false):
        return
    if free_unit_id.is_empty():
        queue_free()
        return
    call_deferred("_spawn_free_unit")


func _process(delta: float) -> void:
    if not _retrying:
        return
    _retry_timer -= delta
    if _retry_timer <= 0.0:
        _retrying = false
        _spawn_free_unit()


func _spawn_free_unit() -> void:
    var parent := get_parent() as Node3D
    if not parent:
        queue_free()
        return

    var cell := Pathfinder.world_to_cell(parent.global_position)
    var foundation := Vector2i(1, 1)
    var found := _find_adjacent_free_cell(cell, foundation)
    if found == Vector2i(-1, -1):
        _retrying = true
        _retry_timer = RETRY_INTERVAL
        return

    var free_entity := EntityFactory.create_entity(free_unit_id)
    if not free_entity:
        _retrying = true
        _retry_timer = RETRY_INTERVAL
        return

    var stats := free_entity.get_node_or_null("StatsComponent") as StatsComponent
    if stats:
        var parent_stats := parent.get_node_or_null("StatsComponent") as StatsComponent
        if parent_stats:
            stats.player_id = parent_stats.player_id

    var world_pos := Pathfinder.cell_to_world(found)
    free_entity.position = world_pos
    parent.get_parent().add_child(free_entity)

    var harvest := free_entity.get_node_or_null("HarvestComponent") as HarvestComponent
    if harvest:
        var resource := harvest._find_nearest_resource(free_entity.global_position)
        if resource:
            harvest.set_target_node(resource)

    queue_free()


func _find_adjacent_free_cell(origin: Vector2i, _foundation: Vector2i) -> Vector2i:
    for radius in range(1, 6):
        for dx in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                if abs(dx) != radius and abs(dz) != radius:
                    continue
                var cell := origin + Vector2i(dx, dz)
                var key := SpatialHash.instance._cell_key(cell)
                if SpatialHash.instance and SpatialHash.instance.get_building_cells().has(key):
                    continue
                if SpatialHash.instance and SpatialHash.instance.is_cell_blocked(cell):
                    continue
                if SpatialHash.instance and SpatialHash.instance._reserved.has(key):
                    continue
                var cell_type := TerrainSystem.get_cell_type(cell)
                if cell_type != "" and cell_type != "clear":
                    continue
                return cell
    return Vector2i(-1, -1)
