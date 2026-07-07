# ponytail: thin data wrapper, grows when passenger boarding/harvesting logic is implemented
class_name TransportComponent extends Node

@export var passengers: int = 0
@export var dock: String = ""
@export var harvester: bool = false
@export var storage: int = 0
@export var pip_scale: String = ""


func configure(data: EntityData) -> void:
    passengers = data.passengers
    dock = data.dock
    harvester = data.harvester
    storage = data.storage
    pip_scale = data.pip_scale


func can_carry() -> bool:
    return passengers > 0


func is_harvester() -> bool:
    return harvester
