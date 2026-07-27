class_name FoundationComponent extends Node

@export var foundation: Vector2i = Vector2i(1, 1)
@export var height: float = 1.0
@export var bib_cells: Array[Vector2i] = []


func configure(data: EntityData) -> void:
    foundation = data.foundation
    height = data.height
    bib_cells = data.bib_cells


func get_cell_count() -> int:
    return foundation.x * foundation.y


func get_foundation_cells(origin_cell: Vector2i) -> Array[Vector2i]:
    return FoundationComponent.footprint_cells(foundation, origin_cell)


func get_occupied_cells(origin_cell: Vector2i) -> Array[Vector2i]:
    return FoundationComponent.occupied_cells(foundation, bib_cells, origin_cell)


func get_bib_cells(origin_cell: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for offset in bib_cells:
        if offset.x >= 0 and offset.x < foundation.x and offset.y >= 0 and offset.y < foundation.y:
            cells.append(origin_cell + offset)
    return cells


func is_buildable(origin_cell: Vector2i) -> bool:
    return FoundationComponent.footprint_buildable(foundation, origin_cell)


# ========================================
# Canonical footprint math (static, callable from raw EntityData footprint
# during preview/validation before an entity instance exists)
# ========================================


static func footprint_cells(footprint: Vector2i, origin_cell: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for dx in footprint.x:
        for dz in footprint.y:
            cells.append(origin_cell + Vector2i(dx, dz))
    return cells


static func occupied_cells(
    footprint: Vector2i, bibs: Array[Vector2i], origin_cell: Vector2i
) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for dx in footprint.x:
        for dz in footprint.y:
            var offset := Vector2i(dx, dz)
            if not bibs.has(offset):
                cells.append(origin_cell + offset)
    return cells


static func is_cell_buildable(cell: Vector2i) -> bool:
    var sh := SpatialHash.instance
    if sh:
        if sh.get_building_cells().has(CellUtil.cell_key(cell)):
            return false
        if sh.is_cell_blocked(cell):
            return false
        if sh.is_any_entity_on_cell(cell):
            return false
        if sh.is_bib_cell(cell):
            return false
        if sh.has_resource_cell(cell):
            return false
    var cell_type := TerrainSystem.get_cell_type(cell)
    return cell_type == "" or cell_type == "clear"


static func footprint_buildable(footprint: Vector2i, origin_cell: Vector2i) -> bool:
    var min_h := INF
    var max_h := -INF
    for dx in footprint.x:
        for dz in footprint.y:
            var cell := origin_cell + Vector2i(dx, dz)
            if not FoundationComponent.is_cell_buildable(cell):
                return false
            var h := TerrainSystem.get_cell_max_height(cell)
            min_h = minf(min_h, h)
            max_h = maxf(max_h, h)
    if min_h != INF and (max_h - min_h) > TerrainSystem.HEIGHT_STEP:
        return false
    return true
