# ponytail: thin data wrapper, grows when production queue logic is implemented
class_name FactoryComponent extends Node

@export var factory_type: String = ""
@export var free_unit: String = ""


func configure(data: EntityData) -> void:
    factory_type = data.factory
    free_unit = data.free_unit


func can_produce(entity_type: String) -> bool:
    return factory_type == entity_type
