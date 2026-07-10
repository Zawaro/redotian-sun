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
