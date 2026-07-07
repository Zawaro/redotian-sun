# ponytail: stub with no callers — delete when map override system is implemented
class_name MapOverride extends Resource

## TODO: Map/mission override system — implement in later phase
## This stub exists to support the entity system design.
## Maps will reference base EntityData and override specific fields.

@export var entity_id: String = ""
@export var overrides: Dictionary = {}
@export var art_overrides: Dictionary = {}


func apply_to(base_data: EntityData) -> EntityData:
    var merged := base_data.duplicate() as EntityData
    for key in overrides:
        merged.set(key, overrides[key])
    return merged
