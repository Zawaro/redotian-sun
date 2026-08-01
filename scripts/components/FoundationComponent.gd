class_name FoundationComponent extends Node

@export var foundation: Vector2i = Vector2i(1, 1)
@export var height: float = 1.0
@export var bib_cells: Array[Vector2i] = []

var _registered_cells: Array[Vector2i] = []
var _registered_bib_cells: Array[Vector2i] = []


func _ready() -> void:
    if Engine.is_editor_hint():
        return
    var entity := get_parent() as Node3D
    if not entity:
        return
    if entity.has_meta("_preview") or entity.process_mode == Node.PROCESS_MODE_DISABLED:
        return
    # Only buildings register building cells — vehicles/infantry should not.
    var stats := entity.get_node_or_null("StatsComponent") as StatsComponent
    if stats and stats.entity_type != EntityData.EntityType.BUILDING:
        return
    if not SpatialHash.instance:
        return
    var origin_cell := CellUtil.world_to_cell_origin(entity.global_position, foundation)
    _registered_cells = get_foundation_cells(origin_cell)
    _registered_bib_cells = get_bib_cells(origin_cell)
    # Bib cells are the walkable pad in front of the building (e.g. the refinery
    # dock) — dockers must path onto them, so they are NOT blocked building
    # cells. Register only the non-bib foundation cells as blocked, matching
    # BuildingManager.place_building.
    var non_bib_cells: Array[Vector2i] = _registered_cells.duplicate()
    for bib in _registered_bib_cells:
        non_bib_cells.erase(bib)
    SpatialHash.instance.register_building_cells(non_bib_cells)
    if not _registered_bib_cells.is_empty():
        SpatialHash.instance.register_bib_cells(_registered_bib_cells)


func _exit_tree() -> void:
    if not SpatialHash.instance:
        return
    if not _registered_cells.is_empty():
        SpatialHash.instance.unregister_building_cells(_registered_cells)
    if not _registered_bib_cells.is_empty():
        SpatialHash.instance.unregister_bib_cells(_registered_bib_cells)


func configure(data: EntityData) -> void:
    foundation = data.foundation
    height = data.height
    bib_cells = data.bib_cells


func get_cell_count() -> int:
    return foundation.x * foundation.y


func get_foundation_cells(origin_cell: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for dx in foundation.x:
        for dz in foundation.y:
            cells.append(origin_cell + Vector2i(dx, dz))
    return cells


func get_bib_cells(origin_cell: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for offset in bib_cells:
        if offset.x >= 0 and offset.x < foundation.x and offset.y >= 0 and offset.y < foundation.y:
            cells.append(origin_cell + offset)
    return cells
